"""Plans, Stripe Checkout, customer portal and webhooks.

Configure with environment variables:
  STRIPE_SECRET_KEY        sk_live_... / sk_test_...
  STRIPE_PRICE_STARTER     price_... (recurring monthly)
  STRIPE_PRICE_PRO         price_... (recurring monthly)
  STRIPE_WEBHOOK_SECRET    whsec_...  (endpoint: POST /api/billing/webhook)
  PUBLIC_URL               https://yourdomain.com  (used for return URLs)
Without them the site still works; paid plans just can't be purchased.
"""
from __future__ import annotations

import json
import os
from typing import Optional

import stripe

from . import db

PLANS = {
    "free":    {"label": "Free",    "price": 0,     "edits": 3,  "watermark": True,  "max_clips": 6,  "max_seconds": 30},
    "starter": {"label": "Starter", "price": 19.99, "edits": 10, "watermark": False, "max_clips": 15, "max_seconds": 60},
    "pro":     {"label": "Pro",     "price": 39.99, "edits": 30, "watermark": False, "max_clips": 20, "max_seconds": 60},
}
ACTIVE = {"active", "trialing", "past_due"}


def _prices() -> dict[str, str]:
    return {"starter": os.environ.get("STRIPE_PRICE_STARTER", ""), "pro": os.environ.get("STRIPE_PRICE_PRO", "")}


def enabled() -> bool:
    return bool(os.environ.get("STRIPE_SECRET_KEY") and all(_prices().values()))


def _price_to_plan(price_id: str) -> Optional[str]:
    return next((p for p, pid in _prices().items() if pid and pid == price_id), None)


def public_plans() -> list[dict]:
    return [{"id": k, **v} for k, v in PLANS.items()]


def create_checkout(user, plan: str, base_url: str) -> str:
    if not enabled():
        raise RuntimeError("Billing is not configured on this server.")
    if plan not in ("starter", "pro"):
        raise ValueError("Unknown plan")
    stripe.api_key = os.environ["STRIPE_SECRET_KEY"]
    meta = {"user_id": str(user["id"]), "plan": plan}
    kwargs = dict(
        mode="subscription",
        line_items=[{"price": _prices()[plan], "quantity": 1}],
        client_reference_id=str(user["id"]),
        metadata=meta,
        subscription_data={"metadata": meta},
        success_url=f"{base_url}/?billing=success",
        cancel_url=f"{base_url}/?billing=cancelled",
        allow_promotion_codes=True,
    )
    if user["stripe_customer"]:
        kwargs["customer"] = user["stripe_customer"]
    else:
        kwargs["customer_email"] = user["email"]
    return stripe.checkout.Session.create(**kwargs).url


def create_portal(user, base_url: str) -> str:
    if not enabled() or not user["stripe_customer"]:
        raise RuntimeError("No active subscription to manage.")
    stripe.api_key = os.environ["STRIPE_SECRET_KEY"]
    return stripe.billing_portal.Session.create(customer=user["stripe_customer"], return_url=base_url).url


def handle_webhook(payload: bytes, sig_header: str) -> str:
    """Verify + apply a Stripe event. Raises ValueError on a bad signature."""
    secret = os.environ.get("STRIPE_WEBHOOK_SECRET", "")
    if not secret:
        raise ValueError("Webhook secret not configured")
    try:
        stripe.Webhook.construct_event(payload, sig_header, secret)   # verifies signature + timestamp
    except Exception as e:
        raise ValueError(f"Invalid signature: {type(e).__name__}")
    ev = json.loads(payload)
    if not db.mark_event(ev["id"]):
        return "duplicate"
    obj = ev["data"]["object"]
    etype = ev["type"]

    def resolve_user():
        uid = (obj.get("metadata") or {}).get("user_id") or obj.get("client_reference_id")
        if uid and str(uid).isdigit():
            u = db.get_user(int(uid))
            if u:
                return u
        if obj.get("customer"):
            return db.find_user_by_customer(obj["customer"])
        return None

    if etype == "checkout.session.completed" and obj.get("mode") == "subscription":
        u = resolve_user()
        plan = (obj.get("metadata") or {}).get("plan")
        if u and plan in PLANS:
            db.set_plan(u["id"], plan, customer=obj.get("customer"), sub=obj.get("subscription"), status="active")
            return "plan set"
    elif etype in ("customer.subscription.updated", "customer.subscription.created"):
        u = resolve_user()
        if u:
            items = (obj.get("items") or {}).get("data") or []
            price_id = ((items[0].get("price") or {}).get("id")) if items else None
            plan = (obj.get("metadata") or {}).get("plan") or _price_to_plan(price_id or "") or u["plan"]
            status = obj.get("status")
            db.set_plan(u["id"], plan if status in ACTIVE else "free", customer=obj.get("customer"),
                        sub=obj.get("id"), status=status)
            return "subscription synced"
    elif etype == "customer.subscription.deleted":
        u = resolve_user()
        if u:
            db.set_plan(u["id"], "free", status="canceled")
            return "downgraded"
    return "ignored"

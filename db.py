"""Tiny SQLite layer: users, sessions, monthly usage, processed webhook events."""
from __future__ import annotations

import hashlib
import hmac
import os
import secrets
import sqlite3
import time
from contextlib import contextmanager
from pathlib import Path
from typing import Optional

_path: Optional[Path] = None

SCHEMA = """
CREATE TABLE IF NOT EXISTS users(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  email TEXT UNIQUE NOT NULL,
  pw TEXT NOT NULL,
  created REAL NOT NULL,
  plan TEXT NOT NULL DEFAULT 'free',
  stripe_customer TEXT,
  stripe_sub TEXT,
  sub_status TEXT
);
CREATE TABLE IF NOT EXISTS sessions(
  token TEXT PRIMARY KEY,
  user_id INTEGER NOT NULL,
  expires REAL NOT NULL
);
CREATE TABLE IF NOT EXISTS usage(
  user_id INTEGER NOT NULL,
  month TEXT NOT NULL,
  count INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY(user_id, month)
);
CREATE TABLE IF NOT EXISTS events(id TEXT PRIMARY KEY, seen REAL NOT NULL);
"""


def init(data_dir: Path) -> None:
    global _path
    _path = Path(data_dir) / "recut.db"
    with conn() as c:
        c.executescript(SCHEMA)


@contextmanager
def conn():
    c = sqlite3.connect(_path, timeout=15)
    c.row_factory = sqlite3.Row
    try:
        yield c
        c.commit()
    finally:
        c.close()


# ------------------------------------------------------------------ passwords
def hash_pw(pw: str) -> str:
    salt = os.urandom(16)
    h = hashlib.scrypt(pw.encode(), salt=salt, n=2 ** 14, r=8, p=1, dklen=32)
    return f"scrypt${salt.hex()}${h.hex()}"


def check_pw(pw: str, stored: str) -> bool:
    try:
        _, salt, h = stored.split("$")
        calc = hashlib.scrypt(pw.encode(), salt=bytes.fromhex(salt), n=2 ** 14, r=8, p=1, dklen=32)
        return hmac.compare_digest(calc.hex(), h)
    except Exception:
        return False


# ---------------------------------------------------------------------- users
def create_user(email: str, pw: str) -> int:
    with conn() as c:
        try:
            cur = c.execute("INSERT INTO users(email, pw, created) VALUES(?,?,?)",
                            (email, hash_pw(pw), time.time()))
        except sqlite3.IntegrityError:
            raise ValueError("exists")
        return int(cur.lastrowid)


def get_user(user_id: int) -> Optional[sqlite3.Row]:
    with conn() as c:
        return c.execute("SELECT * FROM users WHERE id=?", (user_id,)).fetchone()


def get_user_by_email(email: str) -> Optional[sqlite3.Row]:
    with conn() as c:
        return c.execute("SELECT * FROM users WHERE email=?", (email,)).fetchone()


def find_user_by_customer(customer: str) -> Optional[sqlite3.Row]:
    with conn() as c:
        return c.execute("SELECT * FROM users WHERE stripe_customer=?", (customer,)).fetchone()


def set_plan(user_id: int, plan: str, customer: Optional[str] = None, sub: Optional[str] = None,
             status: Optional[str] = None) -> None:
    with conn() as c:
        c.execute("UPDATE users SET plan=?, stripe_customer=COALESCE(?, stripe_customer), "
                  "stripe_sub=COALESCE(?, stripe_sub), sub_status=COALESCE(?, sub_status) WHERE id=?",
                  (plan, customer, sub, status, user_id))


# ------------------------------------------------------------------- sessions
def _h(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()


def create_session(user_id: int, days: int = 30) -> str:
    token = secrets.token_urlsafe(32)
    with conn() as c:
        c.execute("DELETE FROM sessions WHERE expires < ?", (time.time(),))
        c.execute("INSERT INTO sessions(token, user_id, expires) VALUES(?,?,?)",
                  (_h(token), user_id, time.time() + days * 86400))
    return token


def session_user(token: str) -> Optional[sqlite3.Row]:
    with conn() as c:
        return c.execute("SELECT u.* FROM sessions s JOIN users u ON u.id=s.user_id "
                         "WHERE s.token=? AND s.expires>?", (_h(token), time.time())).fetchone()


def delete_session(token: str) -> None:
    with conn() as c:
        c.execute("DELETE FROM sessions WHERE token=?", (_h(token),))


# ---------------------------------------------------------------------- usage
def month() -> str:
    return time.strftime("%Y-%m")


def used(user_id: int) -> int:
    with conn() as c:
        r = c.execute("SELECT count FROM usage WHERE user_id=? AND month=?", (user_id, month())).fetchone()
        return int(r["count"]) if r else 0


def add_usage(user_id: int, delta: int = 1) -> None:
    with conn() as c:
        c.execute("INSERT INTO usage(user_id, month, count) VALUES(?,?,MAX(0,?)) "
                  "ON CONFLICT(user_id, month) DO UPDATE SET count=MAX(0, count+?)",
                  (user_id, month(), delta, delta))


# --------------------------------------------------------------------- events
def mark_event(event_id: str) -> bool:
    """True if this webhook event is new (and is now recorded), False if already processed."""
    with conn() as c:
        cur = c.execute("INSERT OR IGNORE INTO events(id, seen) VALUES(?,?)", (event_id, time.time()))
        return cur.rowcount == 1

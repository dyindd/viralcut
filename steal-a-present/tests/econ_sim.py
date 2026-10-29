#!/usr/bin/env python3
"""Economy pacing sim that reads the REAL Config.lua / Catalog.lua (via lupa)."""
import random, statistics, os, sys
from lupa import LuaRuntime
os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
L = LuaRuntime(unpack_returned_tuples=True)
L.execute('local m = dofile("tests/mock.lua"); CFG = require(m.folder("src/shared").Config); CAT = require(m.folder("src/shared").Catalog)')
CFG = L.globals().CFG; CAT = L.globals().CAT
TIERS=[]
for i in range(1, len(list(CFG.BoxTiers.values()))+1):
    t = CFG.BoxTiers[i]
    if t.SpawnWeight > 0:
        TIERS.append((t.Key, t.Price, t.Strength, {k:v for k,v in t.Odds.items()}))
INCOME={}
for i in range(1, len(list(CAT.Presents.values()))+1):
    p = CAT.Presents[i]
    INCOME.setdefault(p.Rarity, []).append(p.Income)
MUT=[("None",1,0)]
tot=0
for k in ["Golden","Frosted","CandyCane","Rainbow","Galaxy"]:
    m=CAT.Mutations[k]; MUT.append((k,m.Multiplier,m.Chance)); tot+=m.Chance
MUT[0]=("None",1,100-tot)
REBIRTH_COST=CFG.Rebirth.BaseCost; SLOTS=CFG.Plots.StartingSlots; SELL=CFG.SellSeconds
TRIP=float(sys.argv[1]) if len(sys.argv)>1 else 24.0
TRAIN=CFG.Strength.GainPerSecond

def roll(odds):
    r=random.random()*100; acc=0; last=None
    for k,v in odds.items():
        acc+=v; last=k
        if r<=acc: return k
    return last

def sim(seed, minutes=180):
    random.seed(seed); cash=50.0; strength=0.0; presents=[]; t=0.0; firsts={}; rebirth_at=None; coal=0; boxes=0
    while t<minutes*60:
        income=sum(presents)
        choice=None
        for key,price,need,odds in TIERS:
            if cash>=price and strength>=need: choice=(key,price,need,odds)
        nxt=None
        for key,price,need,odds in TIERS:
            if cash>=price and strength<need: nxt=(key,price,need); break
        if nxt and (choice is None or [x[0] for x in TIERS].index(choice[0]) < [x[0] for x in TIERS].index(nxt[0])):
            dt=min(20.0,(nxt[2]-strength)/TRAIN+0.01); strength+=TRAIN*dt; cash+=income*dt; t+=dt; continue
        if choice is None:
            cash+=income*5; t+=5; continue
        key,price,need,odds=choice
        cash-=price; cash+=income*TRIP; t+=TRIP; boxes+=1
        rarity=roll(odds)
        if rarity=="Coal": coal+=1; continue
        val=random.choice(INCOME[rarity])
        m=roll({k:w for k,_,w in MUT}); val*=next(x[1] for x in MUT if x[0]==m)
        if rarity not in firsts: firsts[rarity]=t
        if len(presents)>=SLOTS:
            worst=min(presents)
            if val>worst: presents.remove(worst); cash+=worst*SELL; presents.append(val)
            else: cash+=val*SELL
        else: presents.append(val)
        if rebirth_at is None and cash>=REBIRTH_COST: rebirth_at=t
    return firsts, rebirth_at, sum(presents), boxes

runs=[sim(s) for s in range(300)]
print(f"TRIP={TRIP}s  tiers={[t[0] for t in TIERS]}")
for k in ["Uncommon","Rare","Epic","Legendary","Mythic","Secret"]:
    vals=[r[0][k] for r in runs if k in r[0]]
    print(f"first {k:9s}: median {round(statistics.median(vals)/60,1) if vals else None} min  ({len(vals)}/300 within 3h)")
rb=[r[1] for r in runs if r[1]]
if rb: print(f"first rebirth (${REBIRTH_COST}): median {statistics.median(rb)/60:.1f} min, p10 {sorted(rb)[len(rb)//10]/60:.1f}, p90 {sorted(rb)[len(rb)*9//10]/60:.1f}  ({len(rb)}/300 within 3h)")
print(f"income at 3h: median ${statistics.median([r[2] for r in runs]):.0f}/s ; boxes bought median {statistics.median([r[3] for r in runs])}")

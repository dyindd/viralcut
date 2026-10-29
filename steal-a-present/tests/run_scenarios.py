#!/usr/bin/env python3
"""Boots the real server (and client) inside the headless engine and runs tests/scenarios.lua.
Usage: python3 tests/run_scenarios.py   (needs: pip install lupa)"""
import os, sys
from lupa import LuaRuntime
os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
L = LuaRuntime(unpack_returned_tuples=True)
files = []
for dp, _, fns in os.walk("src"):
    for fn in fns:
        if fn.endswith(".lua"):
            files.append(os.path.join(dp, fn).replace(os.sep, "/"))
L.globals().ENGINE_FILES = L.table_from(sorted(files))
try:
    L.execute(open("tests/scenarios.lua", encoding="utf-8").read())
except Exception as e:
    print(e)
    sys.exit(1)

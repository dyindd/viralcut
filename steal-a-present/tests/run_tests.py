#!/usr/bin/env python3
"""Runs tests/tests.lua with a real Lua VM (pip install lupa). Usage: python3 tests/run_tests.py"""
import os, sys
from lupa import LuaRuntime
os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
L = LuaRuntime(unpack_returned_tuples=True)
try:
    L.execute(open("tests/tests.lua", encoding="utf-8").read())
except Exception as e:
    print(e)
    sys.exit(1)

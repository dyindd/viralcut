#!/usr/bin/env python3
"""Paste image ids into src/shared/Icons.lua from a text list.
Make the list in Studio after Bulk Import + Insert: with the Decals inside ReplicatedStorage.Icons, run
this in the Command Bar and copy the Output:
  local out={} for _,d in ipairs(game.ReplicatedStorage.Icons:GetChildren()) do local id=(tostring(d.Texture or d.Value or "")):match("%d+") if id then table.insert(out,d.Name.." = "..id) end end print(table.concat(out,"\n"))
Then:  python3 tools/apply_ids.py ids.txt
Lines look like:  present_TeddyBear = 123456789
"""
import re, sys, os
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
ICONS = os.path.join(ROOT, "src", "shared", "Icons.lua")
PREFIX = {"ui_": "UI", "cur_": "Currency", "box_": "Boxes", "trap_": "Traps", "mut_": "Mutations", "pass_": "Passes", "prod_": "Products", "present_": "Presents", "wrapping_": "Textures", "tool_": "Tools"}
src = open(ICONS, encoding="utf-8").read()
written = 0
for line in open(sys.argv[1], encoding="utf-8"):
    m = re.match(r"\s*([\w\.]+?)(?:\.png)?\s*[=:,\t ]\s*(\d+)\s*$", line)
    if not m:
        continue
    name, asset_id = m.group(1), m.group(2)
    for prefix, section in PREFIX.items():
        if name.startswith(prefix):
            key = name[len(prefix):]
            block = re.search(r"(Icons\.%s = \{)(.*?)(\n\})" % section, src, re.S)
            if block:
                body, n = re.subn(r"(\n\t%s = )\d+," % re.escape(key), r"\g<1>%s," % asset_id, block.group(2))
                if n:
                    src = src[:block.start(2)] + body + src[block.end(2):]
                    written += 1
            break
open(ICONS, "w", encoding="utf-8").write(src)
print(f"wrote {written} ids into {ICONS}")

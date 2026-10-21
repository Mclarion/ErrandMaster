"""Collect isolated Lua test failures without stopping at the first legacy expectation."""
import ast
import re
import sys
from pathlib import Path
sys.path.insert(0,'.testdeps')
from lupa.lua51 import LuaRuntime
text=Path('tests/run_tests.py').read_text()
body=text.split('for script in (',1)[1].split('):\n    LuaRuntime()',1)[0]
scripts=ast.literal_eval('('+body+')')
failed=[]
for script in scripts:
    try:
        LuaRuntime().execute('dofile("tests/'+script+'")')
    except Exception as exc:
        lines=str(exc).splitlines()
        failed.append((script, lines[0]))
print('\nFAILURES',len(failed),'of',len(scripts))
for script,message in failed:
    print(script+': '+message)
if failed: raise SystemExit(1)

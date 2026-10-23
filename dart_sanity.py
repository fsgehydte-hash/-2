"""فحص بدائي لملفات Dart (توازن الأقواس وتحقق مسارات الاستيراد). ليس مترجماً ولا يغني عن flutter analyze/test."""
import pathlib, re, sys
APP = pathlib.Path(__file__).resolve().parent.parent / "app"
bad = 0
def strip(src):
    out, i, n = [], 0, len(src)
    while i < n:
        c = src[i]
        if src.startswith("//", i):
            while i < n and src[i] != "\n": i += 1
        elif src.startswith("/*", i):
            j = src.find("*/", i + 2); i = n if j < 0 else j + 2
        elif c in "'\"":
            q = "".join([c] * 3) if src.startswith(c * 3, i) else c
            i += len(q)
            while i < n and not src.startswith(q, i):
                i += 2 if src[i] == "\\" else 1
            i += len(q)
        else:
            out.append(c); i += 1
    return "".join(out)
for f in sorted(APP.rglob("*.dart")):
    raw = f.read_text(encoding="utf-8"); s = strip(raw)
    stack, pairs = [], {")": "(", "]": "[", "}": "{"}
    for ch in s:
        if ch in "([{": stack.append(ch)
        elif ch in ")]}":
            if not stack or stack.pop() != pairs[ch]: print("UNBALANCED", f); bad += 1; break
    else:
        if stack: print("UNCLOSED", f); bad += 1
    for imp in re.findall(r"^import '([^']+)'", raw, re.M):
        if imp.startswith("package:rayhana_app/"): tgt = APP / "lib" / imp[len("package:rayhana_app/"):]
        elif imp.startswith(("package:", "dart:")): continue
        else: tgt = (f.parent / imp).resolve()
        if not tgt.exists(): print("MISSING IMPORT", f.name, imp); bad += 1
print("dart files:", len(list(APP.rglob("*.dart"))), "problems:", bad)
sys.exit(1 if bad else 0)

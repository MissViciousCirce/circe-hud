"""Build a reproducible source/package ZIP without saves, logs or Git history."""
from pathlib import Path
import hashlib
import json
import zipfile

root = Path(__file__).resolve().parents[1]
version = "0.1.3-alpha"
payload = root / "CirceHUD"
files = [{"Path": p.relative_to(payload).as_posix(),
          "SHA256": hashlib.sha256(p.read_bytes()).hexdigest().upper()}
         for p in sorted(payload.rglob("*")) if p.is_file()]
(root / "manifest.json").write_bytes((json.dumps({"Version": version, "Files": files}, indent=2) + "\n").encode())
archive = root.parent / ("CirceHUD-" + version + ".zip")
allowed_roots = {"CirceHUD", "tools", "tests"}
allowed_files = {"README.md", "LICENSE", "Install.ps1", "manifest.json", ".gitignore", ".gitattributes"}
with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as z:
    for path in sorted(root.rglob("*")):
        rel = path.relative_to(root)
        if not path.is_file() or "__pycache__" in rel.parts:
            continue
        if rel.parts[0] not in allowed_roots and rel.as_posix() not in allowed_files:
            continue
        item = zipfile.ZipInfo("CirceHUD-Standalone/" + rel.as_posix(), (2026, 10, 17, 0, 0, 0))
        item.compress_type = zipfile.ZIP_DEFLATED
        z.writestr(item, path.read_bytes())
with zipfile.ZipFile(archive) as z:
    assert z.testzip() is None
    for f in files:
        assert hashlib.sha256(z.read("CirceHUD-Standalone/CirceHUD/" + f["Path"])).hexdigest().upper() == f["SHA256"]
print(archive)

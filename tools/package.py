"""Build a reproducible source/package ZIP without saves, logs or Git history."""
from pathlib import Path
import hashlib
import json
import zipfile

root = Path(__file__).resolve().parents[1]
version = "0.1.5-alpha"
payload = root / "CirceHUD"
files = [{"Path": p.relative_to(payload).as_posix(),
          "SHA256": hashlib.sha256(p.read_bytes()).hexdigest().upper()}
         for p in sorted(payload.rglob("*")) if p.is_file()]
(root / "manifest.json").write_bytes((json.dumps({"Version": version, "Files": files}, indent=2) + "\n").encode())
archive = root.parent / ("CirceHUD-" + version + ".zip")
allowed_roots = {"CirceHUD", "tools", "tests"}
allowed_files = {"README.md", "NEXUS-README.txt", "CHANGELOG.md", "LICENSE", "Install.ps1", "manifest.json", ".gitignore", ".gitattributes"}
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

# Nexus/Vortex gets only the runtime folder and its instructions. In particular,
# do not deploy the personal migration installer or another mod's enablement.
nexus_archive = root.parent / ("Circes-Circular-Minimap-Region-and-Clock-" + version + ".zip")
nexus_entries = {"CirceHUD/" + f["Path"]: (payload / f["Path"]).read_bytes() for f in files}
nexus_entries["CirceHUD/README.txt"] = (root / "NEXUS-README.txt").read_bytes()
nexus_entries["CirceHUD/LICENSE.txt"] = (root / "LICENSE").read_bytes()
with zipfile.ZipFile(nexus_archive, "w", zipfile.ZIP_DEFLATED) as z:
    for name, data in sorted(nexus_entries.items()):
        item = zipfile.ZipInfo(name, (2026, 10, 17, 0, 0, 0))
        item.compress_type = zipfile.ZIP_DEFLATED
        z.writestr(item, data)
with zipfile.ZipFile(nexus_archive) as z:
    assert z.testzip() is None
    assert set(z.namelist()) == set(nexus_entries)
    for name, data in nexus_entries.items():
        assert z.read(name) == data
print(nexus_archive)

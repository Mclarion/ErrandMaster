"""Build and read back the audited Forever runtime-only ErrandMaster archive."""
from __future__ import annotations

import argparse
import hashlib
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile

ROOT = Path(__file__).resolve().parents[1]
TOC = ROOT / "ErrandMaster.toc"


def build(output: Path) -> dict[str, str]:
    lines = TOC.read_text(encoding="utf-8").splitlines()
    assert "## Interface: 16001" in lines, "not the Forever interface"
    runtime = [line.strip().replace("\\", "/") for line in lines
               if line.strip() and not line.lstrip().startswith("#")]
    assert runtime and runtime[-1] == "Core/Init.lua" and len(runtime) == len(set(runtime))
    images = sorted(p.relative_to(ROOT).as_posix() for p in (ROOT / "Textures").glob("*.blp"))
    names = ["ErrandMaster.toc", "Bindings.xml", "README.md",
             "docs/READINESS.md", *runtime, *images]
    assert len(names) == len(set(names)) and images, "missing images or duplicate entries"
    manifest = {}
    payload = {}
    for name in names:
        source = ROOT / name
        assert source.is_file() and source.resolve().is_relative_to(ROOT.resolve()), name
        data = source.read_bytes()
        assert data, name
        payload[f"ErrandMaster/{name}"] = data
        manifest[name] = hashlib.sha256(data).hexdigest()
    assert not output.exists(), f"refusing to overwrite {output}"
    with ZipFile(output, "x", compression=ZIP_DEFLATED, compresslevel=9) as archive:
        for name in sorted(payload):
            archive.writestr(name, payload[name])
    with ZipFile(output) as archive:
        assert set(archive.namelist()) == set(payload), "archive members differ"
        assert archive.testzip() is None, "corrupt archive"
        for name, data in payload.items():
            assert archive.read(name) == data, f"archive mismatch: {name}"
    return manifest


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    inventory = build(args.output)
    print(f"Verified {len(inventory)} runtime files in {args.output}; SHA256 "
          f"{hashlib.sha256(args.output.read_bytes()).hexdigest()}")

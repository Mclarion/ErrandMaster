"""Create exact v0.6.1 -> v0.6.2 inventories for a guarded upgrade."""
import argparse
import hashlib
import json
from pathlib import Path
from zipfile import ZipFile


def inventory(path):
    with ZipFile(path) as archive:
        assert archive.testzip() is None
        result={}
        for name in archive.namelist():
            assert name.startswith("ErrandMaster/") and not name.endswith("/")
            relative=name.removeprefix("ErrandMaster/")
            assert relative and ".." not in relative.split("/") and relative not in result
            result[relative]=hashlib.sha256(archive.read(name)).hexdigest().upper()
        return dict(sorted(result.items()))


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("old_archive",type=Path)
    parser.add_argument("new_archive",type=Path)
    parser.add_argument("manifest",type=Path)
    args=parser.parse_args()
    old,new=inventory(args.old_archive),inventory(args.new_archive)
    assert len(old)==38 and len(new)==87
    with ZipFile(args.old_archive) as archive:
        old_toc=archive.read("ErrandMaster/ErrandMaster.toc").decode("utf-8")
    with ZipFile(args.new_archive) as archive:
        new_toc=archive.read("ErrandMaster/ErrandMaster.toc").decode("utf-8")
    assert "## Version: 0.6.1-rc1" in old_toc.splitlines()
    assert "## Version: 0.6.2-dev" in new_toc.splitlines()
    assert "## Interface: 16001" in new_toc.splitlines()
    assert old["ErrandMaster.toc"]!=new["ErrandMaster.toc"]
    data={"zipSHA256":hashlib.sha256(args.new_archive.read_bytes()).hexdigest().upper(),
          "old":old,"new":new}
    args.manifest.parent.mkdir(parents=True,exist_ok=True)
    args.manifest.write_text(json.dumps(data,sort_keys=True,indent=2)+"\n")
    assert json.loads(args.manifest.read_text())==data
    print(f"Upgrade manifest: {len(old)} old, {len(new)} new; SHA256 {data['zipSHA256']}")

if __name__=="__main__": main()

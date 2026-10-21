"""The public runtime package must not ship imported transport tables."""
import importlib.util
from pathlib import Path
import tempfile
from zipfile import ZipFile

ROOT = Path(__file__).resolve().parents[1]
toc = (ROOT / 'ErrandMaster.toc').read_text()
assert 'Data/StaticTransport.lua' not in toc, 'static dataset consumer must not load in the public runtime'
assert 'transport-fixture' not in toc and '.testdeps' not in toc
spec = importlib.util.spec_from_file_location('em_package_boundary', ROOT / 'tools/build_package.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
with tempfile.TemporaryDirectory() as temp:
    path = Path(temp) / 'boundary-test.zip'
    module.build(path)
    with ZipFile(path) as archive:
        names = archive.namelist()
        assert not any('StaticTransport' in name or '.testdeps' in name or
                       'transport-fixture' in name or 'transport-source' in name for name in names)
        for name in names:
            if name.endswith('.lua'):
                assert b'addon.transportData' not in archive.read(name), name
print('public runtime archive excludes imported transport data and its consumer')

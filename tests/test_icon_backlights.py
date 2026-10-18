"""Source layer contracts complement the UI frame-mock tests."""
from pathlib import Path

root = Path(__file__).resolve().parents[1]
for name in ("AddonSettings", "MainWindow"):
    source = (root / "UI" / f"{name}.lua").read_text()
    assert 'local iconGlow = frame:CreateTexture(nil, "BACKGROUND")' in source, name
    assert 'iconGlow:SetPoint("CENTER", icon, "CENTER")' in source, name
    assert 'iconGlow:SetBlendMode("ADD")' in source, name
source = (root / "UI" / "WorldMap.lua").read_text()
assert 'local glow = pin:CreateTexture(nil, "BACKGROUND")' in source
assert 'pin.glow:Hide()' in source
assert 'if category == "Waypoint" then pin.glow:Show() end' in source
print("header and waypoint backlight layer contracts passed")

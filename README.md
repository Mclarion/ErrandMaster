# ErrandMaster – Smart Route Planner

An early, **source-only** WoW: Forever addon (v0.3.0). It stores personal errands and suggests an approximate nearest-neighbor order for same-map destinations, including opt-in player-discovered service locations, explicitly registered in-game gossip POIs, and a click-to-confirm radial selection wheel. It does **not** automate movement, interactions, combat, or purchases.

## Install and verify in game

1. Copy this `ErrandMaster` directory (excluding `.testdeps`, `.venv`, `tests`, `tools`, and `.gitignore`) to the **Forever** client `Interface/AddOns/ErrandMaster`, not the Retail or Classic Era client. Include `Bindings.xml` and `Textures/HiddenCursor.blp`; they are required runtime assets. The beta path observed in September 2026 was `World of Warcraft/_classic_beta_/Interface/AddOns/ErrandMaster`.
2. The Forever Beta `WowB.exe` file version was read remotely as **1.60.1.70374**. The audited addon source was published at `github.com/Mclarion/ErrandMaster`, installed while the game was stopped, and all 13 installed files were hash-matched to the source package. Four existing addon-state files were explicitly enabled with their previous bytes backed up. In the actual client, use `/dump select(2, GetBuildInfo())` for the build and `/dump select(4, GetBuildInfo())` for the interface. Compare the latter to `## Interface: 16001`. No live API assertion has been made for build 70374.
3. Enable the addon on the character selection AddOns screen and log in. If initialization fails, check chat and the game's Lua error display. Try `/em help`, `/em add`, then add an errand, `/em route`, `/em next`, and `/reload`.
4. Confirm an errand survives `/reload`, logout/login, and a full restart on the actual installed build. Persistence is unverified outside a Lua mock.

## Current features

- `/em` opens/closes the window; `/em add` focuses the name input. The window supports add, edit, delete, complete/reopen, move up/down, selected scope toggle, and current-position capture. Blank location fields create an unlocated task. Coordinates entered in the UI are **percent** (0–100); stored coordinates are normalized (0–1). No preloaded NPC catalog is included; destinations must be entered or observed.
- `/em route` lists the first ten same-map stops and a count of deferred errands; `/em optimize` enables automatic ordering; `/em next` reports the next name, map ID, and coordinates and optionally creates a TomTom waypoint; `/em settings` shows the window's order/scope/TomTom/discovery and Wheel settings controls; `/em debug` toggles a stored flag (detailed event tracing is not implemented); `/em help` lists commands.
- **Radial selection:** click **Wheel settings** in the main window (or `/em wheel settings`), then **Set wheel key** and press an unused keyboard key out of combat. `Bindings.xml` also exposes the action under WoW's AddOns Key Bindings as a fallback. `/em wheel` previews it without a binding. The wheel centers on the current mouse position; moving the mouse from the center highlights the directional category. Left click over a highlighted direction opens the main Add errand form with that category prefilled, **without creating an errand until Add errand is clicked**. Left click while still in the center dead zone cancels; Escape and a non-left click also close it. Opening is refused in combat and entering combat closes it. Wheel radius and icon size persist in SavedVariables; the chosen key is owned by WoW's binding system. Near a screen edge, some icons can be clipped rather than moving the center away from the cursor. Hold-and-release selection is not implemented.
- While the wheel is open, `SetCursor` attempts to use the packaged transparent BLP texture; closing, Escape, and combat restore the default cursor. If the client does not support that cursor API/texture, the wheel remains clickable but the cursor may remain visible. The texture and all keyboard/mouse/visual behavior need an actual client test; no mock can establish that a cursor truly disappears on build 70374.
- **Opt-in discovery:** `/em discover on` or the window button records the player's **approximate position** when the native merchant, mail, or auction interface opens. `CanMerchantRepair()` must return true to add Repair alongside Vendor. No services are recorded at first install or migrated from older saves unless the player enables this. `/em discover off` stops automatic observations. Bank and trainer event capture await build-specific verification.
- **Game POIs:** after a player obtains a marker through in-game gossip, `/em poi repair` (or another explicitly chosen category, such as `bank`, `mailbox`, `auction house`, `vendor`) attempts to save the map coordinate returned by `C_GossipInfo.GetPoiForUiMapID` and `GetPoiInfo`. The addon **does not classify the POI**; the category is the player's assertion. This explicit command works with passive discovery off. No marker/API, protected value, or invalid coordinates means no record. The POI name is a map label, not a verified NPC identity.
- `/em locations` lists the first ten observed locations with IDs, coordinates and precision; `/em forget loc-<number>` removes one from the current character's registry. Records are character-only to avoid silently assuming another character can use the same service. There are no fabricated NPC IDs. Unlocated errands with a matching category can be routed to the nearest previously observed same-map candidate; directly entered errand coordinates always take precedence. Approximate locations display `~` in the window and are labeled in chat.
- Ordered and deferred/completed errands appear in the window, eight per page. New errands default to character-only; toggle to account-wide from the window. One versioned `ErrandMasterDB` SavedVariables table holds account errands, character errands, per-character observed locations, ID counters, and settings. Schema 1 migrates to schema 2 with discovery **off**; unknown newer schemas are refused instead of silently rewritten.
- Up to 200 visible errands and 200 observed locations per character; route calculations run only on explicit actions and zone/enter-world events, not continuously. Same-map nearest-neighbor is a straight-line approximation, not a path or travel-time optimizer. Different-map/unmatched errands are deferred and never passed to the navigation adapter. Manual order disables optimization until re-enabled.
- TomTom integration is optional and checked at use time. Only the returned handle from ErrandMaster's own waypoint is removed; no unrelated TomTom waypoint is touched. Without TomTom, `/em next` and the window show the destination and coordinates. **Native map pins are not implemented.**

## API decisions and fallback behavior

| Feature | API used | If unavailable/secret/unsupported |
| --- | --- | --- |
| Player position | `C_Map.GetBestMapForUnit("player")`, `C_Map.GetPlayerMapPosition(mapID,"player")`, vector `GetXY()`, `issecretvalue` guard | With no map, defer every errand. With a map but no position, manually located errands remain in manual order; no observed candidate can be selected reliably. |
| Character identity | `UnitFullName`, fallback `UnitName` + `GetRealmName` | Defer initialization to `PLAYER_LOGIN` if identity is not yet known; refuse to create a character bucket without an identity. |
| Storage | Native `## SavedVariables` global, `ADDON_LOADED` | If the client fails to restore saved data, tasks will not persist; no external cloud API or fabricated fallback. Test actual `/reload` and restart. |
| Navigation | Optional `TomTom:AddWaypoint` / `TomTom:RemoveWaypoint` (`source`, `title`, nonpersistent) | Still show coordinates in chat/window. No external service required for the MVP. |
| Native service observation | `MERCHANT_SHOW`, `MAIL_SHOW`, `AUCTION_HOUSE_SHOW`, `CanMerchantRepair`, `InCombatLockdown`, player position | No automatic location capture; use manually entered errand coordinates. If a service is observed, the saved coordinate is where the player stood, **not** the NPC's location. First-run off. |
| Guard/gossip POI | `C_GossipInfo.GetPoiForUiMapID`, `C_GossipInfo.GetPoiInfo`, POI vector `GetXY` | `/em poi` refuses cleanly; manually enter the destination. A POI does not encode a trustworthy service category by itself. |
| Wheel binding | Auto-loaded `Bindings.xml`, `GetBindingAction`, `GetBindingKey`, `SetBinding`, `SaveBindings`, `GetCurrentBindingSet`; frame keyboard input out of combat | If direct capture is restricted/unavailable, bind **Open ErrandMaster selection wheel** in WoW's own Key Bindings → AddOns, or use `/em wheel`. Conflicting existing bindings are not overwritten. |
| Wheel input/cursor | `GetCursorPosition`, frame `OnUpdate`/`OnMouseDown`, `UISpecialFrames`, `SetCursor` with bundled transparent BLP | Missing cursor data/combat state refuses opening; missing `SetCursor` leaves the visible cursor and keeps click selection usable. The wheel never simulates a player click or invokes protected gameplay. |
| Event/UI | `CreateFrame`, `ADDON_LOADED`, `PLAYER_LOGIN`, `PLAYER_ENTERING_WORLD`, `ZONE_CHANGED_NEW_AREA`, standard Blizzard templates | Core Lua remains separately testable; a missing UI template or changed API requires an in-client compatibility fix before distribution. |
| Equipment/inventory/trainer data | **Not used in v0.3.0** | Manual errands only. Do not infer NPC services, trainer offerings, or repair needs from unverified data. |
| Compact tracker / hold-release | **Not used in v0.3.0** | Main window and click-to-confirm wheel remain available. |

**No additional external web API is needed for this source version.** TomTom is the only optional addon API. WoW's native addon APIs expose a selected gossip POI or a player's position at an observed service, **not an exhaustive callable registry of every NPC, service, exact position, faction restriction or travel connection**. We cannot truthfully build an automatic complete service catalog from these signals. A future curated data pack would need source/version/license review, with explicit provenance and reachability rules; simply calling the Blizzard Developer web API does not supply a known NPC-location catalog. An external routing service is not necessary for same-map straight-line order. No out-of-game web API is contacted by the addon.

## Known restrictions

Forever has a Retail-derived API and secret-value/combat rules, not the Classic Era API. This code avoids protected gameplay actions, movement, item use, and combat-state analysis. Binding changes use the native restricted API **only out of combat and in response to a player keypress**; the normal Blizzard binding UI is the fallback. `16001` and the POI API signatures come from nearby beta development references, **not a probe of reported build 70374**. The addon refuses protected/unavailable values where checked. SavedVariables may vary across beta builds; do not claim persistence until testing the actual client. Same-map routing does not prove accessibility, faction availability or path length. Location capture is intentionally disabled in combat; no NPC IDs are inferred from the target. The window has no drag-position/scale persistence. No sound, compact tracker, smart suggestions, native map pins, comprehensive NPC database, or hold-to-release keybind yet.

## Developer tests

From the project root, install `lupa` in an isolated local target (Python 3 available):

```sh
python3 -m pip install --target .testdeps lupa
python3 tests/run_tests.py
```

`run_tests.py` checks TOC file presence/order, Bindings.xml syntax/action, the uncompressed transparent BLP structure, and Lua 5.1 parsing. It runs core storage, migration, routing, discovery/POI, protected-value refusal, wheel directional/cancel/keyboard/rollback, and mock WoW boot/UI tests. `lupa` is only a developer dependency; do not package `.testdeps`. Mocks **do not prove** real UI layout, cursor rendering, keybinding persistence, client API compatibility, actual POI event timing, or SavedVariables persistence.

In-client checklist on **1.60.1.70374**: first install and interface number; wheel preview at center and edge, disappearing/restored cursor, move-toward highlight, left click into each category, center click cancel, Escape, mouse right click, combat entry and blocked opening; key capture/clear conflict and Blizzard Key Bindings fallback; wheel settings and binding across `/reload`; normal-size/ultrawide frames and icon clipping; `/reload` and full restart for errands; two characters and account scope; discovery defaults off and migrates off; opt in and visit a repairable merchant, non-repair merchant, mailbox and Auction House; obtain and save a guard POI using `/em poi <category>`; reject absent marker/protected value; deduplicate repeated visits; `/em locations` and `/em forget`; route an unlocated category to one of multiple observed same-map points; unavailable position, combat, different maps and potential faction restrictions; missing TomTom and waypoint ownership; invalid/zero/100% coordinates; add/edit/delete/complete/reactivate/reorder; auto versus manual order; UI scale and Lua errors. Inspect the saved variable file only after the game writes it and the game is stopped. Do not copy secrets or private account files into reports.

## Next milestones

1. Run the installed addon in Forever Beta to verify its interface number and native service-event/POI contracts; fix any live incompatibility, verify save/reload and waypoint ownership. Source publication and file installation alone are not game tests.
2. Verify the click-to-confirm wheel and keybinding in the real client, then add compact tracker and persistent window scale/position.
3. Add opt-in durability/bag-space suggestions only after checking accessible, nonsecret APIs; leave class/profession suggestions manual until verified.
4. Add a validated bank/trainer interaction path if exposed by build 70374; only then consider a separately sourced/attributed location pack and zone-aware navigation with reachable transport edges.

## Development references

- Forever development kit: https://github.com/Thunderz96/forever-addon-kit (observed interface `16001`, modern API notes).
- Extracted Blizzard beta API documentation for gossip POIs (not the installed build): https://github.com/Gethe/wow-ui-source/blob/beta/Interface/AddOns/Blizzard_APIDocumentationGenerated/GossipInfoDocumentation.lua
- Client-generated API reference: https://github.com/Atraeau/WoW-Addons (the published reference says build 70170, interface `16001` as of October 1, 2026; not this host's installed client).
- Beta API-change notes: https://warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes/notes (including October 8 notes on secret aspects).
- WoW addon key bindings: https://warcraft.wiki.gg/wiki/Creating_key_bindings and https://warcraft.wiki.gg/wiki/API_SetBinding (binding changes restricted in combat).
- Cursor API caveat: https://warcraft.wiki.gg/wiki/API_SetCursor (invalid texture can show a black square; `nil` resets the default cursor).
- BLP2 raw BGRA format: https://www.wowdev.wiki/BLP (used only to generate the transparent cursor asset).
- TomTom: https://www.curseforge.com/wow/addons/tomtom ; its documented waypoint API requires a `source` string.
- Blizzard UI Add-On Development Policy: https://us.forums.blizzard.com/en/wow/t/ui-add-on-development-policy/24534 (free, publicly visible code, no negative realm impact or gameplay automation exemption).

No third-party source was copied into ErrandMaster. Verify licenses before importing a dataset or code later.

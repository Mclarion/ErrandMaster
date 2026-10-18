# UI rework acceptance ledger — player feedback 2026-10-16

Authoritative requested next candidate. Installed baseline: v0.6.5-test1. Player closed WoW and authorizes guarded installation ONLY after all implementation/review/offline gates below pass. Do not call visual behavior accepted until player review. Preserve custom layouts, Favorites, saves, other addons; ErrandMaster independent of RestedXP. Never inspect player SavedVariables contents. No game launch or credential use.

Status convention: [ ] pending; [x] implemented AND offline verified. All finished implementation items move into the player-review section, not silently closed as client-verified.

## Wheel input and geometry
- [x] Preserve full movement, including A/D, while open; intercept only intentional UI keys, never movement binds.
- [x] Dynamic viewport/effective-UI-scale sizing (5120x1440 at 100% is an example, not a constant). Much smaller useful minimum than current radius 80; functional wheel scale and independent icon scale.
- [x] One consistent geometry model for wedges, icons, border medallions, center and hit tests; larger correctly centered icons and generous entire-sector outer-ring selection.
- [x] Show icons on all outer tiers; retain untinted supplied art and correct directional medallions on actual borders.
- [x] Center emblem perfectly fills hub; no arbitrary transparent-image padding mismatch.
- [x] Hide per-sector labels; show hovered name centered in hub, separated from ring layout.
- [x] Reposition away from cursor/screen edge as needed to fit maximum/deeper extents; fit viewport dynamically and recalculate after resize/UI-scale change.
- [x] Soft active-crystal crossfade and border glow on hover/selection/press, no abrupt texture swap.
- [x] Elaborate transparent gold border artwork aligned to every sector, based on supplied concept. If custom border art is needed, provide exact canvas dimensions, radii, angles, orientations/templates for supported counts/tiers.
- [x] Center click always closes; outside click closes except unlocked edit mode (allow external spell/item drag).
- [x] Remove flip/orientation calibration and fixed-color customization; make fixed orientation correct.

## Wheel editing
- [x] Discoverable add menu/folder, icon assignment, existing layout edit operations.
- [x] Unlocked wheel accepts real spellbook/bag cursor types safely (no insecure automatic casting/using).
- [x] Dragged icon follows cursor continuously; animated live slot rearrangement.
- [x] Hover an existing entry to form a folder (phone launcher/Samsung-style), distinct from insertion between neighbors; preview feedback and cancellation.
- [x] Between-item insert expands ring modestly with count and recomputes all geometry; support nested folder movement without lost/duplicated items.
- [x] Persist custom layout and handle drag leave/cancel/close/combat/empty wheel safely.

## Target sidebar and route behavior
- [x] Transparent shell with tight elf/fantasy-style cards only; scrollable list of all targets, no four-row pagination; vertical scrollbar when overflow.
- [x] User-resizable dimensions and screen clamping; dynamic available-height behavior.
- [x] Hide completely when no targets; remove empty-state text and window close button; settings checkbox controls visibility.
- [x] Drag ghost tracks cursor, animated live reorder and scrolling; only manually moved target's position overrides optimization, not global optimization freeze.
- [x] Replace text buttons with right-side cross/remove, favorite below, and navigation-icon move-to-top; labels only in hover tooltips. No Done action.
- [x] Automatically advance/remove active queue target when reliably within 2 yards. Do not fabricate distances or complete based on unknown/cross-map/floor/taxi data. This is requested queue arrival behavior, not proof a service/quest was actually completed.
- [x] Own navigation arrow above sidebar, visible with valid active target and hidden with no active target; replace dependency on missing TomTom arrow. Do not tamper with other addons' arrows/waypoints. Unknown direction/distance must remain truthful.

## Settings
- [x] Settings/database: either unset primary-profession dropdown includes all nine primary professions; Fishing/Cooking/First Aid included by default with individual opt-out. test_ui_preferences.lua and test_addon_settings.lua pass. Wheel and runtime filters consume db:GetWheelProfessions(); integrated boot and hierarchy tests pass.
- [x] Effective radius/scale/icon-scale controls with updated ranges and migration respecting layouts.
- [x] Remove color controls and flip control.
- [x] Replace separate expert-settings entry with intuitive tab in main addon settings; advanced functionality remains accessible.

## Evidence and release
### Integration checkpoint
Final v0.6.6-test1 offline suite, compilation, artwork regeneration and diff checks passed. All independent review findings were fixed with regression coverage, including binding capture cleanup, icon-proximity native-folder dwell, inward medallions, displayed-order anchors, completed-only hiding, floor-safe arrival and unreachable-anchor deferral. Full movement/UI-scale/drag geometry remains mocked, not client-observed. The 434-file archive was byte-read back against source and installed through a tested guarded swap; independent readback matched all installed files, 431 prior-version files, 62 unchanged QuestieDB files, four enabled-addon states and two SavedVariables backups. WoW stayed stopped. Exact archive hash and rollback paths are in TEST-STATUS.md. All implementation gates below are closed for this feedback candidate; the separate player-review checklist stays open. Border visual quality and actual native orientation are not claimed accepted.

- [x] Inspected attached upload_20261016_180031_10.png: gross scale/alignment/label inconsistency visible. Player report establishes movement/editor/arrow interaction defects, not mocks.
- [x] Retrieved and inspected C:\Users\mclar\Pictures\Screenshots\Screenshot 2026-10-16 192908.png and Screenshot 2026-10-16 193433.png. Local evidence .testdeps/feedback-20261016/. Oversized drawn wedges relative to icon/hit geometry and sparse massive sidebar cards confirmed.
- [x] Reproduce underlying coordinate/scale/input bugs with tests before fixes; test non-1 UI scales, short/tall/wide viewports, edge/deep nesting, drag lifecycles.
- [x] Independent implementation review; resolve findings and all integrated offline tests/compile/art/package checks.
- [x] Exact source-matched next-version archive; stopped-client preflight against v0.6.5 manifest; backups, guarded install and independent readback. Do not install a partial candidate.
- [x] Document verified implementation versus player-review items and rollback; no claims of live visuals from offline preview.

## Player review — remains open after install
### Urgent client feedback hotfix
Player reported `/em wheel` cannot complete, empty preview/no wheel, invisible binding/status feedback and minimap button buried under map (upload_20261016_203506_14..17.png). Reproduced invalid `CreateTexture(nil,"TOOLTIP")`: TOOLTIP is frame strata, not a texture layer. Previous permissive mock missed this. Corrected to OVERLAY, start construction hidden, clean up failed open/update and expose a single chat error rather than a repeated update storm. Strict layer regression plus failed-create/update recovery tests pass. Settings feedback/native-options dismissal and minimap layering are being repaired separately. v0.6.6-test2 candidate is not installed; preflight still sees one running WoW process. Retain all earlier visual acceptance items for player review after hotfix. Pathing work is lower priority until this hotfix is available.

Pathing/accessibility research was added to scope separately in `PATHING-OPTIONS.md`. Options analysis is complete; native Forever capability checks, data-source selection and implementation remain pending. This addition does not reopen or replace the UI feedback build and does not authorize extraction, automatic movement or another installation.

- [ ] Full movement while wheel open; center/outside-close semantics.
- [ ] Compact wheel at player's UI scale; all layers/icons/rim crystals correctly aligned, no clipping, readable hub hover names.
- [ ] Smooth highlights and drag/drop animations; spells/items, folder creation, insertion and persistence.
- [ ] Compact transparent sidebar; resize/scroll, controls and per-item manual-order behavior.
- [ ] Native arrow orientation while turning/moving; 2-yard queue arrival and advance; empty-state hiding.
- [ ] Settings usability and profession defaults; RestedXP coexistence without integration.

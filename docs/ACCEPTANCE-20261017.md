# ErrandMaster client acceptance failures — 2026-10-17

Current test candidate: 0.6.14-test1; consult `RELEASE-v0.6.14-test1.md`. The dated checkpoints and installed-version references below are historical. Offline fixes do not close client acceptance; the all-waypoints in-world marker failure remains open until tested in WoW.

## Current reconciliation against the original player request

This summary supersedes historical source/install status statements below, not the original requirements. Installed baseline is v0.6.9-test1, with no new player acceptance reported. Working source contains additional provider, discovery, route-evidence and responsiveness fixes documented in NEXT-FIX-BUNDLE.md. The prepared v0.6.10-test1 archive is stale and must not be treated as current source. Publication/installation remain paused.

| Original scope | Working-source status | Still required for closure |
| --- | --- | --- |
| S01-S03: last row to top, individual manual anchor, reoptimize remainder, new-target refresh and first-row arrow ownership | Implemented; handler/queue/planner regressions passed | Verify real scrolling/dragging, repeated anchors, additions and single-target behavior in client |
| S04-S06: centered sidebar text, fading backgrounds, bright usable controls | Implemented; layout/assets/handler tests passed | Real scale/contrast/hit-area/tooltip acceptance |
| W01: off-center hub and bleed | Measured rim correction and icon containment implemented; geometric tests passed | Unhovered hub, alpha bleed and scaling in client |
| W02-W03: full silhouette/expanded-side shadows, black default, discreet smooth menu tint | Implemented with regenerated shadow geometry and transition regressions | Real expanded menus and visual transitions |
| W04-W06: icon/medallion glow, active brightness, White/Gold contrast | Implemented across audited wheel/sidebar/minimap/arrow/logo/map surfaces | Visual intensity, jewel ordering and complete visible-surface acceptance; mocks do not prove the requested appearance |
| H01-H02: Trainer artwork, class trainer, Hunter Pet Trainer and one Weapon Trainer | Implemented and tested | Actual class-menu behavior and provider destinations; weapon specialization expansion remains intentionally deferred |
| H03-H04: Quests -> zone -> active quests, safe migration | Implemented with current-log grouping/pagination; full-root migration gets a center right-click shortcut without changing saved slots | Verify client shortcut, grouping, log changes and quests without coordinates |
| E01-E02: remove Pin semantics, persistent visible edit mode and EDIT MODE label | Implemented; explicit exit/combat cleanup regressions passed | Real interaction and state after close/reopen/reload |
| E03-E06: identical item/spell insertion, cursor preview, ring growth, occupied-icon grouping into black folders, existing-entry moves | Implemented and tested, including Mailbox-under-another-entry style grouping, cross-folder moves and cancellation | Native client cursor/animations and persistence; nesting is limited to two folder levels, not arbitrary depth |
| M01: resized/scaled minimap button | Implemented with geometry-change checks and retry after initially unavailable geometry; retries reuse one invisible/noninteractive button until placement succeeds | User's enlarged minimap, startup recovery and persisted angle in client |
| R01-R04: zone-aware direct fallback, 10-yard replans and independent per-yard distance | Implemented with guarded projection and timer tests | Actual Forever coordinate/facing availability, movement/turning and target transitions |
| V01-V03: closest correct service regardless of starting zone, ordered destination recalculation | Implemented sequential closest-known eligible target resolution from each preceding stop; manual priority, cross-zone search and explicit NPC identity tested | Verify representative services/maps in client; unknown projection/data limits are not proof of nearest possible NPC. Food/unvisited-merchant coverage is not comprehensive |
| R05: useful walking routes rather than everything unknown | Partial: observed-corridor follower, world-instance-zero support and immediate evidence invalidation implemented | Verify recording-to-following in client; general terrain/path connectivity remains unavailable. Direct bearing is fallback, not a walking route |

Priorities before declaring the request complete: finish independent review, build and verify a fresh candidate, then complete every original live acceptance scenario and fix any failures. Missing provider evidence and unknown walking connectors remain real limitations, not source fixes disguised as data. Keep every acceptance ID client-open until that evidence exists. Historical entries below describe their then-current state; this table is the current reconciliation.

Authoritative follow-up to installed v0.6.8-test1. User reports repeated fixes did not work in-game. Supersedes optimistic older completion notes. Implementation, offline verification, installed-byte verification and player/client acceptance are separate states. None of the work below is accepted merely because a mock passes. No universal terrain pathfinding claim.

Evidence: /opt/data/images/upload_20261017_075625_1.png through _4.png. User explicitly reports hub offset/leak, last-row drag failure, minimap placement and missing Thelsamar ammo vendor. Preserve these as reported failures even where screenshots alone cannot establish behavior.

## Completion contract
Every ID starts OPEN. Record root cause, regression command, actual result, source/install version and client acceptance separately. Do not mark all done or silently defer scope. Preserve user layouts/saves, other addons and independent RestedXP compatibility. Do not read player SavedVariables contents. No client launch. Install only an authorized candidate with stopped-client checks/backups/readback; current request does not say the game is closed.

## Priority 1 — provider, target order and arrow
- S01 OPEN: Last/bottom sidebar entry must drag to first/top and every other displayed insertion position. Reproduce red Repair row to first, including scroll offsets and optimized-vs-stored order.
- S02 OPEN: A manual move constrains the chosen target to the requested position; recalculate the rest for the best supported route, not freeze the whole list. Resolve stale/conflicting prior anchors and verify repeated moves with real queue+planner, not mocked Reorder.
- S03 OPEN: Adding any new target immediately recalculates route/order and distances; arrow follows the first displayed target. A single target is automatically active. No stale activeTargetId pointing at a different row.
- V01 OPEN: Investigate full service data chain: provider contract/build, records, service classification, faction/class filters, area-to-map conversions, candidate selection and nearby-zone fallback. Distinguish absent provider data from filtering/coordinate errors. Do not paper over failures by inventing NPC coordinates.
- V02 OPEN: Reproduce Loch Modan -> nearest Vendor and Ammo vendor. User expects the nearby Thelsamar ammo vendor, not Badlands. Check actual authorized provider data for a suitable local record and identity. Select nearest eligible specific service, not generic Vendor or arbitrary cross-zone candidate. Prove why each candidate is accepted/rejected.
- V03 OPEN: Audit coverage for other service classes (screenshot Mailbox/Class Trainer unknown, distant Repair). Expose diagnostic missing-data reasons rather than silent wrong destinations. Do not claim comprehensive provider coverage without evidence.
- R01 OPEN: Route unknown must still yield a raw destination bearing whenever trustworthy coordinate transforms and facing permit it. Separate direction availability from walkability/route evidence.
- R02 OPEN: Zone-aware raw arrow: same-zone delta or validated shared-world coordinate projection across zones. Never subtract unrelated normalized zone coordinates. Handle instance/floor/map mismatch without fabricating directions.
- R03 OPEN: Recalculate targets/routes after 10 yards of movement (rather than 50), and on target/map/data changes. Verify cadence while recording is off and no legacy TomTom handle exists. Bound expensive work.
- R04 OPEN: Arrow distance updates at each yard of movement/change, with appropriate frame/timer throttling; do not wait for the 10-yard route recalculation. Verify rounding, stationary behavior and world-position availability.
- R05 OPEN: Solidify observed-path following separately from direct fallback: usable known route shows next observed node; unknown path shows destination bearing and truthful label. Current user report is that every path is unknown. Diagnose recording/default-off/coverage/provider/projection causes and document actual limits. No claim native APIs provide inaccessible-area/navmesh data based on function presence.

## Sidebar appearance and usability
- S04 OPEN: Center card text within the usable content region; keep actions and text from colliding at different window sizes/UI scales.
- S05 OPEN: Fade category background color toward card edges instead of hard rectangular edges, retaining readable contrast.
- S06 OPEN: Add bright soft backglow and adequate hit areas to sidebar buttons; remove/favorite/navigation actions must be distinguishable and have hover tooltips.

## Wheel rendering
- W01 OPEN: Diagnose and fix unhovered center emblem's visible centering and background bleed against actual source alpha, crop, hub aperture, draw order and effective UI scale. Do not dismiss the user's report because a mock or screenshot analysis looks centered.
- W02 OPEN: Uniform lifted shadow beneath the entire visible wheel silhouette, including expanded partial arcs and their side edges. Shadow geometry extends/contracts with menus.
- W03 OPEN: Shadow defaults black; hover/expanded branch gives a discreet menu-colored shadow with smooth transitions and no abrupt reset. Keep all shadow layers beneath artwork.
- W04 OPEN: All addon icons receive soft brighter backlighting, covering wheel and retained rings, sidebar controls, native arrow/minimap where applicable. Keep supplied illustration pixels untinted.
- W05 OPEN: Medallions are backlit in their own colors, stronger when active, and jewels remain above effect layers.
- W06 OPEN: White/Gold background treatments need more visible contrast and saturation/brightness without washing out icon detail.

## Trainer and quest hierarchy
- H01 OPEN: Main Trainer entry uses supplied default Class Trainer icon.
- H02 OPEN: Trainer submenu includes class-appropriate Class Trainer, class-specific other trainer types when relevant (Hunter Pet Trainer example), and one Weapon Trainer entry for every class. Keep weapon specialization expansion deferred explicitly, not duplicated alternatives now.
- H03 OPEN: Ensure a reachable Quests entry exists in current/customized root layouts without resetting user order or folders. Add missing built-in entry safely, not only to brand-new default accounts.
- H04 OPEN: Quests -> zone -> character's current quests for that zone (e.g. Quests -> Loch Modan -> active Loch Modan quests). Use quest-log zone grouping, not only current-map POIs. Distinguish entries with/without usable target coordinates.

## Editing and persistence
- E01 OPEN: Remove Pin Wheel control/setting behavior. Migrate legacy pinned/unlocked state without losing layouts. Edit mode itself keeps wheel open until explicit exit; no separate ambiguous pin mode.
- E02 OPEN: Show EDIT MODE prominently in hub while unlocked; keep state/control discoverable.
- E03 OPEN: Native food/bag-item drop between wheel entries inserts at that position with animated neighboring movement and count-based layout growth. Cursor preview tracks mouse before release; edit mode remains open.
- E04 OPEN: Native spell drops behave identically to item drops; preserve safe non-execution behavior unless separately authorized/designed.
- E05 OPEN: Drop onto an occupied icon creates a folder/submenu instead of insertion. Clearly distinguish icon-center grouping intent from between-slot insertion. New custom folders use black background treatment initially.
- E06 OPEN: Existing entries can move/reorder/group while unlocked, including moving Mailbox under Auction House. Preserve source item identity and contents; do not duplicate/drop entries accidentally. Validate category-to-folder conversion, nested moves, cancel, hover animation and persistence.

## Minimap
- M01 OPEN: Button placement reacts to minimap resize/scale/layout changes, not only initial attach/drag. Keep outside minimap rim with correct effective-scale math and above clipping layers. Validate the player's enlarged-minimap case and persisted angle.

## Evidence priorities / working hypotheses
1. Arrow likely suppresses direct direction through incomplete position/world-size/facing validation; trace separately from graph status.
2. Local vendor missing may be classification or map/faction filtering, not missing source data; inspect the exact provider pipeline first.
3. Displayed first-row drag may be hit-index boundary/scroll math or active-target/manual-anchor mismatch; reproduce real queue+display order.
4. Quest entry may be absent from migrated/custom layouts and zone grouping may use current-map-only POIs.
5. Minimap attach-only placement cannot respond to later minimap resizing.

No item above has client acceptance yet. Installed baseline remains v0.6.8-test1 until a documented guarded release replaces it.

## Initial baseline source findings (before this follow-up's edits)
- Routing/Navigation.lua:129-130 immediately rejects a target whose map differs from the player's map. Thus a cross-zone direct arrow cannot work through Measure even with usable world-coordinate conversion available elsewhere. R02 remains OPEN.
- Routing/Navigation.lua:136-139 returns no distance or angle if MapWorldSize is unavailable. Test actual Forever world-size/projection capabilities rather than claiming this is the player's observed root cause.
- Core/Init.lua:290-293 still uses squared displacement 2500 (50-yard cadence), not the requested 10-yard threshold. R03 remains OPEN.
- UI/NavigationArrow.lua:24-27 refreshes readings every 0.1 seconds, but this alone does not establish that valid coordinates reach it or one-yard changes are correctly displayed. R04 remains OPEN.
- Read-only investigations completed for provider coverage/selection, sidebar ordering/activation, and menu/editor/minimap gaps. No client acceptance is claimed.

## Follow-up implementation evidence — source only, not installed
- R01/R02: Added guarded native world projection to Navigation.Measure. Equal world-instance IDs permit cross-zone direct bearing; instance 0 is valid. Same-zone projection supplies distance/bearing when map-size API is absent. Different instances, invalid/secret data and projection errors fail closed. Explicit floor restrictions remain conservative.
  - RED: `test_navigation_projection.lua` failed on cross-zone projected distance before the implementation.
  - GREEN: projection, observed follower, queue and arrow suites passed with Lua 5.1 via Lupa.
  - Expanded arrow timer test uses the real navigation module and checks displayed 100 -> 99 yards without a route refresh; passed. This is native-API fixture evidence, not a Forever client measurement. Observed-waypoint mode's destination-distance presentation remains to review.
- M01: Added bounded idle geometry checks and map/button effective-scale conversion. Reanchors on width/height/scale changes at the saved angle, skips unchanged geometry and preserves last safe placement during invalid sizes.
  - RED: minimap idle-resize regression failed before implementation.
  - GREEN: `test_minimap.lua` passed resize, unequal scales, repeat-update and existing click/drag/persistence checks. Still requires enlarged-minimap client acceptance.
- Source whitespace check passed. No full integrated-suite claim while core/sidebar implementation is underway. No package, install, commit or SavedVariables inspection performed.

## Completed read-only investigation findings
- Vendor: observed-walk mode with empty evidence defers a valid local service candidate; sibling-zone hint search then excludes the current map and can display a farther Badlands result. This reproduced with synthetic eligible local candidates. It does not prove the installed Thelsamar provider record exists: exact installed provider data has not been inspected.
- Sidebar: deferred rows are appended after eligible rows regardless of saved anchor. A separate reproduced release-focus defect resolves the animated dragged card as its own drop target, discarding a valid first-slot preview. Existing activeErrandId can disagree with the top displayed row.
- Menus/editor: current quest UI is current-map POIs rather than zone-grouped quest log; existing customized roots need a safe insertion migration. Trainer root lacks pet-trainer branching. Layout currently supports only one folder level; native drops lack explicit between-slot insertion preview. Pin/edit are separate flags. These remain open implementation work.
- Core/queue worker owns planner, Init and errands (including 10-yard cadence and map-size projection fallback). Sidebar worker owns card/drop UI. Integrate and test their shared displayed-order contract before claiming either fixed.

## Integrated queue/sidebar checkpoint — source only
- Integrated route:DisplayOrder into the sidebar, not just ActiveTarget. Added an actual-handler off-map Repair drag-to-first regression: failed before this integration, passed afterward. This closes the append-deferred ordering gap in offline evidence only (S01/S02).
- Removed hidden persisted selection precedence: ActiveTarget derives its target from the shared display order, and explicit ActivateTarget moves its target to slot one. Added stale saved-selection regression (RED then GREEN). Retained two-yard/floor/taxi arrival safeguards; floor-arrival regression now explicitly places its test target first instead of relying on hidden selection (S05/S06).
- Core worker implemented local service retention with unknown-route status when no observed graph path exists; no walking yards/waypoints are invented. Added/reordered targets release stale selection; movement replans at ten yards and MapWorldSize can derive dimensions from guarded native projections (V01/R03).
- Sidebar worker added stationary cursor/scale/scroll-aware drag slots, centered text, destination-only edge-faded card art and larger backlit action buttons (S01/S03/S04). Actual visual acceptance remains pending.
- `python3 tests/run_tests.py`, destination asset `--check`, and `git diff --check` passed after shared display-order integration. Subsequent stale-selection correction passed focused Init, queue, boot and destination suites plus whitespace check; broad verification will run again after remaining wheel/quest integration.
- Retrieved installed QuestieDB addon source only for coverage audit, without reading player saves or modifying the client. All 62 files individually SHA-256 matched remote readback. Installed provider: 1.0.6, contract 4, interface 16001; Forever TOC SHA-256 `954c5cfbd6ffb812efef338b4c9a42c964b785485b6f9ab4a458679fbb4707d0`. Private ignored audit copy: `.testdeps/QuestieDB-client-audit-20261017`. Provider is not bundled into ErrandMaster. The actual installed-record audit is underway (V02/V03).
- Wheel/Trainer/editor implementation and zone-grouped quest inventory are underway in separate owned files. H03 root migration/menu integration still needs parent work. No requirement is client-accepted; no new build installed.

## Installed-provider audit correction and follow-up
- Initial decoded NPC audit found 26 admitted Loch Modan service NPCs and no local literal Ammo subtitle. Representative coordinates selected a local generic vendor and repair NPC but not Ammo. This establishes a subtitle-classification limitation, not that ammunition sellers are absent in-game.
- Parent found an important omitted provider surface: installed `src/meta/itemMeta.lua:40-47` defines ammoType, class, subClass and vendors (NPC ID array); foodType is also available. Absence of inventory on NPC rows does NOT establish absence of inventory associations in the provider. Do not conclude Ammo Vendor must remain unresolved until the item-vendor joins are examined.
- Dispatched actual installed item-record audit and, if supported by real data, bounded runtime item-to-vendor specialty indexing with synthetic regression fixtures. Also requested trainer noun aliases under verified TRAINER flags. Preserve multiple specialties and faction/map filters; do not copy provider records into distributed addon files.
- Wheel/editor and quest workers remain in progress. No additional runtime change or installed-client validation claimed at this checkpoint.

## Wheel and quest inventory checkpoint — source, not client acceptance
- Wheel worker returned implemented hub sizing, tintable silhouette shadows, retained-ring backlights, White/Gold contrast, Trainer artwork/Hunter Pet Trainer, removed Pin semantics and native insertion preview. Detailed limitations/evidence: `WHEEL-ACCEPTANCE-20261017-EVIDENCE.md`. Parent ran both new wheel acceptance suites successfully. Animated ring growth before native drop and arbitrary nested-folder movement remain OPEN; persistent-edit dismissal semantics are under independent review.
- Quest worker implemented `quests:ZoneInventory()` with localized header groups, completion queries, validated optional native coordinates and bounded collapsed-header expansion/restoration. Parent ran the new inventory test successfully and added it plus the new wheel acceptance tests to the main runner. Radial hierarchy/root-migration integration is now a separate active task; inventory alone does not satisfy H03/H04.
- R04: observed-route guidance now retains live direct distance to the final target separately from next-waypoint distance. Added failing-before/passing-after real follower and caption regressions; route-unknown/partial-end wording remains visible.
- W04: added independent soft background backlights to minimap and navigation arrow without tinting icon art. Tests failed before implementation and passed afterward; unavailable direction hides the arrow backlight. Remaining icon surfaces and actual visual intensity still require acceptance.
- The inventory-index job reported an owner-exit notification, but direct task-state lookup showed it still running; no duplicate writer was started. Do not infer completion or failure from that notification alone.
- No install, commit, game launch or player-save inspection. Full integrated verification waits for the active quest/vendor changes; all client acceptance remains OPEN.

## Inventory-based vendor classification checkpoint
- Corrected actual installed-data audit: projectile items use class=6 and their vendors arrays identify ammunition sellers, including Thelsamar's Yanni Stoutheart (Rough Arrow). The ammoType field is not a reliable projectile classifier: the audited data uses it on ammunition-consuming weapons. Reported decoded join: 15 ammunition item/vendor pairs across five Loch Modan NPCs; 24 reagent pairs across three NPCs. These are provider candidate associations, not live stock or walking-path verification.
- Implemented staged Item then NPC indexing in Data/NpcCatalog.lua. The existing Init frame scheduler calls Step(80), returns no ready catalog before both passes finish, and refreshes the queue when indexing completes. Multiple inventory-derived specialties are preserved; vendor flags, faction and valid spawns remain required. NPC-only providers explicitly report limited subtype coverage.
- Parent independently ran inventory, NPC, NPC-route and zone-search suites: all passed under Lua 5.1. Registered test_npcs_inventory.lua in the full runner. Inventory worker reported a full-suite failure at test_wheel_navigation.lua:45 during concurrent quest migration; the quest integration worker has been notified. No new full-suite-green claim yet.
- Added trainer noun aliases under TRAINER evidence. Food inventory classification remains limited in this installed dataset: explicit foodType or class=0/subClass=5 evidence was absent in the decoded audit. Do not infer a proven food inventory solely from an NPC name.
- Wheel review's owner-exit notification again did not mean it had stopped: direct task-state lookup showed both review and quest integration active. No duplicate writer/reviewer was started. Remaining wheel/editor gaps and all client acceptance remain open.

## Independent wheel review — acceptance failures reopened
- E01: enabling edit while closed does not open the wheel; center, Escape and repeated Open can hide it while wheelUnlocked remains true. Add Coordinates, Pin waypoint and AddOns Settings also dismiss it without leaving edit mode. Parent added `tests/test_wheel_edit_lifecycle_regression.lua`: RED at enabling edit must open the wheel. Not fixed or registered as green yet. Decision: center/Escape explicitly exit edit before closing; ordinary actions/binding must not silently leave hidden edit state. Combat remains a safety exception.
- E05: immediate drop at occupied icon inserts instead of grouping unless dwell has elapsed; a hub drop appends because nil target reaches WheelInsert. Preview and commit need one position-based classification; reject hub/non-ring destinations. Do not treat dwell-only grouping as accepted.
- W03: Layout/RenderHistory reset shadow vertex color to black without resetting interpolation state, causing a visible discontinuity. Preserve current interpolated tint across rebuilding.
- W04/W05: medallionGlow at OVERLAY sublevel 5 is above ARTWORK icons. Backlights must sit below icon artwork, while jewels stay above effects. Existing jewel-only ordering assertion is insufficient.
- E03/E04: drop leaves addon ghost/nativePreview until another update. Clear addon-owned transient visuals immediately on success/rejection. Native payload retention vs consumption must be explicit; SetCursor resets pointer appearance, not payload ownership. Earlier broad safe-cursor-clear wording is not established.
- W01: source alpha mass is above the texture-box center; geometric aperture checks do not establish optical centering. Keep client alignment/bleed acceptance OPEN.
- Quest integration currently owns RadialMenu.lua/Core/Database.lua; parent is not racing that writer. Apply the reviewed fixes after ownership is released, then rerun affected and integrated tests. Pre-drop animated ring growth and nested-folder moves remain separate unfinished requirements.

## Integrated quest and reviewed-wheel fixes — offline green checkpoint
- H03/H04: zone-grouped quests now reach the wheel with pagination, live-log revalidation, missing-location guidance and one-time non-destructive root migration. Parent verified all three new quest integration tests. Full 24-slot layouts remain intact and require manually freeing a slot; intentional later removal is respected.
- E01: SetEditing(true) opens a closed wheel. Open while editing keeps it visible. Center/Escape/Close exit edit mode before dismissal. Ordinary coordinate/settings/pin actions do not hide editing; outside clicks are ignored. Lifecycle regression passed after failing on the prior implementation.
- E05 and native cleanup: occupied icon drops group immediately, using the same positional criterion as preview; non-icon ring space inserts. Hub/outside drops cannot append. Success and rejection clear addon-owned previews immediately. Native payload is deliberately retained. Empty folders/collections accept drops in their ring. New native-drop regression passed RED then GREEN.
- W03/W04/W05: relayout/history preserve interpolated shadow tint. Active and retained medallion backlights now use BORDER, below ARTWORK icons; supplied jewels remain OVERLAY. Expanded effect regression passed.
- Updated obsolete tests for the new explicit lifecycle and positional drop contract. NPC-only boot fixture now correctly expects incomplete inventory coverage rather than fully ready coverage.
- Parent ran `python3 tests/run_tests.py`, `python3 tests/build_destination_card_pattern.py --check`, `python3 -m compileall -q tests tools`, and `git diff --check`: all passed at this checkpoint. No client acceptance or installation follows from this.
- Remaining editing work dispatched: pre-drop ring growth and root/folder/cross-folder moves with bounded nesting, cancellation, capacity and cycle safeguards. This worker owns RadialMenu/Database; do not race edits. Optical hub alignment, remaining icon-surface coverage and live-client acceptance remain open.

## Nested editing integration — offline verification
- Worker returned path-based root/folder/cross-folder transfers, identity/capacity/cycle guards and a two-folder-depth limit; native insertion previews grow the ring and move neighbors without saving until drop, and cancellation restores layout.
- Parent registered test_wheel_transfer.lua and test_wheel_move_handlers.lua in tests/run_tests.py and ran the complete runner successfully, including both new suites and existing quest migration, native-drop, lifecycle, routing and arrow regressions. git diff --check passed.
- This establishes offline regression coverage, not client animation or interaction acceptance. Optical hub alignment, remaining icon-surface coverage, food-data limitations and all live-client checks remain open. No install or commit performed.

## Observed merchant specialty fallback
- Extended opt-in MERCHANT_SHOW discovery beyond ammunition: inspected reagent class and food/drink subclass now record independent specialties at the observed service-access position. Mixed inventories retain all matching specialties. These are not asserted NPC coordinates or globally complete provider records.
- Added a regression that failed on missing food discovery before the fix; verified mixed inventory, unknown/generic consumables, item API failures, the 200-item read bound and discovery opt-out. Full tests/run_tests.py and git diff --check passed afterward.
- Provider food coverage remains limited for unvisited merchants. No inference from names, no save inspection and no installation. Remaining icon/hub audit is read-only and in progress; all client acceptance remains open.

## Icon coverage audit follow-up
- Added separate BACKGROUND backlights to settings/main-window logos and world-map waypoint artwork. Waypoint glow resets on pooled reuse and hides with the custom icon; other map markers retain their existing treatment.
- Removed White-category desaturation from active and retained supplied wheel icons. Neutral Back surfaces and white jewels remain independent of the artwork. Regression failed before the fix; updated the older contradictory desaturation expectation.
- Source-layer contracts and waypoint show/reuse checks passed. Integrated runner passed through minimap, then exposed missing texture methods in the settings fixture. After adding those real texture-method mocks, settings and every remaining runner suite passed; git diff --check passed. No client visual acceptance claimed.
- Hub optical alignment remains open: audit found source-art opacity above its box center. No blind anchor shift or artwork alteration applied; actual scaled rendering must guide that adjustment. No install or commit.

## Measured hub alignment and preview coverage
- Corrected the software renderer to include active/retained icon and medallion backlights plus the center shadow. Added a regression for actual runtime region inclusion; older previews omitted these layers.
- Measured the opaque circular rim independently of its decoration-biased opacity centroid. Least-squares edge fit on the 512px asset gave center (255.11,245.57), radius 247.24 and radial residual about 0.90px. This establishes a geometric offset despite the initial visual inspection appearing centered.
- Applied a scale-relative art-only anchor correction (.00075 width right, .0194 height down). Source illustration pixels, hover plaque, labels, click target and wheel geometry are unchanged. New regression failed before correction and passed afterward at .75/1/1.5 scale, checking rim alignment and all alpha>=32 pixels remain inside the hub aperture.
- Regenerated .testdeps/wheel-runtime-preview.png; complete offline suite and git diff --check passed. Software preview raises remaining visual checks for expanded-tier glow strength and Back-icon crowding, especially large icon settings; do not interpret geometry tests as client acceptance. No package/install or commit performed.

## v0.6.9-test1 candidate preparation
- Reproduced square-icon corners crossing neighboring sectors despite centered anchors. Replaced arc-width sizing with square containment inside the sector's inscribed circle, retaining a small margin. Dense/sparse, three-tier and small-viewport corner regressions failed before and passed after the fix.
- Regenerated software preview now shows Back artwork within its sectors; deliberately extended soft glow/shadows remain separate. Glow strength is a client-review question, not a reason to silently reduce the requested backlighting.
- Full offline runner, destination-art checks, Python compilation and whitespace checks passed after the geometry change. Bumped candidate metadata/docs to 0.6.9-test1 and included this ledger in the runtime-only archive build. No installation, client launch, commit or player-save inspection. All acceptance IDs remain client-open; provider food coverage and unknown walking connectors remain explicit limitations.

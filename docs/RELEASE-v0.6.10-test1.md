# v0.6.10-test1 — temporary client-test checkpoint

This is an integrated client-test prerelease, not a stable or client-accepted build. Use the published archive and its matching checksum, not earlier locally prepared archives with this version label. Target executable: Forever Beta 1.60.1.70450; TOC interface: 16001. QuestieDB Forever remains an external required dependency, not bundled data. ErrandMaster remains independent of RestedXP; coexistence only.

## Included since the installed v0.6.9-test1

- Retry minimap placement when startup geometry is unavailable, reusing one invisible/noninteractive pending button until placement succeeds.
- Resolve each ordered service relative to the preceding selected destination, not repeatedly from the player's original location. Preserve manual priority and explicit NPC identity. Search indexed maps without the old sibling-zone/radius restriction, filtering by service flags rather than assuming projected map corners bound every NPC.
- Refresh queued quests on their own maps and refresh cached coordinates at click-to-add. Vanished objectives no longer retain navigable stale coordinates.
- Provide center right-click Quests access for a full 24-slot root blocked by migration, without changing saved slots or reinserting deliberately removed categories on other layouts.
- Incrementally normalize sparse/duplicate/malformed provider lists; bound map materialization with explicit incomplete-coverage reporting. Invalidate observed navigation immediately when its evidence disappears.
- Accept valid world instance ID zero in observed trail sampling and graph validation; reject negative/missing identities and cross-instance connections.
- Preserve independent merchant observations when optional repair data fails. Record saved and failed categories without silently reporting full success at storage capacity.
- Report multiple provider-data failures independently. Empty spawn tables and malformed coordinates mark coverage incomplete while preserving valid sibling candidates.
- Provide map/service evidence diagnostics and faction exclusion counts. Missing food inventory evidence means unknown coverage, not proof that no food seller exists.
- `/em npcs explain Food Vendor` and `/em discover status` expose diagnostics. Map-specific coordinate counters are available internally but not yet printed individually by the command.

The checkpoint also publishes the accumulated UI/navigation changes already present in the v0.6.9 test installation: sidebar/arrow order, frequent distance updates, zone-grouped quests, wheel editing/folders/materials, minimap resizing and inventory-derived ammunition candidates.

## Evidence boundaries

Offline tests exercise Lua mocks, input handlers, data migrations, assets and packaging. They cannot prove native rendering, client API behavior or SavedVariables persistence. Installation readback proves matching files, not gameplay acceptance. No current live acceptance item is closed by this release. Use ACCEPTANCE-20261017.md as the detailed ledger.

Known limitations: incomplete provider/food inventory coverage and unrecorded walking connectors. Closest means closest eligible known candidate with comparable coordinates, not a guarantee about undiscovered NPCs or walking time. Provider caps/failures remain visible. Unresolved forced stops cannot provide fictional next origins or trustworthy cumulative totals. Unknown routes remain explicitly unknown. No guessed NPC coordinates or terrain routes were added.

## In-game test pass

1. Confirm AddOns shows 0.6.10-test1, QuestieDB is enabled for the character, and login produces no Lua errors.
2. From multiple zones, wait for `/em npcs status` to finish indexing. Prioritize Auction House above Bank/Ammo; verify subsequent services resolve around the auction destination. Reorder and move, then repeat. Thelsamar/Ironforge is one example, not a hardcoded case. Compare selected NPCs with actual services; capture `/em npcs explain Ammo Vendor` if selection is wrong.
3. Queue several destinations. Drag the last sidebar row to first; verify the arrow follows that first row and its distance updates while moving. A direct arrow is not a walking route.
4. Open `/em wheel`: test zone-grouped quests, other-zone objectives, Back, editor lock/unlock, native item/spell drops, root/folder transfers, cancel/Escape and normal movement. On a full migrated root lacking Quests, right-click the center and verify saved slots remain intact. Inspect hub, shadows, glow and icon containment at your UI scale; resize the minimap.
5. If deliberately testing observations, opt in with `/em discover on`, visit a merchant, inspect `/em discover status`, and opt out afterward if desired. Recording remains off unless you enable it.
6. Verify existing custom layout, errands and favorites survive `/reload` and a normal logout/login. Report version, zone, action and exact error/screenshot for failures.

## Recovery

The authorized installer preserves the prior addon and matching save/state backups outside active AddOns, keeps QuestieDB and character enablement unchanged, and verifies copied file hashes. Do not restore while WoW runs. After testing, preserve newer saves separately before any rollback; restoring preinstall saves can discard later changes. No game launch is automated.

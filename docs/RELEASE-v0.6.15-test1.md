# ErrandMaster 0.6.15-test1

Forever interface 16001 test candidate; audited against installed QuestieDB 1.0.11 and client build 1.60.1.70790. Offline verification does not establish in-client acceptance.

## Fixes
- Recognize profession occupation titles (including ranked Leatherworker/Leathercrafter and other explicit occupations), profession specializations, and ranked occupation titles ending in Trainer. Require the provider TRAINER flag; retain faction and coordinate validation.
- Resolve Pet Trainer and Weapon Master/Weapon Trainer titles to their existing wheel destinations without assigning them to a class or profession.
- Preserve every explicitly named profession on multi-profession supply vendors, plus plural Reagents. Deduplicate matching inventory/title evidence and keep profession grouping on the correct specialty only.

## Audit and limits
- Inspected all 13,411 NPC, 21,421 Item and 7,039 Object base records of the installed Forever dataset, and consumed API fields, flags, numeric defaults and direct area mappings. Static corrections are baked into that provider; runtime/localized behavior remains a separate check.
- General Repair, Bank, Auction House, Flight Master, Innkeeper, Vendor and Trainer use service flags. Ammo, reagent and food inventory joins use item class/subclass/vendor IDs. Active quests use native client APIs rather than QuestieDB quest-title matching.
- Mailbox identity remains exact unlocalized base-name matching. Unsupported object names, missing spawns, invalid/unmapped coordinates and uncertain trainer titles are not guessed. Native map projection, phase, walking access, rank-specific training and recipe availability are not established by the audit.
- QuestieDB and Waypoint UI are not modified or bundled. No save schema, waypoint preference or target coordinate changes.

## Acceptance
Repeat nearest Leatherworking Trainer, Pet Trainer, Weapon Trainer and both specialties of a multi-profession vendor in the game. Existing in-world waypoint visibility remains an independent open acceptance item.

Rollback with WoW stopped. Before restoring matching prior addon and preinstall save/state backups after a game save, preserve newer saves separately.

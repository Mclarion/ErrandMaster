# ErrandMaster 0.6.14-test1

Forever interface 16001 test candidate. This release is not evidence of in-client acceptance.

- A one-time edited-save migration moves stock Bank, Mailbox, and Auction House into Services; removes the stock Custom wedge/view and the outside Travel shortcut; keeps Travel and Trainer as independent root wedges and preserves custom folders/actions. A deliberately full custom wheel is not silently overwritten.
- Services includes Profession with all primary and secondary trainer choices until two primary slots are learned, then learned primaries and all three secondary specialties. Trainer remains a separate root with class, pet, profession, and weapon trainers.
- Labels sit under icons; icons are slightly larger/inward with stronger shape-based shadows. A new continuous union-mask perimeter shadow follows each expanded tier and adopts the hovered wedge color, without per-wedge dark seams.
- The optional Waypoint UI bridge checks native tracking and retries a missing tracked marker in a bounded way, without automatically overwriting a foreign waypoint. Waypoint UI 1.7.4 may hide markers inside its configured Hide Distance (25 yards by default); this is not established as the cause of the reported failure across all waypoints. This release does not change that user setting or offset target coordinates.
- Full offline Lua/Python suite and software wheel preview are prerequisites to installation. In-client marker visibility and visuals remain user-run acceptance after the complete bundle is installed.

Rollback after a game save requires restoring matching prior addon code and preinstall account SavedVariables/addon states with WoW stopped; preserve newer saves separately first.

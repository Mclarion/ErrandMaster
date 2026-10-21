# Local observed transport history

Implementation checkpoint; not installed or client-validated.

## Data boundary

Ship recorder/planner code, not imported transport tables. The public TOC and archive exclude the experimental static catalog and `.testdeps` fixtures. A package readback regression enforces this. Runtime native API queries and this character's own completed observations are separate from the abandoned static-import experiment. No upload or shared transport database is added.

## Flights

Completed native taxi observations retain the actual reported boarding and landing map coordinates, directed identity, sampled duration and bounded samples locally. Invalid landing coordinates do not produce a usable persisted leg. Distinct same-name endpoints do not silently overwrite each other. Reverse travel is not inferred. Client-project/build and character isolation apply.

## Boats

- `/em boat start`: confirm you have boarded; start the ride clock at the current reported map position.
- `/em boat arrive`: confirm you have disembarked; save the actual reported destination and elapsed ride time, then refresh navigation.
- `/em boat cancel`: discard an unfinished recording.
- `/em boat status`, `on`, `off`: inspect or change local boat recording. Ground trails and flight recording are independent.
- `/em boat clear`, followed by `confirm` within the displayed confirmation window: clear only this character's boat observations.

These are user confirmations, NOT automatic boat detection. Zone changes alone never establish a boat journey. Waiting time is unknown, not part of an automatically inferred schedule. Invalid/incomplete trips do not create records. Boat storage is bounded to 64 directed legs; the recorder refuses a new leg when full rather than deleting existing records.

## Calculation

A transport recommendation evaluates current position to recorded origin, then recorded landing to requested destination. It never substitutes a zone center or assumes a reverse route. A known cross-world boat connection is usable when each walking leg can be projected in its own world; no fictitious direct distance or saved distance across worlds is produced. Comparable-world candidates must meet the existing walking-distance-reduction threshold. These estimates do not establish walkability or a faster ETA.

Flights specifically require a direct player-to-target distance **strictly greater than 600 yards**. Insert a known flight only when player-to-recorded-takeoff plus recorded-landing-to-target is strictly shorter than direct player-to-target distance. Exactly 600 yards, equal costs, and longer combined walking legs do not qualify. The earlier 100-yard/15% savings threshold no longer applies to flights. Actual endpoint maps may differ from player/target maps when native world projections are comparable. Flight positions are queried through native map APIs and existing provider candidates; two known positions alone never establish a usable directed connection.

Transient boarding steps preserve the requested errand and manual order. Reaching a boarding marker does not complete the original destination. While recording a boat ride, automatic arrival completion is suppressed. The actual disembarkation command triggers onward recalculation.

This currently selects a single observed transport intermediary, not an arbitrary multi-transfer network. Client-reported coordinates and sampling/user confirmation have uncertainty; no exact floor, height, or boat timetable is invented.

## Verification

Full offline suite and whitespace checks passed after integration. Coverage includes persisted endpoint identity, reload, invalid landings, forward-only trips, cross-world boats, adjacent maps, preserved errands, boat stage labels, and public archive exclusion of imported transport data. In-game boat confirmation timing, native landing sampling, display behavior and CPU remain unverified.

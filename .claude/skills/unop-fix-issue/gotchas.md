# CK3 Gotchas

CK3 script and engine behavior that is easy to get wrong. General topics come first, then one section per game folder, in the order of `game/` and `game/common/`.

## Scopes

- **Guard a scope from outside it.** A check inside the scope it guards, e.g. `exists = scope:x` within `scope:x = { }`, already runs in the invalid scope and logs the error. Check from the enclosing scope, or enter it with `scope:x ?= { }`.
- **Inside `any_player`, bare triggers apply to the iterated player, not to root.** Such bugs show only in multiplayer.

## Triggers

- **A trigger block is an implicit AND.** A scripted trigger named `a_or_b` that just lists `a` and `b` is missing an `OR`.

## Effects

- **`destroy_title` takes effect at once.** Later checks in the same effect block no longer see the title.

## Variables

- **Variables live on the object they're set on.** Before reading `var:x` from a scope, check that its `set_variable` runs on that kind of object.
- **`has_variable` stays true after the variable's object is gone,** e.g. an ended war, while `exists = var:x` is false.

## Modifiers

- **`foo` and `foo_factor` modifiers have nearly the same display text,** so a flat amount where a percentage was meant is often a dropped `_factor`.

## Tooltips

- **`custom_description` is a tooltip wrapper, not a condition.** `custom_description = { text = X; <trigger> }` evaluates `<trigger>` and labels failures with `X`'s loc; the `text =` line is not a separate condition.
- **A `custom_description` or `custom_tooltip` wrap also collapses the evaluated tooltip** to a single line. Check every GUI context that shows the block.
- **While a tooltip is built, `create_character` saves a null character.** Guard its saved scope from outside, see **Scopes**.

## Characters and Titles

- **An independent ruler is their own `liege` and `top_liege`.** "Is a vassal" needs `is_independent_ruler = no` or `liege != this`.
- **Guardian and ward, warden and hostage, are separate pairs.** Guardians educate wards; wardens hold hostages.
- **A vassal who gains a title of their liege's tier is passed up to the liege's liege.**
- **A player who loses their last title while the primary title goes to a heir outside the dynasty is Game Over.** In a scripted handover, mind the order of the title transfers and the player switch.

## `common/buildings`

- **Building `ai_value` modifiers apply in order,** and candidates below 80% of the best one are dropped (`BUILDING_MIN_SCORE_COMPARED_TO_BEST`), except holdings.

## `common/character_interactions`

- **`cost` blocks have no root, and `ai_potential` runs before `scope:target` is set.** Values there that depend on root or the target never apply.

## `common/court_positions`

- **`appoint_court_position` and `replace_court_position` fire `on_court_position_received`.** Logic copied from a caller into the hook runs twice; move it instead.

## `common/decisions`

- **`ai_check_interval = 0` means the AI never checks the decision,** so its `is_ai = yes` branches are dead code.

## `common/governments`

- **Administrative governments differ.** Celestial, meritocratic and Japanese governments have their own bureaucracy law groups instead of `imperial_bureaucracy`. Noble Family titles are duchy-tier for administrative and county-tier for the others. Administrative, celestial, meritocratic and steppe administrative pay from treasury, so a cost check needs `treasury_or_gold`, not `gold`.
- **A ruler whose `can_get_government` fails falls back to a government valid for their heritage** (`primary_heritages`), before `on_vassal_change` runs.

## `common/landed_titles`

- **`tier_hegemony` ranks above `tier_empire`,** so `= tier_empire` misses hegemons.

## `common/on_action`

- **An on_action picks its event, runs its `effect`, then fires the event with its trigger re-checked.** An `effect` that makes the trigger fail leaves the pulse empty. `random_events` weights above 100000 never fire.
- **No on_action runs when a save is loaded.** A game-start cleanup fixes only new games; Unop is save-compatible, so gate where the state is read.
- **Script also reaches on_actions that the engine fires.** `destroy_title`, `death` and the like fire them, so check the teardown hooks, e.g. a faction's `on_destroy`, before calling a path engine-only.

## `common/religion`

- **1.20 turned many faiths into rites of a parent faith.** `rite:X` in a faith scope is never true; compare `faith.main_rite`.
- **Reforming a pagan faith creates a new faith.** Helpers that filter by the same faith skip the old faith's counties, so check every converted entity: characters, courts and counties.
- **Boolean doctrine parameters get no `$VALUE$`.** Vanilla hides marker parameters with an empty key.

## `common/succession_appointment`

- **An appointment candidate who receives a title of the appointed tier drops out** (`allowed_candidate_tier`).

## `common/trigger_localization`

- **Trigger loc lives here, under a different key,** so a key missing from `localization/` proves nothing.

## `history`

- **`Y.M` dates are valid.** Only a missing `=` is malformed.

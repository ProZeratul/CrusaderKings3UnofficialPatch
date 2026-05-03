# Examples

Short retrospectives of past investigations, each tagged with the lesson(s) it teaches. Read the relevant one when its situation comes up.

## Issue 420 — verify against current vanilla, find the simpler fix

Lessons: Step 3 (verify current vanilla), Step 5 (try simpler fix first).

Issue [#420](https://github.com/ProZeratul/CrusaderKings3UnofficialPatch/issues/420): cancelling a tribute mission and starting a new one on the same day wiped the second mission's variables, because the cancel on_action ran delayed (1 day) and refunded/cleaned the wrong mission's state.

Two mistakes on the first pass:

1. **Didn't check that the buggy flow was still reachable.** The script logic matched the reporter's diagnosis, so the investigation went straight to fix design. But vanilla 1.19 had added a 5-year cooldown to the "Pay Tribute" decisions, making the cancel-and-restart-same-day flow unreachable. The whole investigation was wasted.
2. **Designed a complex fix without checking for simpler ones.** First proposal: a counter-based supersede mechanism touching `tribute_mission_decision_effect`, the cleanup effect, and a new on_actions file added to the mod. The user asked: *"why is it even possible to start a new tribute mission immediately after cancelling? isn't preventing this a better fix?"* — pointing at the existing `is_already_tribute_missioning_trigger`, which already had the right shape but used `current_travel_plan ?=` (vacuously false when no plan exists, so cancel-pending didn't count as "still on a mission"). The actual fix would have been a 6-line `trigger_if` tweak in one file.

## Issue 440 — articulate guard intent, verify against other guards in the same block

Lessons: Step 5 (articulate guard intent, verify against other guards in the same block).

Issue [#440](https://github.com/ProZeratul/CrusaderKings3UnofficialPatch/issues/440): a Catholic HRE Emperor who took `restore_roman_empire_holy_decision` lost their HRE; afterwards `e_germany` was uncreatable (gated to non-Catholics) and Restore HRE was permanently blocked.

Two near-misses:

1. **First-draft fix targeted the wrong guard.** Proposed dropping `is_roman_emperor_trigger = yes` from `restore_holy_roman_empire_decision.is_shown`. The user pointed out the same block also had `NOT = { has_global_variable = flag_restored_roman_empire }` — which would still block the case. A no-op fix.
2. **Almost loosened a guard whose intent was right there in the loc.** The trigger label `form_germania_christian_trigger` lives in `common/trigger_localization/`, and its loc reads *"As a Catholic ruler you can reform the HRE instead"* — the design intent in one line. That reframed the fix from "let Roman Emperors create Germania" to "release the Catholic gate only when HRE is no longer reachable" (i.e. `flag_restored_roman_empire` is set). Same one-line change, philosophically aligned with vanilla intent.

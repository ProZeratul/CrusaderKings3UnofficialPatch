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

## Issue 498 — fix at the right altitude, enumerate the pattern class, verify the load-bearing assumption

Lessons: Step 2 (find the right altitude, enumerate the pattern class incl. sibling systems, evaluate suggested fixes critically, name the load-bearing assumption).

Issue [#498](https://github.com/ProZeratul/CrusaderKings3UnofficialPatch/issues/498): an Administrative noble family that loses its governorship keeps its obligation theme (`admin_theme_military`/`civilian`), so `monthly_treasury_from_military_budget_base` fires into a non-existent treasury. The pipeline converged on a per-theme `is_valid` guard when the right fix was one level up.

Four compounding mistakes:

1. **Inherited a recorded fix suggestion uncritically.** The shared file prescribed per-theme `is_valid` guards with a copied idiom (`tier = tier_duchy`, from `administrative_salary_rank_duchy`). That idiom is tier-specific; in a theme available to all tiers it wrongly reset *landed* kingdom/empire governors to balanced — a regression. Re-derive from the verified facts; a suggestion is a hypothesis, not a spec.
2. **Wrong altitude.** These themes only make sense for landed governors; the *group* `administrative_themes` is the right level. The fix should add `is_landless_ruler = no` to the group `is_shown`, mirroring how Celestial already solves it — one guard covers every theme (the per-theme approach missed `admin_theme_imperial` at first).
3. **Didn't enumerate the pattern class.** Of the four admin province-contract groups, Celestial excludes landless explicitly, Meritocratic by accident (county-tier NF title fails its `tier >= tier_duchy` check), Administrative fails to, and **`japan_administrative` fails too** (threshold `tier_county`). The fix touched only `administrative.txt` and never opened `japan_administrative.txt`, where the bug also reproduces.
4. **Load-bearing assumption never verified.** The per-theme fix depends on "an invalidated *active* level resets to the group default" — asserted from a `.info` line that is actually about `is_shown`, never corroborated. The group-`is_shown` fix sidesteps it: it runs on the exact mechanism the report confirms works for Celestial.

## Issue 501 — a narrow guard is often a proxy; read the effect and loc for intent

Lessons: Step 2 (articulate guard intent from the whole feature; target the real condition, not the proxy).

Issue [#501](https://github.com/ProZeratul/CrusaderKings3UnofficialPatch/issues/501): `restore_backwater_counties_decision` — the AI never takes it (no `ai_will_do`), and empire-tier vassals are excluded by an `is_shown` tier gate (duchy/kingdom only).

- **The tier gate was a proxy.** The decision is governor-facing: its `effect` does `liege = { notify the emperor }` and its loc reads "Restore [PrimaryTitle]" — it structurally needs a liege. The duchy/kingdom gate stood for "is a governor, not the top liege," which holds in the standard Byzantine setup (governors duchy/kingdom, emperor empire-tier). It only breaks once a player becomes a hegemon and governors can be empire-tier vassals — the real bug.
- **Widening the proxy over-reached.** The prescribed fix (blanket `tier = tier_empire`) re-admitted the case the gate was guarding: a normal independent empire-tier emperor, who then gets broken loc and an `effect` firing `liege = {}` on a non-existent liege. The fix should target the real condition (is a governor / has a liege), not widen the proxy — and neither the fixer nor the review caught it, though the `liege` block is right there.
- **Two agreeing gates signalled intent.** `is_shown` (duchy/kingdom) and `ai_check_interval_by_tier` (empire/hegemony = 0) independently excluded empire. The analyzer used the interval to confirm the AI bug but didn't apply it to the tier bug, stamping the latter confirmed/High instead of reading the loc/effect to recover the "why." (Bug 1, the missing `ai_will_do`, was a clean catch.)

## Issue 213 — find all call sites, watch for "boon to wrong party," use the tiger skill

Lessons: Step 5 (find all call sites, evaluate the reporter's fix critically, invoke the `tiger` skill).

Issue [#213](https://github.com/ProZeratul/CrusaderKings3UnofficialPatch/issues/213): an adopted bastard had their house/dynasty reset to the bio father's when the underlying bastard secret was later exposed.

Three mistakes on the first pass:

1. **Missed a duplicate of the buggy block.** Guarded `set_father` inside `secret_exposed_owner_effects_effect` but vanilla runs the same block again directly in `secret_unmarried_illegitimate_child.on_expose`. The duplicate would still fire and the bug wasn't actually fixed. Grep the symbol you're about to guard across the codebase first — vanilla often runs the same logic in 2-3 places.
2. **Took the reporter's suggested fix uncritically.** Reporter suggested removing the secret on adoption; the user pointed out this silently strips intrigue leverage from secret owners — a "boon to the wrong party." Right shape: keep the secret, guard the harmful child-side consequences via a `unop_was_adopted` flag. The reporter's diagnosis is one candidate, not the default.
3. **Hand-classified tiger warnings instead of invoking the `tiger` skill.** Added `# False positives` / `# Ignored` entries from intuition, at one point with the comment "vanilla bug, out of scope for this mod" — directly contradicting the project's purpose. Always invoke the `tiger` skill before touching `ck3-tiger.conf`.

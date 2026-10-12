# Paradox Bug Reports — Batch 01

Issues found and fixed (or evaluated) in the Unofficial Patch, to report to Paradox. Walking backward from 2026-09-27, ranked by gameplay impact.

| # | Issue | Unop | Status | ID |
| --- | --- | --- | --- | --- |
| 1 | AI never passes the top tier of Crown Authority or any Bureaucracy law | [#644](https://github.com/ProZeratul/CrusaderKings3UnofficialPatch/issues/644) | Not Created | |
| 2 | Losing an independence faction or refused-demand war doesn't lower authority for most governments | [#612](https://github.com/ProZeratul/CrusaderKings3UnofficialPatch/issues/612) | Not Created | |
| 3 | Wanua government is treated as Tribal | [#655](https://github.com/ProZeratul/CrusaderKings3UnofficialPatch/issues/655) | Not Created | |
| 4 | Multi-stop travel contracts can't be completed if the travel is cancelled | [#579](https://github.com/ProZeratul/CrusaderKings3UnofficialPatch/issues/579) | Not Created | |
| 5 | AI never takes decisions with a non-zero influence cost | [#475](https://github.com/ProZeratul/CrusaderKings3UnofficialPatch/issues/475) | Not Created | |
| 6 | Japanese tributaries of a Mandala overlord can assimilate to Mandala, breaking Japan | [#561](https://github.com/ProZeratul/CrusaderKings3UnofficialPatch/issues/561) | Created | 743114 |
| 7 | Court physician never treats diseases unless hired through the paid decision | [#605](https://github.com/ProZeratul/CrusaderKings3UnofficialPatch/issues/605) | Not Created | |
| 8 | Cannot start a new Grand Wedding due to a stale activity invitation | [#604](https://github.com/ProZeratul/CrusaderKings3UnofficialPatch/issues/604) | Not Created | |
| 9 | Random Harm game rule doesn't change how often harm events happen | [#476](https://github.com/ProZeratul/CrusaderKings3UnofficialPatch/issues/476) | Not Created | |
| 10 | Dynastic Cycle "push towards/away from Expansion" catalysts are reversed during Expansion | [#551](https://github.com/ProZeratul/CrusaderKings3UnofficialPatch/issues/551) | Not Created | |
| 11 | Hegemony-tier rulers are locked out of emperor-level major decisions | [#555](https://github.com/ProZeratul/CrusaderKings3UnofficialPatch/issues/555) | Not Created | |
| 12 | AI Demand Administrative Government wealth check is inverted | [#639](https://github.com/ProZeratul/CrusaderKings3UnofficialPatch/issues/639) | Not Created | |
| 13 | Coronation never auto-equips the crown or regalia | [#538](https://github.com/ProZeratul/CrusaderKings3UnofficialPatch/issues/538) | Not Created | |
| 14 | Rejected From Marriage Bed is not removed when a non-primary spouse or concubine is widowed | [#635](https://github.com/ProZeratul/CrusaderKings3UnofficialPatch/issues/635) | Not Created | |

---

## 1. AI never passes the top tier of Crown Authority or any Bureaucracy law

Unop: https://github.com/ProZeratul/CrusaderKings3UnofficialPatch/issues/644 / https://github.com/ProZeratul/CrusaderKings3UnofficialPatch/pull/681
Forum: https://forum.paradoxplaza.com/forum/threads/ai-will-never-pass-any-absolute-authority-law.1939758/

Summary: The AI never enacts `crown_authority_3`, `imperial_bureaucracy_3`, `celestial_bureaucracy_3`, `meritocratic_bureaucracy_3` or `japanese_bureaucracy_3`, because none of them has an `ai_will_do`.

Description: In `common/laws/00_realm_laws.txt`, every tier 1 and tier 2 law has an `ai_will_do` (`value = 1` when the ruler has the previous tier). The five top-tier laws above have none, so they default to 0 and the AI never picks them. This affects Feudal, Clan, Administrative, Celestial, Meritocratic, Steppe Admin and Japanese AI rulers.

The omission doesn't seem to be intentional: `tribal_authority_3` and `nomadic_authority_5` are also top tiers and do have the same `ai_will_do`.

Suggested fix: add the same `ai_will_do` as the lower tiers, e.g. `ai_will_do = { if = { limit = { has_realm_law = crown_authority_2 } value = 1 } }`.

Steps to reproduce:

1. Start a game and run observer mode for 100+ years.
2. Check powerful Feudal or Administrative AI realms that have the required innovation and tier 2 authority.
3. None of them passes tier 3, while Tribal AI rulers do pass `tribal_authority_3`.

---

## 2. Losing an independence faction or refused-demand war doesn't lower authority for most governments

Unop: https://github.com/ProZeratul/CrusaderKings3UnofficialPatch/issues/612 / https://github.com/ProZeratul/CrusaderKings3UnofficialPatch/pull/625

Summary: When the liege loses `independence_faction_war` or `refused_liege_demand_war`, only `crown_authority` and `tribal_authority` are lowered. Administrative, Celestial, Meritocratic, Steppe Admin, Japanese and Nomadic rulers lose nothing.

Description: In `common/casus_belli_types/00_civil_war.txt`, both CBs step the authority down with a hardcoded `add_realm_law` chain that covers only `crown_authority` and `tribal_authority`. The other governments use separate law groups (`imperial_bureaucracy`, `nomadic_authority`, etc.), so for them nothing happens. For example, an Administrative emperor who loses an independence war keeps full authority.

Both wars seem to be reachable for all these governments: the independence faction only restricts the vassal's government (e.g. Administrative vassals must be kingdom tier), and refused demands come from interactions such as imprison, revoke title, retract vassal and governor removal.

Suggested fix: step down the current authority law with `change_realm_law_level`, as `liberty_faction_war`'s `on_victory` already does (it also lacks `nomadic_authority`, though). Also, `decrease_nomadic_authority_effect` appears to be missing a `nomadic_authority_5` branch.

Steps to reproduce:

1. Play as a vassal of an Administrative or Nomadic ruler with tier 2+ authority.
2. Lead an independence faction and win the war.
3. The liege's authority law doesn't change. With a Feudal liege, it drops one tier.

---

## 3. Wanua government is treated as Tribal

Unop: https://github.com/ProZeratul/CrusaderKings3UnofficialPatch/issues/655 / https://github.com/ProZeratul/CrusaderKings3UnofficialPatch/pull/658

Summary: An adventurer who conquers a Wanua ruler becomes Tribal instead of Wanua. The same happens in a few other places where the government is chosen based on flags.

Description: `wanua_government` has both the `government_is_tribal` and `government_is_wanua` flags. The following places check `government_is_tribal` first, so Wanua always takes the Tribal branch and the Wanua branch is never reached:

- `07_dlc_ep3_scripted_effects.txt`, `ep3_become_landed_transfer_effect`: the `switch` on `scope:government_giver` (conquering a Wanua ruler as an adventurer).
- The same effect, the `if/else_if` chain on `scope:new_liege` (becoming landed under a Wanua liege).
- `00_faction_effects.txt`: peasant-uprising government setup.

Suggested fix: use `government_is_tribal_excluding_wanua` in the Tribal branches.

Steps to reproduce:

1. Play as an adventurer in maritime Southeast Asia, next to Wanua rulers.
2. Conquer a Wanua ruler's realm to become landed.
3. Your new government is Tribal instead of Wanua.

---

## 4. Multi-stop travel contracts can't be completed if the travel is cancelled

Unop: https://github.com/ProZeratul/CrusaderKings3UnofficialPatch/issues/579 (not fixed, beyond Unop scope)

Summary: The Improvised Spycraft, Collect Taxes, Hunt Criminals and Conduct Census contracts (and possibly Mediate on Behalf) can't be completed if their travel is cancelled.

Description: These contracts start a travel plan with a fixed itinerary of several stops, and they seem to rely on all stops being visited in order as part of that same travel plan. If the travel is cancelled via Go Home, Abandon Trip, or the "out of provisions" event (which can also affect the AI), there is no way to resume it and the contract stays active but can't be completed. Single-destination contracts such as Fight Corruption can be resumed via the "Travel to Complete" interaction, but this doesn't cover multi-stop itineraries.

Steps to reproduce:

1. As an adventurer, accept a Collect Taxes contract and start the travel.
2. Before the last stop, cancel the travel with Go Home or Abandon Trip.
3. The contract is still active, but there is no way to resume or complete it.

---

## 5. AI never takes decisions with a non-zero influence cost

Unop: https://github.com/ProZeratul/CrusaderKings3UnofficialPatch/issues/475 / https://github.com/ProZeratul/CrusaderKings3UnofficialPatch/pull/509

Summary: The AI seems to never take a decision that has an `influence` entry in its `cost` block (unless it has `ai_goal = yes`), even when all `is_shown`, `is_valid`, `ai_potential` and `ai_will_do` checks pass. Players are unaffected.

Description: This looks like an engine limitation: the AI doesn't seem to budget influence for decisions. It affects at least 13 decisions, e.g. `tgp_japan_imperial_branch_decision` (Request Royal Honsei), `ask_western_help_decision`, `foster_integration_decision`, `gather_faction_support_decision`, `consolidate_rule_decision`, `renounce_governorship_decision`, `house_head_consults_heaven_decision`, `favored_movement_consults_heaven_decision`, `convert_to_meritocratic_decision`.

We added `debug_log` to all 13 decisions and ran observer mode for 50 years from 867: none of them was taken even once. After the workaround below, 7 of them were taken 1–8 times each in the same period.

Workaround used in Unop: charge the influence cost in the `cost` block only for players, check that the AI can afford it in `is_shown`, and have the AI pay it with `change_influence` in `effect`. Ideally, this would be fixed in the engine instead.

Steps to reproduce:

1. Add `debug_log` to the `effect` of any of the decisions above.
2. Run observer mode for 50 years from 867.
3. The decisions are never taken by the AI.

---

## 6. Japanese tributaries of a Mandala overlord can assimilate to Mandala, breaking Japan

Unop: https://github.com/ProZeratul/CrusaderKings3UnofficialPatch/issues/561 / https://github.com/ProZeratul/CrusaderKings3UnofficialPatch/pull/583

Summary: A Ritsuryo or Soryo realm that becomes a tributary of a Mandala overlord can take `assimilate_to_mandala_decision` and become Mandala. This can make AI Japan degenerate over time (Mandala -> Feudal -> Soryo, Ritsuryo vassals expelled, landless Ritsuryo families).

Description: In `tgp_east_asia_decisions.txt`, `convert_to_mandala_government_decision` (independent rulers) blocks Japanese governments with `government_is_japanese_trigger = no`, but `assimilate_to_mandala_decision` (Mandala tributaries) doesn't have this check. The omission doesn't seem to be intentional.

Suggested fix: add `government_is_japanese_trigger = no` to `assimilate_to_mandala_decision`.

Steps to reproduce:

1. Start in 1066 or later, play as a Mandala emperor near Japan.
2. Make the Japanese Ritsuryo regent your tributary.
3. Switch to the regent: `assimilate_to_mandala_decision` is valid, and taking it turns Japan Mandala.

---

## 7. Court physician never treats diseases unless hired through the paid decision

Unop: https://github.com/ProZeratul/CrusaderKings3UnofficialPatch/issues/605 / https://github.com/ProZeratul/CrusaderKings3UnofficialPatch/pull/622

Summary: The physician treatment events (`health.3101`, `health.4001`) only fire if the court physician was hired via the Find Physician decision and their fee was paid. If a courtier is appointed via the court position UI, or the found physician is invited instead of paid, the ruler is never treated.

Description: The treatment kick-off is in `set_court_physician_effect` (`20_health_effects.txt`), which is only called from the paid `health.3001` chain and `learning_medicine_events`. Other appointment routes go through `court_physician_title_accepted_effect`, which doesn't start treatments. Since `health.3100` stops rescheduling itself when there is no physician, a character who got sick before having one is never treated. The comment at `health_events.txt:7300` ("if we hire a new physician, they will treat everyone upon being hired") suggests this isn't intended.

Suggested fix: move the treatment kick-off to `court_physician_title_accepted_effect`, similar to `wet_nurse_title_accepted_effect`.

Steps to reproduce:

1. Start as Baldwin IV in 1178 (Leprosy), without a court physician.
2. Appoint a courtier as court physician via the court positions UI.
3. The treatment event never fires. Hiring via Find Physician and paying the fee makes it fire right away.

---

## 8. Cannot start a new Grand Wedding due to a stale activity invitation

Unop: https://github.com/ProZeratul/CrusaderKings3UnofficialPatch/issues/604 / https://github.com/ProZeratul/CrusaderKings3UnofficialPatch/commit/bb19061bdf292b149c52bbadfa2b8e88cb09d37f
Forum: https://forum.paradoxplaza.com/forum/threads/new-grand-wedding-bug-in-1-19.1936012/

Summary: A promised Grand Wedding can't be started, with the tooltip "Both betrothed characters need to be adult and ready to marry" even though both are. Traveling somewhere and coming back fixes it.

Description: In `common/activities/activity_types/wedding.txt`, `can_start_showing_failures_only` checks `NOT = { any_invited_activity = {} }` for both betrothed under the `wedding_need_to_be_valid` tooltip. Any outstanding invitation blocks the wedding, even one that can no longer be accepted, and the tooltip shown is unrelated. Other activity types use `is_available` instead.

Suggested fix: move the check into its own tooltip, and only count invitations the character can still join (`can_join_activity`, `can_arrive_in_time_to_activity_minimum`).

Steps to reproduce:

1. Betroth someone with a promised Grand Wedding.
2. Wait until you get invited to some other activity. Don't accept the invitation.
3. Try to start the Grand Wedding: it's blocked with the tooltip above (reproducible with the saves attached to the forum thread).

---

## 9. Random Harm game rule doesn't change how often harm events happen

Unop: https://github.com/ProZeratul/CrusaderKings3UnofficialPatch/issues/476 / https://github.com/ProZeratul/CrusaderKings3UnofficialPatch/pull/484, https://github.com/ProZeratul/CrusaderKings3UnofficialPatch/pull/506

Summary: All enabled settings of the Random Harm game rule, from Illusion of Safety to Tragically Spiteful, give the same yearly chance of a harm event.

Description: Harm events start from `yearly_health_pulse` via `15 = harm.9501`, which then picks an event from `harm_events_pulse`. `harm.9501` has no `weight_multiplier`, so its yearly chance ignores the game rule. The rule's `harm_game_rule_likelihood_value` is instead added to the weights of the individual harm events (`harm.0501`–`harm.1112`), where it only changes which harm event is picked, not how often one happens.

Suggested fix: apply `harm_game_rule_likelihood_value` to `harm.9501`'s weight and remove it from the individual events.

Steps to reproduce:

1. Run observer mode for 50 years with Random Harm set to Illusion of Safety, logging `harm.9501`.
2. Repeat with Tragically Spiteful.
3. The number of harm events is about the same.

---

## 10. Dynastic Cycle "push towards/away from Expansion" catalysts are reversed during Expansion

Unop: https://github.com/ProZeratul/CrusaderKings3UnofficialPatch/issues/551 / https://github.com/ProZeratul/CrusaderKings3UnofficialPatch/pull/574

Summary: During the Expansion era, the "House Head / Movement consulted Heaven — push towards Expansion" catalysts push towards Tension, and the "push away from Expansion" ones push away from Tension.

Description: In the `dynastic_cycle` situation, in the Expansion -> Instability `future_phases` block, the four `..._expansion_positive` catalysts are set to `_gain` (progress towards Instability) and the `..._expansion_negative` ones to `_loss`. This is the opposite of what the catalyst names say, and of the `_instability_*` catalysts in the same block.

Suggested fix: swap `_gain`/`_loss` on these four lines.

Steps to reproduce:

1. As China during the Expansion era, cause the first catalyst above.
2. Check the Dynastic Cycle situation.
3. Progress towards Tension increases instead of decreasing.

---

## 11. Hegemony-tier rulers are locked out of emperor-level major decisions

Unop: https://github.com/ProZeratul/CrusaderKings3UnofficialPatch/issues/555 / https://github.com/ProZeratul/CrusaderKings3UnofficialPatch/pull/570

Summary: Several major decisions check `highest_held_title_tier = tier_empire`, so rulers who hold a Hegemony can't take them, although the intent seems to be "emperor or above".

Description: Affected decisions include Unite the West Slavs, Become the Greatest of Khans (both versions), GOK World Conquest, Consolidate Rule, Pleasure Dome, and two steppe decisions. CK3 already uses `>= tier_empire` for the same intent elsewhere, e.g. `06_ep3_admin_decisions.txt` has both `>= tier_empire # Only for Emperors` and `= tier_empire # Only for Emperors`.

Suggested fix: use `>= tier_empire` where the intent is "emperor or above".

Steps to reproduce:

1. Hold a custom Hegemony title and one of the West Slavic kingdoms.
2. Open the Unite the West Slavs decision.
3. It's not valid, while it is for an emperor with the same kingdom.

---

## 12. AI Demand Administrative Government wealth check is inverted

Unop: https://github.com/ProZeratul/CrusaderKings3UnofficialPatch/issues/639 / https://github.com/ProZeratul/CrusaderKings3UnofficialPatch/pull/662

Summary: The AI is blocked from `demand_admin_interaction` when it can afford it, and checks gold even when it pays from its treasury.

Description: In `06_ep3_interactions.txt`, `demand_admin_interaction`'s `ai_will_do` has `factor = 0` modifiers with `gold >= 300 / 600 / 2000`, so the AI is blocked exactly when it has the gold. Also, most eligible governments (Administrative, Celestial, Steppe Admin, Meritocratic) pay from treasury, not gold.

Suggested fix: use `treasury_or_gold < X` in these modifiers.

Steps to reproduce:

1. Run observer mode with a wealthy Administrative AI realms that have non-Administrative vassals, with `debug_log` in the interaction effect.
2. They never demand Administrative government from any vassal.

---

## 13. Coronation never auto-equips the crown or regalia

Unop: https://github.com/ProZeratul/CrusaderKings3UnofficialPatch/issues/538 / https://github.com/ProZeratul/CrusaderKings3UnofficialPatch/pull/545

Summary: At the end of a coronation, the crowning artifact is never equipped automatically, so the player has to equip it manually.

Description: In `coronation_events_6.txt`, the equip check `can_equip_artifact = scope:crowning_artifact` runs before `coronation_change_law_effect`, which replaces the `uncrowned` law. Crowns and regalia can't be equipped with `uncrowned` (`can_equip` in `00_type_templates.txt`), so the check always fails. The same pattern appears six times in the file.

Suggested fix: call `coronation_change_law_effect` before the equip check.

Steps to reproduce:

1. Hold a coronation with a crown or regalia that is not equipped.
2. Complete it.
3. The artifact is still not equipped.

---

## 14. Rejected From Marriage Bed is not removed when a non-primary spouse or concubine is widowed

Unop: https://github.com/ProZeratul/CrusaderKings3UnofficialPatch/issues/635 / https://github.com/ProZeratul/CrusaderKings3UnofficialPatch/pull/668

Summary: If the partner of a secondary spouse or concubine with `rejected_from_marriage_bed_modifier` dies, the modifier stays forever, leaving a permanent -1000% fertility penalty.

Description: The modifier is added in `health.2003` to any consort (spouses and concubines). On death, `death_management.0098` only fires if the primary spouse has the modifier, and then removes it only from spouses (`every_spouse`), not concubines. Divorce removes it correctly.

Suggested fix: use `any_consort` / `every_consort` in `death_management.0098`.

Steps to reproduce:

1. Have a ruler with a concubine or secondary spouse who gets `rejected_from_marriage_bed_modifier` (e.g. via console).
2. Kill the ruler.
3. The widowed concubine or spouse keeps the modifier and its fertility penalty.

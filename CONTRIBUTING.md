# Contributing to the Unofficial Patch

Thanks for considering a contribution! For reporting bugs without writing code, see the **Contributing** section of the [README](README.md). This document covers what we expect from pull requests.

## Scope

Unop fixes issues. It does not add new content, change the balance, or alter the gameplay beyond what's needed to make existing features work as intended. Additions and balance tweaks belong in other mods.

## Code style

* **Do the minimum change required to fix the issue.** Avoid drive-by refactors and unrelated whitespace or formatting changes.
* **Match the formatting of the surrounding vanilla code.** When wrapping existing code in a new scope, indent it properly.
* **Mark every change with a `#Unop <reason>` comment** on the first changed line (`#Unop: <reason>` is also acceptable). Don't mention tool names in the comment. Changes to Unop's own code don't need a marker.
* **Comment out vanilla code rather than deleting it.** Put the `#Unop` comment on the first removed/replaced line, and only comment out the lines you're actually replacing.
* **Don't change the interface of a vanilla object**, e.g. by adding a parameter to a scripted trigger or changing the scope it expects, since a later vanilla caller would break. Fix the call site, or call an `unop_` copy instead.
* **Put new `unop_` triggers and effects in Unop's own files**, e.g. `common/scripted_triggers/unop_triggers.txt` or `common/scripted_effects/00_unop_effects.txt`, not in a vanilla override. Prefer moving a large inline fix block into such an effect.
* **Don't write a `NOT` with several entries.** It acts as `NOR` but is easily misread as `NAND`; write `NOR` or `NAND`, or turn it into an `OR` or `AND`.
* **Add new vanilla files in a separate commit** (unchanged) before the commit with the fix. This makes review much easier.

## Workflow

1. Branch off `main`, using a short descriptive name like `<username>-fix-<slug>` (e.g. `pharaox-fix-court-positions`).
2. Run [ck3-tiger](https://github.com/amtep/tiger) with `make tiger` and resolve every non-false-positive error or warning. Add genuine false positives to `ck3-tiger.conf` under the appropriate section.
3. When practical, run the game and check `logs/error.log` for any errors related to your fix.
4. Open a pull request with a short imperative title (e.g. `Fix travel_events.2012 option B showing wrong tooltip`) and link the issue with `Fixes #<id>` in the description.

## Localization

Unop fixes only English localization. New or changed keys live in `localization/replace/english/`:

* `unop_fixed_keys_l_english.yml` - fixes to existing vanilla keys
* `unop_new_keys_*_l_english.yml` - new keys introduced by Unop

Translations to other languages are welcome as separate mods.

## AI assistance

Some maintainers use [Claude Code](https://www.anthropic.com/claude-code) when working on the mod. The `.claude/` directory contains instructions and skills that encode these guidelines for the assistant - you're welcome to read or use them, but they aren't required for contributing.

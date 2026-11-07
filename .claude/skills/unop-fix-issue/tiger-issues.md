# Tiger Issues

How to analyze, fix and review a **tiger issue**, an issue labelled `tiger`. Such an issue names tiger reports on vanilla files that its author believes point to real problems. It may add explanations or suggested fixes, but it doesn't have to. Treat them as unverified input, and double-check every report whatever the issue claims.

## Problems

Group the reports by the problem they point to, as the `tiger` skill does. Each problem gets its own verdict:

- **No longer reported**: tiger doesn't report it any more, see **Checking the Reports**.
- Otherwise, the `tiger` skill's verdict: **real**, **false positive**, **intended** or **unclear**, see **Verifying a Problem**.

The issue's reports are its scope, so a real problem is fixed, see **Resolving Tiger Reports** in `CLAUDE.md`. A false positive, intended or unclear problem keeps its reports ignored.

The pattern-class rules apply as usual, since the issue may have missed cases or be out of date. So the scope also covers siblings with the same mistake.

## Running Tiger

Run tiger single-threaded, as **Run tiger** in `CLAUDE.md` says. The comparisons below need exact output.

## Exclusions

Find the `ck3-tiger.conf` rules that currently ignore the issue's reports, by matching their `key`, `text` and `file` against the reports. A rule may also cover other reports.

## Checking the Reports

The game and the Unop change, so some reports may be gone. Before verifying anything:

1. Copy `ck3-tiger.conf` to a temp file, without the rules found above.
2. Run tiger on the current tree with `--config <copy>`, writing to a temp file.
3. Look for each of the issue's reports in the output by its file, report type and message, not by its line, since vanilla updates move lines. A report that doesn't appear is **no longer reported**. It needs no further verification and no code change; only its rule goes away.

If only some of a problem's reports are gone, un-ignore those, and verify the problem with the rest. Other reports that the removed rules were also hiding don't belong to the issue; leave them alone.

## Verifying a Problem

- Follow the vanilla logic end to end: the scopes, the callers, and where the scopes it uses are saved.
- Check the `.info` docs and the logs, see **Game Docs** in `CLAUDE.md`.
- Check the section of the `tiger` skill's `report-types.md` for the report's type, including its known false positives and known docs issues.

Then reach the verdict by the `tiger` skill's criteria.

## Arguing Verdicts

Each step reaches its own verdict on every problem. Earlier verdicts and their reasons are input to check, not rulings to follow:

- **Analysis** gives each verdict with its reason.
- **Fix** re-checks every problem, and may reach another verdict with evidence, e.g. a caller, a saved scope or a known docs issue that the analysis missed.
- **Review** gives its own verdict on every problem. A verdict it disagrees with is a `Medium` finding, with the evidence. So is a guessed fix that it finds less likely than another.
- **Re-fix** needn't accept such a finding. Re-check the problem, then either follow the finding or reject it with evidence. A re-review weighs that evidence, and repeats the finding only if the evidence doesn't hold.

Whenever a verdict differs from an earlier one, give the evidence for it. Don't give in just to end a disagreement; one that persists goes to a human.

## Updating the Exclusions

- **No longer reported:** remove the rule that ignores its reports, and change no code.
- **Real:** remove the rules that ignore its reports, and those of any sibling fixed with it.
- **False positive, intended or unclear:** make sure a rule in the verdict's section ignores its reports, with the reason in its comment. When moving a rule, drop any mention of the issue from its comment.

If a rule also covers other reports, narrow it instead of removing it, e.g. drop only the matching `OR` entries. Afterwards, tiger must show neither the fixed nor the no-longer-reported reports, and nothing new.

## In-Game Testing

The proof is in the files, so a tiger issue gets no test script. A fix whose key assumption the files can't confirm is a guess: give the reasons, as for any guessed fix.

The analysis may settle an unclear problem in-game with a repro following `testing.md`, if its symptom can be derived from the report and reached in-game, and the result would show whether the problem is real. Write at most one repro per issue, for the problem that matters most. If its run is inconclusive, it may be revised and run once more, like any repro. Its result settles the problem: `Reproduced` makes it real, anything else keeps it unclear.

## Per-Problem Lines

List the problems in this shape, one line each, wherever they are summarized:

```markdown
- `<file>:<lines>` (`<report types>`): real: <root cause and fix>
- `<file>:<lines>` (`<report types>`): no longer reported: un-ignore
- `<file>:<lines>` (`<report types>`): <false positive | intended | unclear>: <reason>
```

Give all of the problem's lines and report types, and each file if it spans several. For a false positive, the reason names its upstream tiger issue, or says that it's a new kind. For an unclear problem, it names the game test that would settle it. When a fix is a guess, append why it's the most likely one. Where the verdict differs from an earlier step's, append the evidence for it.

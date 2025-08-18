# Claude Prompt

The GitHub repository [CrusaderKings3UnofficialPatch](https://github.com/ProZeratul/CrusaderKings3UnofficialPatch) is a CK3 mod that contains fixes to the base game. I want to generate a Changelog in CSV format with a description of each fix, the version it was introduced in, and any external links if available.

The input is in the following CSV format, using `|` as delimiter:

```csv
SHA|Author|Subject|Body|PR Link
d3d74b7|pharaox|Fix \"Stock Up for Travels\" Caravan Master task||https://github.com/ProZeratul/CrusaderKings3UnofficialPatch/pull/225
```

The last 2 columns may be empty. For PRs that contain multiple fixes, `Body` may contain a list of individual commits, on a single line, separated by ` * `.

I will also give you a list of all potential PR and issue links so you can fetch them.

The output should be in the following CSV format:

```csv
SHA|Author|Description|Version|Type|PR Link|Other Links
d3d74b7|pharaox|Fixed "Stock Up for Travels" Caravan Master task that was only providing +1 travel speed/safety instead of the intended scaled amount due to travel plan modifier scaling not working properly.||Fix|https://github.com/ProZeratul/CrusaderKings3UnofficialPatch/pull/225|https://github.com/ProZeratul/CrusaderKings3UnofficialPatch/issues/224
```

To generate it, follow the PR links, and any issue links they contain, and collect information about the fix. Also collect any external links to Paradox forum posts, Reddit posts, etc.

Column descriptions:

* `SHA`, `Author`, and `PR Link` are just copied from above.
* `Description` is a good description of the fix from the perspective of the player.
* `Version` is the version the fix was introduced in.
* `Type` is `Fix` for fixes to the base game, or `Internal` for fixes of issues introduced by the mod or other internal changes.
* `Other Links` is a list of all other relevant links (issues, forum posts, Reddit posts, etc.).

Make sure to:

* Include all commits from the original batch in the output, also internal ones.
* The version can be tracked by commits "Bump version to x.y.z" or similar. Make sure to include all version bump commits as "Bumped version to x.y.z". All commits after such a commit are included in that version, until the previous version bump.
* For PRs that contain multiple fixes, prefer using the PR description. If not available, use the commit list in `Body`, ignoring messages for adding files to the mod (such as "Create <file>" or "Add <file>"), messages that are too generic to be usable, or those that indicate internal fixes, indentation changes, etc.
* For PRs that contain multiple fixes, add a separate CSV output line for each fix.
* Commits "Fix ck3-tiger errors" or similar refer to fixing errors reported by [ck3-tiger](https://github.com/amtep/tiger), a static code analysis tool. For them, generate a generic description such as "Fixed ck3-tiger errors in newly added files". These are classified as `Fix`, not as `Internal`, since the issues fixed are in the base game.
* If there are multiple `Other Link`, separate them with commas.
* Improve English and fix spelling mistakes in descriptions, but only if you are sure it's a mistake.

Note that:

* In CK3 yml files contain localization texts, not configuration.
* I am especially interested in collecting all non-PR links. Analyze all PRs and their linked issues for external links and collect them all.

Be concise. Just give me the output with the best quality you can achieve.

Don't strategize or try to cut corners. ANALYZE ALL PRS! COLLECT ALL LINKS!

I will provide a batch of commits and a list of links in the next prompt.

# Crusader Kings 3 Unofficial Patch

[Subscribe on Steam](https://steamcommunity.com/sharedfiles/filedetails/?id=2871648329)

![Unofficial Patch](https://github.com/user-attachments/assets/1712db54-24bd-4a75-86d4-fdb283677ecd)

## Overview

The **Unofficial Patch (Unop)** is a CK3 mod that fixes a large number of issues in the vanilla game - bugs, typos, missing localizations, inconsistencies, oversights, and more. It is a community-maintained collection of mostly small, targeted fixes that the developers have not (yet) addressed.

This mod focuses purely on fixing issues. It does not add new content, change the balance, or alter the gameplay beyond what is needed to make existing features work as intended.

## Fixes

The mod has been actively developed since 2022 and now contains **thousands of fixes** spanning almost every part of the game. To give a sense of the scope:

* **3,300+** in-code `#Unop` change markers across **400+** modified files
* **280+** merged pull requests and **100+** closed issues on GitHub

Over the years, Paradox has adopted a number of Unop fixes into the base game, and we drop them from the mod when they do. Even so, a much larger number of issues remain unaddressed in vanilla, and new ones appear with each CK3 update - so the mod is still very much relevant.

A complete and up-to-date list of changes is maintained externally:

* [Steam Change Notes](https://steamcommunity.com/sharedfiles/filedetails/changelog/2871648329) - full historical changelog, including fixes that predate GitHub
* [GitHub Releases](https://github.com/ProZeratul/CrusaderKings3UnofficialPatch/releases)

### Highlights

A few examples:

* **"Summon Wealthy Visitors" decision** ([#183](https://github.com/ProZeratul/CrusaderKings3UnofficialPatch/pull/183)) - major rework. The merchant is now sent to the host's *domicile* and no longer chases them around the map; they cannot be pruned, die, change court, or be selected as a ruler mid-journey; the development-level check for origin cities is lowered so options other than Constantinople actually appear; and the Artifact Materials reward correctly enables *Commission Artifact* instead of disabling it.
* **Grand Wedding lockout** - a long-standing vanilla bug introduced in 1.9.2 that could permanently prevent the player from performing a *Grand Wedding*.
* **Hold Court** - 60+ fixes across the activity's event chains: incorrect scopes, options not applying their effects, missing or wrong tooltips, duplicate event entries, and many smaller correctness issues.

## Installation

The recommended way is to subscribe on the [Steam Workshop](https://steamcommunity.com/sharedfiles/filedetails/?id=2871648329).

### Steam Workshop Out-of-Date Issue

Steam sometimes serves an older version of the mod after an update. If the launcher reports that the mod is for a different game version, or the game crashes on load:

1. Unsubscribe from the mod
2. Stop Steam
3. Subscribe again
4. Start Steam

This is a Steam-side issue we can't do anything about. If the steps above don't help, try verifying the integrity of the game files in Steam. If nothing else helps, install the mod manually as described below.

### Manual Installation

1. Download the latest release archive `CK3_FixPack-X.Y.Z.zip` from the [Releases page](https://github.com/ProZeratul/CrusaderKings3UnofficialPatch/releases).
2. Unzip it into your CK3 user mod directory:
   * Windows: `Documents\Paradox Interactive\Crusader Kings III\mod`
   * Linux: `~/.local/share/Paradox Interactive/Crusader Kings III/mod`
   * macOS: `~/Documents/Paradox Interactive/Crusader Kings III/mod`
3. Unsubscribe from the mod in Steam to avoid launcher issues.

## Compatibility

The current version is compatible with **CK3 1.19**. Older CK3 versions are supported by older mod versions; see the [Releases page](https://github.com/ProZeratul/CrusaderKings3UnofficialPatch/releases).

**The mod must be loaded at the very top of your mod list.** Because Unop fixes issues by overriding vanilla files, it conflicts with any other mod that edits the same files. Loading Unop first tells the game engine to give it lower priority - any other mod that touches the same file wins, while Unop's fixes still apply everywhere else.

With the above load order, Unop is compatible with practically every other mod. If another mod replaces a file Unop also edits, you lose Unop's fixes for that file, but you avoid breaking the other mod's content.

The mod works with all DLCs and is save-game compatible.

## Localization

The mod fixes only the **English** localization. If you play in another language, some keys added or changed by Unop will appear as raw strings. Community translations to other languages are available as separate mods - see [Links](#links).

If you'd like to translate the mod yourself, the only files you need to translate are those in `localization/replace/english`. New translations are welcome as separate mods.

## Process

Our current workflow looks roughly like this:

* We collect issues reported by users on our Steam page, GitHub repo, Paradox bug reports, and sometimes Reddit posts.
* We play the game with a troubleshooting attitude. When something doesn't seem right, we investigate it.
* We sometimes run the game in observer mode and inspect `error.log`.
* We investigate the issues methodically and thoroughly, and try to come up with the simplest possible fix.
* We reproduce all issues and verify all fixes in-game.
* We run [ck3-tiger](https://github.com/amtep/tiger) - a static analysis tool ("linter") that checks for errors and inconsistencies in script files - on all files changed by the mod, and fix every non-false-positive error or warning it reports.
* We open pull requests with the fixes and review each other's work before merging.
* After a vanilla update, we adopt any vanilla fixes for issues we'd already patched, and drop any redundant files.

See [CONTRIBUTING.md](CONTRIBUTING.md) for the code style and conventions we follow when adding fixes.

## Contributing

Contributions such as bug reports, fixes, and translations are **very welcome**!

If you've spotted a vanilla bug Unop doesn't yet cover, the most helpful thing you can do is:

* Preferred: File a [Paradox bug report](https://forum.paradoxplaza.com/forum/forums/crusader-kings-iii-bug-report.1143/) with reproduction steps, then share the link with us. The more vanilla bugs Paradox sees, the more likely they are to fix them - which means fewer fixes Unop has to maintain in the long run.
* Otherwise, just describe the bug to us directly, ideally with reproduction steps.

You can reach us either by opening an issue on [GitHub](https://github.com/ProZeratul/CrusaderKings3UnofficialPatch/issues) or by posting in the [Fix suggestions discussion](https://steamcommunity.com/workshop/filedetails/discussion/2871648329/4697908845434539387/) on Steam. Pull requests with fixes are also very welcome.

## Acknowledgment

* [Patch 1.9.0](https://forum.paradoxplaza.com/forum/developer-diary/dev-diary-128-ck3-1-9-0-lance-update.1583293/)
* [Patch 1.18.2](https://forum.paradoxplaza.com/forum/threads/update-1-18-2.1887748/)

## Links

* [Steam Workshop](https://steamcommunity.com/sharedfiles/filedetails/?id=2871648329)
* [GitHub Repository](https://github.com/ProZeratul/CrusaderKings3UnofficialPatch)
* [German Localization Add-on](https://steamcommunity.com/sharedfiles/filedetails/?id=3355568022)
* [French Localization Add-on](https://steamcommunity.com/sharedfiles/filedetails/?id=3728831113)

If you'd like to support the lead maintainer's work: [ko-fi.com/kazarion](https://ko-fi.com/kazarion).

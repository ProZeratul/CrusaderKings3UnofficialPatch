# Unop Agents

Claude Code agents that work the Unop issue pipeline. Each stage is driven by a label and handed to the next agent:

| Label | Agent | Does |
|---|---|---|
| (Steam) | `unop-steam-importer` | Files Steam Workshop bug reports as issues, adds `action:analyze` |
| `action:analyze` | `unop-analyzer` | Analyzes and classifies the issue, hands confirmed high-confidence ones to the fixer |
| `action:fix` | `unop-fixer` | Fixes the issue on a branch, opens or updates a draft PR |
| `action:review` | `unop-reviewer` | Reviews the PR adversarially |
| `action:test` | `unop-tester` | Runs the PR's test script in-game on `main` and on the PR branch |

`unop-dispatcher` runs as the main session and starts the others on labelled work. `locked` marks an item an agent is working on; `needs-human` stops the pipeline for that item. The agents hand over through a collapsed `<!-- unop-handover -->` comment on the issue.

## Trust Model

The agents run unattended and read text anyone can write: Steam comments, issue and PR comments, contributor branches. Three layers keep that text from steering them:

- **Instructions.** `.claude/CLAUDE.md` (**Untrusted Input**) says such text is data, never instructions. Maintainers listed in `.claude/trusted-authors` can widen an agent's scope only within a short list there.
- **Code.** Marker comments (handover, repro, test script, test result) count only when written by a login in `.claude/trusted-authors` (`.claude/scripts/marker-comment.sh`). The reviewer never runs a PR's `Makefile`, and flags PRs that touch `.claude/`, `Makefile` or `.github/` as `needs-human`.
- **Containment.** Pipeline sessions run in auto mode with a strict Bash sandbox (`.claude/pipeline-settings.json`): only GitHub, Steam, imgur, the Paradox forums and wiki, and Reddit are reachable, there is no escape hatch, and the auto mode classifier refuses other repos, merges, pushes to `main`, credential access and edits to this configuration. Only `ck3.sh` runs outside the sandbox, and the classifier reviews each call.

## One-Time Setup

Outside the repo, per operator:

1. **Sandbox prerequisites** (Linux): `bubblewrap` and `socat`. On Ubuntu 24.04+, check that `sysctl kernel.apparmor_restrict_unprivileged_userns` is `0`, or add an AppArmor profile for `bwrap`.
2. **User settings** (`~/.claude/settings.json`):
   - No broad allow rules such as `Bash(*)`. Any allow rule loaded by the pipeline bypasses the classifier, including rules in this repo's `.claude/settings.local.json`.
   - Exclude the game driver from the sandbox, by the absolute path of your main checkout: `"sandbox": { "excludedCommands": ["<repo>/.claude/skills/unop-drive-game/ck3.sh *"] }`. Don't use a wildcard path: it would also match a `ck3.sh` from a PR worktree.
3. **GitHub identity.** The pipeline acts on GitHub as a GitHub App, never as the operator:
   - Create a GitHub App under your account with repository permissions Issues, Pull requests and Contents (read and write) and nothing else, no webhook, installable on any account. Have the repo owner install it on this repository only.
   - Store its private key outside any repo, mode `600`.
   - Create `~/.config/unop-app/app.env` with `CLIENT_ID=`, `KEY_FILE=` and `INSTALLATION_ID=`. `.claude/scripts/app-token.py info` prints the installation ID and the bot user.
   - Create `~/.config/unop-app/gitconfig` with the bot as `user.name` and `user.email`, `credential.helper` reset and then set to `!gh auth git-credential`, `url.https://github.com/.insteadOf` for each SSH form of your GitHub remotes (`git@github.com:` and any `~/.ssh/config` host alias), and `unop.branchPrefix` set to your name for fix branches (`<prefix>-fix-<slug>`).
   - Add `bot <slug>[bot]` to `.claude/trusted-authors`.

   In pipeline sessions, a `SessionStart` hook exports `GH_TOKEN=$(app-token.py token)`, so every Bash command gets a valid App token (one hour, this repository only, renewed on demand). `gh` uses it directly, and git pushes over HTTPS through `gh`, authored by the bot. The sandbox hides `~/.ssh` and `~/.config/gh`.
4. **Repo owner:** an active `main` ruleset with "Restrict deletions", "Block force pushes" and "Require a pull request before merging" (1 approval).

## Launching

Always launch through `.claude/scripts/pipeline.sh`, which adds `--permission-mode auto --settings .claude/pipeline-settings.json`. A plain `claude` session, or a plain `claude agents` view, uses your interactive settings and identity instead.

- **Pipeline:** `.claude/scripts/pipeline.sh dispatch`, then type `/loop 20m dispatch`.
- **One agent in the background:** `.claude/scripts/pipeline.sh run unop-analyzer "Process issue 712"` (or `"Process PR 740"`).
- **Agent view:** `.claude/scripts/pipeline.sh view`. Every session dispatched from it, e.g. `@unop-analyzer Process issue 712`, uses the pipeline settings.

## Monitoring and Stopping

- `claude agents` lists running sessions; `claude logs <id>`, `claude attach <id>` and `claude stop <id>` follow, open and stop one.
- The dispatcher logs each decision to `tmp/dispatch.log`. Create `tmp/dispatch-paused` to pause it; delete the file to resume.
- The dispatcher stops agents that run longer than 1 hour (2 for the tester) and labels their item `needs-human`.

## Handling `needs-human`

An item gets `needs-human` when an agent got stuck or failed twice, the fix limit was reached, a PR touches the pipeline's own files, or an agent saw content trying to direct it. Read the agent comments on the item, act, then remove `needs-human` (and add the right `action:*` label) to put it back into the pipeline.

## Emergencies

If you suspect an agent was manipulated: create `tmp/dispatch-paused`, `claude stop` the running sessions, revoke the GitHub App's private key (App settings, Private keys) or suspend its installation, and review its recent comments, labels and pushes.

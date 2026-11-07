# Unop Agents

Claude Code agents that work the Unop issue pipeline. Each stage is driven by a label and handed to the next agent:

| Label | Agent | Does |
|---|---|---|
| (Steam) | `unop-steam-importer` | Files Steam Workshop bug reports as issues, adds `action:analyze` |
| `action:analyze` | `unop-analyzer` | Analyzes and classifies the issue, hands confirmed high-confidence ones to the fixer, and the rest, with a repro, to the tester |
| `action:fix` | `unop-fixer` | Fixes the issue on a branch, opens or updates a draft PR |
| `action:review` | `unop-reviewer` | Reviews the PR adversarially, hands a needs-work fix back to the fixer and a looks-good one with a test script to the tester |
| `action:test` | `unop-tester` | Runs the PR's test script in-game on `main` and on the PR branch, or an issue's repro on `main` and hands it back to the analyzer |

`test:*` labels hold the latest PR test verdict, `repro:*` labels the latest repro verdict. Issues labelled `tiger` name tiger reports on vanilla files: the agents check that each still appears, fix the ones they find real and keep the others ignored in `ck3-tiger.conf`, usually without an in-game test. `unop-dispatcher` runs as the main session and starts the others on labelled work. `locked` marks an item an agent is working on; `needs-human` stops the pipeline for that item. The agents hand over through a collapsed `<!-- unop-handover -->` comment on the issue.

## Trust Model

The agents run unattended and read text anyone can write: Steam comments, issues, PRs and their comments, contributor branches. What that means for you:

- **Only maintainers steer the agents.** Agents treat such text as data about the bug, never as instructions. Comments by the maintainers in `.claude/trusted-authors` count as feedback, and can widen an agent's task only within the limits in `.claude/CLAUDE.md` (**Untrusted Input**). A comment someone else has edited loses that authority.
- **Humans merge.** Agents never merge, approve or close anything, and never push to `main`; every change needs a maintainer's approval (see **Recommended Repo Setup**). A PR that touches the pipeline's own files, such as `.claude/`, `CLAUDE.md`, `Makefile` or CI, gets `needs-human` and is yours to review.
- **Agents are contained.** Pipeline sessions run sandboxed, as the GitHub App, which can reach only this repository. They can reach only GitHub, Steam, imgur, the Paradox forums and wiki, and Reddit, can't change their own configuration or memory, and can't read your keys or tokens.
- **It's not airtight.** Watch what the agents post and push, and act as in **Emergencies** if one seems manipulated.

## One-Time Setup

Each operator (a maintainer who runs the pipeline on their machine) does this once, outside the repo. The commands are for Debian-based Linux (Debian, Ubuntu, Mint).

### 1. Install the sandbox tools

Claude Code sandboxes Bash commands with bubblewrap and routes their network traffic through a proxy reached via socat:

```shell
sudo apt-get install bubblewrap socat
```

Some Debian distros may block the unprivileged user namespaces bubblewrap needs. Check:

```shell
sysctl kernel.apparmor_restrict_unprivileged_userns
```

If it prints `1`, allow them for `bwrap` only, with an AppArmor profile:

```shell
sudo tee /etc/apparmor.d/bwrap <<'EOF'
abi <abi/4.0>,
include <tunables/global>

profile bwrap /usr/bin/bwrap flags=(unconfined) {
  userns,
  include if exists <local/bwrap>
}
EOF
sudo apparmor_parser -r /etc/apparmor.d/bwrap
```

Then `bwrap --ro-bind / / true && echo ok` should print `ok`. In Claude Code, `/sandbox` shows whether the sandbox is active.

### 2. Install the token script's dependencies

`.claude/scripts/app-token.py` signs GitHub App tokens with PyJWT:

```shell
sudo apt-get install python3-jwt python3-cryptography
```

### 3. Install ck3-tiger and the `tiger` skill

The analyzer, fixer and reviewer run [ck3-tiger](https://github.com/amtep/tiger), which must be on your `PATH`:

```shell
gh release download -R amtep/tiger -p 'ck3-tiger-linux-*.tar.gz' -D /tmp
mkdir -p ~/bin
tar -xzf /tmp/ck3-tiger-linux-*.tar.gz -C ~/bin --strip-components=1 --wildcards '*/ck3-tiger'
ck3-tiger --version
```

They also use the `tiger` skill: the fixer to fix or ignore tiger reports, the analyzer and reviewer to judge them. It lives in the private [pharaox/ck3](https://github.com/pharaox/ck3) repo; ask pharaox for access, then clone it and link the skill into your user skills:

```shell
git clone git@github.com:pharaox/ck3.git <path>/ck3
mkdir -p ~/.claude/skills
ln -s <path>/ck3/.claude/skills/tiger ~/.claude/skills/tiger
```

A `git pull` in the clone updates the skill.

### 4. Create `.env` and adjust your Claude Code settings

`.env` in the repo root tells the scripts and agents where the game is. It's git-ignored, so create it, with Steam's default paths:

```shell
CK3_BASE_DIR="${HOME}/.steam/steam/steamapps/common/Crusader Kings III/game"
CK3_USER_DIR="${HOME}/.local/share/Paradox Interactive/Crusader Kings III"
```

If you build `ck3-tiger` yourself, also add `CK3_TIGER_DIR` with the path of that checkout, so the agents read the source of the tiger they run.

Allow the agents to read the game files, the game's user directory (logs, `.info` files), the `tiger` skill and, if set, `CK3_TIGER_DIR`, and to use the skill. Put these rules in `~/.claude/settings.json` if you work on several CK3 mods, or in this repo's `.claude/settings.local.json` if Unop is your only one. Pipeline sessions load both files.

```json
{
  "permissions": {
    "allow": [
      "Read(~/.steam/steam/steamapps/common/Crusader Kings III/**)",
      "Read(~/.steam/debian-installation/steamapps/common/Crusader Kings III/**)",
      "Read(~/.local/share/Paradox Interactive/Crusader Kings III/**)",
      "Read(<path>/ck3/.claude/skills/tiger/**)",
      "Read(<path>/tiger/**)",
      "Read(~/.cache/ck3-shots/**)",
      "Skill(tiger)",
      "Skill(tiger:*)"
    ]
  }
}
```

In `~/.claude/settings.json`:

- **Remove broad allow rules** such as `Bash(*)`, `Bash(*:*)`, a bare `WebFetch` or `Edit`. Pipeline sessions ignore Bash allow rules (`classifyAllShell`), but any other allow rule they load skips the auto mode classifier, and that includes rules in this repo's `.claude/settings.local.json`.
- **Keep `Edit` and write rules out of it.** User settings apply to pipeline sessions too, so an `Edit` rule for your other mods would let an agent change them without review. Put such rules in the `.claude/settings.local.json` of the projects that need them.
- **Exclude the game driver from the sandbox,** so the tester can start and stop the game. Use the absolute path of your main checkout, never a wildcard path, which would also match a `ck3.sh` from a PR:

  ```json
  {
    "sandbox": {
      "excludedCommands": [
        "/home/<you>/<path>/CrusaderKings3UnofficialPatch/.claude/skills/unop-drive-game/ck3.sh *"
      ]
    }
  }
  ```

### 5. Create a GitHub App

The pipeline acts on GitHub as a GitHub App. Its tokens last an hour and reach this repository only, and you can revoke it at any time.

1. On GitHub, open **Settings > Developer settings > GitHub Apps > New GitHub App**:
   - **GitHub App name:** e.g. `<you>-agents`. Its bot user will be `<you>-agents[bot]`.
   - **Homepage URL:** `https://github.com/ProZeratul/CrusaderKings3UnofficialPatch`.
   - **Webhook:** uncheck **Active**.
   - **Repository permissions:** **Contents**, **Issues** and **Pull requests** set to **Read and write**. Leave everything else at **No access** (**Metadata** stays read-only).
   - **Where can this GitHub App be installed?** **Any account**.
2. Click **Create GitHub App**. On the App's page, note the **Client ID**, then click **Generate a private key**.
3. Move the downloaded key to `~/.config/unop-app/key.pem`, readable only by you. Pipeline sessions block reads of this exact path:

   ```shell
   mkdir -p -m 700 ~/.config/unop-app
   mv <downloads>/<you>-agents.*.private-key.pem ~/.config/unop-app/key.pem
   chmod 600 ~/.config/unop-app/key.pem
   ```

4. Ask the repo owner to install the App from `https://github.com/apps/<you>-agents/installations/new`, choosing **Only select repositories** and **CrusaderKings3UnofficialPatch**.

### 6. Configure the pipeline identity

Create `~/.config/unop-app/app.env` (mode `600`), first without the installation ID:

```ini
# GitHub App the Unop pipeline acts as (read by .claude/scripts/app-token.py)
CLIENT_ID=<Client ID from step 5>
INSTALLATION_ID=<from app-token.py info, see below>
KEY_FILE=~/.config/unop-app/key.pem
```

Once the App is installed, look up the installation ID and the bot's user ID, and fill in `INSTALLATION_ID`:

```shell
.claude/scripts/app-token.py info
# app: <you>-agents (id ..., owner <you>)
# installation: <installation ID> on ProZeratul (selected)
# bot: <you>-agents[bot] (user id <bot ID>, email <bot ID>+<you>-agents[bot]@users.noreply.github.com)
```

Create `~/.config/unop-app/gitconfig` (mode `600`), which pipeline sessions include on top of your own git config:

```ini
# Git settings for Unop pipeline sessions, included via pipeline-settings.json.
[user]
	name = <you>-agents[bot]
	email = <bot ID>+<you>-agents[bot]@users.noreply.github.com
[credential]
	# Drop your own credential helpers, then use the App token via gh.
	helper =
	helper = !gh auth git-credential
[url "https://github.com/"]
	# Push over HTTPS with the App token instead of your SSH key.
	# Add a line for each SSH host alias you use for GitHub in ~/.ssh/config.
	insteadOf = git@github.com:
[unop]
	# Prefix for fix branches: <prefix>-fix-<slug>
	branchPrefix = <you>
```

Link the token script to a fixed path, from which the pipeline's hooks run it, and check that a token can be minted. Run this in your main checkout:

```shell
ln -s "$PWD/.claude/scripts/app-token.py" ~/.config/unop-app/app-token.py
~/.config/unop-app/app-token.py token > /dev/null && echo ok
```

Finally, add the bot to `.claude/trusted-authors` in a PR, so that other agents accept its marker comments:

```
bot <you>-agents[bot]
```

In pipeline sessions, a `PreToolUse` hook runs `~/.config/unop-app/app-token.py refresh` before each Bash call, outside the sandbox: it renews the token in `~/.cache/unop-app/token` when it's older than 50 minutes. A `SessionStart` hook makes every Bash command export `GH_TOKEN` from that file. `gh` uses it directly, and git pushes over HTTPS through `gh`, as the bot. The sandbox can read the token but not write it, and hides the App's key and `app.env` as well as `~/.ssh` and `~/.config/gh`, so your own keys and token are out of reach too.

## Recommended Repo Setup

The repo owner sets this up once, for all operators, so that nothing the pipeline does reaches `main` without a human approval:

- **Protect `main`.** In **Settings > Rules > Rulesets**, an active branch ruleset (`MainBranchProtection`) with:
  - **Enforcement status:** Active, with an empty bypass list.
  - **Target branches:** the default branch.
  - **Restrict deletions** and **Block force pushes**.
  - **Require a pull request before merging**, with **Required approvals** set to 1, **Dismiss stale pull request approvals when new commits are pushed**, so an approval doesn't carry over to commits the fixer pushes later, and **Require review from Code Owners**, so the approval must come from a maintainer in `.github/CODEOWNERS`, never from a GitHub App.
- **Protect tags.** A tag ruleset (target: all tags) with **Restrict creations**, **Restrict updates** and **Restrict deletions**, so no agent can create or move release tags.
- **Make releases immutable** (**Settings > General > Releases > Enable release immutability**), so no agent can replace a published release's assets. It applies to releases published from then on.
- **Keep auto-merge off** (**Settings > General > Allow auto-merge**), so no agent can queue a merge.
- **Give write access only to maintainers.** Contributors work from forks; the agents can't push to fork branches.
- **Install each operator's GitHub App on this repository only**, with the permissions in step 5 of the setup above.

## Launching

Always launch through `.claude/scripts/pipeline.sh`, which adds `--permission-mode auto --settings .claude/pipeline-settings.json`. A plain `claude` session, or a plain `claude agents` view, uses your interactive settings and identity instead.

Launch from a main checkout on an up-to-date `main`. The agents run its scripts and trust the authors in its `.claude/trusted-authors`, and the worktree agents start from its last commit. To test pipeline changes, you can launch from their branch instead; `pipeline.sh` then warns that `.claude/` differs from `origin/main`, and fixers leave their worktrees behind (see below).

- **Pipeline:** `.claude/scripts/pipeline.sh dispatch`, then type `/loop 20m dispatch`.
- **One agent in the background:** `.claude/scripts/pipeline.sh run unop-analyzer "Process issue 712"` (or `"Process PR 740"`).
- **Agent view:** `.claude/scripts/pipeline.sh view`. Every session dispatched from it, e.g. `@unop-analyzer Process issue 712`, uses the pipeline settings.

## Monitoring and Stopping

- `claude agents` lists running sessions; `claude logs <id>`, `claude attach <id>` and `claude stop <id>` follow, open and stop one.
- The dispatcher logs each decision to `tmp/dispatch.log`. Create `tmp/dispatch-paused` to pause it; delete the file to resume.
- The dispatcher stops agents that run longer than 1 hour (2 for the tester) and labels their item `needs-human`.
- Agents remove their worktrees when they finish. A fixer can't when its worktree's `.claude/` differs from `origin/main` (when you launched from another branch): the sandbox keeps `.claude/` read-only, so switching to the fix branch leaves the old files behind as changes. Claude Code also leaves `worktree-agent-*` branches behind. To remove all of them, run `.claude/scripts/cleanup.sh`. It keeps the worktrees of running agents (Claude Code locks them), worktrees with changes outside `.claude/`, and fix branches that aren't pushed, and prints what it removed and kept.

## Handling `needs-human`

An item gets `needs-human` when an agent got stuck or failed twice, the fix limit was reached, a PR touches the pipeline's own files, or an agent saw content trying to direct it. Read the agent comments on the item, act, then remove `needs-human` (and add the right `action:*` label) to put it back into the pipeline.

## Emergencies

If you suspect an agent was manipulated: create `tmp/dispatch-paused`, `claude stop` the running sessions, revoke the GitHub App's private key (App settings, Private keys) or suspend its installation, and review its recent comments, labels and pushes.

Before running git again in the main checkout, check `.git/` for files an agent could have planted: a `.git/commondir` (`pipeline.sh` refuses to start with one) or changed `gitdir` and `commondir` files under `.git/worktrees/`, which redirect git to another repo and its config, and so to commands outside the sandbox.

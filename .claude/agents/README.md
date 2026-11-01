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

The fixer and reviewer lint with [ck3-tiger](https://github.com/amtep/tiger), which must be on your `PATH`:

```shell
gh release download -R amtep/tiger -p 'ck3-tiger-linux-*.tar.gz' -D /tmp
mkdir -p ~/bin
tar -xzf /tmp/ck3-tiger-linux-*.tar.gz -C ~/bin --strip-components=1 --wildcards '*/ck3-tiger'
ck3-tiger --version
```

The fixer also uses the `tiger` skill to fix or ignore tiger warnings. It lives in the private [pharaox/ck3](https://github.com/pharaox/ck3) repo; ask pharaox for access, then clone it and link the skill into your user skills:

```shell
git clone git@github.com:pharaox/ck3.git <path>/ck3
mkdir -p ~/.claude/skills
ln -s <path>/ck3/.claude/skills/tiger ~/.claude/skills/tiger
```

A `git pull` in the clone updates the skill.

### 4. Adjust your Claude Code settings

The game must be installed at the paths in `.env` (Steam's default). Allow the agents to read the game files, the game's user directory (logs, `.info` files) and the `tiger` skill, and to use the skill. Put these rules in `~/.claude/settings.json` if you work on several CK3 mods, or in this repo's `.claude/settings.local.json` if Unop is your only one. Pipeline sessions load both files.

```json
{
  "permissions": {
    "allow": [
      "Read(~/.steam/steam/steamapps/common/Crusader Kings III/**)",
      "Read(~/.steam/debian-installation/steamapps/common/Crusader Kings III/**)",
      "Read(~/.local/share/Paradox Interactive/Crusader Kings III/**)",
      "Read(<path>/ck3/.claude/skills/tiger/**)",
      "Skill(tiger)",
      "Skill(tiger:*)"
    ]
  }
}
```

In `~/.claude/settings.json`:

- **Remove broad allow rules** such as `Bash(*)`, `Bash(*:*)` or a bare `WebFetch`. Any allow rule the pipeline loads skips the auto mode classifier, and that includes rules in this repo's `.claude/settings.local.json`.
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
3. Move the downloaded key to `~/.config/<you>-agents`, readable only by you:

   ```shell
   mkdir -p -m 700 ~/.config/<you>-agents
   mv <downloads>/<you>-agents.*.private-key.pem ~/.config/<you>-agents/key.pem
   chmod 600 ~/.config/<you>-agents/key.pem
   ```

4. Ask the repo owner to install the App from `https://github.com/apps/<you>-agents/installations/new`, choosing **Only select repositories** and **CrusaderKings3UnofficialPatch**.

### 6. Configure the pipeline identity

Create `~/.config/unop-app/app.env`, first without the installation ID:

```shell
mkdir -p -m 700 ~/.config/unop-app
```

```ini
# GitHub App the Unop pipeline acts as (read by .claude/scripts/app-token.py)
CLIENT_ID=<Client ID from step 5>
INSTALLATION_ID=<from app-token.py info, see below>
KEY_FILE=~/.config/<you>-agents/key.pem
```

Once the App is installed, look up the installation ID and the bot's user ID, and fill in `INSTALLATION_ID`:

```shell
.claude/scripts/app-token.py info
# app: <you>-agents (id ..., owner <you>)
# installation: <installation ID> on ProZeratul (selected)
# bot: <you>-agents[bot] (user id <bot ID>, email <bot ID>+<you>-agents[bot]@users.noreply.github.com)
```

Create `~/.config/unop-app/gitconfig`, which pipeline sessions include on top of your own git config:

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

Check that a token can be minted:

```shell
.claude/scripts/app-token.py token > /dev/null && echo ok
```

Finally, add the bot to `.claude/trusted-authors` in a PR, so that other agents accept its marker comments:

```
bot <you>-agents[bot]
```

In pipeline sessions, a `SessionStart` hook exports `GH_TOKEN=$(app-token.py token)`, so every Bash command gets a valid token, renewed when it's close to expiry. `gh` uses it directly, and git pushes over HTTPS through `gh`, as the bot. The sandbox hides `~/.ssh` and `~/.config/gh`, so your own keys and token are out of reach.

## Recommended Repo Setup

The repo owner sets this up once, for all operators, so that nothing the pipeline does reaches `main` without a human approval:

- **Protect `main`.** In **Settings > Rules > Rulesets**, an active branch ruleset (`MainBranchProtection`) with:
  - **Enforcement status:** Active, with an empty bypass list.
  - **Target branches:** the default branch.
  - **Restrict deletions** and **Block force pushes**.
  - **Require a pull request before merging**, with **Required approvals** set to 1 and **Dismiss stale pull request approvals when new commits are pushed**, so an approval doesn't carry over to commits the fixer pushes later.
- **Keep auto-merge off** (**Settings > General > Allow auto-merge**), so no agent can queue a merge.
- **Give write access only to maintainers.** Contributors work from forks; the agents can't push to fork branches.
- **Install each operator's GitHub App on this repository only**, with the permissions in step 5 of the setup above.

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

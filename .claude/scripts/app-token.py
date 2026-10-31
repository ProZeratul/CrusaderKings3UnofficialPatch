#!/usr/bin/env -S python3 -I
"""Installation tokens for the GitHub App the Unop pipeline acts as.

Usage:
  app-token.py token  print an installation token (cached, renewed when close to expiry)
  app-token.py env    print shell exports that give each Bash command a fresh token
                      (the pipeline's SessionStart hook appends them to $CLAUDE_ENV_FILE)
  app-token.py info   print the App slug, its installations, and the bot user (for setup)

Config: ~/.config/unop-app/app.env, KEY=VALUE lines:
  CLIENT_ID=<App client ID>
  INSTALLATION_ID=<installation on the Unop repo; see "info">
  KEY_FILE=<path to the App's private key .pem>
"""
import json
import os
import shlex
import sys
import time
import urllib.parse
import urllib.request
from datetime import datetime


API = "https://api.github.com"
REPO = "CrusaderKings3UnofficialPatch"
APP_DIR = os.path.expanduser("~/.config/unop-app")
CACHE = os.path.join(os.environ.get("TMPDIR", "/tmp"), f"unop-app-token-{os.getuid()}.json")
MARGIN = 10 * 60  # renew tokens with less than 10 minutes left (they last 1 hour)


def config():
    cfg = {}
    with open(os.path.join(APP_DIR, "app.env")) as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#"):
                k, _, v = line.partition("=")
                cfg[k.strip()] = v.strip().strip('"')
    cfg["KEY_FILE"] = os.path.expanduser(cfg["KEY_FILE"])
    return cfg


def request(method, path, bearer, body=None):
    req = urllib.request.Request(
        API + path,
        method=method,
        data=None if body is None else json.dumps(body).encode(),
        headers={
            "Authorization": f"Bearer {bearer}",
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28",
        },
    )
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.load(resp)


def app_jwt(cfg):
    import jwt  # only needed when minting

    now = int(time.time())
    with open(cfg["KEY_FILE"]) as f:
        key = f.read()
    return jwt.encode({"iat": now - 60, "exp": now + 540, "iss": cfg["CLIENT_ID"]}, key, algorithm="RS256")


def token():
    try:
        with open(CACHE) as f:
            cached = json.load(f)
        if cached["expires"] - time.time() > MARGIN:
            return cached["token"]
    except (OSError, ValueError, KeyError):
        pass
    cfg = config()
    resp = request(
        "POST",
        f"/app/installations/{cfg['INSTALLATION_ID']}/access_tokens",
        app_jwt(cfg),
        {"repositories": [REPO]},
    )
    expires = datetime.fromisoformat(resp["expires_at"].replace("Z", "+00:00")).timestamp()
    fd = os.open(CACHE + ".new", os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w") as f:
        json.dump({"token": resp["token"], "expires": expires}, f)
    os.replace(CACHE + ".new", CACHE)
    return resp["token"]



def env():
    print(f"export GH_CONFIG_DIR={shlex.quote(APP_DIR)}")
    print(f'export GH_TOKEN="$({shlex.quote(os.path.abspath(__file__))} token)"')


def info():
    cfg = config()
    bearer = app_jwt(cfg)
    app = request("GET", "/app", bearer)
    print(f"app: {app['slug']} (id {app['id']}, owner {app['owner']['login']})")
    for inst in request("GET", "/app/installations", bearer):
        print(f"installation: {inst['id']} on {inst['account']['login']} ({inst['repository_selection']})")
    bot = f"{app['slug']}[bot]"
    with urllib.request.urlopen(f"{API}/users/{urllib.parse.quote(bot)}", timeout=30) as resp:
        user = json.load(resp)
    print(f"bot: {bot} (user id {user['id']}, email {user['id']}+{bot}@users.noreply.github.com)")


def main():
    args = sys.argv[1:]
    if args == ["token"]:
        print(token())
    elif args == ["env"]:
        env()
    elif args == ["info"]:
        info()
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()

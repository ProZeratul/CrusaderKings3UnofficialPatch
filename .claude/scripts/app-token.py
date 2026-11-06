#!/usr/bin/env -S python3 -I
"""Installation tokens for the GitHub App the Unop pipeline acts as.

Usage:
  app-token.py refresh  renew the cached token if it's missing or close to expiry
  app-token.py env      print shell exports that give each Bash command the cached token
  app-token.py token    refresh, then print the token (for setup checks)
  app-token.py info     print the App slug, its installations, and the bot user (for setup)

Config: ~/.config/unop-app/app.env, KEY=VALUE lines:
  CLIENT_ID=<App client ID>
  INSTALLATION_ID=<installation on the Unop repo; see "info">
  KEY_FILE=<path to the App's private key .pem, e.g. ~/.config/unop-app/key.pem>
"""
import json
import os
import shlex
import sys
import tempfile
import time
import urllib.parse
import urllib.request


API = "https://api.github.com"
REPO = "CrusaderKings3UnofficialPatch"
APP_DIR = os.path.expanduser("~/.config/unop-app")
# outside the sandbox's writable paths, so sandboxed commands can read the token but not plant one
CACHE_DIR = os.path.expanduser("~/.cache/unop-app")
CACHE = os.path.join(CACHE_DIR, "token")
MAX_AGE = 50 * 60  # tokens last 1 hour; renew after 50 minutes


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


def fresh():
    try:
        st = os.stat(CACHE)
    except OSError:
        return False
    return st.st_uid == os.getuid() and time.time() - st.st_mtime < MAX_AGE


def refresh():
    if fresh():
        return
    cfg = config()
    resp = request(
        "POST",
        f"/app/installations/{cfg['INSTALLATION_ID']}/access_tokens",
        app_jwt(cfg),
        {"repositories": [REPO]},
    )
    os.makedirs(CACHE_DIR, mode=0o700, exist_ok=True)
    # a unique temp file per process, so concurrent renewals don't collide; the rename is atomic
    fd, tmp = tempfile.mkstemp(dir=CACHE_DIR)
    with os.fdopen(fd, "w") as f:
        f.write(resp["token"])
    os.replace(tmp, CACHE)


def env():
    print(f"export GH_CONFIG_DIR={shlex.quote(APP_DIR)}")
    print(f'export GH_TOKEN="$(cat {shlex.quote(CACHE)})"')


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
    if args == ["refresh"]:
        refresh()
    elif args == ["env"]:
        env()
    elif args == ["token"]:
        refresh()
        with open(CACHE) as f:
            print(f.read())
    elif args == ["info"]:
        info()
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()

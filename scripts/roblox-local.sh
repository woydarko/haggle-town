#!/usr/bin/env bash
# Builds roblox/build-local.rbxl for Studio testing: same code as default.project.json plus
# ServerStorage.Config (BackendUrl + HmacSecret from .env) and HttpService enabled.
# Output and the generated project file are gitignored because they contain the HMAC secret.
# Usage: BACKEND_URL=https://... bash scripts/roblox-local.sh   (default: the Railway URL below)
set -euo pipefail

BACKEND_URL="${BACKEND_URL:-https://backend-production-fccb03fb.up.railway.app}"

python - "$BACKEND_URL" <<'EOF'
import json, sys
url = sys.argv[1]
env = {}
for line in open(".env", encoding="utf-8"):
    line = line.strip()
    if line and not line.startswith("#") and "=" in line:
        k, v = line.split("=", 1)
        env[k] = v
secret = env.get("RBX_HMAC_SECRET")
if not secret:
    sys.exit("RBX_HMAC_SECRET missing in .env")
project = json.load(open("roblox/default.project.json", encoding="utf-8"))
tree = project["tree"]
# Paths are relative to the generated file's folder (roblox/), same as default.project.json.
tree["HttpService"] = {"$properties": {"HttpEnabled": True}}
tree.setdefault("ServerStorage", {})["Config"] = {
    "$className": "Folder",
    "BackendUrl": {"$className": "StringValue", "$properties": {"Value": url}},
    "HmacSecret": {"$className": "StringValue", "$properties": {"Value": secret}},
}
json.dump(project, open("roblox/local.project.json", "w", encoding="utf-8"), indent=2)
print("wrote roblox/local.project.json (BackendUrl =", url + ")")
EOF

rojo build roblox/local.project.json -o roblox/build-local.rbxl
echo "Open roblox/build-local.rbxl in Roblox Studio and press Play."

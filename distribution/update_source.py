"""Writes the SideStore/AltStore source for a release (run by the build workflow).

The app's permissions are read from the built app itself (Info.plist privacy strings and the
embedded entitlements), so the source always matches the IPA exactly; SideStore refuses an
install when they differ.

    python3 update_source.py --template distribution/sidestore-source.json \
        --previous previous.json --out build/sidestore-source.json \
        --version 0.5.0 --build 42 --ipa build/MemoryGarden.ipa \
        --ipa-url https://…/MemoryGarden.ipa --icon-url https://…/icon.png \
        --info-plist path/to/Info.plist --entitlements ent.plist
"""
import argparse
import datetime
import json
import os
import plistlib
import sys

IGNORED_ENTITLEMENTS = {"application-identifier", "com.apple.developer.team-identifier", "get-task-allow", "keychain-access-groups"}
REQUIRED_APP_KEYS = ["name", "bundleIdentifier", "developerName", "localizedDescription", "iconURL", "versions", "appPermissions"]
REQUIRED_VERSION_KEYS = ["version", "date", "downloadURL", "size", "minOSVersion"]


def load_json(path):
    try:
        with open(path) as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError, TypeError):
        return None


def permissions(info_plist, entitlements):
    with open(info_plist, "rb") as f:
        info = plistlib.load(f)
    privacy = {k: v for k, v in sorted(info.items()) if k.startswith("NS") and k.endswith("UsageDescription")}
    ents = []
    if entitlements and os.path.getsize(entitlements) > 0:
        with open(entitlements, "rb") as f:
            ents = sorted(k for k in plistlib.load(f) if k not in IGNORED_ENTITLEMENTS)
    return info, {"entitlements": ents, "privacy": privacy}


def validate(source):
    problems = []
    for key in ["name", "identifier", "apps"]:
        if key not in source:
            problems.append(f"source is missing {key}")
    for app in source.get("apps", []):
        problems += [f"app is missing {k}" for k in REQUIRED_APP_KEYS if k not in app]
        for v in app.get("versions", []):
            problems += [f"version {v.get('version')} is missing {k}" for k in REQUIRED_VERSION_KEYS if k not in v]
            if not str(v.get("downloadURL", "")).startswith("https://"):
                problems.append("downloadURL must be https")
    return problems


def main():
    p = argparse.ArgumentParser()
    for name in ["template", "out", "version", "build", "ipa", "ipa-url", "icon-url", "info-plist"]:
        p.add_argument(f"--{name}", required=True)
    p.add_argument("--previous")
    p.add_argument("--entitlements")
    p.add_argument("--notes", default="")
    a = p.parse_args()

    source = load_json(a.template)
    info, perms = permissions(a.info_plist, a.entitlements)
    app = source["apps"][0]
    if info.get("CFBundleIdentifier") and info["CFBundleIdentifier"] != app["bundleIdentifier"]:
        sys.exit(f"Bundle ID mismatch: IPA has {info['CFBundleIdentifier']}, source says {app['bundleIdentifier']}")

    previous = load_json(a.previous) or {}
    try:
        history = previous["apps"][0]["versions"]
    except (KeyError, IndexError, TypeError):
        history = []

    entry = {
        "version": a.version,
        "buildVersion": a.build,
        "date": datetime.date.today().isoformat(),
        "localizedDescription": a.notes or f"Memory Garden {a.version}",
        "downloadURL": a.ipa_url,
        "size": os.path.getsize(a.ipa),
        "minOSVersion": info.get("MinimumOSVersion", "18.0"),
    }
    app["versions"] = [entry] + [v for v in history if v.get("version") != a.version][:9]
    app["appPermissions"] = perms
    app["iconURL"] = source["iconURL"] = a.icon_url

    problems = validate(source)
    if problems:
        sys.exit("Source is invalid:\n  " + "\n  ".join(problems))
    with open(a.out, "w") as f:
        json.dump(source, f, indent=2, ensure_ascii=False)
        f.write("\n")
    print(f"Source updated to {a.version}: {len(app['versions'])} version(s), permissions {json.dumps(perms)}")


if __name__ == "__main__":
    main()

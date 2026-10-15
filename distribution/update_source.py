"""Writes the SideStore source JSON for a new release (used by the build workflow)."""
import datetime
import json
import sys

template, out, version, build, size, url, icon = sys.argv[1:8]
with open(template) as f:
    source = json.load(f)
try:
    with open(out) as f:
        previous = json.load(f)["apps"][0]["versions"]
except (FileNotFoundError, KeyError, IndexError, json.JSONDecodeError):
    previous = []

app = source["apps"][0]
entry = {
    "version": version,
    "buildVersion": build,
    "date": datetime.date.today().isoformat(),
    "localizedDescription": f"Memory Garden {version}",
    "downloadURL": url,
    "size": int(size),
    "minOSVersion": "17.0",
}
app["versions"] = [entry] + [v for v in previous if v.get("version") != version][:9]
app["iconURL"] = source["iconURL"] = icon
with open(out, "w") as f:
    json.dump(source, f, indent=2, ensure_ascii=False)
    f.write("\n")
print(f"Source updated to {version}")

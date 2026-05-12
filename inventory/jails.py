#!/usr/bin/env python3
"""Dynamic inventory script that discovers jails from roles/jails/."""
import json
import os
import re

def main():
    # Resolve to project root (one level up from inventory/)
    script_dir = os.path.dirname(os.path.realpath(__file__))
    project_root = os.path.dirname(script_dir)
    jails_dir = os.path.join(project_root, "roles", "jails")

    hosts = []
    if os.path.isdir(jails_dir):
        for entry in sorted(os.listdir(jails_dir)):
            path = os.path.join(jails_dir, entry)
            if os.path.isdir(path) and re.match(r"^\d+_", entry):
                name = re.sub(r"^\d+_", "", entry)
                hosts.append(name)

    inventory = {
        "jails": {
            "hosts": hosts,
        },
        "_meta": {
            "hostvars": {},
        },
    }

    print(json.dumps(inventory))

if __name__ == "__main__":
    main()

#!/usr/bin/env python3
import argparse
import re
from pathlib import Path

PATTERN = re.compile(r"^(?P<major>0|[1-9]\d*)\.(?P<minor>0|[1-9]\d*)\.(?P<patch>0|[1-9]\d*)(?:-(?P<stage>beta|rc)\.(?P<number>[1-9]\d*))?$")

def parse(version: str) -> dict[str, str]:
    match = PATTERN.fullmatch(version)
    if not match:
        raise ValueError(f"invalid release version: {version}")

    major = match.group("major")
    minor = match.group("minor")
    patch = match.group("patch")
    stage = match.group("stage")
    number = match.group("number")
    app_version = f"{major}.{minor}.{patch}"
    app_build = f"{major}{minor}{patch}"
    prerelease = "true" if stage else "false"

    return {
        "tag_version": version,
        "tag": f"v{version}",
        "app_version": app_version,
        "app_build": app_build,
        "prerelease": prerelease,
        "stage": stage or "final",
        "stage_number": number or "",
    }

def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("version")
    parser.add_argument("--github-output", type=Path)
    parser.add_argument("--field", choices=["tag_version", "tag", "app_version", "app_build", "prerelease", "stage", "stage_number"])
    args = parser.parse_args()

    try:
        values = parse(args.version)
    except ValueError as exc:
        print(exc)
        return 1

    if args.field:
        print(values[args.field])
        return 0

    if args.github_output:
        with args.github_output.open("a", encoding="utf-8") as handle:
            for key, value in values.items():
                handle.write(f"{key}={value}\n")
        return 0

    for key, value in values.items():
        print(f"{key}={value}")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())

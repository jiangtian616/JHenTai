"""Update the stable AltSource feed from release metadata, never from the tag name."""

import argparse
import json
from pathlib import Path
import re


ASSET_NAME = re.compile(r"JHenTai_([0-9]+(?:\.[0-9]+)+)\+([0-9]+)\.ipa")


def version_key(version, build):
    """Compare numeric version components, then build within that version."""
    if not re.fullmatch(r"[0-9]+(?:\.[0-9]+)+", version):
        raise ValueError(f"Invalid version: {version!r}")
    if not re.fullmatch(r"[0-9]+", str(build)):
        raise ValueError(f"Invalid build number: {build!r}")
    parts = [int(part) for part in version.split(".")]
    while parts and parts[-1] == 0:
        parts.pop()
    return tuple(parts), int(build)


def update_feed(feed, release, allow_downgrade=False):
    """Return whether the feed changed; rejected releases leave it untouched."""
    if release.get("draft") or release.get("prerelease"):
        print("Skipping draft/prerelease: this feed contains stable releases only")
        return False
    assets = [asset for asset in release["assets"]
              if re.fullmatch(r"JHenTai_.*\.ipa", asset["name"])]
    if not assets:
        print("::warning::Release has no JHenTai_*.ipa asset; keeping current feed")
        return False
    if len(assets) != 1:
        raise ValueError("Expected exactly one JHenTai IPA asset")
    asset = assets[0]
    match = ASSET_NAME.fullmatch(asset["name"])
    if not match:
        raise ValueError(f"Unexpected IPA asset name: {asset['name']!r}")
    version, build = match.groups()
    candidate_key = version_key(version, build)
    versions = feed["apps"][0]["versions"]
    if not allow_downgrade and any(
        version_key(entry["version"], entry["buildVersion"]) > candidate_key
        for entry in versions
    ):
        print(f"Skipping older release {version}+{build}; feed already has a newer version")
        return False
    size = asset["size"]
    if type(size) is not int or size <= 0:
        raise ValueError("IPA asset size must be a positive integer")
    if not release.get("published_at"):
        raise ValueError("Release has no publication date")
    entry = {
        "version": version,
        "buildVersion": build,
        "date": release["published_at"],
        "localizedDescription": release.get("body") or "",
        "downloadURL": asset["browser_download_url"],
        "size": size,
    }
    if versions == [entry]:
        print("AltSource.json already up to date")
        return False
    feed["apps"][0]["versions"] = [entry]
    print(f"Updating AltSource.json to {version}+{build}")
    return True


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--release", required=True, type=Path)
    parser.add_argument("--feed", required=True, type=Path)
    parser.add_argument("--allow-downgrade", action="store_true")
    args = parser.parse_args()
    release = json.loads(args.release.read_text(encoding="utf-8"))
    feed = json.loads(args.feed.read_text(encoding="utf-8"))
    if update_feed(feed, release, args.allow_downgrade):
        args.feed.write_text(json.dumps(feed, ensure_ascii=False, indent=2) + "\n",
                             encoding="utf-8")


if __name__ == "__main__":
    main()

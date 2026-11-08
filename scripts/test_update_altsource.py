import copy
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

from update_altsource import update_feed, version_key


def release(version="8.0.18", build="341", **fields):
    return {
        "tag_name": "v-unrelated-tag",
        "draft": False,
        "prerelease": False,
        "published_at": "2026-10-27T00:00:00Z",
        "body": '中文说明\nSecond line: "quoted" $value `code`',
        "assets": [{
            "name": f"JHenTai_{version}+{build}.ipa",
            "browser_download_url": "https://example.com/release/app.ipa",
            "size": 12345,
        }],
        **fields,
    }


def feed():
    return {"name": "source", "apps": [{"name": "app", "versions": [
        {"version": "8.0.17", "buildVersion": "338"}
    ]}]}


class UpdateFeedTests(unittest.TestCase):
    def test_asset_metadata_and_description_are_preserved(self):
        source, rel = feed(), release()
        self.assertTrue(update_feed(source, rel))
        entry = source["apps"][0]["versions"][0]
        self.assertEqual((entry["version"], entry["buildVersion"]), ("8.0.18", "341"))
        self.assertEqual(entry["localizedDescription"], rel["body"])
        self.assertEqual(entry["date"], rel["published_at"])
        self.assertEqual(entry["size"], 12345)
        self.assertEqual(entry["downloadURL"], rel["assets"][0]["browser_download_url"])
        self.assertEqual(source["name"], "source")

    def test_identical_rerun_is_noop(self):
        source, rel = feed(), release()
        update_feed(source, rel)
        before = copy.deepcopy(source)
        self.assertFalse(update_feed(source, rel))
        self.assertEqual(source, before)

    def test_same_version_can_refresh_metadata(self):
        source = feed()
        update_feed(source, release())
        self.assertTrue(update_feed(source, release(body="corrected notes")))

    def test_old_release_finishing_last_cannot_downgrade(self):
        source = feed()
        update_feed(source, release())
        before = copy.deepcopy(source)
        self.assertFalse(update_feed(source, release("8.0.17", "999")))
        self.assertEqual(source, before)

    def test_lower_build_of_same_version_is_skipped(self):
        source = feed()
        before = copy.deepcopy(source)
        self.assertFalse(update_feed(source, release("8.0.17", "337")))
        self.assertEqual(source, before)

    def test_explicit_rollback(self):
        source = feed()
        self.assertTrue(update_feed(source, release("8.0.16", "330"), True))
        self.assertEqual(source["apps"][0]["versions"][0]["version"], "8.0.16")

    def test_draft_and_prerelease_are_skipped_even_with_rollback(self):
        for flags in ({"draft": True}, {"prerelease": True}):
            with self.subTest(flags=flags):
                source, before = feed(), feed()
                self.assertFalse(update_feed(source, release(**flags), True))
                self.assertEqual(source, before)

    def test_no_ipa_is_noop(self):
        source = feed()
        self.assertFalse(update_feed(source, release(assets=[])))
        self.assertEqual(source, feed())

    def test_ambiguous_ipa_is_rejected_without_mutation(self):
        rel = release()
        rel["assets"] *= 2
        source = feed()
        with self.assertRaises(ValueError):
            update_feed(source, rel)
        self.assertEqual(source, feed())

    def test_invalid_asset_is_rejected(self):
        for name in ("JHenTai_8.0.18.ipa", "JHenTai_8.0.18+.ipa",
                     "JHenTai_8.0.18+341+342.ipa"):
            with self.subTest(name=name):
                rel = release()
                rel["assets"][0]["name"] = name
                with self.assertRaises(ValueError):
                    update_feed(feed(), rel)

    def test_numeric_version_order_and_trailing_zeroes(self):
        self.assertGreater(version_key("8.0.10", "1"), version_key("8.0.9", "999"))
        self.assertEqual(version_key("8.0", "01"), version_key("8.0.0", "1"))
        self.assertGreater(version_key("8.0.17", "339"), version_key("8.0.17", "338"))

    def test_empty_feed_can_be_initialized(self):
        source = feed()
        source["apps"][0]["versions"] = []
        self.assertTrue(update_feed(source, release()))

    def test_invalid_release_metadata_is_rejected(self):
        for size in (0, -1, "123", True):
            rel = release()
            rel["assets"][0]["size"] = size
            with self.subTest(size=size), self.assertRaises(ValueError):
                update_feed(feed(), rel)
        with self.assertRaises(ValueError):
            update_feed(feed(), release(published_at=None))

    def test_cli_rerun_keeps_exact_file_bytes(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            source, rel = root / "feed.json", root / "release.json"
            source.write_text(json.dumps(feed()), encoding="utf-8")
            rel.write_text(json.dumps(release()), encoding="utf-8")
            cmd = [sys.executable, str(Path(__file__).with_name("update_altsource.py")),
                   "--feed", str(source), "--release", str(rel)]
            subprocess.run(cmd, check=True, capture_output=True)
            before = source.read_bytes()
            subprocess.run(cmd, check=True, capture_output=True)
            self.assertEqual(source.read_bytes(), before)


if __name__ == "__main__":
    unittest.main()

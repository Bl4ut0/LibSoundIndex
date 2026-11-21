from hashlib import sha256
from io import BytesIO
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch
from zipfile import ZipFile

from scripts import release


class ReleaseTests(unittest.TestCase):
    def archive(self, *, missing=None, extra=None):
        data = BytesIO()
        with ZipFile(data, "w") as archive:
            for path in Path(release.ADDON).rglob("*"):
                if path.is_file() and path.name != missing:
                    archive.write(path, path.as_posix())
            if extra:
                archive.writestr(extra, "wrong package root")
        return data.getvalue()

    def test_archive_covers_all_client_tocs(self):
        versions = release.inspect_archive(self.archive())
        self.assertEqual({name for name, _ in versions},
                         {"1.15.8", "1.15.9", "1.60.1", "2.5.5", "2.5.6", "5.5.3", "12.0.1"})

    def test_archive_rejects_missing_runtime_wrong_root_and_version(self):
        with self.assertRaisesRegex(ValueError, "missing file"):
            release.inspect_archive(self.archive(missing="LibSoundIndexDebug.lua"))
        with self.assertRaisesRegex(ValueError, "Invalid archive path"):
            release.inspect_archive(self.archive(extra="RawData/Item.csv"))
        with self.assertRaisesRegex(ValueError, "must declare Version"):
            release.inspect_archive(self.archive(), "99.0.1")

    def test_forever_uses_the_exact_version_type(self):
        catalog = [
            {"name": "1.60.1", "id": 71, "gameVersionTypeID": 11},
            {"name": "1.60.1", "id": 72, "gameVersionTypeID": 88568},
            {"name": "2.5.6", "id": 73},
        ]
        self.assertEqual(release.version_ids(catalog, [("1.60.1", 88568), ("2.5.6", None)]), [72, 73])
        with self.assertRaisesRegex(ValueError, "found 2"):
            release.version_ids(catalog, [("1.60.1", None)])
        with self.assertRaisesRegex(ValueError, "found 0"):
            release.version_ids(catalog, [("1.15.9", None)])

    def test_upload_is_reserved_before_the_single_curseforge_post(self):
        tag, commit, data = "v2.1.0-beta1", "a" * 40, b"fixture"
        digest = sha256(data).hexdigest()
        with TemporaryDirectory() as directory:
            archive = Path(directory) / "LibSoundIndex-v2.1.0-beta1.zip"
            archive.write_bytes(data)
            checksum = archive.with_suffix(".zip.sha256")
            checksum.write_text(f"{digest}  {archive.name}\n", encoding="ascii")
            assets = [
                {"name": path.name, "digest": "sha256:" + sha256(path.read_bytes()).hexdigest()}
                for path in (archive, checksum)
            ]
            github_release = {"draft": False, "tag_name": tag, "prerelease": True, "body": "Changes", "assets": assets}
            events = []

            def github(path, payload=None):
                if "/releases/tags/" in path:
                    return github_release
                if "deployments?" in path:
                    return []
                if path.endswith("/deployments"):
                    events.append("reserve")
                    self.assertEqual(payload["payload"]["projectId"], 1476448)
                    return {"sha": commit, "id": 13}
                events.append(payload["state"])
                return {}

            def upload(path, body, metadata):
                events.append("upload")
                self.assertEqual(body, data)
                self.assertEqual(metadata["releaseType"], "beta")
                self.assertEqual(metadata["gameVersions"], [72])
                self.assertTrue((path.parent / "curseforge-attempt.json").is_file())
                return 45

            with (patch.dict("os.environ", {"GITHUB_REPOSITORY": "Bl4ut0/LibSoundIndex"}),
                  patch.object(release, "github_api", side_effect=github),
                  patch.object(release, "upload_file", side_effect=upload)):
                release.publish(tag, commit, archive, data, digest, [72])
            self.assertEqual(events, ["reserve", "in_progress", "upload", "success"])

            with (patch.dict("os.environ", {"GITHUB_REPOSITORY": "Bl4ut0/LibSoundIndex"}),
                  patch.object(release, "github_api", side_effect=[github_release, [{"id": 13}]]),
                  patch.object(release, "upload_file") as attempt):
                with self.assertRaisesRegex(ValueError, "already reserved"):
                    release.publish(tag, commit, archive, data, digest, [72])
                attempt.assert_not_called()


if __name__ == "__main__":
    unittest.main()

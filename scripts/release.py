"""Build LibSoundIndex from a Git ref and publish the verified ZIP to CurseForge."""

import argparse
from hashlib import sha256
from io import BytesIO
import json
import os
from pathlib import Path, PurePosixPath
import re
import subprocess
from urllib.error import HTTPError, URLError
from urllib.request import HTTPRedirectHandler, Request, build_opener
from uuid import uuid4
from zipfile import ZipFile

ADDON = "LibSoundIndex"
PROJECT = 1476448
ENDPOINT = "https://wow.curseforge.com/api"
TAG_PATTERN = re.compile(r"v[0-9]+\.[0-9]+\.[0-9]+(?:-beta\.?[0-9]+)?")
CLIENT_TOCS = {"Vanilla", "TBC", "Camelot", "Mists", "Mainline"}
# 11601 was a compatibility alias. CurseForge classifies this client as 1.60.1.
GAME_VERSIONS = {
    11508: ("1.15.8", None),
    11509: ("1.15.9", None),
    16001: ("1.60.1", 88568),
    20505: ("2.5.5", None),
    20506: ("2.5.6", None),
    50503: ("5.5.3", None),
    120001: ("12.0.1", None),
}


def git(*args):
    return subprocess.check_output(["git", *args])


def resolve_commit(ref):
    return git("rev-parse", "--verify", "--end-of-options", ref + "^{commit}").decode().strip()


def inspect_archive(data, version=None):
    with ZipFile(BytesIO(data)) as archive:
        files = {}
        for entry in archive.infolist():
            name = entry.filename
            path = PurePosixPath(name)
            if (not path.parts or path.parts[0] != ADDON or "\\" in name or ".." in path.parts
                    or (entry.external_attr >> 16) & 0o170000 == 0o120000):
                raise ValueError(f"Invalid archive path or file type: {name}")
            if not entry.is_dir():
                if name in files:
                    raise ValueError(f"Duplicate archive entry: {name}")
                files[name] = entry
        expected_tocs = {f"{ADDON}/{ADDON}_{client}.toc" for client in CLIENT_TOCS}
        if {name for name in files if name.endswith(".toc")} != expected_tocs:
            raise ValueError("Archive must contain the five supported client TOCs.")
        interfaces = set()
        for name in sorted(expected_tocs):
            contents = archive.read(files[name]).decode("utf-8-sig")
            fields = dict(re.findall(r"^## ([\w-]+):[ \t]*([^\r\n]+)", contents, re.M))
            if fields.get("X-Curse-Project-ID") != str(PROJECT):
                raise ValueError(f"Wrong CurseForge project in {name}")
            if version is not None and fields.get("Version") != version:
                raise ValueError(f"{name} must declare Version {version} for this tag.")
            declared = {int(value.strip()) for value in fields["Interface"].split(",")}
            if not declared - {11601} or declared - {11601} - GAME_VERSIONS.keys():
                raise ValueError(f"Unmapped Interface metadata in {name}")
            if 11601 in declared and 16001 not in declared:
                raise ValueError(f"Camelot alias requires Interface 16001 in {name}")
            interfaces.update(declared)
            for line in contents.splitlines():
                if line and not line.startswith("#"):
                    filename = f"{ADDON}/{line.strip().replace(chr(92), '/')}"
                    if filename not in files:
                        raise ValueError(f"{name} references a missing file: {line}")
        return [GAME_VERSIONS[interface] for interface in sorted(interfaces - {11601})]


def build_archive(ref, tag, output):
    if tag is not None and not TAG_PATTERN.fullmatch(tag):
        raise ValueError("Release tag must be vX.Y.Z or vX.Y.Z-betaN.")
    commit = resolve_commit(ref)
    if tag and resolve_commit(f"refs/tags/{tag}") != commit:
        raise ValueError("Source commit does not match the release tag.")
    version = tag[1:] if tag else None
    data = git("archive", "--format=zip", commit, "--", f"{ADDON}/")
    game_versions = inspect_archive(data, version)
    output.mkdir(parents=True, exist_ok=True)
    archive = output / f"{ADDON}-{tag or 'dev'}.zip"
    digest = sha256(data).hexdigest()
    archive.write_bytes(data)
    archive.with_suffix(".zip.sha256").write_text(f"{digest}  {archive.name}\n", encoding="ascii")
    print(f"Built {archive.name} from {commit} (SHA-256 {digest}).")
    return commit, archive, data, digest, game_versions


def version_ids(catalog, game_versions):
    if not isinstance(catalog, list):
        raise ValueError("Unexpected CurseForge version catalog.")
    ids = []
    for name, version_type in game_versions:
        matches = [
            row["id"] for row in catalog
            if row.get("name") == name
            and (version_type is None or row.get("gameVersionTypeID") == version_type)
            and type(row.get("id")) is int and row["id"] > 0
        ]
        if len(matches) != 1:
            raise ValueError(f"Expected one CurseForge version for {name}, found {len(matches)}.")
        ids.extend(matches)
    if len(set(ids)) != len(ids):
        raise ValueError("Several supported versions resolved to the same CurseForge ID.")
    return ids


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, request, response, code, message, headers, url):
        return None


def curseforge(path, *, body=None, content_type=None, timeout=45):
    token = os.environ.get("CURSEFORGE_API_TOKEN", "").strip()
    if not token or "\n" in token or "\r" in token:
        raise ValueError("Configure the GitHub Actions secret CURSEFORGE_API_TOKEN.")
    headers = {"X-Api-Token": token}
    if content_type:
        headers["Content-Type"] = content_type
    request = Request(ENDPOINT + path, data=body, headers=headers)
    try:
        with build_opener(NoRedirect()).open(request, timeout=timeout) as response:
            return json.load(response)
    except HTTPError as error:
        raise ValueError(f"CurseForge {request.get_method()} failed (HTTP {error.code}).") from None
    except URLError:
        raise ValueError(f"CurseForge {request.get_method()} could not complete.") from None


def upload_file(archive, data, metadata):
    boundary = uuid4().hex
    body = b"".join((
        f'--{boundary}\r\nContent-Disposition: form-data; name="metadata"\r\n\r\n'.encode(),
        json.dumps(metadata).encode(),
        f'\r\n--{boundary}\r\nContent-Disposition: form-data; name="file"; filename="{archive.name}"\r\n'.encode(),
        b"Content-Type: application/zip\r\n\r\n",
        data,
        f"\r\n--{boundary}--\r\n".encode(),
    ))
    response = curseforge(f"/projects/{PROJECT}/upload-file", body=body, timeout=180,
                         content_type=f"multipart/form-data; boundary={boundary}")
    file_id = response.get("id")
    if type(file_id) is not int or file_id <= 0:
        raise ValueError("CurseForge did not return a file ID. Check deployment history before retrying.")
    return file_id


def github_api(path, payload=None):
    args = ["gh", "api", path]
    data = None
    if payload is not None:
        args += ["--method", "POST", "--input", "-"]
        data = json.dumps(payload).encode()
    return json.loads(subprocess.check_output(args, input=data))


def publish(tag, commit, archive, data, digest, game_ids):
    repo = os.environ.get("GITHUB_REPOSITORY", "")
    if not re.fullmatch(r"[\w.-]+/[\w.-]+", repo):
        raise ValueError("GITHUB_REPOSITORY must identify the repository.")
    release = github_api(f"repos/{repo}/releases/tags/{tag}")
    if release["draft"] or release["tag_name"] != tag or not (release["body"] or "").strip():
        raise ValueError("A published GitHub release with notes is required.")
    is_beta = "-" in tag
    if release["prerelease"] != is_beta:
        raise ValueError("The GitHub release channel must match its tag.")

    checksum = archive.with_suffix(".zip.sha256")
    missing = []
    for asset_path in (archive, checksum):
        existing = next((asset for asset in release["assets"] if asset["name"] == asset_path.name), None)
        if existing is None:
            missing.append(str(asset_path))
        elif existing.get("digest") != "sha256:" + sha256(asset_path.read_bytes()).hexdigest():
            raise ValueError(f"Existing GitHub asset differs from the checked build: {asset_path.name}")

    deployments = f"repos/{repo}/deployments"
    prior = github_api(f"{deployments}?ref={tag}&environment=curseforge&per_page=100")
    if prior:
        raise ValueError("A CurseForge upload was already reserved for this tag. Inspect deployment history.")
    if missing:
        subprocess.run(["gh", "release", "upload", tag, "--repo", repo, *missing], check=True)

    evidence = {"tag": tag, "commit": commit, "sha256": digest, "projectId": PROJECT}
    reservation = github_api(deployments, {
        "ref": tag, "environment": "curseforge", "auto_merge": False, "required_contexts": [],
        "production_environment": not is_beta, "description": "LibSoundIndex CurseForge upload",
        "payload": evidence,
    })
    deployment_id = reservation["id"]
    if reservation["sha"] != commit or type(deployment_id) is not int or deployment_id <= 0:
        raise ValueError("GitHub deployment reservation does not match the checked source.")
    evidence["deploymentId"] = deployment_id
    (archive.parent / "curseforge-attempt.json").write_text(json.dumps(evidence, indent=2) + "\n", encoding="utf-8")
    statuses = f"{deployments}/{deployment_id}/statuses"
    github_api(statuses, {"state": "in_progress", "auto_inactive": False})
    file_id = upload_file(archive, data, {
        "displayName": f"{ADDON} {tag}",
        "gameVersions": game_ids,
        "releaseType": "beta" if is_beta else "release",
        "changelog": release["body"],
        "changelogType": "markdown",
    })
    evidence["fileId"] = file_id
    (archive.parent / "curseforge-upload.json").write_text(json.dumps(evidence, indent=2) + "\n", encoding="utf-8")
    github_api(statuses, {
        "state": "success", "auto_inactive": False, "description": f"CurseForge file {file_id}",
        "environment_url": f"https://www.curseforge.com/wow/addons/libsoundindex/files/{file_id}",
    })
    print(f"Submitted CurseForge file {file_id} to project {PROJECT}.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("build", "check", "publish"))
    parser.add_argument("--ref", default="HEAD")
    parser.add_argument("--tag")
    parser.add_argument("--output", type=Path, default=Path(".versions/Release"))
    args = parser.parse_args()
    if args.command == "publish" and not args.tag:
        parser.error("Publishing requires an existing published GitHub release tag.")
    commit, archive, data, digest, game_versions = build_archive(args.ref, args.tag, args.output)
    if args.command != "build":
        ids = version_ids(curseforge("/game/wow/versions"), game_versions)
        print("CurseForge authenticated. Verified versions: " + ", ".join(name for name, _ in game_versions))
        if args.command == "publish":
            publish(args.tag, commit, archive, data, digest, ids)


if __name__ == "__main__":
    try:
        main()
    except (KeyError, ValueError, OSError, subprocess.CalledProcessError) as error:
        raise SystemExit(str(error)) from None

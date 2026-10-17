#!/usr/bin/env python3

import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import sys
import tempfile
from datetime import datetime, timezone


PLATFORMS = ("ubuntu", "macos")
REQUIRED_ENV = {
    "ubuntu": ("AGE_PASSPHRASE",),
    "macos": ("AGE_PASSPHRASE", "RBW_EMAIL", "RBW_PASSWORD", "RBW_TOTP_SEED"),
}


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2) + "\n")


def fingerprint(source):
    digest = hashlib.sha256()
    for path in sorted(source.rglob("*")):
        if path in (source / "docker.log", source / "macos.log"):
            continue
        if path.is_symlink():
            content = os.fsencode(os.readlink(path))
            kind = b"link"
        elif path.is_file():
            content = path.read_bytes()
            kind = b"file"
        else:
            continue
        digest.update(os.fsencode(path.relative_to(source)) + b"\0" + kind + b"\0")
        digest.update(str(path.lstat().st_mode).encode() + b"\0")
        digest.update(hashlib.sha256(content).digest())
    return digest.hexdigest()


def prepare(repo, extra_paths):
    repo = repo.resolve(strict=True)
    paths = subprocess.check_output(["git", "ls-files", "-z"], cwd=repo).decode().split("\0")
    paths = sorted(set(filter(None, [*paths, *extra_paths])))
    for name in paths:
        path = repo / name
        if Path(name).is_absolute() or ".." in Path(name).parts:
            raise ValueError(f"input must be repository-relative: {name}")
        if not path.is_symlink() and not path.resolve().is_relative_to(repo):
            raise ValueError(f"input leaves repository: {name}")
        if name in extra_paths and not (path.is_file() or path.is_symlink()):
            raise ValueError(f"explicit input is not a file: {name}")
    root = repo / "tmp" / "herdr-tests"
    root.mkdir(parents=True, exist_ok=True)
    run = Path(tempfile.mkdtemp(prefix="run-", dir=root))
    source = run / "source"
    source.mkdir()
    copied = []
    for name in paths:
        original = repo / name
        if not original.is_file() and not original.is_symlink():
            continue
        target = source / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(original, target, follow_symlinks=False)
        copied.append(name)
    expected = sorted(path.stem for path in (source / "tests/integration").glob("*.sh"))
    if not expected:
        raise ValueError("snapshot contains no integration assertions")
    write_json(run / "manifest.json", {
        "commit": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=repo).decode().strip(),
        "sha256": fingerprint(source),
        "inputs": copied,
        "assertions": expected,
    })
    print(run)


def run_platform(run, platform):
    source = run / "source"
    manifest = json.loads((run / "manifest.json").read_text())
    if fingerprint(source) != manifest["sha256"]:
        raise ValueError("snapshot changed; prepare a new run")
    run_env = os.environ.copy()
    missing = [name for name in REQUIRED_ENV[platform] if not run_env.get(name)]
    if missing:
        raise ValueError("missing environment variables: " + ", ".join(missing))
    lock_dir = Path(tempfile.gettempdir()) / f"dotfiles-herdr-{os.getuid()}"
    lock_dir.mkdir(mode=0o700, exist_ok=True)
    if (lock_dir.stat().st_uid != os.getuid() or lock_dir.is_symlink()
            or lock_dir.stat().st_mode & 0o077):
        raise ValueError("unsafe platform lock directory")
    with (lock_dir / f"{platform}.lock").open("a") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise ValueError(f"another pilot is already running {platform}") from None
        with (run / f"{platform}.started").open("x") as started:
            started.write(datetime.now(timezone.utc).isoformat() + "\n")
        print(f"Running {platform}; private log: {run / (platform + '.log')}", flush=True)
        with (run / f"{platform}.log").open("x") as log:
            result = subprocess.run(
                ["just", f"test-{platform}"], cwd=source,
                env=run_env, stdout=log, stderr=subprocess.STDOUT,
            )
        write_json(run / f"{platform}.result.json", {
            "exit_code": result.returncode,
            "finished": datetime.now(timezone.utc).isoformat(),
            "sha256": manifest["sha256"],
        })
        return result.returncode


def summarize(run, platform):
    manifest = json.loads((run / "manifest.json").read_text())
    result_file = run / f"{platform}.result.json"
    result = json.loads(result_file.read_text()) if result_file.exists() else None
    intact = fingerprint(run / "source") == manifest["sha256"]
    if result and result["sha256"] != manifest["sha256"]:
        intact = False
    log = run / f"{platform}.log"
    evidence = []
    outcomes = {}
    if log.exists():
        for number, line in enumerate(log.read_text(errors="replace").splitlines(), 1):
            match = re.fullmatch(r"(SUCCESS|FAILURE)\s+(\S+)\s+\(.+\)", line)
            if match and match[2] in manifest["assertions"]:
                outcomes.setdefault(match[2], []).append(match[1])
                evidence.append({"test": match[2], "result": match[1], "line": number})
    complete = (
        set(outcomes) == set(manifest["assertions"])
        and all(len(values) == 1 for values in outcomes.values())
    )
    failed = any("FAILURE" in values for values in outcomes.values())
    if result is None or not intact:
        status = "unknown"
    elif result["exit_code"] != 0 or failed:
        status = "failed"
    elif not complete:
        status = "unknown"
    else:
        status = "passed"
    return {
        "platform": platform, "status": status,
        "inputs_intact": intact,
        "exit_code": result["exit_code"] if result else None,
        "complete": complete, "expected": len(manifest["assertions"]),
        "passed": sum(values == ["SUCCESS"] for values in outcomes.values()),
        "failed": sum("FAILURE" in values for values in outcomes.values()),
        "evidence": evidence,
    }


def launch(run):
    if shutil.which("herdr") is None:
        raise ValueError("herdr is not on PATH; install it and start its runtime first")
    if (run / "workspace.json").exists():
        raise ValueError("workspace already created; reuse it instead of launching again")
    op_env_file = run / "op.env"
    with op_env_file.open("x") as file:
        op_env_file.chmod(0o600)
        file.write(
            "RBW_EMAIL=op://Personal/com.bitwarden/username\n"
            "RBW_PASSWORD=op://Personal/com.bitwarden/password\n"
            "RBW_TOTP_SEED=op://Personal/com.bitwarden/Security/one-time password\n"
        )
    age_env_file = run / "age.env"
    with age_env_file.open("x") as file:
        age_env_file.chmod(0o600)
        file.write("AGE_PASSPHRASE=op://chezmoi/chezmoi/age-passphrase\n")

    def herdr(*args):
        return json.loads(subprocess.check_output(["herdr", *args]))

    created = herdr("workspace", "create", "--cwd", str(run), "--label", run.name, "--no-focus")
    pane = created["result"]["root_pane"]["pane_id"]
    write_json(run / "workspace.json", created)
    other = herdr("pane", "split", pane, "--direction", "right", "--no-focus")
    other_pane = other["result"]["pane"]["pane_id"]
    created["pilot_panes"] = {"ubuntu": pane, "macos": other_pane}
    write_json(run / "workspace.json", created)
    analyst = herdr("pane", "split", other_pane, "--direction", "down", "--no-focus")
    analyst_pane = analyst["result"]["pane"]["pane_id"]
    created["pilot_panes"]["analyst"] = analyst_pane
    write_json(run / "workspace.json", created)
    driver = str(Path(__file__).resolve())
    commands = (
        [
            "op", "run", "--env-file", str(age_env_file),
            "--env-file", str(op_env_file), "--",
            "python3", driver, "run", str(run), "ubuntu",
        ],
        [
            "op", "run", "--env-file", str(age_env_file),
            "--env-file", str(op_env_file), "--",
            "python3", driver, "run", str(run), "macos",
        ],
    )
    for target, command_parts in zip((pane, other_pane), commands):
        command = shlex.join(command_parts)
        subprocess.run(["herdr", "pane", "run", target, command], check=True)
    print(f"Test panes: {pane}, {other_pane}; analyst shell: {analyst_pane}")
    print("After both runs finish, use the report command in the analyst shell.")


def main():
    os.umask(0o077)
    parser = argparse.ArgumentParser()
    commands = parser.add_subparsers(dest="command", required=True)
    prepare_parser = commands.add_parser("prepare")
    prepare_parser.add_argument("--include", action="append", default=[])
    for name in ("launch", "report", "run"):
        command = commands.add_parser(name)
        command.add_argument("directory", type=Path)
        if name == "run":
            command.add_argument("platform", choices=PLATFORMS)
    args = parser.parse_args()
    if args.command == "prepare":
        prepare(Path(__file__).resolve().parent.parent, args.include)
        return 0
    run = args.directory.resolve(strict=True)
    if args.command == "launch":
        launch(run)
    elif args.command == "run":
        return run_platform(run, args.platform)
    else:
        reports = [summarize(run, platform) for platform in PLATFORMS]
        print(json.dumps(reports, indent=2))
        return 0 if all(report["status"] == "passed" for report in reports) else 1
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        print(f"error: {error}", file=sys.stderr)
        sys.exit(1)

import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch


spec = importlib.util.spec_from_file_location("pilot", Path(__file__).with_name("herdr-pilot.py"))
pilot = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pilot)


class PilotTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        temporary_root = patch.object(pilot.tempfile, "gettempdir", return_value=self.temp.name)
        temporary_root.start()
        self.addCleanup(temporary_root.stop)
        self.run = Path(self.temp.name)
        source = self.run / "source"
        source.mkdir()
        (source / "input").write_text("frozen")
        self.manifest = {
            "sha256": pilot.fingerprint(source),
            "assertions": ["first", "last"],
        }
        pilot.write_json(self.run / "manifest.json", self.manifest)

    def result(self, code=0):
        pilot.write_json(self.run / "ubuntu.result.json", {
            "exit_code": code, "sha256": self.manifest["sha256"],
        })

    def log(self, text):
        (self.run / "ubuntu.log").write_text(text)

    def test_complete_success_with_line_evidence(self):
        self.result()
        self.log("noise\nSUCCESS first (/tests/first.sh)\nSUCCESS last (/tests/last.sh)\n")
        report = pilot.summarize(self.run, "ubuntu")
        self.assertEqual(report["status"], "passed")
        self.assertEqual(report["passed"], 2)
        self.assertEqual(report["evidence"][0]["line"], 2)

    def test_assertion_failure_overrides_zero_exit(self):
        self.result()
        self.log("FAILURE first (/first.sh)\nSUCCESS last (/last.sh)\n")
        self.assertEqual(pilot.summarize(self.run, "ubuntu")["status"], "failed")

    def test_incomplete_duplicate_and_interrupted_runs_are_unknown(self):
        for log, finished in (
            ("SUCCESS first (/first.sh)\n", True),
            ("SUCCESS first (/first.sh)\nSUCCESS first (/first.sh)\nSUCCESS last (/last.sh)\n", True),
            ("SUCCESS first (/first.sh)\nSUCCESS last (/last.sh)\n", False),
        ):
            with self.subTest(log=log, finished=finished):
                (self.run / "ubuntu.result.json").unlink(missing_ok=True)
                if finished:
                    self.result()
                self.log(log)
                self.assertEqual(pilot.summarize(self.run, "ubuntu")["status"], "unknown")

    def test_bootstrap_failure_is_failed_and_incomplete(self):
        self.result(23)
        self.log("bootstrap failed\n")
        report = pilot.summarize(self.run, "ubuntu")
        self.assertEqual(report["status"], "failed")
        self.assertFalse(report["complete"])

    def test_changed_inputs_are_unknown_but_legacy_logs_are_not_inputs(self):
        self.result()
        self.log("SUCCESS first (/first.sh)\nSUCCESS last (/last.sh)\n")
        (self.run / "source/docker.log").write_text("private output")
        self.assertEqual(pilot.summarize(self.run, "ubuntu")["status"], "passed")
        (self.run / "source/input").write_text("changed")
        self.assertEqual(pilot.summarize(self.run, "ubuntu")["status"], "unknown")

    def test_run_records_exit_and_refuses_retry(self):
        with patch.dict(os.environ, {"AGE_PASSPHRASE": "fixture-only"}), patch.object(
            pilot.subprocess, "run", return_value=subprocess.CompletedProcess([], 23),
        ) as command:
            self.assertEqual(pilot.run_platform(self.run, "ubuntu"), 23)
            self.assertEqual(command.call_args.args[0], ["just", "test-ubuntu"])
            result = json.loads((self.run / "ubuntu.result.json").read_text())
            self.assertEqual(result["exit_code"], 23)
            with self.assertRaises(FileExistsError):
                pilot.run_platform(self.run, "ubuntu")
            self.assertEqual(command.call_count, 1)

    def test_macos_loads_test_credentials_from_1password_after_hidden_prompt(self):
        with patch.dict(os.environ, {
            "AGE_PASSPHRASE": "private-fixture",
            "RBW_EMAIL": "test@example.test",
            "RBW_PASSWORD": "password-fixture",
            "RBW_TOTP_SEED": "seed-fixture",
        }), patch.object(
            pilot.subprocess, "run", return_value=subprocess.CompletedProcess([], 0),
        ) as command:
            self.assertEqual(pilot.run_platform(self.run, "macos"), 0)
        self.assertEqual(command.call_args.args[0], ["just", "test-macos"])
        self.assertNotIn("password-fixture", str(command.call_args.args[0]))

    def test_missing_credentials_do_not_start_run(self):
        with patch.dict(os.environ, {}, clear=True):
            with self.assertRaisesRegex(ValueError, "AGE_PASSPHRASE"):
                pilot.run_platform(self.run, "ubuntu")
        self.assertFalse((self.run / "ubuntu.started").exists())

    def test_prepare_freezes_tracked_changes_and_explicit_extra_files(self):
        repo = self.run / "repo"
        (repo / "tests/integration").mkdir(parents=True)
        (repo / "tests/integration/first.sh").write_text("exit 0\n")
        (repo / "extra").write_text("selected")
        (repo / "untracked").write_text("not selected")
        external = self.run / "external"
        external.write_text("must not be copied")
        (repo / "link").symlink_to(external)
        with patch.object(pilot.subprocess, "check_output", side_effect=[
            b"tests/integration/first.sh\0link\0", b"revision\n",
        ]), patch("builtins.print") as output:
            pilot.prepare(repo, ["extra"])
        run = output.call_args.args[0]
        manifest = json.loads((run / "manifest.json").read_text())
        self.assertEqual(manifest["inputs"], ["extra", "link", "tests/integration/first.sh"])
        self.assertTrue((run / "source/link").is_symlink())
        self.assertEqual(os.readlink(run / "source/link"), str(external))
        self.assertEqual(manifest["assertions"], ["first"])
        self.assertFalse((run / "source/untracked").exists())
        (repo / "extra").write_text("later change")
        self.assertEqual((run / "source/extra").read_text(), "selected")

    def test_prepare_rejects_outside_inputs(self):
        with patch.object(pilot.subprocess, "check_output", return_value=b""):
            with self.assertRaisesRegex(ValueError, "repository-relative"):
                pilot.prepare(self.run, ["../outside"])

    def test_launch_uses_returned_pane_ids_and_never_sends_secrets(self):
        responses = [
            b'{"result": {"root_pane": {"pane_id": "root"}}}',
            b'{"result": {"pane": {"pane_id": "second"}}}',
            b'{"result": {"pane": {"pane_id": "third"}}}',
        ]
        with patch.object(pilot.shutil, "which", return_value="/fixture/herdr"), patch.object(
            pilot.subprocess, "check_output", side_effect=responses,
        ), patch.object(pilot.subprocess, "run") as commands, patch("builtins.print"):
            pilot.launch(self.run)
        self.assertEqual(commands.call_args_list[0].args[0][:4], ["herdr", "pane", "run", "root"])
        self.assertEqual(commands.call_args_list[1].args[0][:4], ["herdr", "pane", "run", "second"])
        self.assertNotIn("private-fixture", str(commands.call_args_list))
        workspace = json.loads((self.run / "workspace.json").read_text())
        self.assertEqual(workspace["pilot_panes"]["analyst"], "third")
        env_file = self.run / "op.env"
        self.assertEqual(
            set(env_file.read_text().splitlines()),
            {
                "RBW_EMAIL=op://Personal/com.bitwarden/username",
                "RBW_PASSWORD=op://Personal/com.bitwarden/password",
                "RBW_TOTP_SEED=op://Personal/com.bitwarden/Security/one-time password",
            },
        )
        self.assertEqual(env_file.stat().st_mode & 0o777, 0o600)
        age_file = self.run / "age.env"
        self.assertEqual(
            age_file.read_text(),
            "AGE_PASSPHRASE=op://chezmoi/chezmoi/age-passphrase\n",
        )
        self.assertEqual(
            (self.run / "op.env").read_text().splitlines(),
            [
                "RBW_EMAIL=op://Personal/com.bitwarden/username",
                "RBW_PASSWORD=op://Personal/com.bitwarden/password",
                "RBW_TOTP_SEED=op://Personal/com.bitwarden/Security/one-time password",
            ],
        )
        self.assertEqual(age_file.stat().st_mode & 0o777, 0o600)
        self.assertIn("age.env", commands.call_args_list[0].args[0][4])
        self.assertIn("op.env", commands.call_args_list[0].args[0][4])
        self.assertIn("op.env", commands.call_args_list[1].args[0][4])

    def test_lock_blocks_overlapping_platform_runs(self):
        lock_dir = Path(tempfile.gettempdir()) / f"dotfiles-herdr-{os.getuid()}"
        lock_dir.mkdir(mode=0o700, exist_ok=True)
        with (lock_dir / "ubuntu.lock").open("a") as lock, patch.dict(
            os.environ, {"AGE_PASSPHRASE": "fixture-only"},
        ), patch.object(pilot.subprocess, "run") as commands:
            pilot.fcntl.flock(lock, pilot.fcntl.LOCK_EX | pilot.fcntl.LOCK_NB)
            with self.assertRaisesRegex(ValueError, "already running"):
                pilot.run_platform(self.run, "ubuntu")
            commands.assert_not_called()


if __name__ == "__main__":
    unittest.main()

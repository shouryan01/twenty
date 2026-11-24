import importlib.util
from pathlib import Path
import subprocess
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location(
    "targets", Path(__file__).with_name("detect-build-targets.py")
)
targets = importlib.util.module_from_spec(spec)
spec.loader.exec_module(targets)


class BuildTargetsTests(unittest.TestCase):
    def test_paths(self):
        cases = [
            (["Windows/MainWindow.xaml"], (True, False)),
            (["Mac/twenty/App.swift"], (False, True)),
            (["Windows/twenty.csproj", "Mac/twenty/App.swift"], (True, True)),
            (["README.md", "docs/screenshots/windows-main.png"], (False, False)),
            ([".github/actions/dotnet-publish/action.yml"], (True, False)),
            ([".github/workflows/release.yml"], (True, True)),
            ([".github/scripts/detect-build-targets.py"], (True, True)),
            ([], (False, False)),
        ]
        for paths, expected in cases:
            with self.subTest(paths=paths):
                self.assertEqual(targets.select_targets(paths), expected)

    def test_manual_and_initial_push_build_both(self):
        with patch.object(targets.subprocess, "run") as run:
            self.assertEqual(targets.detect_targets("workflow_dispatch", "", "HEAD"), (True, True))
            self.assertEqual(targets.detect_targets("push", "0" * 40, "HEAD"), (True, True))
            run.assert_not_called()

    def test_complete_push_range_and_both_sides_of_moves(self):
        with patch.object(targets.subprocess, "run") as run:
            run.return_value.stdout = b"Windows/old.cs\0Mac/new.cs\0"
            self.assertEqual(targets.detect_targets("push", "old-sha", "new-sha"), (True, True))
            run.assert_called_once_with(
                ["git", "diff", "--name-only", "--no-renames", "-z", "old-sha", "new-sha", "--"],
                check=True, capture_output=True,
            )

    def test_diff_failure_does_not_silently_skip_builds(self):
        with patch.object(targets.subprocess, "run", side_effect=subprocess.CalledProcessError(1, "git")):
            with self.assertRaises(subprocess.CalledProcessError):
                targets.detect_targets("push", "missing", "HEAD")


if __name__ == "__main__":
    unittest.main()

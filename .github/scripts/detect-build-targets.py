"""Select release builds using the complete pushed commit range."""

import argparse
import os
import subprocess


def select_targets(paths):
    windows = False
    macos = False
    for path in paths:
        if path.startswith("Windows/") or path.startswith(".github/actions/dotnet-publish/"):
            windows = True
        elif path.startswith("Mac/"):
            macos = True
        elif path.startswith((".github/workflows/", ".github/scripts/")):
            windows = macos = True
    return windows, macos


def detect_targets(event, before, after):
    # Manual runs and initial branch pushes have no meaningful comparison base.
    if event == "workflow_dispatch" or not before or set(before) == {"0"}:
        return True, True
    # --no-renames emits both sides of moves, including moves across platforms.
    result = subprocess.run(
        ["git", "diff", "--name-only", "--no-renames", "-z", before, after, "--"],
        check=True, capture_output=True,
    )
    return select_targets(result.stdout.decode("utf-8", errors="surrogateescape").split("\0"))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--event", required=True)
    parser.add_argument("--before", default="")
    parser.add_argument("--after", required=True)
    args = parser.parse_args()
    windows, macos = detect_targets(args.event, args.before, args.after)
    output = f"windows={str(windows).lower()}\nmacos={str(macos).lower()}\n"
    print(output, end="")
    with open(os.environ["GITHUB_OUTPUT"], "a", encoding="utf-8") as stream:
        stream.write(output)


if __name__ == "__main__":
    main()

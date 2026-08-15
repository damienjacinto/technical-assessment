#!/usr/bin/env python3
"""Enforce one IAM action per line, sorted alphabetically, in
`actions`/`not_actions` lists inside aws_iam_policy_document data sources.

No tflint/checkov rule covers this (it's a style preference, not a
correctness or security check), so it's a standalone script instead.

Usage:
  scripts/lint-iam-actions.py          # check, exit 1 on violations
  scripts/lint-iam-actions.py --fix    # rewrite violations in place
"""
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
BLOCK_RE = re.compile(
    r'^(?P<indent>[ \t]*)(?P<key>actions|not_actions)[ \t]*=[ \t]*\[(?P<body>.*?)\]',
    re.MULTILINE | re.DOTALL,
)
STRING_RE = re.compile(r'"((?:[^"\\]|\\.)*)"')


def find_violations(text):
    violations = []
    for m in BLOCK_RE.finditer(text):
        body = m.group("body")
        actions = STRING_RE.findall(body)
        if len(actions) <= 1:
            continue  # a single action is trivially "one per line"
        lines = [line for line in body.split("\n") if line.strip()]
        one_per_line = len(lines) == len(actions) and all(
            len(STRING_RE.findall(line)) == 1 for line in lines
        )
        sorted_actions = sorted(actions)
        if not one_per_line or actions != sorted_actions:
            line_no = text.count("\n", 0, m.start()) + 1
            violations.append((line_no, m, actions, sorted_actions))
    return violations


def fix(text, violations):
    for _, m, _actions, sorted_actions in sorted(violations, key=lambda v: v[1].start(), reverse=True):
        indent = m.group("indent")
        key = m.group("key")
        body = "\n" + "".join(f'{indent}  "{a}",\n' for a in sorted_actions) + indent
        replacement = f"{indent}{key} = [{body}]"
        text = text[: m.start()] + replacement + text[m.end() :]
    return text


def main():
    do_fix = "--fix" in sys.argv[1:]
    failed = False
    for path in sorted(REPO_ROOT.glob("terraform/**/*.tf")):
        if ".terraform" in path.parts:
            continue  # vendored registry module source, not this repo's code
        text = path.read_text()
        violations = find_violations(text)
        if not violations:
            continue
        if do_fix:
            path.write_text(fix(text, violations))
            print(f"fixed: {path.relative_to(REPO_ROOT)}")
        else:
            failed = True
            for line_no, *_ in violations:
                print(
                    f"{path.relative_to(REPO_ROOT)}:{line_no}: "
                    "actions must be one per line, sorted alphabetically"
                )
    if failed:
        print("\nRun scripts/lint-iam-actions.py --fix to fix automatically.")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())

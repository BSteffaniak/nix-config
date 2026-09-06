#!/usr/bin/env python3
"""Validate that shared agent skills honor direct user workflow overrides."""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "configs" / "agents" / "skills"
CONTRACT = ROOT / "_shared" / "user-overrides.md"
REQUIRED_HEADING = "## User overrides"
REQUIRED_LINK = "../_shared/user-overrides.md"

# These phrases recreate the failure mode this policy is intended to prevent
# unless the skill explicitly opts into the shared override contract.
HARD_GATE_PATTERNS = (
    re.compile(r"only (?:a )?direct user Question", re.IGNORECASE),
    re.compile(r"only .*Question .*authoriz", re.IGNORECASE),
    re.compile(r"natural-language .*never approval", re.IGNORECASE),
    re.compile(r"cannot (?:be )?override", re.IGNORECASE),
    re.compile(r"cannot (?:be )?unload", re.IGNORECASE),
)


def main() -> int:
    errors: list[str] = []
    if not CONTRACT.is_file():
        errors.append(
            f"missing shared contract: {CONTRACT.relative_to(ROOT.parent.parent.parent)}"
        )

    skills = sorted(ROOT.glob("*/SKILL.md"))
    for skill in skills:
        text = skill.read_text(encoding="utf-8")
        relative = skill.relative_to(ROOT)
        has_contract = REQUIRED_HEADING in text and REQUIRED_LINK in text
        if not has_contract:
            errors.append(f"{relative}: missing shared user override section/link")

        for pattern in HARD_GATE_PATTERNS:
            for match in pattern.finditer(text):
                if not has_contract:
                    line = text.count("\n", 0, match.start()) + 1
                    errors.append(
                        f"{relative}:{line}: unqualified hard-gate language: {match.group(0)!r}"
                    )

    if errors:
        print("Skill override policy check failed:", file=sys.stderr)
        for error in errors:
            print(f"  - {error}", file=sys.stderr)
        return 1

    print(f"Skill override policy check passed for {len(skills)} skills.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

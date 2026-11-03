#!/usr/bin/env python3
"""Open Android DeX — Zero-Dependency Test Suite Runner.

Discovers and runs all unit tests in tests/ without requiring third-party test runners.
"""

from __future__ import annotations

import importlib
import os
import sys
import time
import traceback
from unittest.mock import MagicMock

# Provide lightweight mock for pytest if pytest is not installed in the environment
if "pytest" not in sys.modules:
    try:
        import pytest  # noqa: F401
    except ImportError:
        sys.modules["pytest"] = MagicMock()


def main() -> int:
    tests_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "tests")
    if not os.path.isdir(tests_dir):
        print(f"❌ Error: tests directory not found at {tests_dir}")
        return 1

    test_files = sorted(
        [
            f[:-3]
            for f in os.listdir(tests_dir)
            if f.startswith("test_") and f.endswith(".py")
        ]
    )

    print("=" * 65)
    print("      🧪 Running Open Android DeX Test Suite")
    print("=" * 65)

    total_passed = 0
    total_failed = 0
    start_time = time.time()

    for mod_name in test_files:
        full_mod = f"tests.{mod_name}"
        try:
            mod = importlib.import_module(full_mod)
        except Exception as exc:
            print(f"\n❌ FAILED to import {full_mod}: {exc}")
            traceback.print_exc()
            total_failed += 1
            continue

        test_callables = [
            (name, getattr(mod, name))
            for name in dir(mod)
            if name.startswith("test_") and callable(getattr(mod, name))
        ]

        for name, fn in test_callables:
            try:
                fn()
                print(f"  ✅ {mod_name}.{name}")
                total_passed += 1
            except Exception as exc:
                print(f"  ❌ {mod_name}.{name} FAILED: {exc}")
                traceback.print_exc()
                total_failed += 1

    duration = time.time() - start_time
    print("-" * 65)
    print(f"Summary: {total_passed} passed, {total_failed} failed in {duration:.2f}s")
    print("=" * 65)

    return 0 if total_failed == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())

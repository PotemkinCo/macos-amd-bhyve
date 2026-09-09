#!/usr/bin/env python3
"""Verify every versioned binary and the sanitized OpenCore template."""

from __future__ import annotations

import hashlib
import json
import plistlib
import sys
from pathlib import Path


def fail(message: str) -> "NoReturn":
    raise SystemExit(f"PUBLIC_TREE_REJECTED: {message}")


def main() -> int:
    root = Path(__file__).resolve().parent.parent
    manifest_path = root / "provenance" / "payload.sha256"
    expected: dict[str, str] = {}

    for number, line in enumerate(manifest_path.read_text().splitlines(), 1):
        try:
            digest, relative = line.split("  ", 1)
        except ValueError:
            fail(f"malformed payload manifest line {number}")
        if len(digest) != 64 or any(
            character not in "0123456789abcdef" for character in digest
        ):
            fail(f"invalid SHA-256 on payload manifest line {number}")
        path = Path(relative)
        if path.is_absolute() or ".." in path.parts:
            fail(f"unsafe payload path: {relative}")
        if relative in expected:
            fail(f"duplicate payload path: {relative}")
        expected[relative] = digest

    actual = {
        path.relative_to(root).as_posix()
        for directory in (root / "firmware", root / "opencore")
        for path in directory.rglob("*")
        if path.is_file()
    }
    if actual != set(expected):
        missing = sorted(set(expected) - actual)
        extra = sorted(actual - set(expected))
        fail(f"payload manifest mismatch; missing={missing}, extra={extra}")

    for relative, wanted in expected.items():
        digest = hashlib.sha256((root / relative).read_bytes()).hexdigest()
        if digest != wanted:
            fail(f"payload hash mismatch: {relative}: {digest}")

    with (root / "opencore/EFI/OC/config.plist").open("rb") as stream:
        config = plistlib.load(stream)
    generic = config["PlatformInfo"]["Generic"]
    if generic["SystemSerialNumber"] != "REPLACEME000":
        fail("public config does not contain the serial placeholder")
    if generic["MLB"] != "REPLACEME00000000":
        fail("public config does not contain the MLB placeholder")
    if generic["SystemUUID"] != "00000000-0000-0000-0000-000000000000":
        fail("public config contains a non-placeholder SystemUUID")
    if generic["ROM"] != b"\x00" * 6:
        fail("public config contains a non-placeholder ROM")
    if config["Kernel"]["Patch"]:
        fail("AMD patch bytes are present in the public config")

    apple_nvram = config["NVRAM"]["Add"]["7C436110-AB2A-4BBB-A880-FE41995C9F82"]
    if "amfi_get_out_of_my_way" in apple_nvram.get("boot-args", ""):
        fail("public config disables AMFI")
    if apple_nvram.get("csr-active-config") != b"\x00" * 4:
        fail("public config disables System Integrity Protection")

    with (root / "provenance/inputs.json").open("rb") as stream:
        provenance = json.load(stream)
    if provenance["amd_vanilla"]["redistributed"] is not False:
        fail("AMD_Vanilla redistribution boundary changed")

    print("PUBLIC_PAYLOAD_OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())

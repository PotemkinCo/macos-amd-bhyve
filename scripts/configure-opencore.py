#!/usr/bin/env python3
"""Render the public OpenCore template into a private, bootable config."""

from __future__ import annotations

import argparse
import plistlib
import re
import secrets
import subprocess
import sys
import uuid
from pathlib import Path


CORE_PATCH_MARKER = "Force cpuid_cores_per_package"
PLACEHOLDER_SERIAL = "REPLACEME000"
PLACEHOLDER_MLB = "REPLACEME00000000"


def fail(message: str) -> "NoReturn":
    raise SystemExit(f"configure-opencore: {message}")


def load_plist(path: Path) -> dict:
    try:
        with path.open("rb") as stream:
            value = plistlib.load(stream)
    except (OSError, plistlib.InvalidFileException) as error:
        fail(f"cannot read {path}: {error}")
    if not isinstance(value, dict):
        fail(f"{path} does not contain a plist dictionary")
    return value


def generate_serials(macserial: Path) -> tuple[str, str]:
    try:
        result = subprocess.run(
            [str(macserial), "--num", "1", "--model", "iMacPro1,1"],
            check=True,
            capture_output=True,
            text=True,
        )
    except (OSError, subprocess.CalledProcessError) as error:
        fail(
            f"could not run {macserial}: {error}; enable FreeBSD's Linux ABI "
            "or pass --system-serial and --mlb"
        )

    for line in result.stdout.splitlines():
        if "|" in line:
            serial, mlb = (part.strip() for part in line.split("|", 1))
            if serial and mlb:
                return serial, mlb
    fail(f"could not parse serial and MLB from {macserial}")


def parse_rom(value: str | None) -> bytes:
    if value is None:
        generated = bytearray(secrets.token_bytes(6))
        generated[0] = (generated[0] | 0x02) & 0xFE
        return bytes(generated)

    compact = re.sub(r"[:-]", "", value)
    if not re.fullmatch(r"[0-9A-Fa-f]{12}", compact):
        fail("--rom must contain exactly six hexadecimal bytes")
    return bytes.fromhex(compact)


def patch_core_count(patches: list, core_count: int) -> None:
    core_patches = [
        patch
        for patch in patches
        if CORE_PATCH_MARKER in str(patch.get("Comment", ""))
    ]
    if len(core_patches) != 4:
        fail(f"expected four AMD core-count patches, found {len(core_patches)}")

    for patch in core_patches:
        replacement = patch.get("Replace")
        if not isinstance(replacement, bytes) or len(replacement) < 2:
            fail("an AMD core-count patch has an invalid Replace value")
        if replacement[0] not in (0xB8, 0xBA):
            fail("an AMD core-count patch has an unexpected opcode")
        patch["Replace"] = replacement[:1] + bytes([core_count]) + replacement[2:]


def validate_identity(serial: str, mlb: str, system_uuid: str) -> None:
    if not re.fullmatch(r"[A-Z0-9]{11,12}", serial):
        fail("--system-serial must be an 11- or 12-character uppercase value")
    if not re.fullmatch(r"[A-Z0-9]{17}", mlb):
        fail("--mlb must be a 17-character uppercase value")
    try:
        uuid.UUID(system_uuid)
    except ValueError:
        fail("--system-uuid is not a valid UUID")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--template", required=True, type=Path)
    parser.add_argument("--patches", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--identity-output", required=True, type=Path)
    parser.add_argument("--core-count", required=True, type=int)
    parser.add_argument("--macserial", type=Path)
    parser.add_argument("--system-serial")
    parser.add_argument("--mlb")
    parser.add_argument("--system-uuid")
    parser.add_argument("--rom")
    args = parser.parse_args()

    if not 1 <= args.core_count <= 64:
        fail("--core-count must be between 1 and 64")

    serial = args.system_serial
    mlb = args.mlb
    if bool(serial) != bool(mlb):
        fail("--system-serial and --mlb must be supplied together")
    if serial is None:
        if args.macserial is None:
            fail("supply --macserial or both --system-serial and --mlb")
        serial, mlb = generate_serials(args.macserial)

    system_uuid = (args.system_uuid or str(uuid.uuid4())).upper()
    vm_uuid = str(uuid.uuid4())
    rom = parse_rom(args.rom)
    validate_identity(serial, mlb, system_uuid)

    config = load_plist(args.template)
    patch_plist = load_plist(args.patches)
    try:
        patches = patch_plist["Kernel"]["Patch"]
        generic = config["PlatformInfo"]["Generic"]
        boot_args = config["NVRAM"]["Add"][
            "7C436110-AB2A-4BBB-A880-FE41995C9F82"
        ]["boot-args"]
    except (KeyError, TypeError) as error:
        fail(f"required plist key is missing: {error}")
    if not isinstance(patches, list):
        fail("AMD patches plist has no Kernel/Patch array")
    if "amfi_get_out_of_my_way" in boot_args:
        fail("the template contains a security-relaxing AMFI boot argument")

    patch_core_count(patches, args.core_count)
    config["Kernel"]["Patch"] = patches
    generic["SystemSerialNumber"] = serial
    generic["MLB"] = mlb
    generic["SystemUUID"] = system_uuid
    generic["ROM"] = rom

    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("wb") as stream:
        plistlib.dump(config, stream, fmt=plistlib.FMT_XML, sort_keys=False)

    args.identity_output.parent.mkdir(parents=True, exist_ok=True)
    identity = "\n".join(
        (
            f"SYSTEM_PRODUCT_NAME=iMacPro1,1",
            f"SYSTEM_SERIAL={serial}",
            f"MLB={mlb}",
            f"SYSTEM_UUID={system_uuid}",
            f"ROM={rom.hex().upper()}",
            f"NETWORK_MAC={':'.join(f'{byte:02x}' for byte in rom)}",
            f"VM_UUID={vm_uuid}",
            "",
        )
    )
    args.identity_output.write_text(identity, encoding="utf-8")
    args.identity_output.chmod(0o600)

    if serial == PLACEHOLDER_SERIAL or mlb == PLACEHOLDER_MLB:
        fail("placeholder identity unexpectedly reached the rendered config")
    return 0


if __name__ == "__main__":
    sys.exit(main())

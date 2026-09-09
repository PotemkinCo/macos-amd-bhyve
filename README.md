# macOS on an AMD-hosted FreeBSD bhyve VM

This repository is a ready-to-assemble boot recipe for an Intel macOS guest on
an AMD FreeBSD/bhyve host. It contains the known-good bhyve firmware, a pristine
UEFI variables template, OpenCore 1.0.6, the required drivers and kexts, a
sanitized configuration, ACPI source, a vm-bhyve template, exact hashes, and
all applicable third-party licence notices.

It deliberately contains no Apple operating-system files, recovery media,
OSK material, installed disk, credentials, or reusable machine identity.

## Quick start

On the FreeBSD host, install `bash`, Python 3, and `vm-bhyve`. The base-system
`makefs`, `mkimg`, and `fetch` utilities are also used. Enable
the FreeBSD Linux ABI so the pinned static `macserial` and `ocvalidate` tools
can run:

```sh
sudo sysrc linux_enable=YES
sudo service linux start
```

Build a private four-core bundle in a new output directory:

```sh
./scripts/assemble-opencore.sh --cores 4 ./out/ready
```

The command downloads only the AMD_Vanilla patch list from its pinned upstream
revision, verifies its SHA-256, inserts the selected guest core count, generates
fresh SMBIOS/UUID/MAC values, validates `config.plist` with OpenCore 1.0.6, and
creates both an EFI tree and a GPT `opencore.img`.

This recipe is intentionally online-assisted rather than fully offline. The
assembler fetches the pinned AMD_Vanilla patch list from its upstream repository
and verifies its SHA-256 before using it. Internet access is therefore required
unless the same verified file has already been placed in the assembler's cache.

The output includes:

* `BHYVE_UEFI.fd` and the immutable `BHYVE_UEFI_VARS.fd` template;
* `EFI/OC/OpenCore.efi`, drivers, kexts, ACPI, and rendered `config.plist`;
* `patches.plist`, `opencore.img`, and `macos.conf.example`;
* private generated values in mode-0600 `identity.env`;
* licence notices, `SHA256SUMS`, and `macos-amd-bhyve-ready.tar.gz`.

You may instead provide an existing iMacPro1,1 identity:

```sh
./scripts/assemble-opencore.sh --cores 4 \
  --system-serial YOUR_SERIAL --mlb YOUR_17_CHARACTER_MLB \
  --system-uuid YOUR_UUID --rom YOUR_12_HEX_DIGIT_ROM \
  ./out/ready
```

Never reuse another machine's identity. Before signing in to Apple services,
check that an automatically generated serial is not already assigned.

## Install into vm-bhyve

For a VM named `macos-amd`, set and verify the datastore path first:

```sh
recipe_vm_datastore="/replace/with/your/vm-datastore"
test -d "$recipe_vm_datastore/macos-amd" || exit 1
sudo install -m 0644 ./out/ready/BHYVE_UEFI.fd \
  "$recipe_vm_datastore/.config/BHYVE_UEFI.fd"
sudo install -m 0600 ./out/ready/BHYVE_UEFI_VARS.fd \
  "$recipe_vm_datastore/macos-amd/uefi-vars.fd"
sudo install -m 0644 ./out/ready/opencore.img \
  "$recipe_vm_datastore/macos-amd/opencore.img"
sudo install -m 0600 ./out/ready/macos.conf.example \
  "$recipe_vm_datastore/macos-amd/macos-amd.conf"
```

Replace `REPLACE_WITH_PRIVATE_VM_SWITCH` in the installed configuration, create
or attach `macos-system.raw`, and attach macOS installer or recovery media that
you obtained under the applicable Apple licence. The generated config uses an
`e1000` NIC so macOS networking does not depend on an unsigned virtio guest
driver. VNC listens on loopback only.

Every VM needs its own copy of `BHYVE_UEFI_VARS.fd`. Never point a running VM
at the repository template and never share a live variables store.

See [docs/launch.md](docs/launch.md) for the complete checklist. To rebuild the
firmware from the pinned EDK2 checkout instead of using the known-good binary:

```sh
./scripts/build-ready-bundle.sh "$EDK2_CHECKOUT" ./out/rebuilt 4
```

## Redistribution boundary

The bundled EDK2, OpenCore, Lilu, VirtualSMC, WhateverGreen, and CryptexFixup
payloads are redistributable under the licence files in `LICENSES/`.
MCEReporterDisabler is a plist-only GPLv2 work; its complete source and GPLv2
text are included.

AMD_Vanilla has no explicit licence or redistribution grant at the pinned
revision. Its patch bytes are therefore **not** committed here. The assembler
downloads them directly from the copyright holder's repository for local use.
Do not publish the generated archive unless the AMD_Vanilla rightsholders grant
permission. See [docs/distribution-boundary.md](docs/distribution-boundary.md)
and `provenance/inputs.json`.

Run this before publishing the source tree:

```sh
./scripts/check-public-tree.sh
```

## Intended use and Apple-software notice

This repository is intended for personal educational use only. Use macOS only
if you have lawfully obtained it, including any required purchase, and comply
with the applicable Apple software licence. Purchasing or downloading macOS
does not by itself grant permission to run it on non-Apple hardware or to
redistribute Apple software. No Apple software, installer, recovery media, OSK
material, or installed system is included here.

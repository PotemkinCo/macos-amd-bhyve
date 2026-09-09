# Public distribution boundary

This repository publishes the complete non-Apple boot recipe, including
licence-cleared firmware, OpenCore, drivers, kexts, and a placeholder-only
configuration. It does not publish a macOS VM or installer.

## Included and redistributable

* The known-good `BHYVE_UEFI.fd` and pristine `BHYVE_UEFI_VARS.fd` template
  under EDK2's BSD-2-Clause-Patent licence.
* OpenCore 1.0.6, its drivers and utilities under BSD-3-Clause.
* Lilu 1.6.8, VirtualSMC 1.3.3, WhateverGreen 1.6.7, and CryptexFixup 1.0.1
  under their included BSD-3-Clause licences.
* The complete plist-only MCEReporterDisabler 0.5 source, which identifies
  itself as GPLv2, together with the GPLv2 text.
* Project-authored documentation, scripts, configuration, ACPI source, and
  EDK2 patch under Apache-2.0.

Exact source URLs, versions, licences, and hashes are recorded in
`provenance/inputs.json` and `provenance/payload.sha256`.

## Fetched locally, not distributed

AMD_Vanilla commit `eaf52ef292abf4ebec899df6d48626569ba50cc6` has no
licence file or explicit redistribution grant. Consequently this source tree
does not contain its patch bytes. `scripts/assemble-opencore.sh` downloads the
pinned `patches.plist` directly from the rightsholder's repository, verifies
SHA-256, adjusts only the four documented core-count replacements, and merges
the patches into the private output.

This fetch is intentional: the recipe is online-assisted and does not claim to
be a fully offline distribution. A verified copy may be supplied through the
assembler's cache when network access is unavailable.

The generated archive contains those patch bytes and a new machine identity.
It is for the operator's local use and must not be published without permission
from the AMD_Vanilla rightsholders.

This repository is intended for personal educational use only. Use macOS only
if it has been lawfully obtained, including any required purchase, and comply
with the applicable Apple software licence. Purchasing or downloading macOS
does not by itself grant permission to run it on non-Apple hardware or to
redistribute Apple software.

## Always excluded

* Apple installers, recovery images, operating-system files, OSK material,
  Apple firmware, installed disks, APFS state, and snapshots.
* Live UEFI variable stores. The committed file is an immutable template and
  must be copied once per VM before first boot.
* Raw logs, screenshots, captures, credentials, private endpoints, owner paths,
  real UUIDs, MAC addresses, MLB values, and serial numbers.
* Generated `opencore.img`, `identity.env`, `patches.plist`, and ready archives.

## Reproducibility claim

The bundled firmware is the exact image used by the working bhyve VM. Its
source commit and one-file EDK2 patch are recorded, but the original complete
toolchain and recursive submodule closure were not retained, so a bit-identical
rebuild is not claimed. `scripts/build-ready-bundle.sh` performs a clean source
rebuild and packages its outputs for an operator-owned boot test.

# macOS on AMD bhyve — source recipe

This public repository contains only a reproducible recipe, source patches, and
sanitized configuration guidance for a headless, non-Metal x86_64 macOS guest
on FreeBSD 15.1 and AMD bhyve. It contains no Apple installer/media, guest
disk, OpenCore image, firmware binary, UEFI variables, host key, credential,
serial number, UUID, MAC address from a real host, or raw machine log.

The project-authored recipe is licensed under Apache 2.0. Upstream
dependencies retain their own licenses and are referenced in `licenses/`.
Apple software, firmware, OpenCore images, AMD kernel patch bytes, guest
disks, UEFI variables, and host state are deliberately outside the public
distribution boundary.

## Intended use and legal notice

This project is provided for personal educational, research, and
interoperability-testing use only. Use macOS only when you have lawfully
obtained it and hold the permissions required by the applicable Apple
software license and by every third-party input used with this recipe. A
macOS purchase or download does not by itself grant permission to run macOS
on non-Apple hardware or to redistribute Apple software. No Apple software,
installer, recovery media, or guest disk is distributed by this repository.
You are responsible for reviewing the applicable terms, preserving required
attribution, and complying with local law before using or redistributing any
input.

## What is reproducible

The retained supervised run proved the following implementation facts:

* EDK2 `edk2-stable202508` / `OvmfPkg/Bhyve/BhyveX64.dsc`, X64, RELEASE,
  GCC5, at commit `d46aa46c8361194521391aa581593e556c707c6e`, with the
  isolated `patches/edk2-known-good-baseline-dxe.patch`;
* the ACPI CPU namespace repair in `acpi/SSDT-BHYVE-CPU.dsl`, which defines
  four `Processor` objects under an `ACPI0010` device;
* a four-vCPU, one-socket/two-core/two-thread bhyve topology, 12 GiB guest
  memory, `uefi-custom`, AHCI disks, `virtio-net`, loopback-only VNC, and
  `wired_memory=no`; and
* AMD_Vanilla commit `eaf52ef292abf4ebec899df6d48626569ba50cc6`, OpenCore
  release `1.0.6` (the upstream release page identifies signed commit prefix
  `64e3b58`), and `ProvideCurrentCpuInfo` as inputs to the owner-built
  OpenCore configuration.

The final observed custom `BHYVE_CODE.fd` was 3,653,632 bytes with SHA-256
`93a38b9ef4b3ab81fde9f240d50272dd14ba21204d92a9c80357ab0688cae3b8`. The
recipe deliberately does not ship that firmware: a clean owner build must
produce and verify its own output.

## Prerequisites

On the FreeBSD host, install or recover the owner-approved equivalents of the
following observed packages/tools:

* FreeBSD 15.1 on an AMD host with bhyve available and AMD virtualization
  enabled;
* `vm-bhyve` 1.7.4, `bhyve-firmware` 1.0_2, `edk2-bhyve-g202508_2`, and
  `qemu-tools` 11.0.2;
* `git`, `make`, GCC5-compatible build tools, NASM, and `acpica-tools`/`iasl`;
* a legally obtained, owner-managed x86_64 macOS installation disk and
  mutable UEFI variables; and
* an owner-built OpenCore 1.0.6 tree/configuration plus the AMD_Vanilla
  checkout at the pin above.

The installer and Apple media are deliberately outside this repository. The
OpenCore config must use fresh, locally generated generic identity values;
never reuse values from an evidence record. AMD kernel patch byte strings are
not redistributed here. Obtain the pinned public AMD_Vanilla source on the
owner's permitted network, retain its license, and apply it to the owner's
OpenCore configuration.

## Fast path on an owner-controlled FreeBSD host

All mutating actions below are explicit owner-run commands. They are not run
by repository publication or by the read-only verification helper.

1. Create a clean EDK2 checkout at the pinned commit and build the custom
   firmware:

   ```sh
   EDK2_ROOT=/path/to/clean/edk2 ./scripts/build-edk2.sh --apply
   ```

   The script refuses a wrong commit and prints the resulting
   `BHYVE_CODE.fd` SHA-256. It does not claim bit-for-bit identity unless the
   owner's toolchain and recursive submodules are also pinned.

2. Compile and verify the CPU SSDT:

   ```sh
   ./scripts/build-ssdt.sh
   ```

   The preserved AML reference is SHA-256
   `67174f18544899ce31f38b02cc6fc39bec7e38584ffbc351561fa59b52faee36`.

3. Build the owner-managed OpenCore 1.0.6 configuration. Apply the AMD
   patches from the pinned AMD_Vanilla checkout, add the compiled SSDT, and
   apply the settings in `config/opencore-config-fragment.md`. Run the
   OpenCore `ocvalidate` tool from that same owner checkout. Do not copy the
   retained final plist: it contained host identity values and is intentionally
   excluded.

4. Copy the owner-approved OpenCore image, macOS system disk, and built
   firmware into the owner-selected vm-bhyve datastore. Start from
   `config/vm.conf.example`, replace every `REPLACE_*` value, and keep the
   resulting working config outside this repository.

5. With the guest powered off, install the config and firmware using the
   explicit backup-aware command:

   ```sh
   VM_NAME=macos-amd-bhyve \
   DATASTORE="$VM_DATASTORE" \
   CUSTOM_FIRMWARE="$BUILD_DIR/BHYVE_CODE.fd" \
   ./scripts/install.sh --apply
   ```

6. Run the read-only host checks, then the owner-authorized reboot persistence
   proof. `verify-reboot.sh` requires explicit SSH key and known-host paths and
   never embeds a username, address, key, or guest secret:

   ```sh
   VM_NAME=macos-amd-bhyve DATASTORE=/path/to/vm-bhyve-datastore \
   ./scripts/verify-install.sh

   SSH_USER=... SSH_HOST=... SSH_KEY="$SSH_PRIVATE_KEY_FILE" \
   SSH_KNOWN_HOSTS="$SSH_KNOWN_HOSTS_FILE" \
   VM_NAME=macos-amd-bhyve DATASTORE="$VM_DATASTORE" \
   ./scripts/verify-reboot.sh --apply
   ```

The persistence proof is successful only when the guest returns after reboot,
reports the expected macOS release and four CPUs, retains its owner-selected
network configuration, and accepts strict pinned SSH. It is not a Metal,
GUI-quality, physical-device, or VPN-functional qualification.

## Rollback

`install.sh` writes a timestamped backup before replacing the custom firmware
or VM configuration. It refuses to operate on a running VM. To roll back,
stop the guest through the owner's normal maintenance procedure, inspect the
backup, and run:

```sh
VM_NAME=macos-amd-bhyve \
DATASTORE=/path/to/vm-bhyve-datastore \
BACKUP_DIR=/path/to/inspected/backup \
./scripts/rollback.sh --apply
```

Rollback never deletes the guest disk or UEFI variables. It restores only the
configuration and custom firmware files saved by `install.sh`.

## Public boundary and limitations

The source and hashes were derived from the owner-only retrospective and
protected evidence bundle dated 2026-08-23. The exact sources are indexed in
`provenance/preserved-inputs.md`; no raw logs or machine-state files are copied
here.

This is publishable as a source-only recipe, but it is not an exact,
one-command public release. The following limitations are explicit:

* the official OpenCore `1.0.6` release and signed commit prefix `64e3b58`
  are now independently identified, but the full 40-hex commit and exact
  release-asset digest were not preserved, so the observed image still cannot
  be tied to an immutable source/archive hash;
* the clean EDK2 toolchain version and complete recursive submodule closure
  were not retained together, so the known-good firmware digest is a reference
  rather than a reproducible artifact claim;
* AMD_Vanilla patch bytes were preserved locally but are intentionally not
  redistributed because they are kernel patch data; the preserved AMD tree
  and official upstream inventory do not expose a license file, so its
  licensing must be verified before publication; and
* the final OpenCore plist, guest disk, UEFI variables, custom firmware, and
  host vm-bhyve state are intentionally excluded from this source recipe.

The missing original bytes are therefore not silently replaced by inferred
values. Run `./scripts/check-public-tree.sh` before committing changes. A
successful check confirms the distribution boundary; it does not prove that
the guest will boot on every FreeBSD, bhyve, or AMD host.

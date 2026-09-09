# Operator launch checklist

The repository contains every non-Apple boot input needed by the tested
four-vCPU baseline. The operator still supplies FreeBSD/bhyve, vm-bhyve, a
private switch, a blank system disk, and legally obtained Apple installation
or recovery media.

## 1. Verify the public payload

From the repository root:

```sh
./scripts/check-public-tree.sh
```

This verifies every committed firmware, EFI, kext, utility, and sanitized
configuration hash before any private output is created.

## 2. Assemble private boot inputs

FreeBSD requires Bash, Python 3, `makefs`, `mkimg`, and either `fetch` or
`curl`. Enable the Linux ABI for the bundled static Linux builds of
OpenCore's `macserial` and `ocvalidate` utilities.

```sh
sudo sysrc linux_enable=YES
sudo service linux start
./scripts/assemble-opencore.sh --cores 4 ./out/ready
```

The assembler performs the following operations without using a working VM:

1. Copies the committed, hash-pinned OpenCore/driver/kext payload.
2. Includes the known-good AML compiled from `SSDT-BHYVE-CPU.dsl`.
3. Downloads the pinned AMD_Vanilla patch list from its upstream owner and
   checks SHA-256 before use.
4. Sets all four AMD core-count patches to four, merges them into a copy of
   the sanitized config, and generates new iMacPro1,1 serial/MLB, UUID, and
   locally administered MAC/ROM values.
5. Validates the rendered plist with OpenCore 1.0.6.
6. Creates a 64 MiB FAT EFI partition inside a GPT `opencore.img`, plus a
   ready archive and checksums.

The committed template contains conspicuous dummy values; only the private
rendered config contains usable identities. Keep `identity.env` private and
check the generated serial before using Apple services.

## 3. Create the vm-bhyve guest

Create a VM directory using the normal vm-bhyve workflow, then install:

* `BHYVE_UEFI.fd` as the datastore's `.config/BHYVE_UEFI.fd` custom bootrom;
* a fresh per-VM copy of `BHYVE_UEFI_VARS.fd` as `uefi-vars.fd`;
* `opencore.img` as the first AHCI disk; and
* the generated `macos.conf.example` as the guest configuration.

Replace its private-switch placeholder. Its generated UUID and MAC are already
filled in. The known-good topology is one socket, two cores, two threads (four
vCPUs), with 12 GiB RAM, `wired_memory=no`, AHCI storage, loopback-only VNC,
and an `e1000` NIC.

Create or attach `macos-system.raw`, then temporarily attach the permitted
installer/recovery media. Keep the OpenCore disk first in boot order. Start the
guest with vm-bhyve and connect VNC through localhost or an SSH tunnel.

## 4. Security and operational notes

The public config removes the working image's diagnostic AMFI bypass and uses
an all-zero `csr-active-config`, so System Integrity Protection remains enabled.
It also removes physical-machine Bluetooth, audio, USB-map, and AGPM leftovers.
The `e1000` NIC avoids an unsigned virtio network kext.

The text OpenCore picker is enabled for installation and recovery. No graphical
acceleration, audio, GPU passthrough, physical-device compatibility, or Apple
licence entitlement is claimed. A successful firmware/OpenCore boot does not
guarantee every macOS release; preserve the known-good EFI and a recovery path
before updating.

## 5. Optional clean firmware rebuild

To replace the bundled known-good firmware with a clean build, prepare the EDK2
checkout at the exact commit in `provenance/inputs.json`, including recursive
submodules, ACPICA `iasl`, and the EDK2 build prerequisites, then run:

```sh
./scripts/build-ready-bundle.sh "$EDK2_CHECKOUT" ./out/rebuilt 4
```

The rebuild emits both `BHYVE_UEFI.fd` and a new immutable
`BHYVE_UEFI_VARS.fd`. Bit-identical reproduction is not claimed; validate the
rebuilt firmware separately before replacing a working bootrom.

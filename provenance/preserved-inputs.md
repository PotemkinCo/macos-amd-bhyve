# Preserved publishable inputs

This index records only safe source/recipe/provenance inputs used by the local
staging tree. The source evidence remains in ignored owner-only storage; raw
logs, firmware, OpenCore images, UEFI variables, guest disks, and private
machine state are not copied here.

| Staged input | Preserved source | SHA-256 | Use |
|---|---|---|---|
| `acpi/SSDT-BHYVE-CPU.dsl` | `runtime/results/2026-08-20-my-bsd-workflow-update.gp7qlg/protected-artifacts/macos-bhyve/SSDT-BHYVE-CPU.dsl` | `a858e947ace143768e2a3b825d6fe97c8c7d7cafe79be2fc0dae844c35965264` | Four-CPU ACPI source |
| `patches/edk2-known-good-baseline-dxe.patch` | `.../protected-artifacts/macos-bhyve/edk2-build-provenance-20260823/known-good-baseline-dxe.patch` | original `fe8892d5ce5adb755c6690117d3ee28127083af57695f17fb219c043ae47e34a`; staged normalized `27b5d90d6d6edb089cc95d14cb706dce921adb442f7132110f113f6a89e6b3b8` | Isolated EDK2 source patch |
| `LICENSE` | preserved PotemkinCo repository blob `261eeb9e9f8b2b4b0d119366dda99c6fd7d35c64` | recorded in evidence `6211` | Staging repository Apache-2.0 license |
| `licenses/OPENC-BSD3.txt` | preserved OpenCore license evidence `6213-opencore-license.txt.original.log` | source evidence hash recorded locally | OpenCore attribution reference |
| `licenses/EDK2-BHYVE-BSD3.txt` | protected `edk2-bhyve-g202508_2/LICENSE` | source evidence hash recorded locally | EDK2-bhyve package notice |
| `licenses/VM-BHYVE-BSD2.txt` | protected `vm-bhyve-1.7.4/BSD2CLAUSE` | source evidence hash recorded locally | vm-bhyve notice |

## Upstream pins

* PotemkinCo/macos-amd-bhyve: observed main tree object
  `1992222abfa1a320c45a39131baeefcb3b7f0821`; local checkout absent.
* Tianocore EDK2: `https://github.com/tianocore/edk2.git`, commit
  `d46aa46c8361194521391aa581593e556c707c6e`.
* AMD_Vanilla: commit `eaf52ef292abf4ebec899df6d48626569ba50cc6`; its patch
  bytes are not staged in this repository.
* OpenCore: version 1.0.6 was observed, but no immutable source commit was
  retained.
* FreeBSD package observations: `vm-bhyve-1.7.4`, `bhyve-firmware-1.0_2`,
  `edk2-bhyve-g202508_2`, and `qemu-tools-11.0.2`.

The custom firmware reference digest is
`93a38b9ef4b3ab81fde9f240d50272dd14ba21204d92a9c80357ab0688cae3b8`; it is
not shipped. The preserved EDK2 build record explicitly says the original
invocation/toolchain/submodule closure was incomplete.

The staged EDK2 patch is newline-normalized for portable Git application; its
content is the preserved isolated patch, while the original evidence byte hash
is retained in the audit evidence. The SSDT source is byte-identical to the
preserved source.

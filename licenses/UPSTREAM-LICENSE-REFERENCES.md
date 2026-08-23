# Upstream license and redistribution references

This recipe contains source and notices only. These references do not grant
rights to redistribute Apple software, guest disks, firmware images, or kernel
patch data.

* OpenCorePkg release `1.0.6`: the official repository contains `LICENSE.txt`
  and identifies the project as BSD-3-Clause. The preserved BSD-3 notice is
  `licenses/OPENC-BSD3.txt`.
  <https://github.com/acidanthera/OpenCorePkg/releases/tag/1.0.6>
  <https://github.com/acidanthera/OpenCorePkg>
* Tianocore EDK II `edk2-stable202508` / commit
  `d46aa46c8361194521391aa581593e556c707c6e`: the official project states
  that most content uses BSD-2-Clause-Patent, with OvmfPkg and git submodules
  subject to additional licenses. This staging tree does not contain the
  complete EDK2 source or dependency closure; `licenses/EDK2-BHYVE-BSD3.txt`
  is only the preserved FreeBSD package notice.
  <https://github.com/tianocore/edk2/releases/tag/edk2-stable202508>
  <https://github.com/tianocore/edk2/tree/d46aa46c8361194521391aa581593e556c707c6e>
  <https://github.com/tianocore/edk2>
* AMD-OSX/AMD_Vanilla commit
  `eaf52ef292abf4ebec899df6d48626569ba50cc6` is the upstream source of the
  owner-applied binary kernel patch set. The official repository does not
  expose a license file in the pinned tree/repository inventory. Do not copy
  or redistribute its patch bytes until the owner verifies license and
  redistribution permission.
  <https://github.com/AMD-OSX/AMD_Vanilla/commit/eaf52ef292abf4ebec899df6d48626569ba50cc6>
  <https://github.com/AMD-OSX/AMD_Vanilla/blob/eaf52ef292abf4ebec899df6d48626569ba50cc6/patches.plist>
* vm-bhyve is separately covered by the preserved BSD-2 notice in
  `licenses/VM-BHYVE-BSD2.txt`; this repository does not vendor vm-bhyve.

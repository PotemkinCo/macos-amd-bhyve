# OpenCore configuration fragment (sanitized)

This is a field-level recipe, not a plist. The retained final plist contained
machine identity values and is intentionally not redistributed.

Apply these settings to an owner-built OpenCore 1.0.6 configuration, then run
the matching `ocvalidate` binary before installing the image:

* `ACPI -> Add`: add `SSDT-BHYVE-CPU.aml` with `Enabled=true`.
* `Kernel -> Quirks`: enable `ProvideCurrentCpuInfo`.
* `Kernel -> Patch`: apply the AMD_Vanilla patch set from the pinned owner
  checkout. Enable the four core-count entries, CPU-family/vendor/MSR/panic
  fixes, and the Sequoia PAT entry observed in the evidence. Keep the
  alternate PAT and AM5 hotplug entries disabled unless the owner has a
  separately reviewed host-specific reason.
* `PlatformInfo`: set `Automatic=true` and `CustomMemory=true`.
* `PlatformInfo -> Memory`: use the guest's selected memory size. The proven
  baseline used `DataWidth=64`, one virtual-memory device, `Size=12288` MiB,
  `MaxCapacity=12884901888`, `TotalWidth=64`, `Type=26`, and `TypeDetail=128`.
  Use generic values for asset/device/part/serial fields; never reuse a
  retained identity.
* `PlatformInfo -> Generic`: generate fresh owner-local `MLB`, `ROM`,
  `SystemSerialNumber`, and `SystemUUID`; use a generic supported product name
  only after the owner reviews its licensing and compatibility implications.
* `NVRAM -> Add -> 7C436110-AB2A-4BBB-A880-FE41995C9F82`: use the proven
  serial-capable bring-up arguments
  `-v keepsyms=1 amfi_get_out_of_my_way=1 tlbto_us=0 vti=9 serial=7 debug=0x2 pci=0x1 npci=0x2000`.
  These are diagnostic bring-up arguments, not a security recommendation.
* `Misc -> Boot`: use `ShowPicker=false` only for an owner-approved headless
  baseline; keep a recovery copy with a visible picker.

Do not copy Apple recovery data, kernel bytes, a retained plist, private UUIDs,
serial numbers, ROM/MLB values, or host network identity into this tree.

This bundle was assembled locally from the pinned, hash-checked source recipe.
Its known-good bhyve firmware was either copied from the public recipe or
rebuilt from the recorded EDK2 source and patch.

1. Keep BHYVE_UEFI_VARS.fd as an immutable template. Give each VM its own copy;
   never share or reuse a live variable store.
2. Install BHYVE_UEFI.fd as the vm-bhyve custom firmware.
3. Copy opencore.img and macos.conf.example into a new VM directory. Rename the
   configuration as required by vm-bhyve and replace the private-switch placeholder.
4. Create/attach macos-system.raw and permitted Apple recovery or installer media.
5. Keep identity.env private. Verify its generated serial is unused before signing
   in to Apple services.

Do not publish this generated archive: patches.plist has no explicit upstream
redistribution licence, and config.plist contains a generated machine identity.
Publish the source recipe instead.

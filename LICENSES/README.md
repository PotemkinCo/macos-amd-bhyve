# Third-party licences

The licence texts in this directory apply to the bundled third-party payloads
listed in `NOTICE` and `provenance/inputs.json`. They do not relicense those
works under the repository's Apache-2.0 project licence.

The exact committed payload is covered as follows:

* EDK2-derived firmware: BSD-2-Clause-Patent.
* OpenCorePkg EFI files, driver, ACPI binary, and utilities: BSD-3-Clause.
* Lilu, VirtualSMC, WhateverGreen, and CryptexFixup: their respective
  BSD-3-Clause texts.
* MCEReporterDisabler's complete plist-only source: GPL-2.0-only, based on the
  copyright/licence notice embedded by its author.

The AMD_Vanilla patch list is absent because its pinned source repository has
no explicit redistribution licence. A file downloaded into a private build
directory by the assembler is not part of this public distribution.

Apple media and software are never included.

DefinitionBlock ("", "SSDT", 2, "BHYVE", "BVCPUS", 0x00000000)
{
    Scope (\_SB)
    {
        Device (CPUS)
        {
            Name (_HID, "ACPI0010")
            Name (_UID, Zero)

            Processor (C000, 0x00, 0x00000000, 0x00)
            {
            }

            Processor (C001, 0x01, 0x00000000, 0x00)
            {
            }

            Processor (C002, 0x02, 0x00000000, 0x00)
            {
            }

            Processor (C003, 0x03, 0x00000000, 0x00)
            {
            }
        }
    }
}

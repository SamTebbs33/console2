ENTRY(_start)

MEMORY {
    ppu(rx) : org = 0, len = (8 * 1024)
}

/*
 * Mem map
 * 0 - 8KiB: Code
 * 8KiB - 16KiB: Sprite table (2880B), tile table (2880B) and ppu registers
 * 16KiB - 32KiB: Sprite defs, animation defs and palette defs
 * 32KiB - 64KiB: Pixel map (30000B) and working mem (2KiB)
 */
_stack_end = 64 * 1024 - 1;

SECTIONS
{
    .text :
    {
        *(.start)
        . = 0x0066;
        *(.nmiHandler)
        *(.text)
    } > ppu
}

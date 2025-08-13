ENTRY(_start)

MEMORY {
    code(rx) : org = 0, len = (8 * 1024)
}

/*
 * Mem map
 * 0 - 8KiB: Code
 * 8KiB - 48KiB: Working mem, stack at top
 * 48KiB - 64KiB: Sprite table and ppu registers
 */
_stack_end = 48 * 1024 - 1;

SECTIONS
{
    .text :
    {
        *(.start)
        . = 0x0038;
        *(.intHandler)
        *(.text)
    } > code
}

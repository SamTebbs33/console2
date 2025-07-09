ENTRY(_main)

MEMORY {
    ppuCode (xr) : org = 0x0, len = 8 * 1024
    ppuData (rw) : org = 8 * 1024, len = (64 * 1024) - (8 * 1024)
}

SECTIONS
{
    .text :
    {
        *(.start)
        *(.text)
    } > ppuCode

    .data :
    {
        _spriteEntries = .;
        . = . + 2 * 1024;
        _tileEntries = .;
        . = . + 2 * 1024;
        . = . + 4 * 1024;
        _spriteDefs = .;
        . = . + 8 * 1024;
        _animations = .;
        . = . + 8 * 1024;
        stack_start = .;
        . = . + 2 * 1024;
        stack_end = .;
    } > ppuData
}

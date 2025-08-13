; vim: ft=z80 tabstop=4 shiftwidth=4:
SPRITE_TABLE_ADDR = 48 * 1024
PPU_DEFS_ADDR = 16 * 1024
SPRITE_0_ADDR = PPU_DEFS_ADDR + 0 * 64

.section .intHandler
.global _intHandler
_intHandler:
    ld ix, SPRITE_TABLE_ADDR
    ld (ix+2), SPRITE_0_ADDR & 0xFF
    ld (ix+3), SPRITE_0_ADDR >> 8
    ld (ix+4), 8
    ld (ix+5), 8
    ld (ix+6), SPRITE_0_ADDR & 0xFF
    ld (ix+7), SPRITE_0_ADDR >> 8
    reti

.section .start
.global _start
_start:
    im 1
    ei
.spin:
    jr .spin

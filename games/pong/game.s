; vim: ft=z80 tabstop=4 shiftwidth=4:
SPRITE_TABLE_ADDR = 48 * 1024
PPU_DEFS_ADDR = 16 * 1024
SPRITE_0_ADDR = PPU_DEFS_ADDR + 0 * 64

.section .intHandler
.global _intHandler
_intHandler:
    inc b
    jp nz, .ret
    ld ix, SPRITE_TABLE_ADDR
    ld (ix), c ; x
    ld (ix+1), 0 ; y
    ld (ix+2), SPRITE_0_ADDR & 0xFF ; sprite addr low
    ld (ix+3), SPRITE_0_ADDR >> 8 ; sprite addr high
    inc c
.ret:
    ei
    reti

.section .start
.global _start
_start:
    ld b, 0
    ld c, 0
    im 1
    ei
.spin:
    jr .spin

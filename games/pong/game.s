; vim: ft=z80 tabstop=4 shiftwidth=4:
SPRITE_ENTRY_SIZE = 5
SPRITE_ENTRIES_NUM = 64
SPRITE_TABLE_ADDR = 48 * 1024
TILE_TABLE_ADDR = SPRITE_TABLE_ADDR + SPRITE_ENTRIES_NUM * SPRITE_ENTRY_SIZE
PPU_DEFS_ADDR = 16 * 1024
SPRITE_0_ADDR = PPU_DEFS_ADDR + 0 * 64
SPRITE_2_ADDR = PPU_DEFS_ADDR + 2 * 64

.section .intHandler
.global _intHandler
_intHandler:
    inc a
    cp 10
    jr nz, .ret
    ld a, 0
    ld ix, SPRITE_TABLE_ADDR
    inc (ix+7)
    .ret:
    ei
    reti

.section .start
.global _start
.extern _stack_end
_start:
    ld ix, _stack_end
    ld sp, ix
    jr setup_background

.section .text
setup_background:
    ld ix, TILE_TABLE_ADDR
    ld bc, 2
    .rep 19
        .rep 25
            ld (ix), SPRITE_2_ADDR & 0xFF
            ld (ix+1), SPRITE_2_ADDR >> 8
            add ix, bc
        .endr
    .endr
    ld ix, SPRITE_TABLE_ADDR
    ld (ix), 1 ; enabled
    ld (ix+1), 0 ; y
    ld (ix+2), 8 ; x
    ld (ix+3), SPRITE_0_ADDR & 0xFF ; sprite addr low
    ld (ix+4), SPRITE_0_ADDR >> 8 ; sprite addr high
    ld (ix+5), 1 ; enabled
    ld (ix+6), 0 ; y
    ld (ix+7), 0 ; x
    ld (ix+8), SPRITE_0_ADDR & 0xFF ; sprite addr low
    ld (ix+9), SPRITE_0_ADDR >> 8 ; sprite addr high
    ld a, 0
    im 1
    ei
.spin:
    jr .spin

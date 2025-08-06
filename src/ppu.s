SPRITE_TABLE_ADDR = (8 * 1024)
SPRITE_DEFS_ADDR  = (16 * 1024)
PIXEL_MAP_ADDR = (32 * 1024)
SPRITE_DEF_NUM = 255
SPRITE_DEF_PIXELS_X = 8
SPRITE_DEF_PIXELS_Y = 8
SPRITE_DEF_PIXELS_NUM = (SPRITE_DEF_PIXELS_X * SPRITE_DEF_PIXELS_Y)
SPRITE_DEF_SIZE = (SPRITE_DEF_PIXELS_NUM / 2)
SPRITE_DEF_MEM_SIZE = (SPRITE_DEF_SIZE * SPRITE_DEF_NUM)
ANIMATION_DEFS_ADDR = (SPRITE_DEFS_ADDR + SPRITE_DEF_MEM_SIZE)
SPRITE_ENTRIES_NUM_X = 25
SPRITE_ENTRIES_NUM_Y = 19
SPRITE_ENTRIES_NUM = (SPRITE_ENTRIES_NUM_X * SPRITE_ENTRIES_NUM_Y)
SPRITE_ENTRIES_NUM_LOW = SPRITE_ENTRIES_NUM & 0xFF
SPRITE_ENTRIES_NUM_HIGH = SPRITE_ENTRIES_NUM >> 8
SPRITE_ENTRIES_PIXELS_X = (SPRITE_ENTRIES_NUM_X * SPRITE_DEF_PIXELS_X)
SPRITE_ENTRIES_PIXELS_Y = (SPRITE_ENTRIES_NUM_Y * SPRITE_DEF_PIXELS_Y - 2)
SPRITE_ENTRY_SIZE = 4
TILE_TABLE_ADDR = (SPRITE_TABLE_ADDR + (SPRITE_ENTRY_SIZE * SPRITE_ENTRIES_NUM))
PPU_REGS_ADDR = (TILE_TABLE_ADDR + (SPRITE_ENTRIES_NUM * SPRITE_ENTRY_SIZE))
REG_PALETTE_BASE = 0

.extern _stack_end

.macro RENDERX
    ; Put two pixels from current sprite def address into VRAM
    ld a, (hl) ; a has the two pixels for this sprite def addr
    inc hl  ; hl is now at the next sprite def addr
    ld c, a ; save pixels
    and 0xF ; first pixel
    ; Add palette index to palette address
    ld ix, PPU_REGS_ADDR + REG_PALETTE_BASE
    ld d, 0
    ld e, a
    add ix, de
    ; Put the colour from the palette into pixel mem
    ld a, (ix)
    ld (iy), a
    inc iy
    ; Extract the top 4 bits from the saved pixel byte
    ld e, c
    srl e
    srl e
    srl e
    srl e
    ; Put the colour into pixel mem
    ld ix, PPU_REGS_ADDR + REG_PALETTE_BASE
    add ix, de
    ld a, (ix)
    ld (iy), a
    inc iy
.endm

.macro RENDERY
    RENDERX
    RENDERX
    RENDERX
    RENDERX
    ; move pixel address to next line
    ld e, SPRITE_ENTRIES_PIXELS_X - SPRITE_DEF_PIXELS_X
    ld d, 0
    add iy, de
.endm

.section .start
.global _start
_start:
    ; The interrupt handler takes the return address from hl
    ld hl, render
    ld ix, _stack_end
    ld sp, ix
    im 1
    ei
    jp spin

.section .intHandler
.global _intHandler
; An interrupt means we're transitioning from spinning to rendering
_intHandler:
    ; Remove return address from top of stack and put saved render address there instead
    ex (sp), hl
    ; Restore previously saved regs from last rendering period
    ex af, af'
    exx
    ei
    reti

.section .nmiHandler
.global _nmiHandler
; An NMI means we're transitioning from rendering to spinning
_nmiHandler:
    ; Save regs. Spinning doesn't modify the regs so we don't have to worry about them being clobbered before the next rendering period
    exx
    ex af, af'
    ; Replace nmi return address with spin function then save return address
    ld hl, spin
    ex (sp), hl
    retn

.section .text
spin:
    halt

render:
    ld bc, SPRITE_ENTRIES_NUM ; sprite entry counter
    ld ix, SPRITE_TABLE_ADDR
.loop_sprites:
    push bc ; Save the sprite entry counter. We don't need it again until checking if we've rendered all sprites
.render_sprite:
    ld b, (ix) ; b now has the full x coord
    inc ix
    ld c, (ix) ; c now has the full y coord
    inc ix ; ix is now at the sprite address
    ld l, (ix)
    inc ix
    ld h, (ix) ; hl now has the sprite def addr
    inc ix ; ix is now at the next sprite entry
    push ix ; We won't need the sprite entry addr until moving to the next sprite
    ; hl has sprite def addr
    ; b has x coord
    ; c has y coord
    ld iy, PIXEL_MAP_ADDR
    ld e, b
    ld d, 0
    add iy, de
    ; Find the pixel map offset corresponding to y and add it to iy. y must be multiplied by two since each entry in the lookup table takes two bytes
    ld ix, pixel_lookup
    ld e, c
    sla e
    rl d
    add ix, de
    ld e, (ix)
    ld d, (ix + 1) ; de how has the pixel map offset
    add iy, de ; iy now has the full pixel map address for this sprite

    RENDERY
    RENDERY
    RENDERY
    RENDERY
    RENDERY
    RENDERY
    RENDERY
    RENDERY

    pop ix ; Now we need the sprite entry addr again
    ; Decrement the sprite entry counter and check if we've done the last entry
    pop bc
    dec bc
    xor a
    or b
    jp nz, .loop_sprites
    or c
    jp nz, .loop_sprites
    ; Wait for the next display period
    nop
    halt
    ; When the next blanking period starts, the interrupt handler will jump here
    jp render

; A lookup table with the y pixel coordinate mapped to an offset into the pixel map, to be added to the x pixel coordinate
pixel_lookup:
.dcb.w 1, 0
.dcb.w 1, 200
.dcb.w 1, 400
.dcb.w 1, 600
.dcb.w 1, 800
.dcb.w 1, 1000
.dcb.w 1, 1200
.dcb.w 1, 1400
.dcb.w 1, 1600
.dcb.w 1, 1800
.dcb.w 1, 2000
.dcb.w 1, 2200
.dcb.w 1, 2400
.dcb.w 1, 2600
.dcb.w 1, 2800
.dcb.w 1, 3000
.dcb.w 1, 3200
.dcb.w 1, 3400
.dcb.w 1, 3600
.dcb.w 1, 3800
.dcb.w 1, 4000
.dcb.w 1, 4200
.dcb.w 1, 4400
.dcb.w 1, 4600
.dcb.w 1, 4800
.dcb.w 1, 5000
.dcb.w 1, 5200
.dcb.w 1, 5400
.dcb.w 1, 5600
.dcb.w 1, 5800
.dcb.w 1, 6000
.dcb.w 1, 6200
.dcb.w 1, 6400
.dcb.w 1, 6600
.dcb.w 1, 6800
.dcb.w 1, 7000
.dcb.w 1, 7200
.dcb.w 1, 7400
.dcb.w 1, 7600
.dcb.w 1, 7800
.dcb.w 1, 8000
.dcb.w 1, 8200
.dcb.w 1, 8400
.dcb.w 1, 8600
.dcb.w 1, 8800
.dcb.w 1, 9000
.dcb.w 1, 9200
.dcb.w 1, 9400
.dcb.w 1, 9600
.dcb.w 1, 9800
.dcb.w 1, 10000
.dcb.w 1, 10200
.dcb.w 1, 10400
.dcb.w 1, 10600
.dcb.w 1, 10800
.dcb.w 1, 11000
.dcb.w 1, 11200
.dcb.w 1, 11400
.dcb.w 1, 11600
.dcb.w 1, 11800
.dcb.w 1, 12000
.dcb.w 1, 12200
.dcb.w 1, 12400
.dcb.w 1, 12600
.dcb.w 1, 12800
.dcb.w 1, 13000
.dcb.w 1, 13200
.dcb.w 1, 13400
.dcb.w 1, 13600
.dcb.w 1, 13800
.dcb.w 1, 14000
.dcb.w 1, 14200
.dcb.w 1, 14400
.dcb.w 1, 14600
.dcb.w 1, 14800
.dcb.w 1, 15000
.dcb.w 1, 15200
.dcb.w 1, 15400
.dcb.w 1, 15600
.dcb.w 1, 15800
.dcb.w 1, 16000
.dcb.w 1, 16200
.dcb.w 1, 16400
.dcb.w 1, 16600
.dcb.w 1, 16800
.dcb.w 1, 17000
.dcb.w 1, 17200
.dcb.w 1, 17400
.dcb.w 1, 17600
.dcb.w 1, 17800
.dcb.w 1, 18000
.dcb.w 1, 18200
.dcb.w 1, 18400
.dcb.w 1, 18600
.dcb.w 1, 18800
.dcb.w 1, 19000
.dcb.w 1, 19200
.dcb.w 1, 19400
.dcb.w 1, 19600
.dcb.w 1, 19800
.dcb.w 1, 20000
.dcb.w 1, 20200
.dcb.w 1, 20400
.dcb.w 1, 20600
.dcb.w 1, 20800
.dcb.w 1, 21000
.dcb.w 1, 21200
.dcb.w 1, 21400
.dcb.w 1, 21600
.dcb.w 1, 21800
.dcb.w 1, 22000
.dcb.w 1, 22200
.dcb.w 1, 22400
.dcb.w 1, 22600
.dcb.w 1, 22800
.dcb.w 1, 23000
.dcb.w 1, 23200
.dcb.w 1, 23400
.dcb.w 1, 23600
.dcb.w 1, 23800
.dcb.w 1, 24000
.dcb.w 1, 24200
.dcb.w 1, 24400
.dcb.w 1, 24600
.dcb.w 1, 24800
.dcb.w 1, 25000
.dcb.w 1, 25200
.dcb.w 1, 25400
.dcb.w 1, 25600
.dcb.w 1, 25800
.dcb.w 1, 26000
.dcb.w 1, 26200
.dcb.w 1, 26400
.dcb.w 1, 26600
.dcb.w 1, 26800
.dcb.w 1, 27000
.dcb.w 1, 27200
.dcb.w 1, 27400
.dcb.w 1, 27600
.dcb.w 1, 27800
.dcb.w 1, 28000
.dcb.w 1, 28200
.dcb.w 1, 28400
.dcb.w 1, 28600
.dcb.w 1, 28800
.dcb.w 1, 29000
.dcb.w 1, 29200
.dcb.w 1, 29400
.dcb.w 1, 29600
.dcb.w 1, 29800
.dcb.w 1, 30000
.dcb.w 1, 30200

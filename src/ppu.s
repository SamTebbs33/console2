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
    ld iy, ANIMATION_DEFS_ADDR
    ld a, (ix) ; Animation index from sprite
    inc ix ; ix is now at frame counter
    or a
    jp nz, .hasAnimation
    inc ix ; ix is now at spriteIndex
    ld bc, 0 ; b and c store the x and y render offsets, respectively
    ld de, 0 ; e stores the sprite offset
    push de ; render_sprite expects the sprite offset to be on the stack
    jp .render_sprite
.hasAnimation:
    ; Multiply the anim index by 4 to get the offset into the animation def table
    ld h, 0
    ld l, a
    add hl, hl
    add hl, hl
    ld d, h
    ld e, l
    ; iy now has the address of the animation
    add iy, de
    ; Process speed if the animation has speed
    ld a, (iy)
    inc iy ; iy is now at the nextAnimIndex
    or a
    jp z, .computeOffsets
    ; Compare speed with sprite's frame counter
    ld d, (ix)
    cp d
    ; If the speed matches the frame counter, proceed to the next animation
    jp z, .nextAnimIndex
    inc (ix) ; Increment the frame counter
    jp .computeOffsets
.nextAnimIndex:
    ld (ix), 0
    ld d, (iy)
    ld (ix - 1), d
.computeOffsets:
    inc iy ; Increment iy to point to cordinate offsets
    inc ix ; ix is now at spriteAddr
    ; Extract the x offset from the bottom 4 bits
    ld c, (iy)
    ld a, c
    and 0xF
    ld b, a ; Now b has the x offset
    ; Extract the y offset from the top 4 bits
    srl c
    srl c
    srl c
    srl c ; Now c has the y offset
    ld a, (iy + 1) ; Load the metadata byte, including the sprite offset in the bottom 3 bits
    and 0b111
    ld e, a
    xor d
    push de ; de will be needed before the sprite offset is needed so save it to the stack
.render_sprite:
    ; b has the x offset, c has the y offset and e has the sprite offset (also saved to stack)
    ; Load the appropriate x and y coordinates from coord_lookup then add to saved x and y offsets
    push ix
    pop hl
    ld de, SPRITE_TABLE_ADDR
    sbc hl, de ; Subtract the base addr from the sprite entry addr to just get the offset into the table
    ld de, coord_lookup
    add hl, de ; hl now has the address into the lookup table for retrieving the pixel x and y
    ld a, b
    add a, (hl)
    ld b, a ; b now has the full offsetted x coordinate
    inc hl
    ld a, c
    add a, (hl)
    ld c, a ; c now has the full offsetted y coordinate

    pop de ; Restore the sprite offset we saved earlier
    ld l, (ix)
    inc ix
    push ix ; We won't need the sprite entry addr until moving to the next sprite
    ld h, (ix)
    add hl, de ; hl now has the sprite def addr
    ; hl has sprite def addr
    ; b has x coord with offset applied
    ; c has y coord with offset applied
    ld iy, PIXEL_MAP_ADDR
    ld e, b
    ld d, 0
    add iy, de
    ; Find the pixel map offset corresponding to y and add it to iy
    ld ix, pixel_lookup
    ld e, c
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
    inc ix ; Increment sprite entry addr
    ; Increment the sprite entry counter and check if we've done the last entry
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
.dcb.b 6, 0
.dcb.w 1, 1600
.dcb.b 6, 0
.dcb.w 1, 3200
.dcb.b 6, 0
.dcb.w 1, 4800
.dcb.b 6, 0
.dcb.w 1, 6400
.dcb.b 6, 0
.dcb.w 1, 8000
.dcb.b 6, 0
.dcb.w 1, 9600
.dcb.b 6, 0
.dcb.w 1, 11200
.dcb.b 6, 0
.dcb.w 1, 12800
.dcb.b 6, 0
.dcb.w 1, 14400
.dcb.b 6, 0
.dcb.w 1, 16000
.dcb.b 6, 0
.dcb.w 1, 17600
.dcb.b 6, 0
.dcb.w 1, 19200
.dcb.b 6, 0
.dcb.w 1, 20800
.dcb.b 6, 0
.dcb.w 1, 22400
.dcb.b 6, 0
.dcb.w 1, 24000
.dcb.b 6, 0
.dcb.w 1, 25600
.dcb.b 6, 0
.dcb.w 1, 27200
.dcb.b 6, 0
.dcb.w 1, 28800
.dcb.b 6, 0

; A lookup table with the sprite entry offset mapped to the pixel x and y coordinate. x is in the lower byte and y is in the higher
; Each sprite entry is 4 bytes large so each lookup table entry needs to be 4 bytes after the previous one
coord_lookup:
.dcb.b 2, 0 ; Padding for first entry since we index this by sprite entry offset + 2
.dcb.w 1, 0
.dcb.b 2, 0
.dcb.w 1, 8
.dcb.b 2, 0
.dcb.w 1, 16
.dcb.b 2, 0
.dcb.w 1, 24
.dcb.b 2, 0
.dcb.w 1, 32
.dcb.b 2, 0
.dcb.w 1, 40
.dcb.b 2, 0
.dcb.w 1, 48
.dcb.b 2, 0
.dcb.w 1, 56
.dcb.b 2, 0
.dcb.w 1, 64
.dcb.b 2, 0
.dcb.w 1, 72
.dcb.b 2, 0
.dcb.w 1, 80
.dcb.b 2, 0
.dcb.w 1, 88
.dcb.b 2, 0
.dcb.w 1, 96
.dcb.b 2, 0
.dcb.w 1, 104
.dcb.b 2, 0
.dcb.w 1, 112
.dcb.b 2, 0
.dcb.w 1, 120
.dcb.b 2, 0
.dcb.w 1, 128
.dcb.b 2, 0
.dcb.w 1, 136
.dcb.b 2, 0
.dcb.w 1, 144
.dcb.b 2, 0
.dcb.w 1, 152
.dcb.b 2, 0
.dcb.w 1, 160
.dcb.b 2, 0
.dcb.w 1, 168
.dcb.b 2, 0
.dcb.w 1, 176
.dcb.b 2, 0
.dcb.w 1, 184
.dcb.b 2, 0
.dcb.w 1, 192
.dcb.b 2, 0
.dcb.w 1, 2048
.dcb.b 2, 0
.dcb.w 1, 2056
.dcb.b 2, 0
.dcb.w 1, 2064
.dcb.b 2, 0
.dcb.w 1, 2072
.dcb.b 2, 0
.dcb.w 1, 2080
.dcb.b 2, 0
.dcb.w 1, 2088
.dcb.b 2, 0
.dcb.w 1, 2096
.dcb.b 2, 0
.dcb.w 1, 2104
.dcb.b 2, 0
.dcb.w 1, 2112
.dcb.b 2, 0
.dcb.w 1, 2120
.dcb.b 2, 0
.dcb.w 1, 2128
.dcb.b 2, 0
.dcb.w 1, 2136
.dcb.b 2, 0
.dcb.w 1, 2144
.dcb.b 2, 0
.dcb.w 1, 2152
.dcb.b 2, 0
.dcb.w 1, 2160
.dcb.b 2, 0
.dcb.w 1, 2168
.dcb.b 2, 0
.dcb.w 1, 2176
.dcb.b 2, 0
.dcb.w 1, 2184
.dcb.b 2, 0
.dcb.w 1, 2192
.dcb.b 2, 0
.dcb.w 1, 2200
.dcb.b 2, 0
.dcb.w 1, 2208
.dcb.b 2, 0
.dcb.w 1, 2216
.dcb.b 2, 0
.dcb.w 1, 2224
.dcb.b 2, 0
.dcb.w 1, 2232
.dcb.b 2, 0
.dcb.w 1, 2240
.dcb.b 2, 0
.dcb.w 1, 4096
.dcb.b 2, 0
.dcb.w 1, 4104
.dcb.b 2, 0
.dcb.w 1, 4112
.dcb.b 2, 0
.dcb.w 1, 4120
.dcb.b 2, 0
.dcb.w 1, 4128
.dcb.b 2, 0
.dcb.w 1, 4136
.dcb.b 2, 0
.dcb.w 1, 4144
.dcb.b 2, 0
.dcb.w 1, 4152
.dcb.b 2, 0
.dcb.w 1, 4160
.dcb.b 2, 0
.dcb.w 1, 4168
.dcb.b 2, 0
.dcb.w 1, 4176
.dcb.b 2, 0
.dcb.w 1, 4184
.dcb.b 2, 0
.dcb.w 1, 4192
.dcb.b 2, 0
.dcb.w 1, 4200
.dcb.b 2, 0
.dcb.w 1, 4208
.dcb.b 2, 0
.dcb.w 1, 4216
.dcb.b 2, 0
.dcb.w 1, 4224
.dcb.b 2, 0
.dcb.w 1, 4232
.dcb.b 2, 0
.dcb.w 1, 4240
.dcb.b 2, 0
.dcb.w 1, 4248
.dcb.b 2, 0
.dcb.w 1, 4256
.dcb.b 2, 0
.dcb.w 1, 4264
.dcb.b 2, 0
.dcb.w 1, 4272
.dcb.b 2, 0
.dcb.w 1, 4280
.dcb.b 2, 0
.dcb.w 1, 4288
.dcb.b 2, 0
.dcb.w 1, 6144
.dcb.b 2, 0
.dcb.w 1, 6152
.dcb.b 2, 0
.dcb.w 1, 6160
.dcb.b 2, 0
.dcb.w 1, 6168
.dcb.b 2, 0
.dcb.w 1, 6176
.dcb.b 2, 0
.dcb.w 1, 6184
.dcb.b 2, 0
.dcb.w 1, 6192
.dcb.b 2, 0
.dcb.w 1, 6200
.dcb.b 2, 0
.dcb.w 1, 6208
.dcb.b 2, 0
.dcb.w 1, 6216
.dcb.b 2, 0
.dcb.w 1, 6224
.dcb.b 2, 0
.dcb.w 1, 6232
.dcb.b 2, 0
.dcb.w 1, 6240
.dcb.b 2, 0
.dcb.w 1, 6248
.dcb.b 2, 0
.dcb.w 1, 6256
.dcb.b 2, 0
.dcb.w 1, 6264
.dcb.b 2, 0
.dcb.w 1, 6272
.dcb.b 2, 0
.dcb.w 1, 6280
.dcb.b 2, 0
.dcb.w 1, 6288
.dcb.b 2, 0
.dcb.w 1, 6296
.dcb.b 2, 0
.dcb.w 1, 6304
.dcb.b 2, 0
.dcb.w 1, 6312
.dcb.b 2, 0
.dcb.w 1, 6320
.dcb.b 2, 0
.dcb.w 1, 6328
.dcb.b 2, 0
.dcb.w 1, 6336
.dcb.b 2, 0
.dcb.w 1, 8192
.dcb.b 2, 0
.dcb.w 1, 8200
.dcb.b 2, 0
.dcb.w 1, 8208
.dcb.b 2, 0
.dcb.w 1, 8216
.dcb.b 2, 0
.dcb.w 1, 8224
.dcb.b 2, 0
.dcb.w 1, 8232
.dcb.b 2, 0
.dcb.w 1, 8240
.dcb.b 2, 0
.dcb.w 1, 8248
.dcb.b 2, 0
.dcb.w 1, 8256
.dcb.b 2, 0
.dcb.w 1, 8264
.dcb.b 2, 0
.dcb.w 1, 8272
.dcb.b 2, 0
.dcb.w 1, 8280
.dcb.b 2, 0
.dcb.w 1, 8288
.dcb.b 2, 0
.dcb.w 1, 8296
.dcb.b 2, 0
.dcb.w 1, 8304
.dcb.b 2, 0
.dcb.w 1, 8312
.dcb.b 2, 0
.dcb.w 1, 8320
.dcb.b 2, 0
.dcb.w 1, 8328
.dcb.b 2, 0
.dcb.w 1, 8336
.dcb.b 2, 0
.dcb.w 1, 8344
.dcb.b 2, 0
.dcb.w 1, 8352
.dcb.b 2, 0
.dcb.w 1, 8360
.dcb.b 2, 0
.dcb.w 1, 8368
.dcb.b 2, 0
.dcb.w 1, 8376
.dcb.b 2, 0
.dcb.w 1, 8384
.dcb.b 2, 0
.dcb.w 1, 10240
.dcb.b 2, 0
.dcb.w 1, 10248
.dcb.b 2, 0
.dcb.w 1, 10256
.dcb.b 2, 0
.dcb.w 1, 10264
.dcb.b 2, 0
.dcb.w 1, 10272
.dcb.b 2, 0
.dcb.w 1, 10280
.dcb.b 2, 0
.dcb.w 1, 10288
.dcb.b 2, 0
.dcb.w 1, 10296
.dcb.b 2, 0
.dcb.w 1, 10304
.dcb.b 2, 0
.dcb.w 1, 10312
.dcb.b 2, 0
.dcb.w 1, 10320
.dcb.b 2, 0
.dcb.w 1, 10328
.dcb.b 2, 0
.dcb.w 1, 10336
.dcb.b 2, 0
.dcb.w 1, 10344
.dcb.b 2, 0
.dcb.w 1, 10352
.dcb.b 2, 0
.dcb.w 1, 10360
.dcb.b 2, 0
.dcb.w 1, 10368
.dcb.b 2, 0
.dcb.w 1, 10376
.dcb.b 2, 0
.dcb.w 1, 10384
.dcb.b 2, 0
.dcb.w 1, 10392
.dcb.b 2, 0
.dcb.w 1, 10400
.dcb.b 2, 0
.dcb.w 1, 10408
.dcb.b 2, 0
.dcb.w 1, 10416
.dcb.b 2, 0
.dcb.w 1, 10424
.dcb.b 2, 0
.dcb.w 1, 10432
.dcb.b 2, 0
.dcb.w 1, 12288
.dcb.b 2, 0
.dcb.w 1, 12296
.dcb.b 2, 0
.dcb.w 1, 12304
.dcb.b 2, 0
.dcb.w 1, 12312
.dcb.b 2, 0
.dcb.w 1, 12320
.dcb.b 2, 0
.dcb.w 1, 12328
.dcb.b 2, 0
.dcb.w 1, 12336
.dcb.b 2, 0
.dcb.w 1, 12344
.dcb.b 2, 0
.dcb.w 1, 12352
.dcb.b 2, 0
.dcb.w 1, 12360
.dcb.b 2, 0
.dcb.w 1, 12368
.dcb.b 2, 0
.dcb.w 1, 12376
.dcb.b 2, 0
.dcb.w 1, 12384
.dcb.b 2, 0
.dcb.w 1, 12392
.dcb.b 2, 0
.dcb.w 1, 12400
.dcb.b 2, 0
.dcb.w 1, 12408
.dcb.b 2, 0
.dcb.w 1, 12416
.dcb.b 2, 0
.dcb.w 1, 12424
.dcb.b 2, 0
.dcb.w 1, 12432
.dcb.b 2, 0
.dcb.w 1, 12440
.dcb.b 2, 0
.dcb.w 1, 12448
.dcb.b 2, 0
.dcb.w 1, 12456
.dcb.b 2, 0
.dcb.w 1, 12464
.dcb.b 2, 0
.dcb.w 1, 12472
.dcb.b 2, 0
.dcb.w 1, 12480
.dcb.b 2, 0
.dcb.w 1, 14336
.dcb.b 2, 0
.dcb.w 1, 14344
.dcb.b 2, 0
.dcb.w 1, 14352
.dcb.b 2, 0
.dcb.w 1, 14360
.dcb.b 2, 0
.dcb.w 1, 14368
.dcb.b 2, 0
.dcb.w 1, 14376
.dcb.b 2, 0
.dcb.w 1, 14384
.dcb.b 2, 0
.dcb.w 1, 14392
.dcb.b 2, 0
.dcb.w 1, 14400
.dcb.b 2, 0
.dcb.w 1, 14408
.dcb.b 2, 0
.dcb.w 1, 14416
.dcb.b 2, 0
.dcb.w 1, 14424
.dcb.b 2, 0
.dcb.w 1, 14432
.dcb.b 2, 0
.dcb.w 1, 14440
.dcb.b 2, 0
.dcb.w 1, 14448
.dcb.b 2, 0
.dcb.w 1, 14456
.dcb.b 2, 0
.dcb.w 1, 14464
.dcb.b 2, 0
.dcb.w 1, 14472
.dcb.b 2, 0
.dcb.w 1, 14480
.dcb.b 2, 0
.dcb.w 1, 14488
.dcb.b 2, 0
.dcb.w 1, 14496
.dcb.b 2, 0
.dcb.w 1, 14504
.dcb.b 2, 0
.dcb.w 1, 14512
.dcb.b 2, 0
.dcb.w 1, 14520
.dcb.b 2, 0
.dcb.w 1, 14528
.dcb.b 2, 0
.dcb.w 1, 16384
.dcb.b 2, 0
.dcb.w 1, 16392
.dcb.b 2, 0
.dcb.w 1, 16400
.dcb.b 2, 0
.dcb.w 1, 16408
.dcb.b 2, 0
.dcb.w 1, 16416
.dcb.b 2, 0
.dcb.w 1, 16424
.dcb.b 2, 0
.dcb.w 1, 16432
.dcb.b 2, 0
.dcb.w 1, 16440
.dcb.b 2, 0
.dcb.w 1, 16448
.dcb.b 2, 0
.dcb.w 1, 16456
.dcb.b 2, 0
.dcb.w 1, 16464
.dcb.b 2, 0
.dcb.w 1, 16472
.dcb.b 2, 0
.dcb.w 1, 16480
.dcb.b 2, 0
.dcb.w 1, 16488
.dcb.b 2, 0
.dcb.w 1, 16496
.dcb.b 2, 0
.dcb.w 1, 16504
.dcb.b 2, 0
.dcb.w 1, 16512
.dcb.b 2, 0
.dcb.w 1, 16520
.dcb.b 2, 0
.dcb.w 1, 16528
.dcb.b 2, 0
.dcb.w 1, 16536
.dcb.b 2, 0
.dcb.w 1, 16544
.dcb.b 2, 0
.dcb.w 1, 16552
.dcb.b 2, 0
.dcb.w 1, 16560
.dcb.b 2, 0
.dcb.w 1, 16568
.dcb.b 2, 0
.dcb.w 1, 16576
.dcb.b 2, 0
.dcb.w 1, 18432
.dcb.b 2, 0
.dcb.w 1, 18440
.dcb.b 2, 0
.dcb.w 1, 18448
.dcb.b 2, 0
.dcb.w 1, 18456
.dcb.b 2, 0
.dcb.w 1, 18464
.dcb.b 2, 0
.dcb.w 1, 18472
.dcb.b 2, 0
.dcb.w 1, 18480
.dcb.b 2, 0
.dcb.w 1, 18488
.dcb.b 2, 0
.dcb.w 1, 18496
.dcb.b 2, 0
.dcb.w 1, 18504
.dcb.b 2, 0
.dcb.w 1, 18512
.dcb.b 2, 0
.dcb.w 1, 18520
.dcb.b 2, 0
.dcb.w 1, 18528
.dcb.b 2, 0
.dcb.w 1, 18536
.dcb.b 2, 0
.dcb.w 1, 18544
.dcb.b 2, 0
.dcb.w 1, 18552
.dcb.b 2, 0
.dcb.w 1, 18560
.dcb.b 2, 0
.dcb.w 1, 18568
.dcb.b 2, 0
.dcb.w 1, 18576
.dcb.b 2, 0
.dcb.w 1, 18584
.dcb.b 2, 0
.dcb.w 1, 18592
.dcb.b 2, 0
.dcb.w 1, 18600
.dcb.b 2, 0
.dcb.w 1, 18608
.dcb.b 2, 0
.dcb.w 1, 18616
.dcb.b 2, 0
.dcb.w 1, 18624
.dcb.b 2, 0
.dcb.w 1, 20480
.dcb.b 2, 0
.dcb.w 1, 20488
.dcb.b 2, 0
.dcb.w 1, 20496
.dcb.b 2, 0
.dcb.w 1, 20504
.dcb.b 2, 0
.dcb.w 1, 20512
.dcb.b 2, 0
.dcb.w 1, 20520
.dcb.b 2, 0
.dcb.w 1, 20528
.dcb.b 2, 0
.dcb.w 1, 20536
.dcb.b 2, 0
.dcb.w 1, 20544
.dcb.b 2, 0
.dcb.w 1, 20552
.dcb.b 2, 0
.dcb.w 1, 20560
.dcb.b 2, 0
.dcb.w 1, 20568
.dcb.b 2, 0
.dcb.w 1, 20576
.dcb.b 2, 0
.dcb.w 1, 20584
.dcb.b 2, 0
.dcb.w 1, 20592
.dcb.b 2, 0
.dcb.w 1, 20600
.dcb.b 2, 0
.dcb.w 1, 20608
.dcb.b 2, 0
.dcb.w 1, 20616
.dcb.b 2, 0
.dcb.w 1, 20624
.dcb.b 2, 0
.dcb.w 1, 20632
.dcb.b 2, 0
.dcb.w 1, 20640
.dcb.b 2, 0
.dcb.w 1, 20648
.dcb.b 2, 0
.dcb.w 1, 20656
.dcb.b 2, 0
.dcb.w 1, 20664
.dcb.b 2, 0
.dcb.w 1, 20672
.dcb.b 2, 0
.dcb.w 1, 22528
.dcb.b 2, 0
.dcb.w 1, 22536
.dcb.b 2, 0
.dcb.w 1, 22544
.dcb.b 2, 0
.dcb.w 1, 22552
.dcb.b 2, 0
.dcb.w 1, 22560
.dcb.b 2, 0
.dcb.w 1, 22568
.dcb.b 2, 0
.dcb.w 1, 22576
.dcb.b 2, 0
.dcb.w 1, 22584
.dcb.b 2, 0
.dcb.w 1, 22592
.dcb.b 2, 0
.dcb.w 1, 22600
.dcb.b 2, 0
.dcb.w 1, 22608
.dcb.b 2, 0
.dcb.w 1, 22616
.dcb.b 2, 0
.dcb.w 1, 22624
.dcb.b 2, 0
.dcb.w 1, 22632
.dcb.b 2, 0
.dcb.w 1, 22640
.dcb.b 2, 0
.dcb.w 1, 22648
.dcb.b 2, 0
.dcb.w 1, 22656
.dcb.b 2, 0
.dcb.w 1, 22664
.dcb.b 2, 0
.dcb.w 1, 22672
.dcb.b 2, 0
.dcb.w 1, 22680
.dcb.b 2, 0
.dcb.w 1, 22688
.dcb.b 2, 0
.dcb.w 1, 22696
.dcb.b 2, 0
.dcb.w 1, 22704
.dcb.b 2, 0
.dcb.w 1, 22712
.dcb.b 2, 0
.dcb.w 1, 22720
.dcb.b 2, 0
.dcb.w 1, 24576
.dcb.b 2, 0
.dcb.w 1, 24584
.dcb.b 2, 0
.dcb.w 1, 24592
.dcb.b 2, 0
.dcb.w 1, 24600
.dcb.b 2, 0
.dcb.w 1, 24608
.dcb.b 2, 0
.dcb.w 1, 24616
.dcb.b 2, 0
.dcb.w 1, 24624
.dcb.b 2, 0
.dcb.w 1, 24632
.dcb.b 2, 0
.dcb.w 1, 24640
.dcb.b 2, 0
.dcb.w 1, 24648
.dcb.b 2, 0
.dcb.w 1, 24656
.dcb.b 2, 0
.dcb.w 1, 24664
.dcb.b 2, 0
.dcb.w 1, 24672
.dcb.b 2, 0
.dcb.w 1, 24680
.dcb.b 2, 0
.dcb.w 1, 24688
.dcb.b 2, 0
.dcb.w 1, 24696
.dcb.b 2, 0
.dcb.w 1, 24704
.dcb.b 2, 0
.dcb.w 1, 24712
.dcb.b 2, 0
.dcb.w 1, 24720
.dcb.b 2, 0
.dcb.w 1, 24728
.dcb.b 2, 0
.dcb.w 1, 24736
.dcb.b 2, 0
.dcb.w 1, 24744
.dcb.b 2, 0
.dcb.w 1, 24752
.dcb.b 2, 0
.dcb.w 1, 24760
.dcb.b 2, 0
.dcb.w 1, 24768
.dcb.b 2, 0
.dcb.w 1, 26624
.dcb.b 2, 0
.dcb.w 1, 26632
.dcb.b 2, 0
.dcb.w 1, 26640
.dcb.b 2, 0
.dcb.w 1, 26648
.dcb.b 2, 0
.dcb.w 1, 26656
.dcb.b 2, 0
.dcb.w 1, 26664
.dcb.b 2, 0
.dcb.w 1, 26672
.dcb.b 2, 0
.dcb.w 1, 26680
.dcb.b 2, 0
.dcb.w 1, 26688
.dcb.b 2, 0
.dcb.w 1, 26696
.dcb.b 2, 0
.dcb.w 1, 26704
.dcb.b 2, 0
.dcb.w 1, 26712
.dcb.b 2, 0
.dcb.w 1, 26720
.dcb.b 2, 0
.dcb.w 1, 26728
.dcb.b 2, 0
.dcb.w 1, 26736
.dcb.b 2, 0
.dcb.w 1, 26744
.dcb.b 2, 0
.dcb.w 1, 26752
.dcb.b 2, 0
.dcb.w 1, 26760
.dcb.b 2, 0
.dcb.w 1, 26768
.dcb.b 2, 0
.dcb.w 1, 26776
.dcb.b 2, 0
.dcb.w 1, 26784
.dcb.b 2, 0
.dcb.w 1, 26792
.dcb.b 2, 0
.dcb.w 1, 26800
.dcb.b 2, 0
.dcb.w 1, 26808
.dcb.b 2, 0
.dcb.w 1, 26816
.dcb.b 2, 0
.dcb.w 1, 28672
.dcb.b 2, 0
.dcb.w 1, 28680
.dcb.b 2, 0
.dcb.w 1, 28688
.dcb.b 2, 0
.dcb.w 1, 28696
.dcb.b 2, 0
.dcb.w 1, 28704
.dcb.b 2, 0
.dcb.w 1, 28712
.dcb.b 2, 0
.dcb.w 1, 28720
.dcb.b 2, 0
.dcb.w 1, 28728
.dcb.b 2, 0
.dcb.w 1, 28736
.dcb.b 2, 0
.dcb.w 1, 28744
.dcb.b 2, 0
.dcb.w 1, 28752
.dcb.b 2, 0
.dcb.w 1, 28760
.dcb.b 2, 0
.dcb.w 1, 28768
.dcb.b 2, 0
.dcb.w 1, 28776
.dcb.b 2, 0
.dcb.w 1, 28784
.dcb.b 2, 0
.dcb.w 1, 28792
.dcb.b 2, 0
.dcb.w 1, 28800
.dcb.b 2, 0
.dcb.w 1, 28808
.dcb.b 2, 0
.dcb.w 1, 28816
.dcb.b 2, 0
.dcb.w 1, 28824
.dcb.b 2, 0
.dcb.w 1, 28832
.dcb.b 2, 0
.dcb.w 1, 28840
.dcb.b 2, 0
.dcb.w 1, 28848
.dcb.b 2, 0
.dcb.w 1, 28856
.dcb.b 2, 0
.dcb.w 1, 28864
.dcb.b 2, 0
.dcb.w 1, 30720
.dcb.b 2, 0
.dcb.w 1, 30728
.dcb.b 2, 0
.dcb.w 1, 30736
.dcb.b 2, 0
.dcb.w 1, 30744
.dcb.b 2, 0
.dcb.w 1, 30752
.dcb.b 2, 0
.dcb.w 1, 30760
.dcb.b 2, 0
.dcb.w 1, 30768
.dcb.b 2, 0
.dcb.w 1, 30776
.dcb.b 2, 0
.dcb.w 1, 30784
.dcb.b 2, 0
.dcb.w 1, 30792
.dcb.b 2, 0
.dcb.w 1, 30800
.dcb.b 2, 0
.dcb.w 1, 30808
.dcb.b 2, 0
.dcb.w 1, 30816
.dcb.b 2, 0
.dcb.w 1, 30824
.dcb.b 2, 0
.dcb.w 1, 30832
.dcb.b 2, 0
.dcb.w 1, 30840
.dcb.b 2, 0
.dcb.w 1, 30848
.dcb.b 2, 0
.dcb.w 1, 30856
.dcb.b 2, 0
.dcb.w 1, 30864
.dcb.b 2, 0
.dcb.w 1, 30872
.dcb.b 2, 0
.dcb.w 1, 30880
.dcb.b 2, 0
.dcb.w 1, 30888
.dcb.b 2, 0
.dcb.w 1, 30896
.dcb.b 2, 0
.dcb.w 1, 30904
.dcb.b 2, 0
.dcb.w 1, 30912
.dcb.b 2, 0
.dcb.w 1, 32768
.dcb.b 2, 0
.dcb.w 1, 32776
.dcb.b 2, 0
.dcb.w 1, 32784
.dcb.b 2, 0
.dcb.w 1, 32792
.dcb.b 2, 0
.dcb.w 1, 32800
.dcb.b 2, 0
.dcb.w 1, 32808
.dcb.b 2, 0
.dcb.w 1, 32816
.dcb.b 2, 0
.dcb.w 1, 32824
.dcb.b 2, 0
.dcb.w 1, 32832
.dcb.b 2, 0
.dcb.w 1, 32840
.dcb.b 2, 0
.dcb.w 1, 32848
.dcb.b 2, 0
.dcb.w 1, 32856
.dcb.b 2, 0
.dcb.w 1, 32864
.dcb.b 2, 0
.dcb.w 1, 32872
.dcb.b 2, 0
.dcb.w 1, 32880
.dcb.b 2, 0
.dcb.w 1, 32888
.dcb.b 2, 0
.dcb.w 1, 32896
.dcb.b 2, 0
.dcb.w 1, 32904
.dcb.b 2, 0
.dcb.w 1, 32912
.dcb.b 2, 0
.dcb.w 1, 32920
.dcb.b 2, 0
.dcb.w 1, 32928
.dcb.b 2, 0
.dcb.w 1, 32936
.dcb.b 2, 0
.dcb.w 1, 32944
.dcb.b 2, 0
.dcb.w 1, 32952
.dcb.b 2, 0
.dcb.w 1, 32960
.dcb.b 2, 0
.dcb.w 1, 34816
.dcb.b 2, 0
.dcb.w 1, 34824
.dcb.b 2, 0
.dcb.w 1, 34832
.dcb.b 2, 0
.dcb.w 1, 34840
.dcb.b 2, 0
.dcb.w 1, 34848
.dcb.b 2, 0
.dcb.w 1, 34856
.dcb.b 2, 0
.dcb.w 1, 34864
.dcb.b 2, 0
.dcb.w 1, 34872
.dcb.b 2, 0
.dcb.w 1, 34880
.dcb.b 2, 0
.dcb.w 1, 34888
.dcb.b 2, 0
.dcb.w 1, 34896
.dcb.b 2, 0
.dcb.w 1, 34904
.dcb.b 2, 0
.dcb.w 1, 34912
.dcb.b 2, 0
.dcb.w 1, 34920
.dcb.b 2, 0
.dcb.w 1, 34928
.dcb.b 2, 0
.dcb.w 1, 34936
.dcb.b 2, 0
.dcb.w 1, 34944
.dcb.b 2, 0
.dcb.w 1, 34952
.dcb.b 2, 0
.dcb.w 1, 34960
.dcb.b 2, 0
.dcb.w 1, 34968
.dcb.b 2, 0
.dcb.w 1, 34976
.dcb.b 2, 0
.dcb.w 1, 34984
.dcb.b 2, 0
.dcb.w 1, 34992
.dcb.b 2, 0
.dcb.w 1, 35000
.dcb.b 2, 0
.dcb.w 1, 35008
.dcb.b 2, 0
.dcb.w 1, 36864
.dcb.b 2, 0
.dcb.w 1, 36872
.dcb.b 2, 0
.dcb.w 1, 36880
.dcb.b 2, 0
.dcb.w 1, 36888
.dcb.b 2, 0
.dcb.w 1, 36896
.dcb.b 2, 0
.dcb.w 1, 36904
.dcb.b 2, 0
.dcb.w 1, 36912
.dcb.b 2, 0
.dcb.w 1, 36920
.dcb.b 2, 0
.dcb.w 1, 36928
.dcb.b 2, 0
.dcb.w 1, 36936
.dcb.b 2, 0
.dcb.w 1, 36944
.dcb.b 2, 0
.dcb.w 1, 36952
.dcb.b 2, 0
.dcb.w 1, 36960
.dcb.b 2, 0
.dcb.w 1, 36968
.dcb.b 2, 0
.dcb.w 1, 36976
.dcb.b 2, 0
.dcb.w 1, 36984
.dcb.b 2, 0
.dcb.w 1, 36992
.dcb.b 2, 0
.dcb.w 1, 37000
.dcb.b 2, 0
.dcb.w 1, 37008
.dcb.b 2, 0
.dcb.w 1, 37016
.dcb.b 2, 0
.dcb.w 1, 37024
.dcb.b 2, 0
.dcb.w 1, 37032
.dcb.b 2, 0
.dcb.w 1, 37040
.dcb.b 2, 0
.dcb.w 1, 37048
.dcb.b 2, 0
.dcb.w 1, 37056
.dcb.b 2, 0

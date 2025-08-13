; vim: ft=z80 tabstop=4 shiftwidth=4:
SPRITE_ENTRY_SIZE = 4
SPRITE_ENTRIES_NUM = 64
SPRITE_TABLE_ADDR = (8 * 1024)
TILE_TABLE_ADDR = (SPRITE_TABLE_ADDR + SPRITE_ENTRIES_NUM * SPRITE_ENTRY_SIZE)
TILES_NUM_Y = 19
TILES_NUM_X = 25
SPRITE_DEFS_ADDR  = (16 * 1024)
PIXEL_MAP_ADDR = (32 * 1024)
SPRITE_DEF_NUM = 255
SPRITE_DEF_PIXELS_X = 8
SPRITE_DEF_PIXELS_Y = 8
SPRITE_DEF_PIXELS_NUM = (SPRITE_DEF_PIXELS_X * SPRITE_DEF_PIXELS_Y)
SPRITE_DEF_SIZE = (SPRITE_DEF_PIXELS_NUM)
SPRITE_DEF_MEM_SIZE = (SPRITE_DEF_SIZE * SPRITE_DEF_NUM)
ANIMATION_DEFS_ADDR = (SPRITE_DEFS_ADDR + SPRITE_DEF_MEM_SIZE)
TILE_TABLE_ADDR = (SPRITE_TABLE_ADDR + (SPRITE_ENTRY_SIZE * SPRITE_ENTRIES_NUM))
PPU_REGS_ADDR = (TILE_TABLE_ADDR + (SPRITE_ENTRIES_NUM * SPRITE_ENTRY_SIZE))
PPU_CPU_INT_PORT = 0

.extern _stack_end

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

.macro RENDERSPRITE
    ; Proceed to next sprite entry. Index ix with negative offsets for this sprite.
    ; This is done unconditionally at the start so that we can jump past this sprite with the address already added to.
    ld bc, SPRITE_ENTRY_SIZE
    add ix, bc
    ; Don't render anything if the high address byte is zero
    ld b, (ix-1)
    dec b
    jp m, 1f

    ; Get y * 200 from the lookup table and add it to x to get the full VRAM address
    ld l, (ix-3) ; l now has the y coord
    ld h, 0
    add hl, hl ; Double y since each entry in the lookup table takes two bytes
    ld de, y_pixel_lookup
    add hl, de ; hl is the lookup address
    ld c, (hl)
    inc hl
    ld h, (hl)
    ld l, c ; hl is the y VRAM offset
    ld b, 0
    ld c, (ix-4)
    add hl, bc ; Add it to the x coord
    ex de, hl ; Put the full VRAM address in de

    ld l, (ix-2)
    ld h, (ix-1) ; hl now has the sprite def addr
    ; Copy 64 bytes from hl (sprite def addr) to de (pixel map addr) in 8 byte chunks
    .rept SPRITE_DEF_PIXELS_Y
        .rept SPRITE_DEF_PIXELS_X
            ldi
        .endr
        ; Move VRAM address to the next row
        ld iy, 192
        add iy, de
        ld d, iyh
        ld e, iyl
    .endr
    ; Jump here if this sprite shouldn't be rendered
    1:
.endm

render:
    ; Render background tiles
    ld ix, TILE_TABLE_ADDR
    ld hl, PIXEL_MAP_ADDR
    .rept TILES_NUM_Y
        ld a, TILES_NUM_X
        1:
            ; Render this tile
            ld e, (ix)
            ld d, (ix+1) ; de has the sprite def address
            inc ix
            inc ix
            .rept SPRITE_DEF_PIXELS_Y
                ; the vram address is held in hl because of its compatibility with ADD and SBC, but it's needed in de for LDI
                ex de, hl
                .rept SPRITE_DEF_PIXELS_X
                    ldi
                .endr
                ex de, hl
                ; Move vram address to the next line
                ld bc, 192
                add hl, bc
            .endr
            dec a
            jp z, 2f
            ; Move to the next tile's start address
            ld bc, 1592
            or a
            sbc hl, bc
            jp 1b
        2:
            ld bc, 192
            or a
            sbc hl, bc
    .endr

    ld ix, SPRITE_TABLE_ADDR
    ld a, 8
    ; A loop is needed since ROM can't hold the full unrolled render loop
.render_batch:
    .rept SPRITE_ENTRIES_NUM / 8
        RENDERSPRITE
    .endr
    dec a
    jp nz, .render_batch
    nop
    ; Interrupt CPU to tell it to update graphics data.
    ; We could use an immediate for the port with the OUT instruction, but that would mean reloading a between the two OUTs
    ; and I want to leave the interrupt line high for as few cycles as possible.
    ld b, 1
    ld c, PPU_CPU_INT_PORT
    out (c), b
    out (c), 0
    ; Wait for the next display period
    halt
    ; When the next blanking period starts, the interrupt handler will jump here
    jp render

; The y coordinate mapped to a VRAM address for that row
; Should be added to the x coordinate to form a full VRAM address
y_pixel_lookup:
.dcb.w 1, 32768
.dcb.w 1, 32968
.dcb.w 1, 33168
.dcb.w 1, 33368
.dcb.w 1, 33568
.dcb.w 1, 33768
.dcb.w 1, 33968
.dcb.w 1, 34168
.dcb.w 1, 34368
.dcb.w 1, 34568
.dcb.w 1, 34768
.dcb.w 1, 34968
.dcb.w 1, 35168
.dcb.w 1, 35368
.dcb.w 1, 35568
.dcb.w 1, 35768
.dcb.w 1, 35968
.dcb.w 1, 36168
.dcb.w 1, 36368
.dcb.w 1, 36568
.dcb.w 1, 36768
.dcb.w 1, 36968
.dcb.w 1, 37168
.dcb.w 1, 37368
.dcb.w 1, 37568
.dcb.w 1, 37768
.dcb.w 1, 37968
.dcb.w 1, 38168
.dcb.w 1, 38368
.dcb.w 1, 38568
.dcb.w 1, 38768
.dcb.w 1, 38968
.dcb.w 1, 39168
.dcb.w 1, 39368
.dcb.w 1, 39568
.dcb.w 1, 39768
.dcb.w 1, 39968
.dcb.w 1, 40168
.dcb.w 1, 40368
.dcb.w 1, 40568
.dcb.w 1, 40768
.dcb.w 1, 40968
.dcb.w 1, 41168
.dcb.w 1, 41368
.dcb.w 1, 41568
.dcb.w 1, 41768
.dcb.w 1, 41968
.dcb.w 1, 42168
.dcb.w 1, 42368
.dcb.w 1, 42568
.dcb.w 1, 42768
.dcb.w 1, 42968
.dcb.w 1, 43168
.dcb.w 1, 43368
.dcb.w 1, 43568
.dcb.w 1, 43768
.dcb.w 1, 43968
.dcb.w 1, 44168
.dcb.w 1, 44368
.dcb.w 1, 44568
.dcb.w 1, 44768
.dcb.w 1, 44968
.dcb.w 1, 45168
.dcb.w 1, 45368
.dcb.w 1, 45568
.dcb.w 1, 45768
.dcb.w 1, 45968
.dcb.w 1, 46168
.dcb.w 1, 46368
.dcb.w 1, 46568
.dcb.w 1, 46768
.dcb.w 1, 46968
.dcb.w 1, 47168
.dcb.w 1, 47368
.dcb.w 1, 47568
.dcb.w 1, 47768
.dcb.w 1, 47968
.dcb.w 1, 48168
.dcb.w 1, 48368
.dcb.w 1, 48568
.dcb.w 1, 48768
.dcb.w 1, 48968
.dcb.w 1, 49168
.dcb.w 1, 49368
.dcb.w 1, 49568
.dcb.w 1, 49768
.dcb.w 1, 49968
.dcb.w 1, 50168
.dcb.w 1, 50368
.dcb.w 1, 50568
.dcb.w 1, 50768
.dcb.w 1, 50968
.dcb.w 1, 51168
.dcb.w 1, 51368
.dcb.w 1, 51568
.dcb.w 1, 51768
.dcb.w 1, 51968
.dcb.w 1, 52168
.dcb.w 1, 52368
.dcb.w 1, 52568
.dcb.w 1, 52768
.dcb.w 1, 52968
.dcb.w 1, 53168
.dcb.w 1, 53368
.dcb.w 1, 53568
.dcb.w 1, 53768
.dcb.w 1, 53968
.dcb.w 1, 54168
.dcb.w 1, 54368
.dcb.w 1, 54568
.dcb.w 1, 54768
.dcb.w 1, 54968
.dcb.w 1, 55168
.dcb.w 1, 55368
.dcb.w 1, 55568
.dcb.w 1, 55768
.dcb.w 1, 55968
.dcb.w 1, 56168
.dcb.w 1, 56368
.dcb.w 1, 56568
.dcb.w 1, 56768
.dcb.w 1, 56968
.dcb.w 1, 57168
.dcb.w 1, 57368
.dcb.w 1, 57568
.dcb.w 1, 57768
.dcb.w 1, 57968
.dcb.w 1, 58168
.dcb.w 1, 58368
.dcb.w 1, 58568
.dcb.w 1, 58768
.dcb.w 1, 58968
.dcb.w 1, 59168
.dcb.w 1, 59368
.dcb.w 1, 59568
.dcb.w 1, 59768
.dcb.w 1, 59968
.dcb.w 1, 60168
.dcb.w 1, 60368
.dcb.w 1, 60568
.dcb.w 1, 60768
.dcb.w 1, 60968
.dcb.w 1, 61168
.dcb.w 1, 61368
.dcb.w 1, 61568
.dcb.w 1, 61768
.dcb.w 1, 61968
.dcb.w 1, 62168
.dcb.w 1, 62368
.dcb.w 1, 62568
.dcb.w 1, 62768
.dcb.w 1, 62968

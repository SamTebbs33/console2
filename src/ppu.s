; vim: ft=z80 tabstop=4 shiftwidth=4:
SPRITE_TABLE_ADDR = (8 * 1024)
SPRITE_DEFS_ADDR  = (16 * 1024)
PIXEL_MAP_ADDR = (32 * 1024)
SPRITE_DEF_NUM = 255
SPRITE_DEF_PIXELS_X = 8
SPRITE_DEF_PIXELS_Y = 8
SPRITE_DEF_PIXELS_NUM = (SPRITE_DEF_PIXELS_X * SPRITE_DEF_PIXELS_Y)
SPRITE_DEF_SIZE = (SPRITE_DEF_PIXELS_NUM)
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
    ld b, (ix) ; b now has the full x coord
    inc ix
    ld c, (ix) ; c now has the full y coord
    inc ix ; ix is now at the sprite address
    ld l, (ix)
    inc ix
    ld h, (ix) ; hl now has the sprite def addr
    inc ix ; ix is now at the next sprite entry
    ; hl has sprite def addr
    ; b has x coord
    ; c has y coord
    ; Find the pixel map offset corresponding to y and add it to iy. y must be multiplied by two since each entry in the lookup table takes two bytes
    ld iy, y_pixel_lookup
    ld d, 0
    ld e, c
    sla e
    rl d
    add iy, de
    ld e, (iy)
    ld d, (iy + 1) ; de how has the y pixel map offset
    ; Find the pixel map offset corresponding to x and add it to iy. x must be multiplied by two since each entry in the lookup table takes two bytes
    ld iy, x_pixel_lookup
    ld c, b
    ld b, 0
    sla c
    rl b
    add iy, bc
    ld c, (iy)
    ld b, (iy + 1) ; de how has the x pixel map offset
    ld iyl, c
    ld iyh, b
    add iy, de ; iy now has the full starting pixel map address for this sprite
    ld d, iyh
    ld e, iyl
    ; Copy 64 bytes from hl (sprite def addr) to de (pixel map addr)
    ld bc, SPRITE_DEF_PIXELS_X * SPRITE_DEF_PIXELS_Y
    ldir
.endm

render:
    ld ix, SPRITE_TABLE_ADDR
    ld a, SPRITE_ENTRIES_NUM_Y
.render_batch:
    .rept SPRITE_ENTRIES_NUM_X
    RENDERSPRITE
    .endr
    dec a
    jp nz, .render_batch
    ; Wait for the next display period
    nop
    halt
    ; When the next blanking period starts, the interrupt handler will jump here
    jp render

; The x coordinate mapped to a VRAM address for that column.
; Should be added to the mapped VRAM address from the y coordinate.
x_pixel_lookup:
.dcb.w 1, 32768
.dcb.w 1, 32769
.dcb.w 1, 32770
.dcb.w 1, 32771
.dcb.w 1, 32772
.dcb.w 1, 32773
.dcb.w 1, 32774
.dcb.w 1, 32775
.dcb.w 1, 32832
.dcb.w 1, 32833
.dcb.w 1, 32834
.dcb.w 1, 32835
.dcb.w 1, 32836
.dcb.w 1, 32837
.dcb.w 1, 32838
.dcb.w 1, 32839
.dcb.w 1, 32896
.dcb.w 1, 32897
.dcb.w 1, 32898
.dcb.w 1, 32899
.dcb.w 1, 32900
.dcb.w 1, 32901
.dcb.w 1, 32902
.dcb.w 1, 32903
.dcb.w 1, 32960
.dcb.w 1, 32961
.dcb.w 1, 32962
.dcb.w 1, 32963
.dcb.w 1, 32964
.dcb.w 1, 32965
.dcb.w 1, 32966
.dcb.w 1, 32967
.dcb.w 1, 33024
.dcb.w 1, 33025
.dcb.w 1, 33026
.dcb.w 1, 33027
.dcb.w 1, 33028
.dcb.w 1, 33029
.dcb.w 1, 33030
.dcb.w 1, 33031
.dcb.w 1, 33088
.dcb.w 1, 33089
.dcb.w 1, 33090
.dcb.w 1, 33091
.dcb.w 1, 33092
.dcb.w 1, 33093
.dcb.w 1, 33094
.dcb.w 1, 33095
.dcb.w 1, 33152
.dcb.w 1, 33153
.dcb.w 1, 33154
.dcb.w 1, 33155
.dcb.w 1, 33156
.dcb.w 1, 33157
.dcb.w 1, 33158
.dcb.w 1, 33159
.dcb.w 1, 33216
.dcb.w 1, 33217
.dcb.w 1, 33218
.dcb.w 1, 33219
.dcb.w 1, 33220
.dcb.w 1, 33221
.dcb.w 1, 33222
.dcb.w 1, 33223
.dcb.w 1, 33280
.dcb.w 1, 33281
.dcb.w 1, 33282
.dcb.w 1, 33283
.dcb.w 1, 33284
.dcb.w 1, 33285
.dcb.w 1, 33286
.dcb.w 1, 33287
.dcb.w 1, 33344
.dcb.w 1, 33345
.dcb.w 1, 33346
.dcb.w 1, 33347
.dcb.w 1, 33348
.dcb.w 1, 33349
.dcb.w 1, 33350
.dcb.w 1, 33351
.dcb.w 1, 33408
.dcb.w 1, 33409
.dcb.w 1, 33410
.dcb.w 1, 33411
.dcb.w 1, 33412
.dcb.w 1, 33413
.dcb.w 1, 33414
.dcb.w 1, 33415
.dcb.w 1, 33472
.dcb.w 1, 33473
.dcb.w 1, 33474
.dcb.w 1, 33475
.dcb.w 1, 33476
.dcb.w 1, 33477
.dcb.w 1, 33478
.dcb.w 1, 33479
.dcb.w 1, 33536
.dcb.w 1, 33537
.dcb.w 1, 33538
.dcb.w 1, 33539
.dcb.w 1, 33540
.dcb.w 1, 33541
.dcb.w 1, 33542
.dcb.w 1, 33543
.dcb.w 1, 33600
.dcb.w 1, 33601
.dcb.w 1, 33602
.dcb.w 1, 33603
.dcb.w 1, 33604
.dcb.w 1, 33605
.dcb.w 1, 33606
.dcb.w 1, 33607
.dcb.w 1, 33664
.dcb.w 1, 33665
.dcb.w 1, 33666
.dcb.w 1, 33667
.dcb.w 1, 33668
.dcb.w 1, 33669
.dcb.w 1, 33670
.dcb.w 1, 33671
.dcb.w 1, 33728
.dcb.w 1, 33729
.dcb.w 1, 33730
.dcb.w 1, 33731
.dcb.w 1, 33732
.dcb.w 1, 33733
.dcb.w 1, 33734
.dcb.w 1, 33735
.dcb.w 1, 33792
.dcb.w 1, 33793
.dcb.w 1, 33794
.dcb.w 1, 33795
.dcb.w 1, 33796
.dcb.w 1, 33797
.dcb.w 1, 33798
.dcb.w 1, 33799
.dcb.w 1, 33856
.dcb.w 1, 33857
.dcb.w 1, 33858
.dcb.w 1, 33859
.dcb.w 1, 33860
.dcb.w 1, 33861
.dcb.w 1, 33862
.dcb.w 1, 33863
.dcb.w 1, 33920
.dcb.w 1, 33921
.dcb.w 1, 33922
.dcb.w 1, 33923
.dcb.w 1, 33924
.dcb.w 1, 33925
.dcb.w 1, 33926
.dcb.w 1, 33927
.dcb.w 1, 33984
.dcb.w 1, 33985
.dcb.w 1, 33986
.dcb.w 1, 33987
.dcb.w 1, 33988
.dcb.w 1, 33989
.dcb.w 1, 33990
.dcb.w 1, 33991
.dcb.w 1, 34048
.dcb.w 1, 34049
.dcb.w 1, 34050
.dcb.w 1, 34051
.dcb.w 1, 34052
.dcb.w 1, 34053
.dcb.w 1, 34054
.dcb.w 1, 34055
.dcb.w 1, 34112
.dcb.w 1, 34113
.dcb.w 1, 34114
.dcb.w 1, 34115
.dcb.w 1, 34116
.dcb.w 1, 34117
.dcb.w 1, 34118
.dcb.w 1, 34119
.dcb.w 1, 34176
.dcb.w 1, 34177
.dcb.w 1, 34178
.dcb.w 1, 34179
.dcb.w 1, 34180
.dcb.w 1, 34181
.dcb.w 1, 34182
.dcb.w 1, 34183
.dcb.w 1, 34240
.dcb.w 1, 34241
.dcb.w 1, 34242
.dcb.w 1, 34243
.dcb.w 1, 34244
.dcb.w 1, 34245
.dcb.w 1, 34246
.dcb.w 1, 34247
.dcb.w 1, 34304
.dcb.w 1, 34305
.dcb.w 1, 34306
.dcb.w 1, 34307
.dcb.w 1, 34308
.dcb.w 1, 34309
.dcb.w 1, 34310
.dcb.w 1, 34311

y_pixel_lookup:
.dcb.w 1, 0
.dcb.w 1, 8
.dcb.w 1, 16
.dcb.w 1, 24
.dcb.w 1, 32
.dcb.w 1, 40
.dcb.w 1, 48
.dcb.w 1, 56
.dcb.w 1, 1600
.dcb.w 1, 1608
.dcb.w 1, 1616
.dcb.w 1, 1624
.dcb.w 1, 1632
.dcb.w 1, 1640
.dcb.w 1, 1648
.dcb.w 1, 1656
.dcb.w 1, 3200
.dcb.w 1, 3208
.dcb.w 1, 3216
.dcb.w 1, 3224
.dcb.w 1, 3232
.dcb.w 1, 3240
.dcb.w 1, 3248
.dcb.w 1, 3256
.dcb.w 1, 4800
.dcb.w 1, 4808
.dcb.w 1, 4816
.dcb.w 1, 4824
.dcb.w 1, 4832
.dcb.w 1, 4840
.dcb.w 1, 4848
.dcb.w 1, 4856
.dcb.w 1, 6400
.dcb.w 1, 6408
.dcb.w 1, 6416
.dcb.w 1, 6424
.dcb.w 1, 6432
.dcb.w 1, 6440
.dcb.w 1, 6448
.dcb.w 1, 6456
.dcb.w 1, 8000
.dcb.w 1, 8008
.dcb.w 1, 8016
.dcb.w 1, 8024
.dcb.w 1, 8032
.dcb.w 1, 8040
.dcb.w 1, 8048
.dcb.w 1, 8056
.dcb.w 1, 9600
.dcb.w 1, 9608
.dcb.w 1, 9616
.dcb.w 1, 9624
.dcb.w 1, 9632
.dcb.w 1, 9640
.dcb.w 1, 9648
.dcb.w 1, 9656
.dcb.w 1, 11200
.dcb.w 1, 11208
.dcb.w 1, 11216
.dcb.w 1, 11224
.dcb.w 1, 11232
.dcb.w 1, 11240
.dcb.w 1, 11248
.dcb.w 1, 11256
.dcb.w 1, 12800
.dcb.w 1, 12808
.dcb.w 1, 12816
.dcb.w 1, 12824
.dcb.w 1, 12832
.dcb.w 1, 12840
.dcb.w 1, 12848
.dcb.w 1, 12856
.dcb.w 1, 14400
.dcb.w 1, 14408
.dcb.w 1, 14416
.dcb.w 1, 14424
.dcb.w 1, 14432
.dcb.w 1, 14440
.dcb.w 1, 14448
.dcb.w 1, 14456
.dcb.w 1, 16000
.dcb.w 1, 16008
.dcb.w 1, 16016
.dcb.w 1, 16024
.dcb.w 1, 16032
.dcb.w 1, 16040
.dcb.w 1, 16048
.dcb.w 1, 16056
.dcb.w 1, 17600
.dcb.w 1, 17608
.dcb.w 1, 17616
.dcb.w 1, 17624
.dcb.w 1, 17632
.dcb.w 1, 17640
.dcb.w 1, 17648
.dcb.w 1, 17656
.dcb.w 1, 19200
.dcb.w 1, 19208
.dcb.w 1, 19216
.dcb.w 1, 19224
.dcb.w 1, 19232
.dcb.w 1, 19240
.dcb.w 1, 19248
.dcb.w 1, 19256
.dcb.w 1, 20800
.dcb.w 1, 20808
.dcb.w 1, 20816
.dcb.w 1, 20824
.dcb.w 1, 20832
.dcb.w 1, 20840
.dcb.w 1, 20848
.dcb.w 1, 20856
.dcb.w 1, 22400
.dcb.w 1, 22408
.dcb.w 1, 22416
.dcb.w 1, 22424
.dcb.w 1, 22432
.dcb.w 1, 22440
.dcb.w 1, 22448
.dcb.w 1, 22456
.dcb.w 1, 24000
.dcb.w 1, 24008
.dcb.w 1, 24016
.dcb.w 1, 24024
.dcb.w 1, 24032
.dcb.w 1, 24040
.dcb.w 1, 24048
.dcb.w 1, 24056
.dcb.w 1, 25600
.dcb.w 1, 25608
.dcb.w 1, 25616
.dcb.w 1, 25624
.dcb.w 1, 25632
.dcb.w 1, 25640
.dcb.w 1, 25648
.dcb.w 1, 25656
.dcb.w 1, 27200
.dcb.w 1, 27208
.dcb.w 1, 27216
.dcb.w 1, 27224
.dcb.w 1, 27232
.dcb.w 1, 27240
.dcb.w 1, 27248
.dcb.w 1, 27256
.dcb.w 1, 28800
.dcb.w 1, 28808
.dcb.w 1, 28816
.dcb.w 1, 28824
.dcb.w 1, 28832
.dcb.w 1, 28840

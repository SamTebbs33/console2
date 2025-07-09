.global __sshl
; HL <<= C (logical shift left)
; Inputs: HL = value, C = shift amount (0–255)
; Output: HL = result
__sshl:
    ld A, C
    or A
    ret z            ; if shift == 0, return HL as is

.shift_loop:
    sla L            ; shift LSB
    rl H             ; shift MSB with carry
    dec A
    jp nz, .shift_loop
    ret

.global __sshru
; HL >>= C (logical, fills with 0s)
; Inputs: HL = value, C = shift amount
; Output: HL = result
__sshru:
    ld A, C
    or A
    ret z

.srl_loop:
    srl H            ; shift MSB right
    rr  L            ; shift LSB with carry from H
    dec A
    jp nz, .srl_loop
    ret


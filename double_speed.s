.include "shell.inc"
; Find rDIV and cycle offset.
; Returns rDiv in b and cycle offset in c.
; Cycle offset will be 40 cycles after the first
; instruction starts. Since call takes 24 cycles,
; this is 64 cycles after the call instruction starts.

; Total cycle count:
; 32 + (65 * 260 - 4) + 20 + 40 = 16988
; (17012 including the call instruction).
GetCycle:
    push af ; 16
    push de ; 16

    ; First read
    ldh a, ($04) ; 12
    ld b, a ; 4
    ld d, a ; 4

    ; Stall for 240 more cycles
    ld e, 64 ; 8
    ld a, 14 ; 8
div_stall:
    dec a            ; 4
    jr nz, div_stall ; 12/8
    ; Stalled for 16 + 14 * 16 - 4 = 236 cycles.
    nop ; 4 more for 240.
div_loop:
    ldh a, ($04) ; 12
    sub d ; 4
    dec a ; 4
    jr nz, div_store ; 12/8
div_nostore:
    jr div_loopstall ; 12
div_store:
    ; This path has 4 more cycles from the jr nz, so
    ; we take 4 cycles less so that both total 20 cycles.
    ld c, e ; 4
    nop     ; 4
div_loopstall:
    ; Update d with new rDiv
    inc a ; 4
    add d ; 4
    ld d, a ; 4
    ; 52 cycles have passed out of 260
    ; Assuming we'll loop again, 16 more cycles will be spent from dec, jr nz.
    ; So we stall for 192 cycles.
    ld a, 11 ; 8
div_loopstallloop:
    dec a   ; 4
    jr nz, div_loopstallloop ; 12 / 8
    ; Stalled for 8 + 16 * 11 - 4 = 180 cycles, need 12 more.
    nop ; 4
    nop ; 4
    nop ; 4
    ; Loop again
    dec e ; 4
    jr nz, div_loop ; 12/8

    ; This would be the time for the 65th read after the initial read, except that
    ; we've spent 4 cycles less because of not taking the jump at the end.
    ; So this instruction is 65 * 260 - 4 = 16896 cycles after the first ldh
    ; instruction.

    ; Adjust cycle offset to be real (and on 0-256 scale).
    ; If c is 64 then we hit 252 (i.e. 63) on the first load.
    ; So we subtract 1 then multiply by 4.
    dec c       ; 4
    sla c       ; 8
    sla c       ; 8

    pop de ; 12
    pop af ; 12
    ret    ; 16

main:
    ; Disable interrupts just to be safe
    di              ; 4
    nop             ; 4
    ; Reset rDiv
    xor a           ; 4
    ldh ($04), a    ; 12
    ; DIV resets 4 cycles before end of instruction
    ; GetCycle takes 64 cycles before the read, so
    ; we expect to see 0 / 68 in the return values
    ; (hex: 00 44)
    ; Start test
    call GetCycle   ; 17012
    push bc         ; 16

    ; Switch to double speed mode
    ldh a, ($FF)    ; 12 FFFF = IE
    push af         ; 16
    xor a           ; 4
    ldh ($FF), a    ; 12 FFFF = IE
    ldh ($0F), a    ; 12 FF0F = IF
    ld a, $30       ; 8
    ldh ($00), a    ; 12 FF00 = P1
    ld a, $1        ; 8
    ldh ($4D), a    ; 12 FF4D = KEY1
    stop            ; ???
    nop             ; 4
    pop af          ; 12
    ldh ($FF), a    ; 12 FFFF = IE

    call GetCycle   ; 17012
    push bc         ; 16

    ; Switch back to normal speed
    ldh a, ($FF)    ; 12 FFFF = IE
    push af         ; 16
    xor a           ; 4
    ldh ($FF), a    ; 12 FFFF = IE
    ldh ($0F), a    ; 12 FF0F = IF
    ld a, $30       ; 8
    ldh ($00), a    ; 12 FF00 = P1
    ld a, $1        ; 8
    ldh ($4D), a    ; 12 FF4D = KEY1
    stop            ; ???
    nop             ; 4
    pop af          ; 12
    ldh ($FF), a    ; 12 FFFF = IE

    call GetCycle   ; 17012
    push bc         ; 16

    pop hl
    pop de
    pop bc
    ld a, b
    call print_a
    ld a, c
    call print_a
    print_str newline
    ld a, d
    call print_a
    ld a, e
    call print_a
    print_str newline
    ld a, h
    call print_a
    ld a, l
    call print_a
    jp tests_passed

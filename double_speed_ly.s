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
    ; Find LY and subLY
    ; We'll treat subLY on a 456/2 = 228
    ; step scale, since video processing does not
    ; double speed in double speed mode.

    ; We want to read LY spaced 460 video cycles apart.
    ; In normal speed, machine cycles are 4 video cycles
    ; so video cycles act like clock cycles.
    ldh a, ($44)    ; 12
    ld b, a         ; 4
    ld d, a         ; 4
    ; 20 cycles have passed here, need to stall for 440 more.
    ld e, 114       ; 8
    ld a, 26        ; 8
stall:
    dec a           ; 4
    jr nz, stall    ; 12/8
    ; Stalled for 16 + 26 * 16 - 4 = 428 cycles, need 12 more.
    nop             ; 4
    nop             ; 4
    nop             ; 4
loop:
    ldh a, ($44)    ; 12
    sub d           ; 4
    jr nc, nocarry  ; 12/8
carry:
    add 154         ; 8
    jr check        ; 12
nocarry:
    ; Stall for 16 cycles to match carry branch (we've already used 4 extra cycles
    ; in the jr)
    nop             ; 4
    nop             ; 4
    nop             ; 4
    nop             ; 4
check:
    dec a           ; 4
    jr nz, store    ; 12/8
nostore:
    jr loopstall    ; 12
store:
    ld c, e         ; 4
    nop             ; 4
loopstall:
    ; Update d with new LY
    inc a           ; 4
    add d           ; 4
    ld d, a         ; 4
    ; 80 cycles have passed out of 460
    ; 16 will be taken from end-of-loop.
    ; Stall for 364 cycles
    ld a, 22        ; 8
loopstallloop:
    dec a           ; 4
    jr nz, loopstallloop ; 12/8
    ; Stalled for 8 + 16*22 - 4 = 356 cycles
    nop             ; 4
    nop             ; 4
    ; Loop
    dec e           ; 4
    jr nz, loop     ; 12/8

    ; This would be the 115th read, but we are 4 cycles early.
    ; Cycle count: 115 * 460 - 4 = 52896

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

    ; We want to read LY spaced 460 video cycles apart.
    ; In double speed, each machine cycle is only 2 video
    ; cycles, so we will count each instruction half.
    ; As a result, subLY has 228 possible values instead
    ; of 114, and we need to space reads by 458 video cycles
    ; instead of 460.
    ldh a, ($44)    ; 6
    ld b, a         ; 2
    ld d, a         ; 2
    ; 10 cycles have passed, need to stall for 448 more.
    ld e, 228       ; 4
    ld a, 55        ; 4
stall2:
    dec a           ; 2
    jr nz, stall2   ; 6/4
    ; Stalled for 8 + 8 * 55 - 2 = 446 cycles
    nop             ; 2
loop2:
    ldh a, ($44)    ; 6
    sub d           ; 2
    jr nc, nocarry2 ; 6/4
carry2:
    add 154         ; 4
    jr check2       ; 6
nocarry2:
    ; Stall for 8 cycles to match carry branch (we've already used 2 extra cycles
    ; in the jr)
    nop             ; 2
    nop             ; 2
    nop             ; 2
    nop             ; 2
check2:
    dec a           ; 2
    jr nz, store2   ; 6/4
nostore2:
    jr loopstall2   ; 6
store2:
    ld c, e         ; 2
    nop             ; 2
loopstall2:
    ; Update d with new LY
    inc a           ; 2
    add d           ; 2
    ld d, a         ; 2
    ; 40 cycles have passed out of 458
    ; 8 will be taken from end-of-loop.
    ; Stall for 410 cycles
    ld a, 51        ; 4
loopstallloop2:
    dec a           ; 2
    jr nz, loopstallloop2 ; 6/4
    ; Stalled for 4 + 8*51 - 2 = 410 cycles
    ; Loop
    dec e           ; 2
    jr nz, loop2    ; 6/4

    ; This would be the 229th read, but we've saved 2 cycles
    ; Cycle count since first read of the second iteration:
    ; 229 * 458 - 2 = 104880

    push bc         ; 8

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

    ; In normal speed, machine cycles are 4 video cycles
    ; so video cycles act like clock cycles.
    ldh a, ($44)    ; 12
    ld b, a         ; 4
    ld d, a         ; 4
    ; 20 cycles have passed here, need to stall for 440 more.
    ld e, 114       ; 8
    ld a, 26        ; 8
stall3:
    dec a           ; 4
    jr nz, stall3   ; 12/8
    ; Stalled for 16 + 26 * 16 - 4 = 428 cycles, need 12 more.
    nop             ; 4
    nop             ; 4
    nop             ; 4
loop3:
    ldh a, ($44)    ; 12
    sub d           ; 4
    jr nc, nocarry3 ; 12/8
carry3:
    add 154         ; 8
    jr check3       ; 12
nocarry3:
    ; Stall for 16 cycles to match carry branch (we've already used 4 extra cycles
    ; in the jr)
    nop             ; 4
    nop             ; 4
    nop             ; 4
    nop             ; 4
check3:
    dec a           ; 4
    jr nz, store3   ; 12/8
nostore3:
    jr loopstall3   ; 12
store3:
    ld c, e         ; 4
    nop             ; 4
loopstall3:
    ; Update d with new LY
    inc a           ; 4
    add d           ; 4
    ld d, a         ; 4
    ; 80 cycles have passed out of 460
    ; 16 will be taken from end-of-loop.
    ; Stall for 364 cycles
    ld a, 22        ; 8
loopstallloop3:
    dec a           ; 4
    jr nz, loopstallloop3 ; 12/8
    ; Stalled for 8 + 16*22 - 4 = 356 cycles
    nop             ; 4
    nop             ; 4
    ; Loop
    dec e           ; 4
    jr nz, loop3    ; 12/8

    push bc         ; 16

    pop hl
    pop de
    pop bc
    ld a, b
    call print_a
    ld a, c
    ; Adjust first subLY
    sub 1
    jr nc, no_wrap
    add 114
no_wrap:
    sla a
    call print_a

    print_str newline

    ld a, d
    call print_a
    ld a, e
    ; Adjust second subLY
    sub 1
    jr nc, no_wrap2
    add 228
no_wrap2:
    call print_a

    print_str newline

    ld a, h
    call print_a
    ld a, l
    ; Adjust third subLY
    sub 1
    jr nc, no_wrap3
    add 114
no_wrap3:
    sla a
    call print_a

    jp tests_passed

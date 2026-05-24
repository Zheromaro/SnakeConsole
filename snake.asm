extern tcgetattr
extern tcsetattr
extern printf
extern fflush
extern getchar
extern usleep
extern select
extern rand

default rel
global main          ; <-- changed from _start

%define COLS 60
%define ROWS 30
section .data
hidecursor:     db 27, '[?25l', 0
showcursor:     db 27, '[?25h', 0
cursortotop:    db 27, '[%iA', 0
cursortotop2:   db 27, '[%iF', 0
gameoverstr:    db 27, '[%iB', 27, '[%iC Game Over! ', 0
tailstr:        db 27, '[%iB', 27, '[%iC·', 0
headstr:        db 27, '[%iB', 27, '[%iC๏', 0
applestr:       db 27, '[%iB', 27, '[%iC🍎', 0

section .bss
data:   resb 1
oldt:   resb 64
newt:   resb 64
buf:    resq COLS * ROWS + 1
x:      resq 1024
y:      resq 1024
xdir:   resq 1
ydir:   resq 1
head:   resq 1
tail:   resq 1
applex: resq 1
appley: resq 1
tv:     resq 2
fds:    resq 16

section .text
init:
    push    rbp
    mov     rdi, hidecursor
    call    printf
    xor     rdi, rdi
    call    fflush

    ; Switch to console mode, disable echo
    mov     rdi, 0
    mov     rsi, oldt
    call    tcgetattr

    mov     rdi, newt
    mov     rsi, oldt
    mov     rcx, 64
    rep     movsb

    and     word[newt +3 * 8], ~(0x0100 | 0x0008)  ; ICANON, ECHO
    mov     rdi, 0
    mov     rsi, 0
    mov     rdx, newt
    call    tcsetattr

    pop     rbp
    ret

exit_fn:             ; <-- renamed to avoid conflict with C's exit()
    mov     rdi, showcursor
    call    printf
    xor     rdi, rdi
    call    fflush

    ; restore terminal mode
    mov     rdi, 0
    mov     rsi, 0
    mov     rdx, oldt
    call    tcsetattr

    mov     rax, 60
    xor     rdi, rdi
    syscall

render_table:
    push    rbp

    ; top line
    mov     rdi, buf
    mov     rax, '⌈'
    stosd
    dec     rdi
    mov     rcx, COLS
    mov     rax, '‾'
_r0:
    stosd
    dec     rdi
    dec     rcx
    jnz     _r0

    mov     rax, '⌉'
    stosd
    mov     byte [rdi - 1], 10 ; new line


    ; mid line
    mov     rsi, ROWS
_r1:
    mov    rax, '⟦'
    stosd
    dec     rdi
    mov     rcx, COLS
    mov     al, '.'
    rep     stosw
    mov     eax, '⟧'
    stosd
    mov     byte [rdi - 1], 10
    dec     rsi
    jnz     _r1

    ; bottom line
    mov     rax, '⌊'
    stosd
    dec     rdi
    mov     rcx, COLS
    mov     al, '_'
_r2:
    stosd
    dec     rdi
    dec     rcx
    jnz     _r2

    mov     rax, '⌋'
    stosd
    mov     byte [rdi - 1], 10

    ; print table
    mov     rdi, buf
    call    printf


    mov     rdi, cursortotop
    mov     rsi, ROWS + 2
    call    printf

    pop     rbp
    ret

main:                ; <-- not _start because gcc
    push    rbp
    call    init

main_loop:
    call    render_table

    mov     qword [tail], 0
    mov     qword [head], 0
    mov     qword [x], COLS / 2
    mov     qword [y], ROWS / 2
    mov     qword [xdir], 1
    mov     qword [ydir], 0
    mov     qword [applex], -1

loop:
    lea     rbp, [data]
    ; Clear snake tail
    mov     rbx, [tail]
    mov     rdi, tailstr
    mov     rsi, [rbp + (y - data) + rbx * 8]
    mov     rdx, [rbp + (x - data) + rbx * 8]
    inc     rsi
    inc     rdx
    call    printf

    mov     rbx, [tail]
    mov     rdi, cursortotop2
    mov     rsi, [rbp + (y - data) + rbx * 8]
    inc     rsi
    call    printf

    ; Move snake head
    mov     rbx, [head]
    mov     rax, rbx
    inc     rbx
    and     rbx, 1023

    mov     rcx, [rbp + (x - data) + rax * 8]
    add     rcx, [xdir]

    ; - 1 Check the left boundary (Is X < 0?)
    cmp     rcx, 0
    jge     .check_xmax        ; If X is 0 or greater, move to the next check
    mov     rcx, COLS - 1      ; If X is negative, force it to the right edge
    jmp     .x_done

.check_xmax:
    ; - 2 Check the right boundary (Is X >= COLS?)
    cmp     rcx, COLS
    jl      .x_done            ; If X is less than COLS, we are good!
    mov     rcx, 0             ; If X is too high, force it to the left edge

.x_done:

    mov     [rbp + (x - data) + rbx * 8], rcx
    mov     rdx, [rbp + (y - data) + rax * 8]
    add     rdx, [ydir]
    cmp     rdx, ROWS
    jb      ok2
    jge     o2
    add     rdx, ROWS
    jmp     ok2
o2:
    sub     rdx, ROWS
ok2:
    mov     [rbp + (y - data) + rbx * 8], rdx
    mov     [head], rbx

    ; Check gameover
    mov     rdi, [head]
    mov     rax, [rbp + (x - data) + rdi * 8]
    mov     rbx, [rbp + (y - data) + rdi * 8]
    mov     rsi, [tail]
r3:
    cmp     rsi, [head]
    jz      r5
    cmp     [rbp + (x - data) + rsi * 8], rax
    jnz     r4
    cmp     [rbp + (y - data) + rsi * 8], rbx
    jz     gameover
r4:
    inc     rsi
    and     rsi, 1023
    jmp     r3
r5:

    ; Draw head
    mov     rbx, [head]
    mov     rdi, headstr
    mov     rsi, [rbp + (y - data) + rbx * 8]
    mov     rdx, [rbp + (x - data) + rbx * 8]
    inc     rsi
    inc     rdx
    call    printf
    mov     rdi, cursortotop2
    mov     rbx, [head]
    mov     rsi, [rbp + (y - data) + rbx * 8]
    inc     rsi
    call    printf
    xor     rdi, rdi
    call    fflush

    ; Delay
    mov     rdi, 5 * 1000000 / 60
    call    usleep

    ; read keyboard
    mov     qword [fds], 1
    mov     rdi, 1
    mov     rsi, fds
    mov     rdx, 0
    mov     rcx, 0
    mov     qword [tv], 0
    mov     qword [tv + 8], 0
    mov     r8, tv
    call    select
    test    rax, 1
    jz      nokey

    call    getchar
    cmp     al, 27
    jz      exit_fn
    cmp     al, 'q'
    je      exit_fn

nokey:
    jmp     loop

gameover:
    ; show game over
    mov     rdi, gameoverstr
    mov     rsi, ROWS / 2
    mov     rdx, COLS / 2 - 5
    call    printf
    mov     rdi, cursortotop2
    mov     rsi, ROWS / 2
    call    printf

    call    getchar
    jmp     main_loop

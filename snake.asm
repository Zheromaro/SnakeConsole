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

section .bss
data:   resb 1
oldt:   resb 64
newt:   resb 64
buf:    resq COLS * ROWS + 1

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

    pop     rbp
    ret

main:                ; <-- not _start because gcc
    push    rbp
    call    init

main_loop:
    call    render_table

    jmp     exit_fn

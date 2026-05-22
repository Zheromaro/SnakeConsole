extern printf
extern fflush

default rel
global main          ; <-- changed from _start

section .data
hidecursor: db 27, '[?25l', 0
showcursor: db 27, '[?25h', 0

section .bss
data:   resb 1

section .text
init:
    push    rbp
    mov     rdi, hidecursor
    call    printf
    xor     rdi, rdi
    call    fflush
    pop     rbp
    ret

exit_fn:             ; <-- renamed to avoid conflict with C's exit()
    mov     rdi, showcursor
    call    printf
    xor     rdi, rdi
    call    fflush
    mov     rax, 60
    xor     rdi, rdi
    syscall

main:                ; <-- not _start because gcc
    push    rbp
    call    init
    jmp     exit_fn

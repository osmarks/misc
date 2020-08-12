BITS 64
GLOBAL _start
SECTION .text
msg:	db "Hello, World!"
len:	equ $-msg
_start:
	; initialize stuff for `write` syscall
	mov rax, 1 ; write
	mov rdi, 1 ; fd 1 (stdout)
	mov rsi, $msg ; write from `msg`
	mov rdx, $len ; write `len` bytes
	syscall
	; exit
	mov rax, 60
	mov rdi, 0
	syscall

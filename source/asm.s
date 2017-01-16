.section ".text"
.arm
.align 4

.global flush_dcache
.type flush_dcache, %function
flush_dcache:
	mov r0, #0
	mcr p15, 0, r0, c7, c10, 0
	bx lr

.nds

.open "code.bin", "code_mod.bin", 0x0

RELOCBIN_OFFSET equ 0x0031F040
RELOCBIN_SIZE equ 0x000281CC

DSIDEV_SRL equ 0xCDE88

RELOC_OFFSET equ (RELOCBIN_OFFSET-0x00100000-0x00300000)

NDSHEADER_PTR equ (0x08089064)
NDSHEADER_CODE_OFFSET equ (0xE00)
ARM9_ROMOFFSET equ (0x4000)
ARM7_ROMOFFSET equ (0x2A000)

ARM9_CPY_TARGET equ (0x08040004)
ARM9_STACK_LR_PTR equ (0x0806E634)
ARM7_RAMADDRESS equ (((0x300000000 + ARM9_CPY_TARGET - 0x20000000) / 4) + 0x2000000)
ARM9_JMP_TARGET equ (NDSHEADER_PTR + NDSHEADER_CODE_OFFSET)
ARM7_SECTIONSIZE equ (0x100000000 - ARM7_RAMADDRESS)

.thumb

.org 0x00106028 + RELOC_OFFSET
	; clear out color fmt to GL_RGBA8_OES
	mov r0, #0

.org 0x0010B1F8 + RELOC_OFFSET
	; setFramebufferPtr va2pa instr
	.thumb
		; generate mov r0, #0x18000000
		mov r0, #0x18
		lsl r0, #0x18

.org DSIDEV_SRL
	.org DSIDEV_SRL + 0x12
		.byte 0x00 ; Unit = NDS
	; .org DSIDEV_SRL + 0x20
	; 	.word ARM9_ROMOFFSET ; arm9 rom offset
	; 	.word 0x02680A50 ; arm9 entrypoint
	; 	.word ARM9_RAMADDRESS ; arm9 section ram address
	; 	.word ARM9_SECTIONSIZE ; arm9 section size
	.org DSIDEV_SRL + 0x30
		.word ARM7_ROMOFFSET ; arm7 rom offset
		.word 0x2280200 ; arm7 entrypoint
		.word ARM7_RAMADDRESS ; arm7 section ram address
		.word ARM7_SECTIONSIZE ; arm7 section size
	.org DSIDEV_SRL + NDSHEADER_CODE_OFFSET
		.arm
			adr r0, arm9_kernel_code
			.word 0xEF00007B ; svc 0x7b
			arm9_kernel_code:
			; read region 3 register (region base 0x100000000)
			mrc p15, 0, r0, c6, c3, 0
			; modify region size to be 0x36 (2 ^ (0x36 / 2 + 1) = 0x10000000, includes VRAM)
			bic r0, #0x3e
			orr r0, #0x36
			; write region 3 register
			mcr p15, 0, r0, c6, c3, 0
			; draw pink to framebuffer from arm9
			ldr r0, =0x18000000
			ldr r1, =0xff00ffff
			test:
				str r1, [r0], #4
				b test
			.pool
	.org DSIDEV_SRL + ARM7_ROMOFFSET + (ARM9_STACK_LR_PTR - ARM9_CPY_TARGET) / 4
		.thumb
		; RAM:08035512 ADD SP, SP, #0x14
		; RAM:08035514 POP {R4-R7,PC}
		.halfword ((0x08035512 + 1) & 0xFFFF)
		.halfword (0xdada)
		.halfword (0xdede)
		.halfword (0xd0d0)
		.halfword (0xdfdf)
		.halfword (ARM9_JMP_TARGET & 0xFFFF)
		.halfword (0xdcdc)
		.halfword (0xdddd)
		.halfword (0xd7d7)

.close

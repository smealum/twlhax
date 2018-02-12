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

PAYLOAD_OFFSET equ (ARM9_ROMOFFSET)
DSIDEV_SRL_PA equ (0x27C00000)

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

; first function called by PrepareArm9ForTwl
.org 0x103550 + RELOC_OFFSET
	sub_103550:

; this hook gives us arm11 code exec right after arm9 setup stuff is done
.org 0x001002A0 + RELOC_OFFSET
	mov r4, r0
	mov r5, r1
	mov r6, r2
	bl sub_103550

	; test to see if fcram is still mapped (it is) (requires k11 patches)
	ldr r0, =0x20000000
	ldr r0, [r0]

	; draw yellow to framebuffer from arm11
	ldr r0, =0x1F000000
	ldr r1, =0xfff00fff
	coloop:
		str r1, [r0]
		add r0, #4
		b coloop
	.pool

.org DSIDEV_SRL
	.org DSIDEV_SRL + 0x12
		.byte 0x00 ; Unit = NDS
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

				; ; allow VRAM through MPU
				; ldr r0, =0x10000037
				; mcr	p15, 0, r0, c6, c3, 0

				; ; allow WRAM through MPU
				; ldr r0, =0x1FF00027
				; mcr	p15, 0, r0, c6, c4, 0
				
				; ; draw crap to screen
				; ldr r0, =0x18000000
				; ldr r1, =0xdead
				; color_loop:
				; str r1, [r0], #4
				; add r1, #32
				; b color_loop

				; ARM9 
					ldr r0, =0x080a0000 ; dst
					ldr r1, =(DSIDEV_SRL_PA + PAYLOAD_OFFSET) ; src
					ldr r2, =(payload_end - payload)
					add r2, r0
					mov r4, r0
					copy_loop:
						ldr r3, [r1], #4
						str r3, [r0], #4
						cmp r0, r2
						blt copy_loop

					; flush dcache
						mov r0, #0
						mcr p15, 0, r0, c7, c10, 0
	
					; invalidate icache
						mcr p15, 0, r0, c7, c5, 0
					
					; jump to payload
						ldr r0, =0xdeadbabe
						blx r4

				.pool

				.align 4
				payload_dst:
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

	.org DSIDEV_SRL + PAYLOAD_OFFSET
		.arm
		payload:
			.incbin "3dsbootldr_fatfs.bin"
		payload_end:

.close

.nds

.create "data/stub.bin", 0x0

.arm

	; clear entrypoint field
	ldr r0, =0x1ffffffc
	mov r1, #0
	str r1, [r0]

	; signal pxi
	ldr r1, =0x10163008
	ldr r2, =0x44846
	str r2, [r1]

	; wait for entrypoint to be populated
	wait_loop:
		ldr r4, [r0]
		cmp r4, #0
		beq wait_loop

	; copy over our custom arm11 firm stuffs...
	ldr r0, =0x18000000
	ldr r1, =0xdead0000 ; source, will be replaced
	ldr r2, =0xdead0001 ; size, will be replaced
	add r2, r0
	copy_loop:
		ldr r3, [r1], #4
		str r3, [r0], #4
		cmp r0, r2
		blt copy_loop

	; copy over our custom arm11 firm stuffs...
	ldr r0, =0x1FF96000
	ldr r1, =0xdead0002 ; source, will be replaced
	ldr r2, =0xdead0003 ; size, will be replaced
	add r2, r0
	copy_loop_2:
		ldr r3, [r1], #4
		str r3, [r0], #4
		cmp r0, r2
		blt copy_loop_2

	; jump to entrypoint!
	bx r4
	
	.pool

.close

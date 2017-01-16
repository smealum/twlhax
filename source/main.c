#include <3ds.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <malloc.h>

#include "stub_bin.h"
#include "firm_0_18000000_bin.h"

u8* bottom_fb = NULL;
u32 copy_core0stub_and_run_ptr = 0;
u32 stub_pa = 0;

void flush_dcache();

s32 kernel_mode(void)
{
	__asm__ volatile("cpsid aif");

	// arm11 firm hooking inspired by https://github.com/yellows8/3ds-totalcontrolhaxx/blob/master/3ds_arm11code.s#L884
	// not used for firmlaunchhax here though obviously

	// search for core0 stub copy-and-run code
	{
		const u32 target = 0x1FFFFC00;
		u32* wram = (u32*)0xdff80000; // WRAM
		u32 length = 0x00080000; // WRAM size

		int i;
		for(i = 0; i < length; i++)
		{
			if(wram[i] == target)
			{
				copy_core0stub_and_run_ptr = (u32)&wram[i];
				break;
			}
		}
	}

	// patch up copy_core0stub_and_run so it'll load the stub we want it to
	if(copy_core0stub_and_run_ptr)
	{
		copy_core0stub_and_run_ptr -= 0x40;
		((u32*)copy_core0stub_and_run_ptr)[0] = 0xE59F0010; // ldr r0, stub_start
		((u32*)copy_core0stub_and_run_ptr)[1] = 0xE59F1010; // ldr r1, stub_end
		((u32*)copy_core0stub_and_run_ptr)[6] = stub_pa; // stub_start (overwrites real stub which will be unused now)
		((u32*)copy_core0stub_and_run_ptr)[7] = stub_pa + stub_bin_size; // stub_end
	}

	flush_dcache();

	return 0;
}

Handle nsHandle = 0;

Result NS_LaunchApplicationFIRM(u64 tid, u32 flags)
{
	Result ret = 0;

	if(!nsHandle) srvGetServiceHandle(&nsHandle, "ns:s");

	printf("NS_LaunchApplicationFIRM %08X %llx\n", (unsigned int)nsHandle, (long long unsigned int)tid);

	u32 *cmdbuf = getThreadCommandBuffer();

	cmdbuf[0] = 0x000500C0;
	cmdbuf[1] = tid & 0xFFFFFFFF;
	cmdbuf[2] = (tid >> 32) & 0xFFFFFFFF;
	cmdbuf[3] = flags;
	
	if((ret = svcSendSyncRequest(nsHandle))!=0) return ret;

	printf("%08X\n", (unsigned int)cmdbuf[1]);

	return (Result)cmdbuf[1];
}

int main(int argc, char **argv)
{
	gfxInitDefault();

	consoleInit(GFX_TOP, NULL);

	gfxSetDoubleBuffering(GFX_BOTTOM, false);
	bottom_fb = gfxGetFramebuffer(GFX_BOTTOM, GFX_LEFT, NULL, NULL);

	gfxSwapBuffers();
	gfxSwapBuffers();

	u32* stub_buffer = (u32*)linearAlloc(0x100000);
	stub_pa = (u32)osConvertVirtToPhys((u32)stub_buffer);
	memcpy(stub_buffer, stub_bin, stub_bin_size);

	void* firm_0_18000000_buffer = linearAlloc(0x100000);
	u32 firm_0_18000000_pa = (u32)osConvertVirtToPhys((u32)firm_0_18000000_buffer);
	memcpy(firm_0_18000000_buffer, firm_0_18000000_bin, firm_0_18000000_bin_size);

	// patch stub so it knows where our section is at
	{
		int i;
		for(i = 0; i < stub_bin_size / 4; i ++)
		{
			u32* ptr = &stub_buffer[i];
			if(*ptr == 0xdeadbabe)
			{
				*ptr = firm_0_18000000_pa;
				printf("found src %d\n", i);
			}else if(*ptr == 0x0deaddad){
				*ptr = firm_0_18000000_bin_size;
				printf("found len %d\n", i);
			}
		}
	}

	svcBackdoor(kernel_mode);

	printf("copy_core0stub_and_run_ptr %08X\n", (unsigned int)copy_core0stub_and_run_ptr);

	// firmlaunch
	NS_LaunchApplicationFIRM(0x0004800542383841ll, 1);
	svcExitProcess();

	// Main loop
	while (aptMainLoop())
	{
		//Scan all the inputs. This should be done once for each frame
		hidScanInput();

		//hidKeysDown returns information about which buttons have been just pressed (and they weren't in the previous frame)
		u32 kDown = hidKeysDown();

		if (kDown & KEY_START) break; // break in order to return to hbmenu

		// Flush and swap framebuffers
		gfxFlushBuffers();
		gfxSwapBuffers();

		//Wait for VBlank
		gspWaitForVBlank();
	}

	gfxExit();
	return 0;
}

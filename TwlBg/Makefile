.PHONY := all clean

all: out.ncch

code_mod.bin: code.bin code_mod.s
	@armips code_mod.s

exefs_mod.bin: code_mod.bin
	@ctrtool -c -t exefs --compresscode --section0name=.code --section0file="code_mod.bin" exefs_mod.bin

out.ncch: build_twlbg.py header.bin exheader.bin exefs_mod.bin
	@py -2 build_twlbg.py header.bin exheader.bin exefs_mod.bin out.ncch

clean:
	@rm -f out.ncch exefs_mod.bin code_mod.bin
	@echo "all cleaned up !"

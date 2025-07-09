#!/usr/bin/bash
mkdir -p build
clang -O3 -g0 -o build/main.out -lz80 src/main.c
clang-z80 --target=z80-none-elf -nostdinc -O3 -g0 -S -o build/ppu.s src/ppu.c
as-z80 -march=z80+full -ignore-undocumented-instructions build/ppu.s -o build/ppu.o
as-z80 -march=z80+full -ignore-undocumented-instructions src/maths.s -o build/maths.o
# Link the ppu and maths library to an elf file
ld-z80 -b elf32-z80 -A z80 build/maths.o build/ppu.o -T src/link.ld -o build/ppu.elf
# Dump the machine code to a binary file to load in to PPU ROM
objcopy-z80 --only-section=.text -O binary build/ppu.elf build/ppu.bin

#!/usr/bin/bash
set -ex
mkdir -p build
opt=$1
debug=$2
clang -O3 -g0 -o build/main.out -lz80 -lSDL2 src/main.c
#clang-z80 --target=z80-none-elf -nostdinc $opt -g0 -S -o build/ppu.s src/ppu.c
if [ "$debug" = "y" ]
then
    clang-z80 --target=z80-none-elf -nostdinc $opt -g0 -S -disable-output src/ppu.c -mllvm -print-after-all 2> build/ppu.log
fi
#as-z80 -march=z80+full -ignore-undocumented-instructions build/ppu.s -o build/ppu.o
#as-z80 -march=z80+full -ignore-undocumented-instructions src/maths.s -o build/maths.o
as-z80 -march=z80+full -ignore-undocumented-instructions src/ppu.s -o build/ppu.o
# Link the ppu and maths library to an elf file
ld-z80 -b elf32-z80 $opt -A z80 build/ppu.o -T src/link.ld -o build/ppu.elf
# Dump the machine code to a binary file to load in to PPU ROM
objcopy-z80 --only-section=.text -O binary build/ppu.elf build/ppu.bin

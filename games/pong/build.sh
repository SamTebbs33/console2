#!/usr/bin/bash
set -ex
mkdir -p build
as-z80 -march=z80+full -ignore-undocumented-instructions game.s -o build/game.o
ld-z80 -b elf32-z80 -A z80 build/game.o -T link.ld -o build/game.elf
objcopy-z80 --only-section=.text -O binary build/game.elf build/game.bin

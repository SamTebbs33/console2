#include <z80.h>
#include <stdio.h>

#define PPU_CODE_END ((ushort)8 * 1024)
#define PPU_TABLES_START PPU_CODE_END
#define PPU_TABLES_END ((ushort)16 * 1024)
#define PPU_DEFS_START PPU_TABLES_END
#define PPU_DEFS_END ((ushort)32 * 1024)
#define PPU_RAM_START PPU_DEFS_END

byte tableRAM[4 * 1024];
byte ppuRAM[(ushort)32 * 1024];
byte ppuCodeROM[8 * 1024];
byte ppuDefROM[16 * 1024];

byte* ppuMemMap(ushort address, ushort* relAddress) {
    if (address < PPU_CODE_END) {
        *relAddress = address;
        return ppuCodeROM;
    } else if (address < PPU_TABLES_END) {
        *relAddress = address - PPU_TABLES_START;
        return tableRAM;
    } else if (address < PPU_DEFS_END) {
        *relAddress = address - PPU_DEFS_START;
        return ppuDefROM;
    } else {
        *relAddress = address - PPU_RAM_START;
        return ppuRAM;
    }
}

byte ppuMemRead(size_t param, ushort address) {
    byte* mem = ppuMemMap(address, &address);
    return mem[address];
}

void ppuMemWrite(size_t param, ushort address, byte data) {
    byte* mem = ppuMemMap(address, &address);
    mem[address] = data;
}

Z80Context PPU = {.memRead = ppuMemRead, .memWrite = ppuMemWrite, .memParam = 1, .ioParam = 1};

int main(int argc, char** argv) {
    if (argc < 2) {
        printf("Expected ppu ROM path\n");
        return 1;
    }

    char* ppuROMPath = argv[1];
    printf("Reading %s\n", ppuROMPath);
    FILE* ppuROMFile = fopen(ppuROMPath, "rb");
    if (!ppuROMFile) {
        printf("Couldn't open %s\n", ppuROMPath);
        return 1;
    }
    int bytesRead = fread(ppuCodeROM, sizeof(byte), sizeof(ppuCodeROM), ppuROMFile);
    printf("Read %d bytes\n", bytesRead);
    fclose(ppuROMFile);

    Z80RESET(&PPU);
    return 0;
}

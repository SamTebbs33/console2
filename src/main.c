#include <z80.h>
#include <SDL2/SDL.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include "consts.h"

#define PPU_CODE_END SPRITE_TABLE_ADDR
#define PPU_TABLES_START PPU_CODE_END
#define PPU_TABLES_END SPRITE_DEFS_ADDR
#define PPU_DEFS_START PPU_TABLES_END
#define PPU_DEFS_END PIXEL_MAP_ADDR
#define PPU_RAM_START PIXEL_MAP_ADDR

#define FRAMES_PER_SECOND 50
#define MILLIS_PER_FRAME (1000 / FRAMES_PER_SECOND)
#define STACK_TOP (64 * 1024)
#define STACK_BOTTOM (64 * 1024 - STACK_SIZE)

byte tableRAM[8 * 1024];
byte ppuRAM[(ushort)32 * 1024];
byte ppuCodeROM[8 * 1024];
byte ppuDefROM[16 * 1024];
unsigned debugStack[32 * 1024];
unsigned debugSP = 32 * 1024 - 1;

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
    if (mem == ppuCodeROM) printf("error: Writing to ppu ROM address %x\n", address);
    else if (mem == ppuDefROM) printf("error: Writing to ppu def ROM address %x\n", address);
    else if (mem == tableRAM) printf("error: Writing to table RAM address %x\n", address);
    mem[address] = data;
}

Z80Context PPU = {.memRead = ppuMemRead, .memWrite = ppuMemWrite, .memParam = 0, .ioParam = 0};

typedef struct {
    enum { HBLANK, VBLANK, DISPLAY } section;
    unsigned vCounter;
    unsigned hCounter;
    unsigned pixelOffset;
} VideoState;

void vStateCycle(VideoState* vstate, SDL_Renderer* renderer) {
    switch (vstate->section) {
        case DISPLAY:
            vstate->pixelOffset++;
            if (vstate->hCounter == 800) {
                vstate->section = HBLANK;
            } else {
                uint8_t pixel = ppuMemRead(1, PIXEL_MAP_ADDR + (vstate->pixelOffset / 4));
                uint8_t r = (pixel & 0b11);
                r |= (r << 2) | (r << 4) | (r << 6);
                uint8_t g = (pixel & 0b1100) >> 2;
                g |= (g << 2) | (g << 4) | (g << 6);
                uint8_t b = (pixel & 0b110000) >> 4;
                b |= (b << 2) | (b << 4) | (b << 6);
                SDL_SetRenderDrawColor(renderer, r, g, b, 255);
                SDL_RenderDrawPoint(renderer, vstate->hCounter, vstate->vCounter);
            }
            vstate->hCounter++;
            break;
        case HBLANK:
            if (vstate->hCounter == 1056) {
                vstate->vCounter++;
                vstate->hCounter = 0;
                if (vstate->vCounter == 600) {
                    vstate->pixelOffset = 0;
                    vstate->section = VBLANK;
                } else {
                    vstate->section = DISPLAY;
                }
            } else {
                vstate->hCounter++;
            }
            break;
        case VBLANK:
            if (vstate->hCounter == 1056) {
                vstate->hCounter = 0;
                if (vstate->vCounter == 628) {
                    vstate->section = DISPLAY;
                    vstate->hCounter = 0;
                    vstate->vCounter = 0;
                } else {
                    vstate->vCounter++;
                }
            } else {
                vstate->hCounter++;
            }
            break;
    }
}

void execute(Z80Context* ctx) {
    unsigned PC = ctx->PC;
    byte opc1 = ppuMemRead(1, PC);
    byte opc2 = ppuMemRead(1, PC + 1);
    switch (opc1) {
        case 0xDD:
        case 0xFD:
            if (opc2 == 0xE1 ) {
                // POP IX
                // POP IY
                debugSP += 2;
                printf("found pop ix/iy\n");
            } else if (opc2 == 0xE5) {
                printf("found push ix/iy\n");
                // PUSH IX
                // PUSH IY
                debugStack[--debugSP] = PC;
                debugStack[--debugSP] = PC;
            }
            break;
        case 0b11000001:
        case 0b11010001:
        case 0b11100001:
        case 0b11110001:
            printf("found pop qq\n");
            // POP qq
            debugSP += 2;
            break;
        case 0b11000101:
        case 0b11010101:
        case 0b11100101:
        case 0b11110101:
            printf("found push qq\n");
            debugStack[--debugSP] = PC;
            debugStack[--debugSP] = PC;
            break;

    }
    Z80Execute(ctx);
}

int main(int argc, char** argv) {
    if (argc < 2) {
        printf("Expected ppu ROM path\n");
        return 1;
    }

    memset(ppuCodeROM, 0, sizeof(ppuCodeROM));
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

    if (SDL_SetHintWithPriority(SDL_HINT_NO_SIGNAL_HANDLERS, "1", SDL_HINT_OVERRIDE) == SDL_FALSE) {
        printf("Failed to set SDL hint\n");
        return 1;
    }

    unsigned pixelScaleFactor = 1;
    struct SDL_Window* window = SDL_CreateWindow("Console", SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, SPRITE_ENTRIES_PIXELS_X, SPRITE_ENTRIES_PIXELS_Y, SDL_WINDOW_RESIZABLE);
    struct SDL_Renderer* renderer = SDL_CreateRenderer(window, -1, 0); 
    SDL_RenderSetScale(renderer, pixelScaleFactor, pixelScaleFactor);
    SDL_SetRenderDrawColor(renderer, 0, 0, 0, 0);
    SDL_RenderClear(renderer);
    SDL_RenderPresent(renderer);

    memset(tableRAM, 0, sizeof(tableRAM));
    memset(ppuRAM, 0, sizeof(ppuRAM));
    memset(ppuDefROM, 0, sizeof(ppuDefROM));

    Z80RESET(&PPU);

    // Give PPU a few cycles to set up stack
    Z80ExecuteTStates(&PPU, 20);

    VideoState vState = { .section = DISPLAY, .hCounter = 0, .vCounter = 0};

    unsigned renderCycles = 0;
    bool debug = argc > 2 && strcmp(argv[2], "y") == 0;
    bool waitForInput = true;
    bool waitForVBlank = false;
    unsigned instrsToSkipForDebug = 0;
    int instrToSkipTo = -1;

    while (true) {
        if (debug && waitForInput && instrsToSkipForDebug == 0 && instrToSkipTo == -1) {
            char decode[20];
            char dump[20];
            Z80Debug(&PPU, dump, decode);
            printf("PC %x %s (%s)\n", PPU.PC, decode, dump);
            char cmd[20];
            if (fgets(cmd, sizeof(cmd), stdin) != NULL) {
                if (strcmp(cmd, "c\n") == 0) {
                    printf("Continuing\n");
                    debug = false;
                } if (strcmp(cmd, "v\n") == 0) {
                    printf("Waiting until vblank\n");
                    waitForInput = false;
                    waitForVBlank = true;
                } else if (strcmp(cmd, "r\n") == 0) {
                    Z80Regs regs = PPU.R1;
                    printf("Regs:\n\tA: %d, F: %d, AF: %d\n\tB: %d, C: %d, BC: %d\n\tD: %d, E: %d, DE: %d\n\tH: %d, L: %d, HL: %d\n\tIX: %d\n\tIY: %d\n\tSP: %d\n", regs.br.A, regs.br.F, regs.wr.AF, regs.br.B, regs.br.C, regs.wr.BC, regs.br.D, regs.br.E, regs.wr.DE, regs.br.H, regs.br.L, regs.wr.HL, regs.wr.IX, regs.wr.IY, regs.wr.SP);
                } else if (strcmp(cmd, "s\n") == 0) {
                    Z80Regs regs = PPU.R1;
                    printf("Stack:\n");
                    unsigned sp = regs.wr.SP;
                    unsigned debugSPCopy = debugSP;
                    while (sp < STACK_TOP) {
                        byte b = ppuMemRead(0, sp);
                        printf("\t%d (pushed by %x)\n", b, debugStack[debugSPCopy++]);
                        sp++;
                    }
                } else if (strcmp(cmd, "f\n") == 0) {
                    byte flags = PPU.R1.br.F;
                    printf("Flags:\n");
                    printf("\tC: %d\n\tN: %d\n\tPV: %d\n\tHC: %d\n\tZ: %d\n\tS: %d\n", (flags & F_C) != 0, (flags & F_N) != 0, (flags & F_PV) != 0, (flags & F_H) != 0, (flags & F_Z)!= 0, (flags & F_S) != 0);
                } else if (strcmp(cmd, "\n") == 0) {
                    execute(&PPU);
                } else if (cmd[0] == 'j' && strlen(cmd) > 1) {
                    int toSkip = atoi(cmd+1);
                    if (toSkip > 0) {
                        instrsToSkipForDebug = toSkip;
                        printf("Executing %d instructions\n", instrsToSkipForDebug);
                    }
                } else if (cmd[0] == 'w' && strlen(cmd) > 1) {
                    int i = strtol(cmd + 1, NULL, 16);
                    if (i > -1) {
                        instrToSkipTo = i;
                        printf("Skipping to %x\n", instrToSkipTo);
                    }
                } else {
                    printf("Unrecognised command\n");
                }
            }
        } else {
            execute(&PPU);
            if (instrsToSkipForDebug > 0) instrsToSkipForDebug--;
            if (instrToSkipTo >= 0 && instrToSkipTo == PPU.PC) instrToSkipTo = -1;
        }
        bool IsVBlank = vState.section == VBLANK;
        bool IsDisplay = vState.section == DISPLAY;
        vStateCycle(&vState, renderer);
        vStateCycle(&vState, renderer);
        if (vState.section == VBLANK && !IsVBlank) {
            SDL_RenderPresent(renderer);
            Z80NMI(&PPU);
            printf("VBLANK triggered\n");
            if (waitForVBlank) {
                waitForVBlank = false;
                waitForInput = true;
            }
        }

        if (vState.section == VBLANK && !IsVBlank) {
            renderCycles = 0;
        } else if (vState.section == VBLANK) renderCycles++;

        if (PPU.R1.wr.SP < STACK_BOTTOM) {
            printf("Stack overflowed to address %x at PC %x\n", PPU.R1.wr.SP, PPU.PC);
            //return 1;
        }
    }

    return 0;
}

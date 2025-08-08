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

#define CPU_PARAM 0
#define EMU_PARAM 1

byte tableRAM[8 * 1024];
byte ppuRAM[(ushort)32 * 1024];
byte ppuCodeROM[8 * 1024];
byte ppuDefROM[16 * 1024];
unsigned debugStack[32 * 1024];
unsigned debugSP = 32 * 1024 - 1;
ushort stacktrace[255];
byte stacktraceEnd = 0;
byte stacktraceStart = 0;
unsigned ppuROMLen = 0;
bool printSectionChanges = false;
unsigned cyclesTakenToRenderAllSprites = 0;

void ppuMemWrite(size_t param, ushort address, byte data);
byte ppuMemRead(size_t param, ushort address);

Z80Context PPU = {.memRead = ppuMemRead, .memWrite = ppuMemWrite, .memParam = CPU_PARAM, .ioParam = CPU_PARAM};

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
    ushort originalAddress = address;
    //if (originalAddress == 0x2b32) printf("Writing %x to render state by PC %x\n", data, PPU.PC);
    byte* mem = ppuMemMap(address, &address);
    if (param == CPU_PARAM) {
        if (mem == ppuCodeROM) printf("error: Writing to ppu ROM address %x after PC %x\n", address, PPU.PC);
        else if (mem == ppuDefROM) printf("error: Writing to ppu def ROM address %x after PC %x\n", address, PPU.PC);
    }
    mem[address] = data;
}

typedef enum { HBLANK, VBLANK, DISPLAY, NONE } VideoSection;
char* toString(VideoSection section) {
    switch (section) {
        case NONE:
            return "NONE";
        case HBLANK:
            return "HBLANK";
        case VBLANK:
            return "VBLANK";
        case DISPLAY:
            return "DISPLAY";
    }
}

unsigned coordToVRAMAddr(unsigned x, unsigned y, unsigned scale) {
    x /= scale;
    y /= scale;
    return (x / 8) * 64 + (y / 8) * 1600 + (x % 8) + (y % 8) * 8;
}

void drawPixel(SDL_Renderer* renderer, unsigned x, unsigned y) {
    uint8_t r, g, b;
    uint8_t pixel = ppuMemRead(EMU_PARAM, PIXEL_MAP_ADDR + coordToVRAMAddr(x, y, 4));
    r = (pixel & 0b11);
    r |= (r << 2) | (r << 4) | (r << 6);
    g = (pixel & 0b1100) >> 2;
    g |= (g << 2) | (g << 4) | (g << 6);
    b = (pixel & 0b110000) >> 4;
    b |= (b << 2) | (b << 4) | (b << 6);
    SDL_SetRenderDrawColor(renderer, r, g, b, 255);
    SDL_RenderDrawPoint(renderer, x, y);
}

typedef struct {
    VideoSection section;
    unsigned vCounter;
    unsigned hCounter;
} VideoState;

void setVideoState(VideoState* state, VideoSection section, unsigned h, unsigned v) {
    state->section = section;
    state->vCounter = v;
    state->hCounter = h;
}

void vStateCycle(VideoState* vstate, SDL_Renderer* renderer) {
    unsigned hCounter = vstate->hCounter;
    unsigned vCounter = vstate->vCounter;
    switch (vstate->section) {
        case NONE:
            perror("Unexpected NONE display state\n");
            break;
        case DISPLAY:
            if (hCounter == 800) {
                setVideoState(vstate, HBLANK, hCounter + 1, vCounter);
            } else {
                drawPixel(renderer, hCounter, vCounter);
                setVideoState(vstate, DISPLAY, hCounter + 1, vCounter);
            }
            break;
        case HBLANK:
            if (hCounter == 1056) {
                if (vCounter == 599) {
                    setVideoState(vstate, VBLANK, 0, vCounter + 1);
                } else {
                    setVideoState(vstate, DISPLAY, 0, vCounter + 1);
                }
            } else {
                setVideoState(vstate, HBLANK, hCounter + 1, vCounter);
            }
            break;
        case VBLANK:
            if (vstate->hCounter == 1056) {
                vstate->hCounter = 0;
                if (vstate->vCounter == 628) {
                    setVideoState(vstate, DISPLAY, 0, 0);
                } else {
                    setVideoState(vstate, VBLANK, 0, vCounter + 1);
                }
            } else {
                setVideoState(vstate, VBLANK, hCounter + 1, vCounter);
            }
            break;
    }
}

void execute(Z80Context* ctx) {
    unsigned PC = ctx->PC;
    if (PC == 0x1145 && cyclesTakenToRenderAllSprites > 1) {
        printf("PPU took %d cycles to render all sprites\n", cyclesTakenToRenderAllSprites);
        cyclesTakenToRenderAllSprites = 0;
    }
    stacktrace[stacktraceEnd++] = PC;
    if (stacktraceEnd <= stacktraceStart) stacktraceStart++;

    byte opc1 = ppuMemRead(EMU_PARAM, PC);
    byte opc2 = ppuMemRead(EMU_PARAM, PC + 1);
    switch (opc1) {
        // RETI
        case 0xED: {
            if (opc2 == 0x4D) {
                ushort SP = ctx->R1.wr.SP;
                ushort retAddr = ppuMemRead(EMU_PARAM, SP) | (ppuMemRead(EMU_PARAM, SP + 1) << 8);
                if (retAddr >= ppuROMLen) printf("Returning from interrupt with return address outside PPU code (%x)\n", retAddr);
            }
            break;
        }
        case 0xDD:
        case 0xFD:
            if (opc2 == 0xE1 ) {
                // POP IX
                // POP IY
                debugSP += 2;
            } else if (opc2 == 0xE5) {
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
            // POP qq
            debugSP += 2;
            break;
        case 0b11000101:
        case 0b11010101:
        case 0b11100101:
        case 0b11110101:
            debugStack[--debugSP] = PC;
            debugStack[--debugSP] = PC;
            break;

    }
    Z80Execute(ctx);
}

void printRegisters(Z80Context* cpu) {
    Z80Regs regs = cpu->R1;
    printf("Regs:\n\tA: %d, F: %d, AF: %d\n\tB: %d, C: %d, BC: %d\n\tD: %d, E: %d, DE: %d\n\tH: %d, L: %d, HL: %d\n\tIX: %d\n\tIY: %d\n\tSP: %d\n", regs.br.A, regs.br.F, regs.wr.AF, regs.br.B, regs.br.C, regs.wr.BC, regs.br.D, regs.br.E, regs.wr.DE, regs.br.H, regs.br.L, regs.wr.HL, regs.wr.IX, regs.wr.IY, regs.wr.SP);
}

void printStackTrace() {
    printf("Stack trace:\n");
    byte idx = stacktraceEnd;
    byte prev = 0;
    byte repeated = 0;
    while (idx != stacktraceStart) {
        byte b = stacktrace[idx--];
        if (b == prev)
            repeated++;
        else if (repeated > 1) {
            printf("repeated %d times\n", repeated);
            repeated = 0;
        } else
            printf("%x\n", b);
        prev = b;
    }
    if (repeated > 1) printf("repeated %d times\n", repeated);
    printRegisters(&PPU);
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
    FILE* vramDumpFile = NULL;
    if (!ppuROMFile) {
        printf("Couldn't open %s\n", ppuROMPath);
        return 1;
    }
    ppuROMLen = fread(ppuCodeROM, sizeof(byte), sizeof(ppuCodeROM), ppuROMFile);
    printf("Read %d bytes\n", ppuROMLen);
    fclose(ppuROMFile);

    if (SDL_SetHintWithPriority(SDL_HINT_NO_SIGNAL_HANDLERS, "1", SDL_HINT_OVERRIDE) == SDL_FALSE) {
        printf("Failed to set SDL hint\n");
        return 1;
    }

    int windowWidth = SPRITE_ENTRIES_PIXELS_X * 4;
    int windowHeight = SPRITE_ENTRIES_PIXELS_Y * 4;
    printf("pixels_x: %d, pixels_y: %d\n", windowWidth, windowHeight);

    SDL_Init(SDL_INIT_VIDEO);
    struct SDL_Window* window = SDL_CreateWindow("Console", SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, windowWidth, windowHeight, SDL_WINDOW_BORDERLESS);
    int width = 0, height = 0;
    SDL_GetWindowSizeInPixels(window, &width, &height);
    printf("%d x %d window created\n", width, height);
    struct SDL_Renderer* renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED);
    SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255);
    SDL_RenderClear(renderer);
    SDL_RenderPresent(renderer);

    memset(tableRAM, 0, sizeof(tableRAM));
    memset(ppuRAM, 0x00, sizeof(ppuRAM));
    memset(ppuDefROM, 0, sizeof(ppuDefROM));
    memset(stacktrace, 0, sizeof(stacktrace));

    Z80RESET(&PPU);

    // Give PPU a few cycles to set up stack
    Z80ExecuteTStates(&PPU, 60);

    // Set up demo
    // Define sprites
    unsigned spriteNo = 0;
    for (unsigned row = 0; row < 8; row++) {
        for (unsigned column = 0; column < 8; column++) {
            ppuDefROM[(SPRITE_DEF_SIZE * spriteNo) + (row * 8) + column] = 0xDD;
        }
    }
    spriteNo = 1;
    for (unsigned row = 0; row < 8; row++) {
        for (unsigned column = 0; column < 8; column++) {
            byte pixel;
            if (row % 2 == 0) pixel = column % 2 == 0 ? 0x00 : 0xDD;
            else pixel = column % 2 == 0 ? 0xBB : 0x99;
            ppuDefROM[(SPRITE_DEF_SIZE * spriteNo) + (row * 8) + column] = pixel;
        }
    }

    // Fill sprite entries
    bool spriteOne = false;
    byte x = 0;
    byte y = 0;
    for (unsigned entry = 0; entry < SPRITE_ENTRIES_NUM; entry++) {
        uint16_t spriteAddr = SPRITE_DEFS_ADDR + SPRITE_DEF_SIZE * (spriteOne ? 1 : 0);
        ppuMemWrite(EMU_PARAM, SPRITE_TABLE_ADDR + (entry * SPRITE_ENTRY_SIZE) + 0, x); // x coord
        ppuMemWrite(EMU_PARAM, SPRITE_TABLE_ADDR + (entry * SPRITE_ENTRY_SIZE) + 1, y); // y coord
        ppuMemWrite(EMU_PARAM, SPRITE_TABLE_ADDR + (entry * SPRITE_ENTRY_SIZE) + 2, spriteAddr & 0xFF); // sprite addr low byte
        ppuMemWrite(EMU_PARAM, SPRITE_TABLE_ADDR + (entry * SPRITE_ENTRY_SIZE) + 3, spriteAddr >> 8); // sprite addr high byte
        spriteOne = !spriteOne;
        x += 8;
        if (x >= SPRITE_ENTRIES_PIXELS_X) {
            x = 0;
            y += 8;
        }
    }

    VideoState vState = { .section = DISPLAY, .hCounter = 0, .vCounter = 0 };

    unsigned renderCycles = 0;
    bool debug = argc > 2 && strcmp(argv[2], "y") == 0;
    bool waitForInput = true;
    VideoSection waitFor = NONE;
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
                    waitFor = VBLANK;
                } else if (strcmp(cmd, "h\n") == 0) {
                    printf("Waiting until hblank\n");
                    waitForInput = false;
                    waitFor = HBLANK;
                } else if (strcmp(cmd, "r\n") == 0) {
                    printRegisters(&PPU);
                } else if (strcmp(cmd, "s\n") == 0) {
                    Z80Regs regs = PPU.R1;
                    printf("Stack:\n");
                    unsigned sp = regs.wr.SP;
                    unsigned debugSPCopy = debugSP;
                    while (sp < STACK_TOP) {
                        byte b = ppuMemRead(EMU_PARAM, sp);
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
                } else if (strcmp(cmd, "d\n") == 0) {
                    printf("Waiting until display\n");
                    waitForInput = false;
                    waitFor = DISPLAY;
                } else if (cmd[0] == 'm' && strlen(cmd) > 1) {
                    int addr = strtol(cmd + 1, NULL, 16);
                    if (addr > -1) {
                        byte b = ppuMemRead(EMU_PARAM, addr);
                        printf("Byte at addr %x is %d\n", addr, b);
                    }
                } else if (strcmp(cmd, "dv\n") == 0) {
                    if (!vramDumpFile) {
                        vramDumpFile = fopen("vram.log", "w");
                    }
                    if (vramDumpFile) {
                        for (unsigned y = 0; y < SPRITE_ENTRIES_PIXELS_Y; y++) {
                            for (unsigned x = 0; x < SPRITE_ENTRIES_PIXELS_X; x++) {
                                fprintf(vramDumpFile, "|%x|", ppuMemRead(EMU_PARAM, PIXEL_MAP_ADDR + coordToVRAMAddr(x, y, 1)));
                            }
                            fprintf(vramDumpFile, "\n");
                        }
                    } else printf("Couldn't open vram.log\n");
                    fclose(vramDumpFile);
                    vramDumpFile = NULL;
                } else {
                    printf("Unrecognised command\n");
                }
            }
        } else {
            execute(&PPU);
            if (instrsToSkipForDebug > 0) instrsToSkipForDebug--;
            if (instrToSkipTo >= 0 && instrToSkipTo == PPU.PC) instrToSkipTo = -1;
        }
        VideoSection prevSection = vState.section;
        vStateCycle(&vState, renderer);
        vStateCycle(&vState, renderer);
        if (vState.section == VBLANK || vState.section == HBLANK) cyclesTakenToRenderAllSprites++;
        if (vState.section == HBLANK && prevSection != HBLANK) {
            SDL_RenderPresent(renderer);
            Z80INT(&PPU, 0);
            if (debug && printSectionChanges) printf("HBLANK triggered\n");
        } else if (vState.section == DISPLAY && prevSection != DISPLAY) {
            //printf("PPU was rendering for %d cycles\n", renderCycles);
            Z80NMI(&PPU);
            renderCycles = 0;
        } else if (vState.section == VBLANK && prevSection != VBLANK) {
            if (debug && printSectionChanges) printf("VBLANK triggered\n");
        }

        if (waitFor == vState.section && prevSection != vState.section) {
            waitFor = NONE;
            waitForInput = true;
        }

        if (vState.section == HBLANK || vState.section == VBLANK)
            renderCycles++;

        if (PPU.R1.wr.SP < STACK_BOTTOM) {
            printf("Stack overflowed to address %x at PC %x\n", PPU.R1.wr.SP, PPU.PC);
            printStackTrace();
            return 1;
        }
    }

    return 0;
}

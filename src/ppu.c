#define true 1
typedef unsigned char uint8_t;
typedef unsigned short uint16_t;
#define UINT8_MAX 0b11111111

#include "consts.h"

typedef struct __attribute__((packed)) {
    uint8_t animIndex : 8;
    uint8_t frameCounter : 8;
    uint8_t spriteIndex : 8;
} SpriteEntry;

typedef struct __attribute__((packed)) {
    uint8_t speed : 8;
    uint8_t nextAnimIndex : 8;
    uint8_t xOffset : 4;
    uint8_t yOffset : 4;
    uint8_t spriteOffset : 3;
    uint8_t horizontalFlip : 1;
    uint8_t verticalFlip : 1;
    uint8_t rotate : 1;
    uint8_t paletteOffset : 2;
} AnimationDef;

uint8_t colour = 0;

void render() {
    uint8_t* pixels = (uint8_t*)PIXEL_MAP_ADDR;
    unsigned spriteEntryX = 0;
    unsigned spriteEntryY = 0;
    uint8_t* entry = (uint8_t*)SPRITE_TABLE_ADDR;
    for (unsigned i = 0; i < SPRITE_ENTRIES_NUM; i++) {
        /*
        uint8_t animIndex = *entry++;
        uint8_t* animPtr = &animations[animIndex * sizeof(AnimationDef)];
        uint8_t speed = *animPtr++;
        uint8_t nextAnimIndex = *animPtr++;
        // Update the entry's frame counter if the animation has speed
        uint8_t frameCounter = *entry;
        if (speed != 0 && frameCounter == speed) {
            *entry = 0;
            *(entry - 1) = nextAnimIndex;
        } else {
            (*entry)++;
        }
        entry++;
        uint8_t animPosOffsets = *animPtr++;*/

        uint8_t xCoord = /*ANIM_X_OFFSET(animPosOffsets) + */spriteEntryX;
        uint8_t yCoord = /*ANIM_Y_OFFSET(animPosOffsets) + */spriteEntryY;
        /*uint8_t animMetadata = *animPtr++;
        uint8_t spriteIndex = *entry++ + ANIM_SPRITE_OFFSET(animMetadata);
        uint8_t* spriteAddr = &spriteDefs[spriteIndex * SPRITE_DEF_SIZE];
        */
        for (unsigned yi = 0; yi < SPRITE_DEF_PIXELS_Y; yi++, yCoord++) {
            // Make sure we haven't gone past the end of the column. We don't have to worry about the add overflowing since the animation offset and yi won't reach 256.
            if (yCoord >= SPRITE_ENTRIES_PIXELS_Y)
                break;
            uint8_t xCoordLocal = xCoord;
            for (unsigned xi = 0; xi < SPRITE_DEF_PIXELS_X; xi+=1, xCoordLocal+=1) {
                // Cut off one pixel from the end of the row just so we know we can render both pixels in this sprite byte
                if (xCoordLocal >= SPRITE_ENTRIES_PIXELS_X - 1)
                    continue;
                //uint8_t paletteIndices = *spriteAddr++;
                uint16_t addr = (yCoord << 8) | xCoordLocal;
                pixels[addr] = colour;
                //ppuRegs[(paletteIndices & 0xF) + REG_PALETTE_BASE];
                //ppuRegs[((paletteIndices & 0xF0) >> 4) + REG_PALETTE_BASE];
            }
        }
        colour++;
        spriteEntryX += SPRITE_DEF_PIXELS_X;
        // Move the pixel address to the start of the next line if we're at the end
        if (spriteEntryX == SPRITE_ENTRIES_PIXELS_X) {
            spriteEntryX = 0;
            spriteEntryY += SPRITE_DEF_PIXELS_Y;
        }
    }
}

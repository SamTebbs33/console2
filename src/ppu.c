typedef unsigned char uint8_t;
typedef unsigned short uint16_t;

#define SPRITE_DEF_NUM 255
#define SPRITE_DEF_PIXELS_NUM 64
#define SPRITE_DEF_PIXELS_X 8
#define SPRITE_DEF_PIXELS_Y 8
#define SPRITE_DEF_SIZE 32
#define SPRITE_DEF_MEM_SIZE (SPRITE_DEF_SIZE * SPRITE_DEF_NUM)

#define ANIM_DEF_SIZE (sizeof(AnimationDef))
#define ANIM_DEF_NUM 255

#define SPRITE_ENTRY_SIZE (sizeof(SpriteEntry))

#define SPRITE_ENTRIES_NUM_X 32
#define SPRITE_ENTRIES_NUM_Y 32
#define SPRITE_ENTRIES_NUM (SPRITE_ENTRIES_NUM_X * SPRITE_ENTRIES_NUM_Y)
#define SPRITE_ENTRIES_PIXELS_X (SPRITE_ENTRIES_NUM_X * SPRITE_DEF_PIXELS_X)
#define SPRITE_ENTRIES_PIXELS_Y (SPRITE_ENTRIES_NUM_Y * SPRITE_DEF_PIXELS_Y)

#define STACK_SIZE (2 * 1024)
#define PIXEL_MAP_ADDR (((uint16_t)32 * 1024) + STACK_SIZE)

typedef struct __attribute__((packed)) {
    uint8_t animIndex : 8;
    uint8_t spriteIndex : 8;
} SpriteEntry;

typedef struct __attribute__((packed)) {
    uint8_t nextAnimIndex : 8;
    uint8_t xOffset : 3;
    uint8_t yOffset : 3;
    uint8_t spriteOffset : 2;
} AnimationDef;

extern SpriteEntry spriteEntries[SPRITE_ENTRIES_NUM];
extern SpriteEntry tileEntries[SPRITE_ENTRIES_NUM];
extern uint16_t spriteDefs[SPRITE_DEF_NUM * (SPRITE_DEF_PIXELS_NUM / 4)];
extern AnimationDef animations[ANIM_DEF_NUM];

void render(SpriteEntry* src) {
    uint16_t pixelAddr = PIXEL_MAP_ADDR;
    unsigned spriteEntryX = 0;
    for (unsigned i = 0; i < SPRITE_ENTRIES_NUM; i++) {
        SpriteEntry entry = src[i];
        AnimationDef animDef = animations[entry.animIndex];
        spriteEntries[i].animIndex = animDef.nextAnimIndex;
        uint8_t spriteIndex = entry.spriteIndex + animDef.spriteOffset;
        // We load 2 bytes at a time, so multiply the index by the size of each def divided by 2
        uint16_t* spriteAddr = &spriteDefs[spriteIndex * (SPRITE_DEF_SIZE / 2)];
        uint16_t *renderAddr = (uint16_t*)(pixelAddr + animDef.xOffset + (animDef.yOffset * SPRITE_DEF_PIXELS_X));
        for (unsigned yi = 0; yi < SPRITE_DEF_PIXELS_Y; yi += 2, renderAddr -= SPRITE_ENTRIES_PIXELS_X + SPRITE_ENTRIES_PIXELS_X) {
            for (unsigned xi = 0; xi < SPRITE_DEF_PIXELS_X; xi += 2) {
                uint16_t pixels = *spriteAddr;
                *renderAddr = pixels;
                renderAddr++;
                spriteAddr++;
            }
        }
        spriteEntryX++;
        // Move the pixel address to the start of the next line if we're at the end
        if (spriteEntryX == SPRITE_ENTRIES_NUM_X) {
            pixelAddr = pixelAddr - SPRITE_ENTRIES_PIXELS_X + SPRITE_ENTRIES_PIXELS_Y;
            spriteEntryX = 0;
        } else {
            pixelAddr += SPRITE_DEF_PIXELS_X;
        }
    }
}

int main() __attribute((section(".start")));
int main() {
    render(spriteEntries);
    render(tileEntries);
    return 0;
}

#define ANIM_DEF_SIZE (4)
#define ANIM_DEF_NUM 255

#define PALETTE_DEF_COLOURS_NUM 16

#define SPRITE_ENTRY_SIZE (3)
#define SPRITE_ENTRIES_NUM_X 25
#define SPRITE_ENTRIES_NUM_Y 19
#define SPRITE_ENTRIES_NUM (SPRITE_ENTRIES_NUM_X * SPRITE_ENTRIES_NUM_Y)
#define SPRITE_ENTRIES_PIXELS_X (SPRITE_ENTRIES_NUM_X * SPRITE_DEF_PIXELS_X)
#define SPRITE_ENTRIES_PIXELS_Y (SPRITE_ENTRIES_NUM_Y * SPRITE_DEF_PIXELS_Y - 2)

#define SPRITE_DEF_NUM 255
#define SPRITE_DEF_PIXELS_X 8
#define SPRITE_DEF_PIXELS_Y 8
#define SPRITE_DEF_PIXELS_NUM (SPRITE_DEF_PIXELS_X * SPRITE_DEF_PIXELS_Y)
#define SPRITE_DEF_SIZE (SPRITE_DEF_PIXELS_NUM / 2)
#define SPRITE_DEF_MEM_SIZE (SPRITE_DEF_SIZE * SPRITE_DEF_NUM)

#define STACK_SIZE (2 * 1024)
#define PIXELS_SIZE (SPRITE_ENTRIES_PIXELS_Y * SPRITE_ENTRIES_PIXELS_X)

#define REG_PALETTE_BASE 0
#define REG_VIDEO_ON (REG_PALETTE_BASE + PALETTE_DEF_COLOURS_NUM)
#define PPU_REGS_NUM (PALETTE_DEF_COLOURS_NUM + 1)

#define SPRITE_TABLE_ADDR (8 * 1024)
#define TILE_TABLE_ADDR (SPRITE_TABLE_ADDR + (SPRITE_ENTRIES_NUM * SPRITE_ENTRY_SIZE))
#define PPU_REGS_ADDR (TILE_TABLE_ADDR + (SPRITE_ENTRIES_NUM * SPRITE_ENTRY_SIZE))
#define SPRITE_DEFS_ADDR (16 * 1024)
#define ANIMATION_DEFS_ADDR (SPRITE_DEFS_ADDR + SPRITE_DEF_MEM_SIZE)
#define PIXEL_MAP_ADDR ((unsigned long)32 * 1024)

#define ANIM_SPRITE_OFFSET(ANIM_METADATA) (ANIM_METADATA & 0xb111)
#define ANIM_PALETTE_OFFSET(ANIM_METADATA) ((ANIM_METADATA & 0xb11000000) >> 6)
#define ANIM_X_OFFSET(ANIM_POS_OFFSETS) (ANIM_POS_OFFSETS & 0xb1111)
#define ANIM_Y_OFFSET(ANIM_POS_OFFSETS) ((ANIM_POS_OFFSETS & 0xb11110000) >> 4)

#include <stdio.h>
#include "src/consts.h"
#include <string.h>
int main(int argc, char** argv) {
    if (strcmp(argv[1], "coord") == 0) {
        printf(".dcb.b 2, 0\n");
        for (unsigned char y = 0; y < 19 * 8; y += 8) {
            for (unsigned char x = 0; x < 25 * 8; x += 8) {
                printf(".dcb.w 1, %d\n", x | (y << 8));
                printf(".dcb.b 2, 0\n");
            }
        }
    } else if (strcmp(argv[1], "pixels") == 0) {
        unsigned pixelOffset = 0;
        for (unsigned y = 0; y < 600; y++) {
            for (unsigned x = 0; x < 800; x++) printf("Drawing from %x at %d,%d\n", pixelOffset++, x, y);
        }
    } else {
        for (unsigned char y = 0; y < 19 * 8; y++) {
            printf(".dcb.w 1, %d\n", y * 200);
        }
    }
    return 0;
}

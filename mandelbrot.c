#define STB_IMAGE_WRITE_IMPLEMENTATION
#include "stb_image_write.h"
#include <complex.h>
#include <stdint.h>

const int WIDTH = 768;
const int WIDTH_THIRD = 768 / 3;
const int HEIGHT = 512;
const int HEIGHT_HALF = HEIGHT / 2;
const int MAX_ITERS = 32;
typedef struct {
    uint8_t r;
    uint8_t g;
    uint8_t b;
} pixel;

int main(int argc, char **argv) {
    char *outfile = argc >= 2 ? argv[1] : "/tmp/mandelbrot.png";
    stbi_write_png_compression_level = 9;
    pixel *buf = malloc(WIDTH * HEIGHT * sizeof(pixel));
    memset(buf, 0, WIDTH * HEIGHT * sizeof(pixel));
    for (int px = 0; px < WIDTH; px++) {
        for (int py = 0; py < HEIGHT; py++) {
            double x = (double)px / WIDTH_THIRD - 2;
            double y = (double)py / HEIGHT_HALF - 1;
            int i = 0;
            double complex z = 0;
            double complex c = x + y * I;
            for (; i < MAX_ITERS && cabs(z) < 2.0; i++) {
                z = z*z + c;
            }
            if (i != MAX_ITERS) {
                pixel pix = { 0, 0, (uint8_t)((double)i / MAX_ITERS * 255) };
                buf[px + py * WIDTH] = pix;
            }
        }
    }
    if (stbi_write_png(outfile, WIDTH, HEIGHT, sizeof(pixel), buf, WIDTH * sizeof(pixel)) == 0) {
        printf("oh no it broke\n");
    }
    free(buf);
}
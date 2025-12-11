#include <errno.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <omp.h>

#include <stdint.h>

// ANSI background color sequences. We precompute the escape strings for all
// 256 xterm colors once, then reuse them per pixel to avoid formatting in the
// hot loop.
#define MAX_PALETTE_LEN 20
static char PALETTE[256][MAX_PALETTE_LEN];
static uint8_t PALETTE_LEN[256];

static size_t init_palette(void) {
    size_t max_len = 0;
    for (int i = 0; i < 256; ++i) {
        int len = snprintf(PALETTE[i], MAX_PALETTE_LEN, "\033[48;5;%dm \033[0m", i);
        if (len < 0 || len >= MAX_PALETTE_LEN) {
            len = MAX_PALETTE_LEN - 1;
            PALETTE[i][len] = '\0';
        }
        PALETTE_LEN[i] = (uint8_t)len;
        if ((size_t)len > max_len) {
            max_len = (size_t)len;
        }
    }
    return max_len;
}

static int parse_long(const char *s, long *out) {
    char *end = NULL;
    errno = 0;
    long v = strtol(s, &end, 10);
    if (errno || end == s || *end != '\0') {
        return -1;
    }
    *out = v;
    return 0;
}

static int parse_double(const char *s, double *out) {
    char *end = NULL;
    errno = 0;
    double v = strtod(s, &end);
    if (errno || end == s || *end != '\0') {
        return -1;
    }
    *out = v;
    return 0;
}

static inline uint8_t iteration_to_color(int iter, int max_iter) {
    // Match the original palette: interior = 16 (black), else 17 + scaled ramp.
    if (iter >= max_iter) {
        return 16;
    }
    const int idx = (int)((int64_t)iter * 200 / max_iter); // 0..199
    return (uint8_t)(17 + idx);                            // 17..216
}

int main(int argc, char **argv) {
    if (argc != 7) {
        fprintf(stderr,
                "Usage: %s <width> <height> <max_iter> <center_x> <center_y> <zoom>\n",
                argv[0]);
        return 1;
    }

    long width_l, height_l, max_iter_l;
    double center_x, center_y, zoom;

    if (parse_long(argv[1], &width_l) || parse_long(argv[2], &height_l) ||
        parse_long(argv[3], &max_iter_l) ||
        parse_double(argv[4], &center_x) ||
        parse_double(argv[5], &center_y) || parse_double(argv[6], &zoom)) {
        fprintf(stderr, "Invalid argument(s).\n");
        return 1;
    }

    if (width_l <= 0 || height_l <= 0 || max_iter_l <= 0 || zoom <= 0.0) {
        fprintf(stderr, "Arguments must be positive.\n");
        return 1;
    }

    const int width = (int)width_l;
    const int height = (int)height_l;
    const int max_iter = (int)max_iter_l;

    // Precompute the plane coordinates for each pixel column/row. This is
    // cache-friendly and saves redundant arithmetic in the hot loop.
    const double aspect = (double)height / (double)width;
    const double xmin = center_x - zoom;
    const double ymin = center_y - zoom * aspect;
    const double dx = (2.0 * zoom) / (double)width;
    const double dy = (2.0 * zoom * aspect) / (double)height;

    double *restrict xs = malloc((size_t)width * sizeof(double));
    double *restrict ys = malloc((size_t)height * sizeof(double));
    uint8_t *restrict colors = malloc((size_t)width * (size_t)height * sizeof(uint8_t));
    if (!xs || !ys || !colors) {
        fprintf(stderr, "Allocation failed.\n");
        free(xs);
        free(ys);
        free(colors);
        return 1;
    }

    for (int px = 0; px < width; ++px) {
        xs[px] = xmin + dx * (double)px;
    }
    for (int py = 0; py < height; ++py) {
        ys[py] = ymin + dy * (double)py;
    }

    // Compute iterations in parallel and store the resulting color index per
    // pixel. Output is produced in a second step to keep writes ordered.
    #pragma omp parallel for schedule(static)
    for (int py = 0; py < height; ++py) {
        const double y0 = ys[py];
        const size_t row_offset = (size_t)py * (size_t)width;

        for (int px = 0; px < width; ++px) {
            const double x0 = xs[px];
            double x = 0.0;
            double y = 0.0;
            double x2 = 0.0;
            double y2 = 0.0;
            int iter = 0;

            // Tight inner loop: keep squared terms, avoid sqrt, and let the
            // compiler vectorize. Branches are minimal and predictable.
            while ((x2 + y2 <= 4.0) && (iter < max_iter)) {
                y = 2.0 * x * y + y0;
                x = x2 - y2 + x0;
                x2 = x * x;
                y2 = y * y;
                ++iter;
            }

            colors[row_offset + (size_t)px] = iteration_to_color(iter, max_iter);
        }
    }

    const size_t max_palette_len = init_palette();
    const size_t row_buf_cap = (size_t)width * max_palette_len + 1;
    char *row_buf = malloc(row_buf_cap);
    if (!row_buf) {
        fprintf(stderr, "Allocation failed.\n");
        free(xs);
        free(ys);
        free(colors);
        return 1;
    }

    // Emit rows sequentially to keep stdout ordering stable.
    for (int py = 0; py < height; ++py) {
        char *p = row_buf;
        const size_t row_offset = (size_t)py * (size_t)width;
        for (int px = 0; px < width; ++px) {
            const uint8_t color = colors[row_offset + (size_t)px];
            const uint8_t len = PALETTE_LEN[color];
            memcpy(p, PALETTE[color], len);
            p += len;
        }
        *p++ = '\n';
        const size_t row_size = (size_t)(p - row_buf);
        if (write(STDOUT_FILENO, row_buf, row_size) < 0) {
            perror("write");
            free(row_buf);
            free(xs);
            free(ys);
            free(colors);
            return 1;
        }
    }

    free(row_buf);
    free(xs);
    free(ys);
    free(colors);
    return 0;
}

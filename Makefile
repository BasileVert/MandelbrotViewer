CC ?= gcc
CFLAGS ?= -O3 -march=native -std=c11 -Wall -Wextra -pedantic -pipe
OPENMP_FLAGS ?= -fopenmp
TARGET := mandelbrot_render
SRC := mandelbrot_render.c

.PHONY: all clean

all: $(TARGET)

$(TARGET): $(SRC)
	$(CC) $(CFLAGS) $(OPENMP_FLAGS) -o $@ $(SRC)

clean:
	$(RM) $(TARGET)

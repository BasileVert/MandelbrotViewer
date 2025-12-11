# Mandelbrot Viewer (Terminal)

Interactive Mandelbrot explorer for the terminal. The Bash front-end handles keyboard navigation; a high-performance C renderer computes colored frames with OpenMP.

## Features
- Arrow keys to pan; Space to zoom in; Backspace to zoom out; `q` to quit.
- ANSI 256-color background palette for a vivid render.
- Optimized C renderer with OpenMP and precomputed coordinates for speed.

## Requirements
- `gcc` or compatible C compiler
- OpenMP support (e.g., `-fopenmp`)
- `make`
- POSIX shell environment (tested with Bash)

## Build
```sh
make
```
This produces the renderer binary `./mandelbrot_render`.

## Run
```sh
./MandelbrotViewer.sh [width] [height] [max_iter]
```
- `width` (default 160): characters per line
- `height` (default 48): lines
- `max_iter` (default 800): iteration depth

Environment override:
- `RENDER_BIN=path/to/mandelbrot_render` to point to a custom renderer binary.

## Controls
- Arrow keys: pan
- Space: zoom in
- Backspace: zoom out
- `q`: quit

## Notes on Performance
- The renderer precomputes x/y coordinates per column/row to reduce arithmetic in the hot loop.
- Tight iteration loop keeps squared terms and minimizes branching; OpenMP parallelizes rows.
- ANSI color escape sequences are preformatted once and reused per pixel to cut formatting cost.

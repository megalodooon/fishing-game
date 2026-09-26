# Optimization and cleanup report

Date: 2026-09-26. All of this work was done overnight on this laptop (GeForce
940MX, Windows 10, Godot 4.7.2) and pushed to
<https://github.com/megalodooon/fishing-game>.

**The rule for every change: the game must look and play exactly the same.**
Any change that could affect rendering was checked by comparing 23 test
frames pixel by pixel against the original build (see
[How it was verified](#how-it-was-verified)). Every kept change is
**bit-identical** on both renderers the game uses: the desktop D3D12
"Mobile" renderer, and the OpenGL/WebGL "Compatibility" renderer that the
web build uses. Changes that could not be made exact were reverted. They are
listed under [Tried and rejected](#tried-and-rejected).

## Summary

| What | Before | After | Change |
|---|---|---|---|
| GPU time per frame, desktop renderer (average of 4 test scenes) | 6.68 ms | 4.80 ms | **-28.1% (1.39x faster)** |
| GPU time per frame, desktop renderer, boat stopped | 5.87 ms | 3.84 ms | **-34.6% (1.53x faster)** |
| GPU time per frame, web renderer (average of 4 test scenes) | 7.19 ms | 5.79 ms | **-19.5% (1.24x faster)** |
| GPU time per frame at a vsync-locked 60 fps (desktop, day) | 7.20 ms | 6.17 ms | -14.3% (1.17x), and at a lower GPU clock |
| CPU time of the whole game process per frame at 60 fps (desktop, day) | 4.87 ms | 4.61 ms | -5.4% (1.06x) |
| Frame time while sailing at cruise speed, uncapped | 9.36 ms (107 fps) | 8.53 ms (117 fps) | **-8.9% (1.10x faster)** |
| Frame time while sailing at full speed, uncapped | 10.02 ms (100 fps) | 8.27 ms (121 fps) | **-17.5% (1.21x faster)** |
| Slowest 1% of frames at full speed | 20.0 ms | 15.2 ms | **-24% (1.32x faster)** |
| Game logic per frame (CPU, average of 3 scenes) | 0.86 ms | 0.74 ms | -14% (1.17x faster) |
| Time to the first frame | 342 ms | 210 ms | **-38.5% (1.63x faster)** |
| Loading plus the first 10 frames | 914 ms | 831 ms | -9.1% (1.10x faster) |
| Building the ripple distance field (at startup) | ~270 ms | ~120 ms | **-56% (2.2x faster)** |
| Pixels that changed in the 23 test frames (both renderers) | | 0 | identical |

In short, the GPU does about 28% less work per frame, and about 35% less
while the boat is stopped. Frames while sailing are 10-21% faster, and the
slowest frames are up to 24% shorter. The game starts faster. The web
version is live and redeploys itself on every push.

## Web version

- Play: <https://megalodooon.github.io/fishing-game/>
- Every push to `main` runs `.github/workflows/deploy-web.yml`. The workflow:
  1. downloads the official Godot 4.7.2 Linux editor and web export template
     (cached after the first run);
  2. exports the project;
  3. publishes it to GitHub Pages.

  A deploy takes about a minute.
- The export is single-threaded, so it needs no special server headers
  (GitHub Pages cannot send them). GitHub Pages gzips the engine, so the
  39.5 MB file is a 10.2 MB download.
- One project setting applies only to the web build:
  `display/window/stretch/aspect.web = "keep"`. A browser window is almost
  never an exact multiple of 192x108. With this setting the web build shows
  exactly the 192x108 view, at the largest integer scale, with black bars.
  That matches how the game looks at 1920x1080 on desktop. The desktop
  build is unchanged.
- Web fidelity fix: the Compatibility renderer does not accumulate alpha
  inside a `CanvasGroup`, so the foam looked thin and lacy in the browser.
  The foam shader now reads its density from the red channel. The particles
  are white, and red blends the same way alpha did. On desktop the result is
  pixel-identical, and in the browser the foam now matches the desktop.
- Tested in a browser:
  - loading, walking, and equipping the rod;
  - charging, casting, the "can't reach" rule, and reeling;
  - skipping hours and the night lighting;
  - resizing the window and high-DPI scaling.
- Checked again at the end in a real Edge window at this laptop's 150%
  display scaling (a device pixel ratio of 1.5). The game shows the full view
  at an integer scale, centered, with nothing cut off. The browser preview
  pane inside the Claude app shows the game cropped, because of how it
  emulates the window size. Real browsers don't do this.
- Known harmless message: at startup, the browser console shows two
  `WebGL: INVALID_OPERATION: bindBuffer/bufferSubData` warnings. They come
  from Godot's WebGL backend, not from the project, and nothing visible is
  affected.

## Changes, one by one

GPU numbers are milliseconds of GPU time per frame at 1920x1080 on the
GeForce 940MX. Each is the sum over all viewports and the median of 3
interleaved runs of 300 frames per scene. The four test scenes:

- **Day** is the default scene.
- **Night** adds the day/night overlay and the lantern.
- **Fishing** has a cast line and the bobber in the water.
- **Stopped** is the boat at anchor.

The GPU tables for changes 1-4 compare each commit with the one before it.
These step-by-step numbers come from one measurement session. The [Whole project](#whole-project)
numbers come from a separate final session, which is why the steps do not
multiply out to the total exactly.

### 1. Clip the boat's sprites to their art (`b1d51d0`, hardened in `e7fccc7`)

The boat sprites are 96x92 textures, but only 7-49% of each texture is art
(the sail 7%, the mast 10%, the hull front 29%, the deck 49%). Godot shaded
every pixel of the full rectangle, including the waterline shader on the
deck and hull and the wind shader on the sail. Each sprite now gets a
scissor clip around its art plus a margin (4 pixels, 2 for the waterline
sprites; the sail's wind moves pixels by up to 3). The rectangle and its
texture coordinates are unchanged, so every pixel that is still drawn
computes exactly what it did before. The clip updates itself if a texture
changes or a sprite is attached (for future boat upgrades).

| Scenario | Before | After | Change |
|---|---|---|---|
| Day | 6.80 ms | 5.63 ms | -17.2% (1.21x) |
| Night | 7.15 ms | 6.08 ms | -14.9% (1.18x) |
| Fishing | 6.70 ms | 5.61 ms | -16.3% (1.19x) |
| Stopped | 5.97 ms | 5.00 ms | -16.1% (1.19x) |
| **Average** | **6.65 ms** | **5.58 ms** | **-16.1% (1.19x)** |

### 2. Skip the wake while stopped, render the ground only when it scrolls (`ec49165`)

- While the boat is completely stopped, the wake distortion writes back
  exactly the pixels it copied, so its full-screen back-buffer copy (the
  most expensive part) and its shader are switched off until the boat
  moves. The foam particles keep simulating, so starting again looks
  exactly as before.
- The seabed is rendered into a small texture first. It has no time input,
  so its picture only changes when its whole-pixel scroll changes (every
  ~6 frames at cruise speed); it now only re-renders then. The editor still
  re-renders every frame so tweaking stays live.
- The boat only pushes its "motion" value to the effects when it changes.

| Scenario | Before | After | Change |
|---|---|---|---|
| Day | 5.63 ms | 5.53 ms | -1.8% (1.02x) |
| Night | 6.08 ms | 6.00 ms | -1.4% (1.01x) |
| Fishing | 5.61 ms | 5.48 ms | -2.4% (1.02x) |
| Stopped | 5.00 ms | 4.23 ms | **-15.4% (1.18x)** |
| **Average** | **5.58 ms** | **5.31 ms** | **-4.9% (1.05x)** |

### 3. Don't shade ripples under the deck (`58b3cec`, hardened in `e7fccc7`)

The ripple rings are drawn as one big rectangle around the boat (about
140x72 game pixels), and the deck covers a large part of it. The rectangle
is now drawn as four scissor-clipped bands around the part of the deck
that is always opaque. That area is computed from the deck art and the
waterline settings with a safety margin, and it follows the deck as it
bobs. All four bands draw the identical rectangle, so the ripple pixels
that are still drawn are bit-identical and the skipped ones were always
covered by the deck. The ripple shader settings are now read once instead
of five renderer queries every frame; this also fixed an error flood when
the game runs without a renderer (headless).

| Scenario | Before | After | Change |
|---|---|---|---|
| Day | 5.53 ms | 5.03 ms | -9.1% (1.10x) |
| Night | 6.00 ms | 5.54 ms | -7.6% (1.08x) |
| Fishing | 5.48 ms | 5.15 ms | -5.9% (1.06x) |
| Stopped | 4.23 ms | 4.04 ms | -4.4% (1.05x) |
| **Average** | **5.31 ms** | **4.94 ms** | **-6.9% (1.07x)** |

### 4. Don't shade water under the deck (`df98497`)

The same idea for the full-screen water shader, the most expensive thing in
the game: the water is drawn as four clipped bands that issue the exact
same draw command the sprite did, leaving out the always-opaque deck area.
That area is computed so it stays inside the deck even if the boat is ever
tilted or flipped (checked with a tilted and a flipped boat). The editor
still shows the plain sprite.

| Scenario | Before | After | Change |
|---|---|---|---|
| Day | 5.03 ms | 5.18 ms | +3.1% (noise, see below) |
| Night | 5.54 ms | 5.48 ms | -1.1% (1.01x) |
| Fishing | 5.15 ms | 4.97 ms | -3.5% (1.04x) |
| Stopped | 4.04 ms | 3.83 ms | -5.4% (1.06x) |
| **Average** | **4.94 ms** | **4.87 ms** | **-1.5% (1.02x)** |

This one is close to the measurement noise (about +-0.1 ms). A dedicated
alternating A/B test of just this change measured 5.22 -> 5.04 ms by day
(-3.4%, 1.04x).

### 5. Build the ripple distance field 2.2x faster (`d0994ba`)

At startup (and whenever a ripple setting is edited in the editor) the
ripples compute a distance field of the hull in GDScript. The distance
transform now evaluates its parabola intersections inline and writes
straight into the grid, and the blur skips clamping in the interior. Every
float operation keeps its order and precision, so the texture is
byte-for-byte identical (checked against the old code).

| Metric | Before | After | Change |
|---|---|---|---|
| Ripple field build | 262-281 ms | 115-125 ms | -56% (2.2x) |

### 6. Push ocean parameters only when they change (`53dbfc8`)

The ocean sent about a dozen renderer calls every frame (and built
parameter-name strings) although only the scroll offset changes per
frame; the field and caustic origins only change on whole-pixel scroll
steps. The water bands are only re-recorded when their rectangles change.

| Function (per frame) | Before | After | Change |
|---|---|---|---|
| Ocean `update_fields` | 17.2 us | 4.4 us | -74% (3.9x) |
| Ripple `update_shader` (from change 3) | 12.4 us | 7.1 us | -43% (1.7x) |

### 7. Cleanup, structure and robustness (`d1e47bc`, `eaecda6`, `529e83d`, `e7fccc7`)

- **Deleted unused files:** `boat/basic/basic_boat.png` and
  `boat/basic/basic_boat_top.png` (referenced nowhere, but shipped in the web
  build).
- **Removed unused shader inputs:** `water.gdshader` declared six uniforms it
  never read (`depth_scale`, `depth_contrast`, `depth_speed`,
  `caustic_speed`, `caustic_coverage`, `caustic_patch_size`; they belong to
  the ocean's field and caustic passes). The ocean script now only sends a
  setting to the shaders that actually declare it.
- **Removed dead data:** the Ground material in `basic_ocean.tscn` stored
  values that the ground script overwrites on its first frame (and they
  were misleading, e.g. relief 0.6 while the real value is 0.35).
- **Moved code:** the generic clipping helpers are in their own small class,
  `components/canvas_clip/canvas_clip.gd` (`CanvasClip`), instead of inside
  the boat. One instance manages the clipped bands used by the ripples and
  the water, so that code is no longer duplicated.
- **Lantern flicker runs on game time** instead of the wall clock (same
  amount and speed; it now respects `Engine.time_scale` and night frames
  can be regression-tested).
- **Editor safety:** the ripple bands are created on first use, so a script
  hot-reload in the editor can no longer leave them empty and flood the
  output with errors.
- Looked for but kept: the boat upgrade API (`Boat.upgrade`,
  `remove_upgrade`, `BoatUpgrade`) is unused today but is the planned
  upgrade system; `OceanGround.newSeedButton` is an editor tool button.

### 8. Stop resizing the caustic passes while scrolling (`bb0a7c4`)

The caustics come from two small SubViewports, about 38x24 and 31x19
texels, that hold one animated value per caustic cell. Their size was
computed from the range of cells under the water at the current scroll
position, and that range flips between two sizes as the ocean scrolls.
Every flip reallocated a render target. That happened about 117 times per
200 pixels of scrolling: 6 times a second at cruise speed, and 29 at full
speed. Each one cost about 0.65 ms of main-thread time, plus rebuilding
the texture on the GPU side.

The size now comes from the area's size alone, with room for every scroll
position, so it never changes while sailing. The water shader reads the
cells with `texelFetch` at absolute cell coordinates and never reads the
extra row and column, so the picture is bit-identical.

| Metric | Before | After | Change |
|---|---|---|---|
| Render-target reallocations per 200 px of scrolling | 117 | 0 | gone |
| Ocean `update_fields`, average per frame at cruise speed | 75 us | 17 us | -77% (4.3x) |
| Frame time at cruise speed, uncapped (mean) | 8.69 ms | 8.49 ms | -2.3% (1.02x) |
| Slowest 1% of frames at cruise speed | 18.3 ms | 15.6 ms | -15% (1.17x) |
| Frame time at full speed, uncapped (mean) | 9.14 ms | 8.28 ms | -9.4% (1.10x) |
| Slowest 1% of frames at full speed | 19.0 ms | 15.2 ms | -20% (1.25x) |

Frame times are wall-clock times per frame with vsync off. Each value is
the mean of two alternating runs of 3000 frames per version.

### 9. Faster fishing line constraints (`10c52a3`)

The rod's update is the most expensive script in the game. About 40% of it
is the loop that relaxes the fishing line, a 13-point rope, 6 times per
physics tick. In that loop the end segments multiplied their correction by
0 or 1 before adding it, and every segment picked its weights with two
branches. The loop now handles the fixed first point, the last segment and
the middle segments separately, with the same float operations in the same
order.

The rope is bit-identical. Its full state (points, velocities, bend,
tension, and the drawn line) was recorded for 570 physics ticks of holding,
casting, floating and reeling, and every tick matches the old code. A
deliberate change of 0.00005% in one factor makes 566 of the 570 ticks
differ, so the check is sensitive enough.

| Function (per physics tick) | Before | After | Change |
|---|---|---|---|
| Line constraint loop | 52 us | 39 us | -26% (1.36x) |
| Whole rod update | 130 us | 110 us | -15% (1.18x) |

### 10. Web build (`6fcd30e`)

See [Web version](#web-version). This commit is also the "before" of every
comparison in this report (it only adds the export setup and the foam fix,
which is pixel-identical on desktop).

## Whole project

The original build (`6fcd30e`) against the final build (`e7fccc7`), measured
together in one final session. Changes 8 and 9 came after that session. They
don't change what is drawn, and they only make the game faster; their own
sections and the sailing table below show their effect.

### GPU time per frame, desktop renderer (D3D12)

| Scene | Before | After | Change |
|---|---|---|---|
| Day | 6.86 ms | 5.06 ms | -26.2% (1.36x) |
| Night | 7.26 ms | 5.29 ms | -27.1% (1.37x) |
| Fishing | 6.73 ms | 5.02 ms | -25.4% (1.34x) |
| Stopped | 5.87 ms | 3.84 ms | -34.6% (1.53x) |
| **Average** | **6.68 ms** | **4.80 ms** | **-28.1% (1.39x)** |

### GPU time per frame, web renderer (Compatibility / OpenGL)

| Scene | Before | After | Change |
|---|---|---|---|
| Day | 7.14 ms | 5.83 ms | -18.4% (1.23x) |
| Night | 7.81 ms | 6.48 ms | -17.1% (1.21x) |
| Fishing | 7.34 ms | 6.09 ms | -17.0% (1.21x) |
| Stopped | 6.45 ms | 4.75 ms | -26.4% (1.36x) |
| **Average** | **7.19 ms** | **5.79 ms** | **-19.5% (1.24x)** |

### Frame time with vsync off

From the final GPU session (before changes 8 and 9), in the four test scenes.

| Scene | Before | After | Change |
|---|---|---|---|
| Desktop renderer, day | 9.08 ms (110 fps) | 8.75 ms (114 fps) | -3.6% (1.04x) |
| Desktop renderer, stopped | 9.70 ms (103 fps) | 8.90 ms (112 fps) | -8.2% (1.09x) |
| Web renderer, day | 11.18 ms (89 fps) | 10.68 ms (94 fps) | -4.5% (1.05x) |
| Web renderer, stopped | 11.64 ms (86 fps) | 9.83 ms (102 fps) | -15.5% (1.18x) |

On this laptop, the uncapped frame time is longer than the GPU time. It is
set mostly by costs these changes don't touch, on the CPU side and in
presenting the frame. So the uncapped frame rate rises less than the GPU
time falls. In normal play the game runs at 60 fps with vsync, and there the
saving shows up differently (see [At 60 fps](#at-60-fps-normal-play)).

### Frame time while sailing (vsync off)

This table includes changes 8 and 9. Each value is the wall-clock time per
frame over 3000 frames, as the mean of two alternating runs per version.

| Speed | Measure | Before | After | Change |
|---|---|---|---|---|
| Cruise | Mean | 9.36 ms (107 fps) | 8.53 ms (117 fps) | -8.9% (1.10x) |
| Cruise | Median | 8.56 ms | 8.23 ms | -3.8% (1.04x) |
| Cruise | Slowest 1% | 18.34 ms | 15.42 ms | -15.9% (1.19x) |
| Full | Mean | 10.02 ms (100 fps) | 8.27 ms (121 fps) | -17.5% (1.21x) |
| Full | Median | 9.43 ms | 7.75 ms | -17.8% (1.22x) |
| Full | Slowest 1% | 20.03 ms | 15.15 ms | -24.4% (1.32x) |

The slow frames that remain (with vsync off) are spread over ordinary frames,
not tied to any game event such as a seabed re-render or a new column of
decorations. Each one is followed by an unusually fast frame. That pattern
points at the graphics driver's frame presentation rather than at the game,
and vsync absorbs it in normal play.

### At 60 fps (normal play)

These numbers are for the day scene at the usual vsync-locked 60 fps. The
CPU time is the total for the whole game process, on all threads: game
logic, rendering, and the graphics driver. It was sampled from outside over
15 seconds. Each value is the median of 3 interleaved runs.

| Measure | Before | After | Change |
|---|---|---|---|
| Desktop renderer, GPU time per frame | 7.20 ms | 6.17 ms | -14.3% (1.17x) |
| Desktop renderer, CPU time per frame | 4.87 ms | 4.61 ms | -5.4% (1.06x) |
| Web renderer, GPU time per frame | 7.99 ms | 6.90 ms | -13.6% (1.16x) |
| Web renderer, CPU time per frame | 9.53 ms | 9.42 ms | -1.2% (within noise) |

At 60 fps the GPU has spare time, so the driver lowers its clock, and lowers
it further when there is less work. That is why these GPU times are longer
than in the uncapped tables and fall by less: part of the saving is taken as
a lower clock (less power) instead of a shorter frame.

With OpenGL, the process uses the same CPU time before and after. Godot's
own render-CPU timer for OpenGL varied by up to 30% between identical runs,
so it was not used.

### Game logic (CPU)

Timed without rendering (headless) over 3000 frames per scene, median of
3 runs. These timings are noisy (about +-15% between runs), so treat them as
a trend.

| Scene | Before | After | Change |
|---|---|---|---|
| Day | 0.76 ms | 0.68 ms | -10.1% (1.11x) |
| Night | 0.87 ms | 0.74 ms | -15.5% (1.18x) |
| Fishing | 0.95 ms | 0.79 ms | -16.6% (1.20x) |
| **Average** | **0.86 ms** | **0.74 ms** | **-14.3% (1.17x)** |

### Per-frame script costs

Each function was called 2000 times in the real renderer and timed. The
table lists the functions that changed, plus the new band bookkeeping.

| Function (per frame) | Before | After | Change |
|---|---|---|---|
| Ocean `update_fields` | 20.2 us | 6.4 us | -68% (3.1x) |
| Ground `_process` | 21.4 us | 3.7 us | -83% (5.8x) |
| Boat `_process` | 10.6 us | 1.8 us | -83% (5.9x) |
| Ripples `update_shader` | 16.2 us | 9.6 us | -41% (1.7x) |
| Water bands (new) | | 21 us | |
| Ripple bands (new) | | 24 us | |

About every sixth frame at cruise speed, the ocean and the ground take a
whole-pixel scroll step and push their settings. Before change 8, about
half of those steps also reallocated the caustic render targets. Change 8
shows the average cost including the steps.

Before changes 8 and 9, the scripts did about the same work per frame as the
original. The bookkeeping for the clipped bands (about 0.045 ms per frame)
cost about what the other script changes saved, and it pays for about 0.5 ms
of GPU time per frame (changes 3 and 4). Changes 8 and 9 then removed about
another 0.08 ms of script time per frame at cruise speed, and more at full
speed.

### Startup

Measured from loading the scene to the tenth frame, median of 3 runs.

| Metric | Before | After | Change |
|---|---|---|---|
| First frame | 342 ms | 210 ms | -38.5% (1.63x) |
| Loading plus the first 10 frames | 914 ms | 831 ms | -9.1% (1.10x) |

Most of this comes from the faster ripple distance field (change 5).

### Other checks

- **Draw calls:** 25 → 30 per frame. The clipped bands for the water and the
  ripples are separate draws. Each is cheap, and the GPU time above already
  includes them.
- **Video memory, objects, primitives:** unchanged.
- **Web download:** unchanged (10.2 MB gzipped). The two deleted images were
  only about 2 KB.
- **GDScript warnings:** zero.

## How it was verified

- **Pixel-exact regression test.** A capture script runs the test scene at a
  fixed 60 fps, with a fixed random seed and a fixed aim point that is set
  before every physics tick. The lantern flicker is turned off, because the
  original flicker used the wall clock.
  The script saves 23 frames covering:
  - the first frames, day, sunrise, dusk, and night;
  - casting, and the bobber in the water;
  - walking behind the mast, and standing at the rim (shadow clipping);
  - the boat slowing down, stopped, stopped at night, and speeding up again.

  Two runs of the same build are bit-identical, even with the mouse cursor
  in different places, so any difference means a real change. Against the
  original build, every kept change produces 23/23 identical frames on both
  renderers. The final build was checked again at the end with the scripts
  in `tools/perf`.

  At first the script set the aim point only once per frame, after the
  physics tick. So on the first tick, and right after the hand went idle,
  the player aimed at the real mouse cursor. That was found and fixed at the
  end (`4b9b3a9`). The flaw could only make identical builds look
  different, never hide a real difference, so the earlier results stand.
- **Mutation test.** At runtime, the test tilts and flips the boat, swaps
  the sail and deck textures, and attaches a new sprite to the mast. It checks
  that the clipping follows and that the frames still match the original
  build (7/7 identical on both renderers).
- **Rope trace.** For change 9, the rope's full state was hashed on every
  physics tick and compared with the old code: 570/570 identical.
- **GPU timing.** The measure is
  `RenderingServer.viewport_get_measured_render_time_gpu`, summed over the
  main viewport and all internal SubViewports. Settings: vsync off,
  fullscreen 1080p, 300 frames per scene after a warm-up. Results are
  medians of interleaved runs, because the laptop's GPU clock moves between
  about 970 and 1160 MHz under load and a single run is noisy by about
  +-0.1 ms.
- **Per-part cost.** Each part of the scene was hidden in turn to see what
  it costs. Godot's `--gpu-profile` confirmed the GPU work in each frame.
- **CPU.**
  - Game logic was timed headless (no rendering).
  - Whole-process CPU use was sampled from outside at a locked 60 fps.
  - Individual per-frame functions were micro-benchmarked in the real
    renderer.
  - Startup was timed from loading the scene to the tenth frame.
- **Other checks:**
  - draw calls, objects, primitives, and video memory per frame;
  - web download size and compression;
  - browser behaviour;
  - GDScript warnings (zero, checked through Godot's language server).

### Re-running the checks

The scripts are in `tools/perf`. That folder is outside the Godot project,
so the editor ignores them. Run the commands in PowerShell from the
repository root, with `godot` meaning the Godot editor executable. For the
web renderer, add
`--rendering-method gl_compatibility --rendering-driver opengl3` after
`--fullscreen`.

```powershell
# Pixel test: capture the 23 frames (needs a 1920x1080 screen), then compare
# them with frames captured from another build or commit.
godot --path godot --fullscreen --fixed-fps 60 -s "$PWD\tools\perf\capture.gd" -- "$PWD\build\frames\after"
godot --headless --path godot -s "$PWD\tools\perf\compare.gd" -- "$PWD\build\frames\before" "$PWD\build\frames\after"

# GPU benchmark of the four scenes ("once" for a single round, "breakdown" for the cost of each part).
godot --path godot --fullscreen --fixed-fps 60 -s "$PWD\tools\perf\bench.gd" -- scenarios

# Game logic without rendering, and startup time.
godot --headless --path godot --fixed-fps 60 -s "$PWD\tools\perf\cpubench.gd"
godot --path godot --fullscreen -s "$PWD\tools\perf\startup.gd"
```

## Tried and rejected

| Idea | Why it was dropped |
|---|---|
| Copy only the wake's area for the wake distortion (`BackBufferCopy` in RECT mode, would save ~0.35 ms while moving) | Godot 4.7 computes the copy rectangle without the `canvas_items` stretch, so it copies the wrong area: the wake showed the seabed instead of the water (12% of pixels wrong). Kept the full-screen copy. |
| Crop the boat sprites with `region_rect` instead of a scissor clip | Changes how texture coordinates are interpolated; a few hundred pixels per frame changed (texel picks flipping at edges). The scissor clip gives the same speed-up exactly. |
| Split the foam into separate stern and bow canvas groups | Not exact (+-1 in a few hundred pixels) and slower (+0.3 ms): every canvas group has a fixed cost. |
| Shrink the foam canvas group's margins | Moves the group's rectangle, which shifts the foam's noise pattern by +-1 in up to 28 pixels. |
| Tint with `CanvasModulate` instead of the night overlay | The water and wake read the screen, so they would be darkened twice. |
| A deeper rewrite of the fishing-line rope simulation (reordering or combining its math) | That changes floating-point rounding, which moves the line by fractions of a pixel. Change 9 instead removes work without changing any float operation. |
| Lower-resolution caustics or ripples, fewer ripple rings, GPU particles for the foam, a frame-rate cap | All of these change how the game looks or feels. They are listed below as options for you to decide on. |

## What still costs the most

Here is what each part of the final build costs, for the day scene on the
desktop renderer (GPU ms per frame). Each part was measured by hiding it, so
the parts overlap a little and don't add up exactly to the 5.08 ms total.

| Part | GPU time | Share |
|---|---|---|
| Water shader (the whole screen) | 2.03 ms | 40% |
| Ripples | 1.14 ms | 22% |
| Boat sprites (deck, hull, mast, sail) | 0.70 ms | 14% |
| Wake distortion (0.35 ms of it is the full-screen copy) | 0.58 ms | 11% |
| Foam | 0.58 ms | 11% |
| Seabed | 0.38 ms | 8% |
| Ocean field and caustic passes | 0.12 ms | 2% |
| Night overlay and lantern (night only) | about 0.23 ms | |
| Player, fishing spots, HUD, decorations | about 0 | |

The `canvas_items` stretch mode runs every shader once per screen pixel.
At 1920x1080 that is 100 times per game pixel. This keeps the effects
smooth, and it is why the water and the ripples dominate.

These options would make the game faster, but they change how it looks, so
I did not do them. They are yours to decide on:

- **Render the water, or the water and the ripples, at a lower internal
  resolution.** At half resolution (960x540) there are 4x fewer water
  pixels, which could save up to about 1.5 ms. Fine water detail would get
  slightly softer.
- **Fewer or shorter-lived ripple rings.** This would save part of the
  1.1 ms.
- **GPU particles for the foam.** This would move the particle simulation
  off the CPU, but the foam pattern would be different.
- **A 60 fps cap.** On 120 or 144 Hz screens the game currently renders
  2-2.4x as many frames. A cap would save that work there, at the cost of
  less smooth motion. It makes no difference on 60 Hz screens.
- **Wake copy.** If a future Godot version fixes the rectangular
  `BackBufferCopy` under `canvas_items` stretch (see above), copying only
  the wake's area would save about 0.35 ms with identical output.

## Notes

- The Godot editor was open when the work started and closed before the
  benchmarks ran. When you next open the project, let it re-import: two
  unused images were deleted and one script was added.
- `OceanGround` now re-renders only when its whole-pixel scroll changes. If
  game code ever changes a ground setting at runtime, call `refresh()` on it.
  The editor still updates live.
- The foam particles must stay white, because their color is used only as
  density.
- The clipping in `CanvasClip` follows texture swaps and added sprites.
  The skipped deck area stays inside the deck when the boat bobs, tilts or
  is flipped (all tested). The water and ripple bands need the water and
  ripple nodes themselves to be drawn without rotation and at an integer
  scale, as they are now. Otherwise they fall back to one full rectangle,
  which is always correct.

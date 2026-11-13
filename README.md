# Shader Library

Standalone GLSL fragment shaders against a resolution and time uniform pair, with one Metal port and rendered previews.

![Seven square shader renders in a grid, each labelled with its file name: a magenta and blue radial gradient, a black and white checkerboard, a black and white ten-armed spiral, a cyan to magenta corner gradient, grey static noise, coloured horizontal bands, and a thin green heartbeat line on black.](docs/contact-sheet.jpg)

## What this is

A shader is a small program that runs on the graphics card. A fragment shader runs once for every pixel on the screen, at the same time, and decides that pixel's colour. GLSL (OpenGL Shading Language) is the language most of these are written in.

Each file here is one `main()` function that reads two inputs: `resolution` (the size of the screen in pixels) and `time` (seconds since the start). There is no framework around them, so they drop into whatever you already have. One shader also has a version for Metal, the graphics system on Apple devices.

The repository also holds an archive of 44 public shaders from the author's Shadertoy account. Shadertoy is a website where people write and share shaders that run in the browser.

## What you can learn from it

- How a graphics card draws a picture by running the same small program for every pixel in parallel (Computer Science).
- How to normalise coordinates, so a pixel position becomes a number from 0 to 1 that works on any screen size (Mathematics).
- How polar coordinates (an angle and a distance from the centre) make spirals and circles (Mathematics).
- How sine waves make repeating stripes and smooth animation over time (Mathematics, Physics).
- How a hash function makes numbers that look random, the basis of procedural noise (Computer Science).
- How a build system can check code for errors automatically (Computer Science).

## Run it

### In your browser

The shaders in the [Shadertoy archive](shadertoy/README.md) each link to their original page on Shadertoy, where they run live. Open the archive list and choose a Shadertoy ID.

The standalone shaders use different names for their inputs than Shadertoy does. To try one on Shadertoy, rename the inputs and wrap the code in Shadertoy's `mainImage` function. Here is `HypnosisSpiral.h` converted:

1. Go to [Shadertoy](https://www.shadertoy.com/) and choose **New** to open the editor.
2. Delete the example code and paste this:

   ```glsl
   void mainImage(out vec4 fragColor, in vec2 fragCoord)
   {
       vec2 uv = fragCoord / iResolution.xy;
       vec2 center = uv - 0.5;
       float angle = atan(center.y, center.x) + iTime;
       float radius = length(center);
       float spiral = sin(angle * 10.0 - radius * 20.0) * 0.5 + 0.5;
       fragColor = vec4(vec3(spiral), 1.0);
   }
   ```

3. Press the play button under the code (or Alt and Enter) to compile it.

You should see a black and white spiral with ten arms, turning slowly.

The same three changes work for the other files: `resolution` becomes `iResolution.xy`, `time` becomes `iTime`, and `gl_FragCoord.xy` becomes `fragCoord`.

### On your own computer

The repository has a check that wraps each standalone shader and tests that it compiles. It does not draw anything on screen.

**You will need:**

- [CMake](https://cmake.org/download/) 3.20 or later, a tool that runs build steps.
- [Python 3](https://www.python.org/downloads/).
- `glslangValidator`, the reference GLSL compiler from the [Khronos glslang project](https://github.com/KhronosGroup/glslang). On macOS it comes with Homebrew's `glslang` package. On Ubuntu it is in `glslang-tools`.

Tested on macOS with CMake 4.4. The project's automatic checks also run on Ubuntu.

1. Download the repository (**Code**, then **Download ZIP**) and unzip it.
2. Open a terminal in the unzipped folder.
3. Run:

   ```sh
   cmake -S . -B build/legacy -DSHADERLIB_USE_CUSTOM_RULES=OFF
   cmake --build build/legacy
   ctest --test-dir build/legacy --output-on-failure
   ```

The build prints one "Generating validated/..." line per shader. The last command should end with `100% tests passed out of 1`.

## How it works

Every standalone shader starts the same way. It divides the pixel position `gl_FragCoord.xy` by `resolution` to get `uv`, a pair of numbers from 0 to 1 across the screen. Then it does some maths on `uv` and `time` and writes a colour. A colour is four numbers from 0 to 1: red, green, blue and opacity.

For example, `HypnosisSpiral.h` moves the origin to the centre, works out the angle and distance of each pixel, and takes `sin(angle * 10 - radius * 20)`. Pixels where the result is high are white and pixels where it is low are black. Adding `time` to the angle makes the spiral turn.

| File or folder | What is in it |
|---|---|
| `HypnosisSpiral.h` and the other `.h` files in the root | The standalone GLSL shaders |
| `DynamicColourGradient/DynamicColourGradient_metal.h` | The Metal shader |
| `docs/` | A rendered PNG of each standalone shader, and the contact sheet |
| `shadertoy/` | The Shadertoy archive: one folder per shader, with code and `metadata.json` |
| `tools/wrap_fragment.py` | Wraps a shader so a modern OpenGL compiler accepts it |
| `tools/verify_wrappers.py` | Checks the wrapped files match the originals |
| `tools/import_shadertoy.py` | Imports a Shadertoy account export into `shadertoy/` |
| `tools/verify_shadertoy_import.py` | Checks the archive is complete |
| `CMakeLists.txt` | The compile check |

## Ideas to try

1. In `HypnosisSpiral.h`, change the `10.0` to another number to change the number of arms, and the `20.0` to change how tightly they wind.
2. In `CheckerBoard.h`, change the `10.0` to make bigger or smaller squares.
3. In `AnimatedCircularGradient.h`, swap the order of the first three numbers in `vec4(...)` and see how the colours change.
4. In `NoiseAnimation.h`, the `noise` function makes a different random value for every pixel. Try rounding `p` with `floor` first to get blocky noise.
5. Write the missing shader. `DynamicColourGradient.h` is empty. Port `DynamicColourGradient/DynamicColourGradient_metal.h` to GLSL, then add the file to `SHADERLIB_SOURCES` in `CMakeLists.txt` and to `HEADERS` in `tools/verify_wrappers.py`.

## Technical details

### The standalone shaders

| File | What it draws |
|---|---|
| [`HypnosisSpiral.h`](HypnosisSpiral.h) | `sin(angle * 10 - radius * 20)` in polar coordinates. Ten arms, tightening toward the centre. |
| [`AnimatedCircularGradient.h`](AnimatedCircularGradient.h) | Radial gradient with the colour driven by time. |
| [`CheckerBoard.h`](CheckerBoard.h) | Procedural checkerboard. |
| [`LoopingGradient.h`](LoopingGradient.h) | Colour gradient that returns to where it started. |
| [`NoiseAnimation.h`](NoiseAnimation.h) | Hash-based noise field, reseeded each frame. |
| [`ScanLines.h`](ScanLines.h) | Horizontal bands over a gradient. |
| [`hearbeat.h`](hearbeat.h) | A waveform plotted as a line, in the shape of a heartbeat trace. The filename is misspelled and stays that way so existing links keep working. |

Every image in the contact sheet is the actual output, rendered headless at 512 by 512 with `time` fixed at 1.7. Full-size PNGs are in [`docs/`](docs/).

### Use

```glsl
uniform vec2  resolution;   // viewport size in pixels
uniform float time;         // seconds
```

Paste the body into any host that provides those two. Most files write `gl_FragColor`. `hearbeat.h` and `LoopingGradient.h` write `fragColor` instead, so they need an `out vec4 fragColor` on a core profile.

### Metal

[`DynamicColourGradient/DynamicColourGradient_metal.h`](DynamicColourGradient/DynamicColourGradient_metal.h) is the same idea written for Metal, taking `resolution` and `time` through buffer bindings instead of uniforms.

```metal
fragment float4 fragmentShader (float2 fragCoord [[position]],
                                constant float2 &resolution [[buffer(0)]],
                                constant float &time [[buffer(1)]])
```

### Rendering these yourself

The contact sheet came from a standalone OpenGL 3.3 context with no window. Each file is wrapped rather than edited: the wrapper supplies the `#version`, the uniforms and an `out` variable, and rewrites `gl_FragColor` to it, so the shader sources stay exactly as they are.

### Compile-time GLSL validation (CMake 4.5)

The seven complete standalone GLSL headers can be wrapped as OpenGL 3.3 fragment shaders and syntax-checked by `glslangValidator`. The original headers are never changed. The CMake 4.5 mode uses one reusable `add_custom_rule(shaderlib_glsl ...)` instantiated by a typed source file set, instead of manually registering one command per file.

```sh
cmake -S . -B build/validate -DSHADERLIB_USE_CUSTOM_RULES=ON
cmake --build build/validate
ctest --test-dir build/validate --output-on-failure
```

Requires CMake 4.5+, Python 3 and glslangValidator. Without CMake 4.5, use `-DSHADERLIB_USE_CUSTOM_RULES=OFF` (default), which supports CMake 3.20+. `DynamicColourGradient.h` is still incomplete and is intentionally left out of validation. This is a static validator for the seven standalone shaders. It does not render Shadertoy multipass, audio or texture shaders; the Shadertoy archive is separate.

### Shadertoy archive: 44 additional public shaders

The [Shadertoy archive](shadertoy/README.md) contains 44 public Shadertoy projects and 54 render-pass GLSL files imported from the account export dated 2026-10-18. Each project has its original shader ID, Shadertoy link, description, tags, ordered passes and channel/sampler metadata. Four shader names, and a few descriptions and tags, were edited after import to suit a school audience. The archive list says which.

These are original Shadertoy GLSL programs. They have not been converted to the standalone `.h` interface above. Some shaders depend on Shadertoy uniforms, buffer feedback, audio channels or external textures; the import keeps their channel declarations but does not bundle media or claim standalone rendering compatibility.

The export also included 34 shaders marked Private. They were not committed to this public repository.

You can validate the import with:

```bash
python3 tools/verify_shadertoy_import.py shadertoy
```

## Project status

Both automatic checks (the archive check and the GLSL validation in both CMake modes) pass on the `main` branch.

- `DynamicColourGradient.h` is empty. The Metal version is the only implementation of it. Anything that includes the GLSL file will fail to link with `No definition of main in fragment shader`.
- The CMake 4.5 mode downloads a release candidate of CMake 4.5 in its automatic check.

## Licence

You can use, copy and change this code for any purpose, as long as you keep the copyright notice. See [LICENSE](LICENSE) (MIT).

## Credits

Written by Abhishek Shivakumar. Shader checking uses [glslang](https://github.com/KhronosGroup/glslang) from Khronos. The archived shaders were first published on [Shadertoy](https://www.shadertoy.com/). To cite this work, see [CITATION.cff](CITATION.cff).

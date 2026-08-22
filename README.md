# Shader Library

A small collection of standalone GLSL fragment shaders. They compile with a standard `resolution`/`time` uniform set and write to `gl_FragColor` (or `fragColor` in the heartbeat shader).

## Shaders

- **AnimatedCircularGradient.h**: radial gradient animated through time.
- **CheckerBoard.h**: procedural checkerboard.
- **DynamicColourGradient.h**: animated colour gradient.
- **HypnosisSpiral.h**: polar spiral driven by sine of angle and radius.
- **LoopingGradient.h**: smooth looping colour gradient.
- **NoiseAnimation.h**: animated pseudo-random noise field.
- **ScanLines.h**: scan-line effect.
- **hearbeat.h**: heartbeat-style waveform plot.

## Usage

Each `.h` file contains a `main()` function. Drop the contents into any environment that provides:

```glsl
uniform vec2 resolution;
uniform float time;
```

Examples: Shadertoy, openFrameworks, JUCE OpenGLComponent, custom engine.

## License

MIT

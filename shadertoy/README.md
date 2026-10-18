# Shadertoy shader archive

Imported from an export of the Shadertoy account `godofecht` made on `2026-10-18T03:10:36.341Z`.

**44 shaders marked Public** in the export are included here, with **54 original render-pass source files**. 34 shaders marked Private are deliberately **not published** in this public GitHub repository.

Each directory uses the stable Shadertoy shader ID and includes a `metadata.json` retaining the original shader information, render-pass types, ordering, channel input descriptors, and sampler settings. Original GLSL code is stored verbatim in `00_Image.glsl`, `01_Buffer_A.glsl`, etc.; the `source_file` field points to the corresponding code. Some shaders require Shadertoy uniforms (`iResolution`, `iTime`, `iMouse`, `iChannel0`, etc.), feedback buffers, audio input, or media resources. These were **not** reimplemented, bundled, or independently render-validated by this import.

The rest of ShaderLibrary's existing standalone `.h` fragment shaders remain unchanged and use their original `resolution` / `time` convention. Shadertoy GLSL is deliberately kept separate rather than rewritten to that interface.

## Imported shaders

| Name | Shadertoy ID | Passes | Channel bindings |
|---|---|---:|---:|
| [5 HT-2A](./NXcXRf/metadata.json) | [NXcXRf](https://www.shadertoy.com/view/NXcXRf) | 1 | 0 |
| [a sense of scale](./sXlSRM/metadata.json) | [sXlSRM](https://www.shadertoy.com/view/sXlSRM) | 1 | 0 |
| [All paths meet at one](./N3SSzK/metadata.json) | [N3SSzK](https://www.shadertoy.com/view/N3SSzK) | 1 | 0 |
| [Beautiful marble seas](./33cfzf/metadata.json) | [33cfzf](https://www.shadertoy.com/view/33cfzf) | 1 | 0 |
| [bedazzled](./s3BXWK/metadata.json) | [s3BXWK](https://www.shadertoy.com/view/s3BXWK) | 1 | 0 |
| [Bloody diarrhoea](./WXdBWB/metadata.json) | [WXdBWB](https://www.shadertoy.com/view/WXdBWB) | 1 | 0 |
| [BRO](./3XGBRW/metadata.json) | [3XGBRW](https://www.shadertoy.com/view/3XGBRW) | 1 | 0 |
| [Bruhhhhhhhhhh](./3XtfWB/metadata.json) | [3XtfWB](https://www.shadertoy.com/view/3XtfWB) | 1 | 0 |
| [Chameleon Skin](./fXB3RD/metadata.json) | [fXB3RD](https://www.shadertoy.com/view/fXB3RD) | 1 | 0 |
| [cloudy with a chance of spitball](./fXXSD7/metadata.json) | [fXXSD7](https://www.shadertoy.com/view/fXXSD7) | 1 | 0 |
| [Colorful Blooms](./wXGfWz/metadata.json) | [wXGfWz](https://www.shadertoy.com/view/wXGfWz) | 1 | 0 |
| [constellasian](./sftGWM/metadata.json) | [sftGWM](https://www.shadertoy.com/view/sftGWM) | 1 | 0 |
| [continuous beams](./73SSzG/metadata.json) | [73SSzG](https://www.shadertoy.com/view/73SSzG) | 1 | 0 |
| [de blob](./NXBGzD/metadata.json) | [NXBGzD](https://www.shadertoy.com/view/NXBGzD) | 1 | 0 |
| [denver pineapples](./N3SXzK/metadata.json) | [N3SXzK](https://www.shadertoy.com/view/N3SXzK) | 1 | 0 |
| [Diffused turbulent advection](./sX2Szm/metadata.json) | [sX2Szm](https://www.shadertoy.com/view/sX2Szm) | 2 | 2 |
| [eigenmodes of an fft](./ffd3RH/metadata.json) | [ffd3RH](https://www.shadertoy.com/view/ffd3RH) | 1 | 0 |
| [Fork Fork Thund godofecht 682](./f3fSD7/metadata.json) | [f3fSD7](https://www.shadertoy.com/view/f3fSD7) | 4 | 4 |
| [Fungal Dreams](./sX2SRG/metadata.json) | [sX2SRG](https://www.shadertoy.com/view/sX2SRG) | 2 | 2 |
| [Gooby Goober](./33yBRR/metadata.json) | [33yBRR](https://www.shadertoy.com/view/33yBRR) | 1 | 0 |
| [i-band v3](./NXjXDc/metadata.json) | [NXjXDc](https://www.shadertoy.com/view/NXjXDc) | 3 | 0 |
| [matrix eye v2](./7XSXzV/metadata.json) | [7XSXzV](https://www.shadertoy.com/view/7XSXzV) | 2 | 3 |
| [Medusean eye](./fXBSzK/metadata.json) | [fXBSzK](https://www.shadertoy.com/view/fXBSzK) | 2 | 2 |
| [Modulated Chimel's example - pt2](./W3dBDl/metadata.json) | [W3dBDl](https://www.shadertoy.com/view/W3dBDl) | 1 | 0 |
| [oil pastel seas at dusk](./wXyfRm/metadata.json) | [wXyfRm](https://www.shadertoy.com/view/wXyfRm) | 1 | 0 |
| [orlando bloom](./sfySRm/metadata.json) | [sfySRm](https://www.shadertoy.com/view/sfySRm) | 1 | 0 |
| [Pagan Symbols?](./WX3fzf/metadata.json) | [WX3fzf](https://www.shadertoy.com/view/WX3fzf) | 1 | 0 |
| [Pagani Symbolisma? v2](./W3cBDB/metadata.json) | [W3cBDB](https://www.shadertoy.com/view/W3cBDB) | 1 | 0 |
| [parameterization of some cool sh](./f3SXRt/metadata.json) | [f3SXRt](https://www.shadertoy.com/view/f3SXRt) | 2 | 2 |
| [Planet #1](./33KfRh/metadata.json) | [33KfRh](https://www.shadertoy.com/view/33KfRh) | 1 | 0 |
| [Planet #2](./tXGBzD/metadata.json) | [tXGBzD](https://www.shadertoy.com/view/tXGBzD) | 1 | 0 |
| [planet ink](./3XVBRW/metadata.json) | [3XVBRW](https://www.shadertoy.com/view/3XVBRW) | 1 | 0 |
| [planet stuff](./33VBRW/metadata.json) | [33VBRW](https://www.shadertoy.com/view/33VBRW) | 1 | 0 |
| [projection mapped lavaland](./sXsSzM/metadata.json) | [sXsSzM](https://www.shadertoy.com/view/sXsSzM) | 1 | 0 |
| [pyramid scheme](./NXjSzD/metadata.json) | [NXjSzD](https://www.shadertoy.com/view/NXjSzD) | 1 | 0 |
| [Quasi + Zeta](./f3SGzD/metadata.json) | [f3SGzD](https://www.shadertoy.com/view/f3SGzD) | 1 | 0 |
| [Ripples in the water](./tXdfzX/metadata.json) | [tXdfzX](https://www.shadertoy.com/view/tXdfzX) | 1 | 0 |
| [sea of thieves](./732SRG/metadata.json) | [732SRG](https://www.shadertoy.com/view/732SRG) | 1 | 0 |
| [Tectonic Longitude / Latitude](./tXyfzD/metadata.json) | [tXyfzD](https://www.shadertoy.com/view/tXyfzD) | 1 | 0 |
| [The power of drugz](./NXB3RD/metadata.json) | [NXB3RD](https://www.shadertoy.com/view/NXB3RD) | 1 | 0 |
| [The Prime Manifold Counts Itself](./s3lSRM/metadata.json) | [s3lSRM](https://www.shadertoy.com/view/s3lSRM) | 1 | 0 |
| [transmission fractal](./f32Szw/metadata.json) | [f32Szw](https://www.shadertoy.com/view/f32Szw) | 1 | 0 |
| [Truly a Broken Record](./WXGBRR/metadata.json) | [WXGBRR](https://www.shadertoy.com/view/WXGBRR) | 1 | 0 |
| [Yes to Every Question](./fXjXWR/metadata.json) | [fXjXWR](https://www.shadertoy.com/view/fXjXWR) | 1 | 0 |

## Re-import

```sh
python3 tools/import_shadertoy.py shaders_all.json --output shadertoy
python3 tools/verify_shadertoy_import.py shadertoy
```

The importer defaults to public entries only. `--include-private` is available for **local private exports only**; do not use it to commit formerly private shaders to this public repository without intentionally deciding to publish them.

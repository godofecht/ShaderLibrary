#!/usr/bin/env python3
"""Turn a standalone legacy ShaderLibrary GLSL header into a GLSL 330 fragment.

Keep the original shader header untouched. In core GLSL, gl_FragColor is
replaced with the explicitly declared fragColor output, while existing shaders
that already write fragColor keep working.
"""
from __future__ import annotations

import argparse
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("destination", type=Path)
    args = parser.parse_args()

    body = args.source.read_text(encoding="utf-8")
    if not body.strip() or "void main()" not in body:
        raise SystemExit(f"Not a complete standalone shader: {args.source}")
    if "#version" in body:
        raise SystemExit(f"Unexpected GLSL version declaration: {args.source}")

    output = (
        "#version 330 core\n"
        "layout(location = 0) out vec4 fragColor;\n"
        "#define gl_FragColor fragColor\n"
        "#line 1\n"
        + body
    )
    args.destination.parent.mkdir(parents=True, exist_ok=True)
    args.destination.write_text(output, encoding="utf-8")


if __name__ == "__main__":
    main()

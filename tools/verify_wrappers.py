#!/usr/bin/env python3
"""Check the exact headers used by the shader library's compile-time rules."""
import sys
from pathlib import Path

HEADERS = (
    "AnimatedCircularGradient.h", "CheckerBoard.h", "HypnosisSpiral.h",
    "LoopingGradient.h", "NoiseAnimation.h", "ScanLines.h", "hearbeat.h",
)


def main() -> None:
    source_dir, generated_dir = map(Path, sys.argv[1:3])
    for header in HEADERS:
        original = (source_dir / header).read_text(encoding="utf-8")
        generated = (generated_dir / (Path(header).stem + ".frag")).read_text(encoding="utf-8")
        assert generated.startswith("#version 330 core\n")
        assert "#define gl_FragColor fragColor\n#line 1\n" + original in generated
    assert len(list(generated_dir.glob("*.frag"))) == len(HEADERS)
    print(f"Verified {len(HEADERS)} generated fragment sources.")


if __name__ == "__main__":
    main()

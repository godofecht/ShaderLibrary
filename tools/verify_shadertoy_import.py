#!/usr/bin/env python3
"""Verify pass files, metadata, and public export consistency."""
import json
import sys
from pathlib import Path

def verify(root):
    index = json.loads((root / "index.json").read_text(encoding="utf-8"))
    entries = index["shaders"]
    seen = set()
    pass_total = 0
    for entry in entries:
        shader_id = entry["id"]
        assert shader_id not in seen, f"Duplicate id: {shader_id}"
        seen.add(shader_id)
        assert entry["published"] == "Public", f"Not public: {shader_id}"
        folder = root / shader_id
        meta = json.loads((folder / "metadata.json").read_text(encoding="utf-8"))
        assert meta["info"]["id"] == shader_id
        assert meta["info"]["published"] == "Public"
        passes = meta["renderpass"]
        assert len(passes) == entry["passes"]
        assert sum(len(p.get("inputs", [])) for p in passes) == entry["channels"]
        for renderpass in passes:
            filename = renderpass["source_file"]
            assert Path(filename).name == filename, f"Unsafe name: {filename}"
            source = (folder / filename).read_text(encoding="utf-8")
            assert source.strip(), f"Missing shader code: {shader_id}/{filename}"
            pass_total += 1
    assert len(entries) == index["imported"]
    assert {p.name for p in root.iterdir() if p.is_dir()} == seen
    print(f"Validated {len(entries)} public shaders and {pass_total} render passes")

if __name__ == "__main__":
    verify(Path(sys.argv[1]) if len(sys.argv) > 1 else Path("shadertoy"))

#!/usr/bin/env python3
"""Import a Shadertoy JSON export without modifying its GLSL source."""
import argparse
import json
import re
from pathlib import Path

def pass_name(renderpass, index):
    title = (renderpass.get("name") or f"Pass {index}").strip()
    safe = re.sub(r"[^A-Za-z0-9]+", "_", title).strip("_") or f"Pass_{index}"
    return f"{index:02d}_{safe}.glsl"

def import_export(source, output, include_private=False):
    export = json.loads(source.read_text(encoding="utf-8"))
    entries = []
    excluded = 0
    for shader in export.get("shaders", []):
        info = shader["info"]
        visibility = info.get("published", "Private")
        if visibility != "Public" and not include_private:
            excluded += 1
            continue
        shader_id = str(info["id"])
        if not re.fullmatch(r"[A-Za-z0-9_-]+", shader_id):
            raise ValueError(f"Unsafe shader id: {shader_id!r}")
        folder = output / shader_id
        folder.mkdir(parents=True, exist_ok=True)
        meta = {key: val for key, val in shader.items() if key != "renderpass"}
        meta["renderpass"] = []
        for index, renderpass in enumerate(shader.get("renderpass", [])):
            file = pass_name(renderpass, index)
            (folder / file).write_text(renderpass.get("code", ""), encoding="utf-8")
            data = {key: val for key, val in renderpass.items() if key != "code"}
            data["source_file"] = file
            meta["renderpass"].append(data)
        (folder / "metadata.json").write_text(
            json.dumps(meta, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )
        entries.append({
            "id": shader_id, "name": info.get("name", ""),
            "description": info.get("description", ""), "published": visibility,
            "date": info.get("date"), "tags": info.get("tags", []),
            "passes": len(meta["renderpass"]),
            "channels": sum(len(p.get("inputs", [])) for p in meta["renderpass"]),
            "url": f"https://www.shadertoy.com/view/{shader_id}" if visibility == "Public" else None,
        })
    entries.sort(key=lambda item: (str(item["date"]), item["id"]))
    (output / "index.json").write_text(
        json.dumps({
            "source": "Shadertoy personal JSON export",
            "userName": export.get("userName"),
            "exportedAt": export.get("date"),
            "imported": len(entries), "excludedNonPublic": excluded,
            "shaders": entries,
        }, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    return len(entries), excluded

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("export", type=Path)
    parser.add_argument("--output", type=Path, default=Path("shadertoy"))
    parser.add_argument("--include-private", action="store_true",
                        help="Allow private entries in local output (never commit unintentionally)")
    args = parser.parse_args()
    count, excluded = import_export(args.export, args.output, args.include_private)
    print(f"Imported {count} shaders; excluded {excluded} non-public shaders")

if __name__ == "__main__":
    main()

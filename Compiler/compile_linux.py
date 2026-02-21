#!/usr/bin/env python3
import argparse
import json
import os
import re
import shutil
import sys
from pathlib import Path

INCLUDE_RE = re.compile(r"^\s*--\s*@include\s+(.+?)\s*$")
GUID_RE = re.compile(r"[0-9a-f]{6}")
TABLE_TITLE = "Hutber's 40k Gaming Table - CA 2025"


def resolve_lua_includes(file_path: Path, include_stack: set[Path] | None = None) -> list[str]:
    include_stack = include_stack or set()
    resolved_path = file_path.resolve()

    if resolved_path in include_stack:
        raise RuntimeError(f"Circular Lua include detected: {resolved_path}")

    include_stack.add(resolved_path)

    if not resolved_path.exists():
        raise FileNotFoundError(f"Lua file not found: {resolved_path}")

    base_dir = resolved_path.parent
    resolved_lines: list[str] = []

    for line in resolved_path.read_text(encoding="utf-8").splitlines():
        match = INCLUDE_RE.match(line)
        if match:
            rel_include = match.group(1).strip()
            if (rel_include.startswith('"') and rel_include.endswith('"')) or (
                rel_include.startswith("'") and rel_include.endswith("'")
            ):
                rel_include = rel_include[1:-1]

            include_path = (base_dir / rel_include).resolve()
            if not include_path.exists():
                raise FileNotFoundError(
                    f"Lua include not found: {rel_include} (from {resolved_path})"
                )

            resolved_lines.append(f"-- BEGIN include: {rel_include}")
            resolved_lines.extend(resolve_lua_includes(include_path, include_stack))
            resolved_lines.append(f"-- END include: {rel_include}")
        else:
            resolved_lines.append(line)

    include_stack.remove(resolved_path)
    return resolved_lines


def iter_objects(objects: list[dict]):
    for obj in objects:
        yield obj
        contained = obj.get("ContainedObjects")
        if isinstance(contained, list) and contained:
            yield from iter_objects(contained)
        states = obj.get("States")
        if isinstance(states, dict) and states:
            for state_obj in states.values():
                if isinstance(state_obj, dict):
                    yield from iter_objects([state_obj])


def _flatten_objectstates_node(node) -> list[dict]:
    if isinstance(node, list):
        return [item for item in node if isinstance(item, dict)]
    if isinstance(node, dict):
        if isinstance(node.get("ObjectStates"), list):
            return [item for item in node["ObjectStates"] if isinstance(item, dict)]
        return [node]
    return []


def load_objectstates_fragments(objectstates_dir: Path) -> list[dict]:
    if not objectstates_dir.exists():
        return []

    fragments = sorted(objectstates_dir.glob("*.json"))
    merged: list[dict] = []

    for fragment in fragments:
        payload = json.loads(fragment.read_text(encoding="utf-8"))
        objects = _flatten_objectstates_node(payload)
        if not objects:
            print(
                f"Warning: skipping empty ObjectStates fragment: {fragment.name}",
                file=sys.stderr,
            )
            continue
        merged.extend(objects)

    return merged


def parse_guid_list_from_first_line(script_path: Path) -> list[str]:
    lines = script_path.read_text(encoding="utf-8").splitlines()
    if not lines:
        raise RuntimeError(f"Empty Lua script file: {script_path}")

    first = lines[0]
    marker = "-- FTC-GUID:"
    idx = first.find(marker)
    if idx == -1:
        raise RuntimeError(f"No GUID marker found in first line: {script_path}")

    after = first[idx + len(marker) :]
    guids = GUID_RE.findall(after)
    if not guids:
        raise RuntimeError(f"No GUIDs found in first line: {script_path}")

    return guids


def gather_scripts(lua_root: Path) -> tuple[str, dict[str, str]]:
    global_file = lua_root / "global.ttslua"
    if not global_file.exists():
        raise FileNotFoundError(f"Missing global script: {global_file}")

    global_script = "\n".join(resolve_lua_includes(global_file))

    guid_to_script: dict[str, str] = {}

    script_files = sorted(
        p
        for p in lua_root.rglob("*.ttslua")
        if p.name != "global.ttslua"
    )

    for script in script_files:
        rel = script.relative_to(lua_root)
        print(f"Scanning GUIDs in {rel} ...", end=" ")
        guids = parse_guid_list_from_first_line(script)
        resolved = "\n".join(resolve_lua_includes(script))

        for guid in guids:
            if guid in guid_to_script:
                print(
                    f"\nWarning: GUID {guid} is duplicated; overriding with {rel}",
                    file=sys.stderr,
                )
            guid_to_script[guid] = resolved

        print("found", " ".join(guids))

    return global_script, guid_to_script


def apply_scripts_to_json(data: dict, global_script: str, guid_to_script: dict[str, str]) -> None:
    data["LuaScript"] = global_script

    objects = list(iter_objects(data.get("ObjectStates", [])))
    existing_guids = {obj.get("GUID") for obj in objects if obj.get("GUID")}

    missing_guids = [g for g in guid_to_script.keys() if g not in existing_guids]
    if missing_guids:
        first_missing = missing_guids[0]
        raise RuntimeError(f"GUID not found in JSON: {first_missing}")

    for obj in objects:
        guid = obj.get("GUID")
        if guid in guid_to_script:
            obj["LuaScript"] = guid_to_script[guid]


def main() -> int:
    parser = argparse.ArgumentParser(description="Linux compiler for TTS save JSON/Lua.")
    parser.add_argument("--test", action="store_true", help="Copy output to local TTS Saves path.")
    parser.add_argument("--json-name", default="hutber_base", help="Source JSON filename without extension.")
    parser.add_argument(
        "--lua-dir",
        default="HutberLua",
        help="Lua source folder relative to repo root (default: HutberLua).",
    )
    parser.add_argument(
        "--json-dir",
        default="BASEJSON",
        help="JSON source folder relative to repo root (default: BASEJSON).",
    )
    parser.add_argument(
        "--objectstates-dir",
        default="objectstates",
        help=(
            "Folder under --json-dir that contains grouped ObjectStates JSON fragments "
            "(default: objectstates)."
        ),
    )
    parser.add_argument(
        "--export-name",
        default="hutber_CA_2025",
        help="Export filename prefix for compiled output (without extension).",
    )
    parser.add_argument("--copy-path", default="", help="Override copy destination for --test.")
    args = parser.parse_args()

    compiler_dir = Path(__file__).resolve().parent
    repo_root = compiler_dir.parent
    lua_root = repo_root / args.lua_dir
    json_root = repo_root / args.json_dir

    if not lua_root.exists():
        raise FileNotFoundError(f"Lua folder not found: {lua_root}")

    json_name = args.json_name
    export_name = args.export_name.strip() or json_name
    base_json = json_root / f"{json_name}.json"
    if not base_json.exists():
        raise FileNotFoundError(f"JSON not found: {base_json}")
    objectstates_dir = json_root / args.objectstates_dir

    print(f"Using Lua source folder: {lua_root}")

    global_script, guid_to_script = gather_scripts(lua_root)

    print(f"Reading {base_json} ...")
    data = json.loads(base_json.read_text(encoding="utf-8"))

    fragment_objects = load_objectstates_fragments(objectstates_dir)
    if fragment_objects:
        data["ObjectStates"] = fragment_objects
        print(
            f"Loaded {len(fragment_objects)} ObjectStates from {objectstates_dir}",
        )
    elif not isinstance(data.get("ObjectStates"), list):
        data["ObjectStates"] = []
        print(
            "Warning: base JSON has no valid ObjectStates list; using empty list",
            file=sys.stderr,
        )

    apply_scripts_to_json(data, global_script, guid_to_script)

    data["SaveName"] = TABLE_TITLE
    data["GameMode"] = TABLE_TITLE

    out_name = f"{export_name}_compiled.json"

    out_path = compiler_dir / out_name
    out_path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Built {out_path}")

    if args.test:
        copy_path = args.copy_path.strip() if args.copy_path else ""
        if not copy_path:
            copy_path = str(Path.home() / ".local/share/Tabletop Simulator/Saves")

        copy_dir = Path(copy_path).expanduser()
        copy_dir.mkdir(parents=True, exist_ok=True)
        shutil.copy2(out_path, copy_dir / out_name)
        print(f"Copied to {copy_dir / out_name}")

    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(1)

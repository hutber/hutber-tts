#!/usr/bin/env python3
import argparse
import json
import socket
import sys
from pathlib import Path
from typing import Any


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


def build_script_states(compiled_json: Path) -> list[dict]:
    data = json.loads(compiled_json.read_text(encoding="utf-8"))
    script_states: list[dict] = []

    global_script = data.get("LuaScript", "")
    if not isinstance(global_script, str):
        global_script = ""
    global_ui = data.get("XmlUI")

    global_state = {
        "name": "Global",
        "guid": "-1",
        "script": global_script,
    }
    if isinstance(global_ui, str) and global_ui:
        global_state["ui"] = global_ui
    script_states.append(global_state)

    for obj in iter_objects(data.get("ObjectStates", [])):
        guid = obj.get("GUID")
        if not isinstance(guid, str) or not guid:
            continue

        script = obj.get("LuaScript", "")
        ui = obj.get("XmlUI")
        if not isinstance(script, str):
            script = ""

        # Match Save & Play behavior: only push scripted / UI-bearing objects.
        if not script and not (isinstance(ui, str) and ui):
            continue

        name = obj.get("Nickname") or obj.get("Name") or f"Object {guid}"
        if not isinstance(name, str) or not name:
            name = f"Object {guid}"

        state = {
            "name": name,
            "guid": guid,
            "script": script,
        }
        if isinstance(ui, str) and ui:
            state["ui"] = ui
        script_states.append(state)

    return script_states


def _send_message(host: str, port: int, timeout_s: float, payload: dict[str, Any]) -> None:
    body = json.dumps(payload, ensure_ascii=False).encode("utf-8")

    with socket.create_connection((host, port), timeout=timeout_s) as sock:
        sock.sendall(body)


def _recv_single_json(conn: socket.socket, timeout_s: float) -> dict[str, Any]:
    conn.settimeout(timeout_s)
    raw = b""

    while True:
        chunk = conn.recv(65536)
        if not chunk:
            break
        raw += chunk

    if not raw:
        raise RuntimeError("No callback payload received from TTS.")

    try:
        data = json.loads(raw.decode("utf-8"))
    except json.JSONDecodeError as exc:
        raise RuntimeError(f"Failed to decode callback JSON: {exc}") from exc

    if not isinstance(data, dict):
        raise RuntimeError("Unexpected callback payload type from TTS.")

    return data


def _send_and_wait_callback(
    host: str,
    send_port: int,
    callback_host: str,
    callback_port: int,
    timeout_s: float,
    payload: dict[str, Any],
) -> dict[str, Any]:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as listener:
        listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        listener.bind((callback_host, callback_port))
        listener.listen(1)
        listener.settimeout(timeout_s)

        _send_message(host, send_port, timeout_s, payload)

        conn, _ = listener.accept()
        with conn:
            return _recv_single_json(conn, timeout_s)


def _print_callback_summary(prefix: str, callback: dict[str, Any]) -> None:
    msg_id = callback.get("messageID")
    if msg_id == 1:
        states = callback.get("scriptStates")
        state_count = len(states) if isinstance(states, list) else "?"
        print(f"{prefix}: messageID=1 scriptStates={state_count}")
        return
    if msg_id == 3:
        err = callback.get("error") or "Unknown Lua error from TTS"
        print(f"{prefix}: messageID=3 error={err}")
        return
    print(f"{prefix}: messageID={msg_id}")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Push compiled TTS JSON scripts to Tabletop Simulator via SaveAndPlay."
    )
    parser.add_argument(
        "--compiled-json",
        default="hutber_CA_2025_compiled.json",
        help="Compiled save JSON path (default: hutber_CA_2025_compiled.json in current dir).",
    )
    parser.add_argument("--host", default="127.0.0.1", help="TTS External Editor host.")
    parser.add_argument("--port", type=int, default=39999, help="TTS External Editor port.")
    parser.add_argument(
        "--callback-host",
        default="127.0.0.1",
        help="Host to bind callback listener (editor side, default: 127.0.0.1).",
    )
    parser.add_argument(
        "--callback-port",
        type=int,
        default=39998,
        help="Port to bind callback listener (editor side, default: 39998).",
    )
    parser.add_argument("--timeout", type=float, default=2.0, help="Socket timeout in seconds.")
    parser.add_argument(
        "--no-callback",
        action="store_true",
        help="Do not open callback listener; send fire-and-forget messages only.",
    )
    parser.add_argument(
        "--skip-preflight",
        action="store_true",
        help="Skip preflight 'Get Lua Scripts' check before SaveAndPlay.",
    )
    parser.add_argument("--dry-run", action="store_true", help="Build payload but do not send.")
    args = parser.parse_args()

    compiled_path = Path(args.compiled_json).expanduser().resolve()
    if not compiled_path.exists():
        print(f"ERROR: Compiled JSON not found: {compiled_path}", file=sys.stderr)
        return 1

    script_states = build_script_states(compiled_path)
    print(f"Prepared SaveAndPlay payload: {len(script_states)} scriptStates")

    if args.dry_run:
        print("Dry run only; not sending to TTS.")
        return 0

    callback_enabled = not args.no_callback

    try:
        if callback_enabled and not args.skip_preflight:
            preflight = _send_and_wait_callback(
                host=args.host,
                send_port=args.port,
                callback_host=args.callback_host,
                callback_port=args.callback_port,
                timeout_s=args.timeout,
                payload={"messageID": 0},
            )
            _print_callback_summary("Preflight", preflight)

        save_and_play_payload = {
            "messageID": 1,
            "scriptStates": script_states,
        }

        if callback_enabled:
            callback = _send_and_wait_callback(
                host=args.host,
                send_port=args.port,
                callback_host=args.callback_host,
                callback_port=args.callback_port,
                timeout_s=args.timeout,
                payload=save_and_play_payload,
            )
            _print_callback_summary("SaveAndPlay callback", callback)
        else:
            _send_message(args.host, args.port, args.timeout, save_and_play_payload)
    except OSError as exc:
        if callback_enabled and exc.errno == 98:
            print(
                "WARNING: Callback port is already in use (likely VS Code extension). "
                "Falling back to fire-and-forget send.",
                file=sys.stderr,
            )
            try:
                _send_message(
                    args.host,
                    args.port,
                    args.timeout,
                    {"messageID": 1, "scriptStates": script_states},
                )
            except OSError as fallback_exc:
                print(
                    f"ERROR: Could not send SaveAndPlay to {args.host}:{args.port}: {fallback_exc}",
                    file=sys.stderr,
                )
                return 2
        else:
            print(
                f"ERROR: Could not send SaveAndPlay to {args.host}:{args.port}: {exc}",
                file=sys.stderr,
            )
            return 2
    except RuntimeError as exc:
        print(
            f"ERROR: SaveAndPlay callback failed: {exc}",
            file=sys.stderr,
        )
        return 2

    print(f"Sent SaveAndPlay to {args.host}:{args.port}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

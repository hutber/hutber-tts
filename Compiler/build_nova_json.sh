#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LUA_FILE="$ROOT_DIR/TTSLUA/v2_nova/global_nova.lua"
OUT_FILE="$ROOT_DIR/TTSJSON/nova_ops_mvp.json"
TTS_SAVES_DIR="$HOME/.local/share/Tabletop Simulator/Saves"
TTS_OUT_FILE="$TTS_SAVES_DIR/nova_ops_mvp.json"

if [[ ! -f "$LUA_FILE" ]]; then
  echo "Missing Lua file: $LUA_FILE" >&2
  exit 1
fi

LUA_CONTENT="$(cat "$LUA_FILE")"

jq -n \
  --arg lua "$LUA_CONTENT" \
  --arg date "$(date '+%d/%m/%Y %I:%M:%S %p')" \
  '{
    SaveName: "Nova Ops Competitive Map - Warhammer 40k 10th Edition MVP",
    GameMode: "Nova Ops Competitive Map - Warhammer 40k 10th Edition MVP",
    Date: $date,
    VersionNumber: "v0.1.0",
    GameType: "Game",
    GameComplexity: "High Complexity",
    PlayingTime: [120, 240],
    PlayerCounts: [2, 2],
    Tags: ["Strategy Games", "Wargames", "Warhammer", "40k", "TTS", "Nova Ops", "MVP"],
    Gravity: 0.5,
    PlayArea: 1.0,
    Table: "Table_None",
    Sky: "Sky_Museum",
    Note: "Standalone next-gen concept map for Warhammer 40k 10th Edition. Includes score control, CP, 5 rounds, phase flow, dice engine, and modular map spawning.",
    Rules: "",
    MusicPlayer: {},
    Grid: {
      Type: 0,
      Lines: false,
      Color: { r: 0, g: 0, b: 0 },
      Opacity: 0.75,
      ThickLines: true,
      Snapping: false,
      Offset: false,
      BothSnapping: false,
      xSize: 1,
      ySize: 1,
      PosOffset: { x: 0, y: 1, z: 0 }
    },
    Lighting: {
      LightIntensity: 0.8,
      LightColor: { r: 1, g: 0.98, b: 0.9 },
      AmbientIntensity: 1.1,
      AmbientType: 0,
      AmbientSkyColor: { r: 0.5, g: 0.5, b: 0.5 },
      AmbientEquatorColor: { r: 0.5, g: 0.5, b: 0.5 },
      AmbientGroundColor: { r: 0.5, g: 0.5, b: 0.5 },
      ReflectionIntensity: 1,
      LutIndex: 0,
      LutContribution: 1
    },
    Hands: {
      Enable: true,
      DisableUnused: true,
      Hiding: 0
    },
    Turns: {
      Enable: false,
      Type: 1,
      TurnOrder: ["Red", "Blue"],
      Reverse: false,
      SkipEmpty: false,
      DisableInteractions: false,
      PassTurns: true,
      TurnColor: ""
    },
    TabStates: {
      "0": {
        title: "Nova Ops MVP",
        body: "Start with the command deck panel. Load a map, set round/phase, and track VP/CP.",
        color: "Grey",
        visibleColor: { r: 0.5, g: 0.5, b: 0.5 },
        id: 0
      }
    },
    LuaScript: $lua,
    LuaScriptState: "",
    XmlUI: "",
    ObjectStates: []
  }' > "$OUT_FILE"

echo "Built $OUT_FILE"

mkdir -p "$TTS_SAVES_DIR"
cp "$OUT_FILE" "$TTS_OUT_FILE"
echo "Copied to $TTS_OUT_FILE"

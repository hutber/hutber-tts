#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_FILE="$ROOT_DIR/TTSJSON/nova_table_only.json"
TTS_SAVES_DIR="$HOME/.local/share/Tabletop Simulator/Saves"
TTS_OUT_FILE="$TTS_SAVES_DIR/nova_table_only.json"
TABLE_LUA_FILE="$ROOT_DIR/TTSLUA/v2_nova/table_only_surface.lua"

if [[ ! -f "$TABLE_LUA_FILE" ]]; then
  echo "Missing Lua file: $TABLE_LUA_FILE" >&2
  exit 1
fi

TABLE_LUA="$(cat "$TABLE_LUA_FILE")"

jq -n \
  --arg date "$(date '+%d/%m/%Y %I:%M:%S %p')" \
  --arg table_lua "$TABLE_LUA" \
  '{
    SaveName: "Nova Table Only - Warhammer 40k 10th Edition",
    GameMode: "Nova Table Only - Warhammer 40k 10th Edition",
    Date: $date,
    VersionNumber: "v0.1.0",
    GameType: "Game",
    GameComplexity: "Simple",
    PlayingTime: [120, 240],
    PlayerCounts: [2, 2],
    Tags: ["Strategy Games", "Wargames", "Warhammer", "40k", "10th Edition", "Table Only"],
    Gravity: 0.5,
    PlayArea: 1.0,
    Table: "Table_None",
    Sky: "Sky_Museum",
    Note: "Minimal map: only a single large table surface for Warhammer 40k 10th Edition.",
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
        title: "Table Only",
        body: "This save intentionally includes only one table surface.",
        color: "Grey",
        visibleColor: { r: 0.5, g: 0.5, b: 0.5 },
        id: 0
      }
    },
    LuaScript: "",
    LuaScriptState: "",
    XmlUI: "",
    ObjectStates: [
      {
        GUID: "a1b2c3",
        Name: "BlockSquare",
        Transform: {
          posX: 0,
          posY: 0.9,
          posZ: 0,
          rotX: 0,
          rotY: 0,
          rotZ: 0,
          scaleX: 180,
          scaleY: 0.3,
          scaleZ: 140
        },
        Nickname: "Warhammer 40k 10e Table",
        Description: "Table-only map",
        GMNotes: "",
        AltLookAngle: { x: 0, y: 0, z: 0 },
        ColorDiffuse: { r: 0.2, g: 0.2, b: 0.22 },
        LayoutGroupSortIndex: 0,
        Value: 0,
        Locked: true,
        Grid: true,
        Snap: true,
        IgnoreFoW: false,
        MeasureMovement: false,
        DragSelectable: true,
        Autoraise: true,
        Sticky: true,
        Tooltip: true,
        GridProjection: false,
        HideWhenFaceDown: false,
        Hands: true,
        LuaScript: $table_lua,
        LuaScriptState: "",
        XmlUI: ""
      }
    ]
  }' > "$OUT_FILE"

mkdir -p "$TTS_SAVES_DIR"
cp "$OUT_FILE" "$TTS_OUT_FILE"

echo "Built $OUT_FILE"
echo "Copied to $TTS_OUT_FILE"

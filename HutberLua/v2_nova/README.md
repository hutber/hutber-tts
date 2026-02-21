# Nova Ops MVP (Standalone)

This is a completely separate TTS mod concept and does not modify the existing FTC map.

## Files
- `TTSLUA/v2_nova/global_nova.lua` - Global script for the new mod.
- `Compiler/build_nova_json.sh` - Builds the standalone save file.
- `TTSJSON/nova_ops_mvp.json` - Import this into Tabletop Simulator.

## Included MVP Systems
- Match start/end flow.
- Red/Blue VP and CP controls.
- Battle round and phase progression.
- Dice roller with average/success/low-roll stats.
- Map size selector.
- Map template loader that spawns a fresh battlefield layout.

## Build
```bash
./Compiler/build_nova_json.sh
```

The script also copies the file to:

`~/.local/share/Tabletop Simulator/Saves/nova_ops_mvp.json`

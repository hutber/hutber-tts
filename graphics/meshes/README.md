# Dice Table Portrait Meshes

Files:
- `dice_table_portrait_plane.obj` (visual mesh, 2:3 portrait plane)
- `dice_table_portrait_collider.obj` (thin box collider)

Use these in `d4e8a2` (`BASEJSON/objectstates/DiceRollers.json`) once hosted at public URLs:

```json
"Name": "Custom_Model",
"CustomMesh": {
  "MeshURL": "https://<your-host>/dice_table_portrait_plane.obj",
  "DiffuseURL": "https://<your-image-url>",
  "NormalURL": "",
  "ColliderURL": "https://<your-host>/dice_table_portrait_collider.obj",
  "Convex": true,
  "MaterialIndex": 1,
  "TypeIndex": 0,
  "CastShadows": true
}
```

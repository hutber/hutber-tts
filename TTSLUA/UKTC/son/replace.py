import os

# Path to your files
directory = "/home/hutber/www/tts-comp-ftc-base-lua-scripts/TTSLUA/UKTC"

# Replacement for the LuaScript at the bottom of the file
replacement_lua_script = '"LuaScript": "function onload() \\r\\n    self.interactable = false\\r\\n    self.gizmo_selectable = true\\r\\nend",'

for filename in os.listdir(directory):
    if filename.endswith(".lua"):
        # Extract the ID from the filename
        parts = filename.split(".")
        if len(parts) < 2:
            continue
        
        file_id = parts[1]
        
        # Build the new filename without the ID
        new_filename = f"{parts[0]}.lua"
        file_path = os.path.join(directory, filename)
        new_file_path = os.path.join(directory, new_filename)

        with open(file_path, "r") as file:
            content = file.read()

        # Add the FTC-GUID line at the top
        if not content.startswith(f"-- FTC-GUID: {file_id}"):
            content = f"-- FTC-GUID: {file_id}\n" + content

        # Replace the last "LuaScript": "" with the replacement
        last_index = content.rfind('"LuaScript": ""')
        if last_index != -1:
            content = (
                content[:last_index]
                + replacement_lua_script
                + content[last_index + len('"LuaScript": ""') :]
            )

        # Write the modified content back to the new file
        with open(new_file_path, "w") as file:
            file.write(content)

        # Remove the old file
        if file_path != new_file_path:
            os.remove(file_path)

print("Processing complete!")


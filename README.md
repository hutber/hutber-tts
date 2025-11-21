# Competitive Hutber Base: LUA scripts
Hutber Map Base LUA Scripts

The following files contain all the LUA scripts contained in the Competitive FTC Base Map for the TTS 40k community. If a file does not exist for an object within the TTS save, then that object does not contain any scripts.

This repo now contains the actual TTS JSON file.

## Compiling

- Requirements: PowerShell (Windows PowerShell or PowerShell Core `pwsh`) installed.
- Run from the `Compiler/` directory so relative paths to `..\TTSLUA` and `..\TTSJSON` resolve.

Examples:

- Windows PowerShell:

  ```powershell
  cd Compiler
  powershell -ExecutionPolicy Bypass -File .\compile.ps1
  ```

- macOS / Linux (PowerShell Core):

  ```bash
  cd Compiler
  pwsh -File ./compile.ps1
  ```

- To run a test build that copies the compiled JSON to the local TTS saves path (uses the `-test` switch):

  ```powershell
  cd Compiler
  pwsh -File ./compile.ps1 -test
  # The script will prompt for a version string; leave blank for no version.
  ```

Output: the script writes `ftc_base_compiled.json` (or `ftc_base_<version>_compiled.json`) in the `Compiler/` folder.

The base was completely built upon the FTC map!!!! And Continues to receive updates from it, thank you eternally for their help!

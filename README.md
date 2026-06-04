# Competitive Hutber Base: LUA scripts
Hutber Map Base LUA Scripts

The following files contain all the LUA scripts contained in the Competitive FTC Base Map for the TTS 40k community. If a file does not exist for an object within the TTS save, then that object does not contain any scripts.

This repo now contains the actual TTS JSON file.

## Compiling

- Requirements: PowerShell (Windows PowerShell or PowerShell Core `pwsh`) installed.
- Preferred entrypoint: run the repo-root `compile.ps1` wrapper. It switches into `Compiler/` before invoking the original script, so relative paths resolve correctly.

Examples:

- Windows PowerShell:

  ```powershell
  powershell -ExecutionPolicy Bypass -File .\compile.ps1
  ```

- macOS / Linux (PowerShell Core):

  ```bash
  pwsh -File ./compile.ps1
  ```

- To run a test build that copies the compiled JSON to the local TTS saves path (uses the `-test` switch):

  ```powershell
  pwsh -File ./compile.ps1 -test
  ```

If you want to invoke the original script directly, run `Compiler/compile.ps1` from inside the `Compiler/` directory.

Output: the script writes `ftc_base_compiled.json` (or `ftc_base_<version>_compiled.json`) in the `Compiler/` folder.
When `-test` is used, the output file is `Compiler/ftc_base_test_compiled.json` and it is also copied into the local TTS saves folder.

The base was completely built upon the FTC map!!!! And Continues to receive updates from it, thank you eternally for their help!

param ([Switch]$test)

$compilerScript = Join-Path $PSScriptRoot 'Compiler/compile.ps1'

if (!(Test-Path $compilerScript))
{
    throw "Compiler script not found: $compilerScript"
}

Push-Location (Split-Path $compilerScript -Parent)
try
{
    & $compilerScript -test:$test
}
finally
{
    Pop-Location
}

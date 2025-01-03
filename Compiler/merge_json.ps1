# Paths
$ttsSaves = "/home/hutber/.local/share/Tabletop Simulator/Saves/"
$pathLua = '../TTSLUA/'
$pathJson = '../TTSJSON/'
$jsonName = 'ftc_base'
$jsonExt = '.json'
$mergeOutputName = 'ftc_base_merged.json'
$jsonCompileUpdate = '_compiled'
$compilerScript = './compile.ps1'
$gwWtcMapsJsonPath = '../TTSJSON/GW_WTC_Maps.json'

# Validate primary JSON file
$primaryFileName = $pathJson + $jsonName + $jsonExt
if (!(Test-Path $primaryFileName)) {
	Write-Host "$primaryFileName could not be found! Ending process..."
	exit
}

# Validate secondary JSON file
if (!(Test-Path $gwWtcMapsJsonPath)) {
	Write-Host "GW_WTC_Maps.json file not found. Skipping merge."
	exit
}

# Read the JSON files
Write-Host "Reading $primaryFileName..."
$primaryJson = Get-Content $primaryFileName | ConvertFrom-Json
Write-Host "Reading $gwWtcMapsJsonPath..."
$secondaryJson = Get-Content $gwWtcMapsJsonPath | ConvertFrom-Json

# Validate 'ObjectStates' property
if ($primaryJson.ObjectStates -eq $null) {
	Write-Host "Primary JSON does not contain 'ObjectStates'. Merge cannot proceed."
	exit
}
if ($secondaryJson.ObjectStates -eq $null) {
	Write-Host "Secondary JSON does not contain 'ObjectStates'. Merge cannot proceed."
	exit
}

# Merge ObjectStates
Write-Host "Merging GW_WTC_Maps.json into ftc_base.json's ObjectStates..."
foreach ($secondaryObject in $secondaryJson.ObjectStates) {
	$primaryJson.ObjectStates += $secondaryObject
}

# Save merged content locally
$mergeOutputPath = $pathJson + $mergeOutputName
Write-Host "Saving merged JSON to $mergeOutputPath..."
$primaryJson | ConvertTo-Json -Depth 100 | Set-Content $mergeOutputPath

# Run the compiler script
if (Test-Path $compilerScript) {
	Write-Host "Running compiler script: $compilerScript..."
	Start-Process -FilePath "pwsh" -ArgumentList "-ExecutionPolicy Bypass -File $compilerScript" -Wait
	Write-Host "Compilation completed."
} else {
	Write-Host "Compiler script $compilerScript not found. Compilation skipped."
}

Write-Host "Process completed successfully."

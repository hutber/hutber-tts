<#
.SYNOPSIS
  Expand/collapse the XmlUI string in TTSJSON/ftc_base.json for easier editing.

.DESCRIPTION
  This script extracts the large XmlUI string from TTSJSON/ftc_base.json into
  TTSJSON/ftc_base_ui.xml (expand) and re-embeds an edited XML file back into
  the JSON (collapse). It creates a backup of the JSON before writing.

  Usage:
    .\xmlui_tool.ps1 expand
    .\xmlui_tool.ps1 collapse

  The script intentionally operates only on TTSJSON/ftc_base.json and the
  readable TTSJSON/ftc_base_ui.xml. It does not touch compiled JSON files.
#>

param(
    [Parameter(Mandatory=$true, Position=0)]
    [ValidateSet('expand','collapse')]
    [string]$Command
)

function Write-ErrAndExit {
    param($msg, $code=1)
    Write-Error $msg
    exit $code
}

function Find-JsonStringEnd {
    param(
        [Parameter(Mandatory=$true)][string]$Text,
        [Parameter(Mandatory=$true)][int]$StartQuoteIndex
    )
    for ($i = $StartQuoteIndex + 1; $i -lt $Text.Length; $i++) {
        if ($Text[$i] -eq '"') {
            $bs = 0
            for ($j = $i - 1; $j -ge 0 -and $Text[$j] -eq '\\'; $j--) {
                $bs++
            }
            if (($bs % 2) -eq 0) {
                return $i
            }
        }
    }
    return -1
}

try {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $repoRoot = Resolve-Path (Join-Path $scriptDir '..')
    $jsonPath = Join-Path $repoRoot 'TTSJSON\ftc_base.json'
    $xmlPath  = Join-Path $repoRoot 'TTSJSON\ftc_base_ui.xml'

    if (-not (Test-Path $jsonPath)) {
        Write-ErrAndExit "Could not find $jsonPath"
    }

    if ($Command -eq 'expand') {
        $raw = Get-Content -Raw -Encoding UTF8 -Path $jsonPath

        # Locate the first XmlUI value in the raw JSON (without reformatting)
        $pattern = '"XmlUI"\s*:\s*"((?:\\.|[^"\\])*)"'
        $m = [regex]::Match($raw, $pattern, 'Singleline')
        if (-not $m.Success) {
            Write-ErrAndExit "Could not find XmlUI value in $jsonPath"
        }
        $xmlui = $m.Groups[1].Value

        # Unescape JSON string content into readable XML
        $xml = $xmlui -replace '\\r\\n',"`r`n" -replace '\\r',"`r" -replace '\\n',"`n" -replace '\\t',"`t" -replace '\\"','"' -replace '\\\\','\\'

        $xml | Out-File -FilePath $xmlPath -Encoding utf8 -Force
        Write-Host "Expanded XmlUI written to: $xmlPath"
        exit 0
    }

    if ($Command -eq 'collapse') {
        if (-not (Test-Path $xmlPath)) { Write-ErrAndExit "Expanded XML not found at $xmlPath" }

        $xml = Get-Content -Raw -Encoding UTF8 -Path $xmlPath

        # Trim leading whitespace on each line to reduce noisy diffs
        $lines = $xml -split "\r?\n"
        $lines = $lines | ForEach-Object { $_.TrimStart() }
        $xmlTrimmed = $lines -join "`r`n"

        # Normalize newline sequences to CRLF for embedding
        $xmlNorm = $xmlTrimmed -replace "`r`n","`n" -replace "`r","`n" -replace "`n","`r`n"

        # Build an escaped single-line JSON value for XmlUI and replace only
        # the XmlUI value in the raw JSON text. This preserves formatting
        # for the rest of the file so diffs remain readable.

        # Manual JSON escaping to avoid \u003c encoding
        $xmlEsc = $xmlNorm -replace '\\', '\\\\'
        $xmlEsc = $xmlEsc -replace '"', '\"'
        $xmlEsc = $xmlEsc -replace "`r`n", '\r\n'
        $xmlEsc = $xmlEsc -replace "`r", '\r'
        $xmlEsc = $xmlEsc -replace "`n", '\n'
        $xmlEsc = $xmlEsc -replace "`t", '\t'
        $xmlEsc = $xmlEsc -replace "`b", '\b'
        $xmlEsc = $xmlEsc -replace "`f", '\f'

        $raw = Get-Content -Raw -Encoding UTF8 -Path $jsonPath

        # Replace only the XmlUI value in the raw JSON text (no reformatting)
        $pattern = '"XmlUI"\s*:\s*"((?:\\.|[^"\\])*)"'
        $m = [regex]::Match($raw, $pattern, 'Singleline')
        if (-not $m.Success) {
            Write-ErrAndExit "Could not find XmlUI value in $jsonPath to replace"
        }
        $valStart = $m.Groups[1].Index
        $valLen = $m.Groups[1].Length

        # Backup original
        $bak = "$jsonPath.bak"
        Copy-Item -Force -Path $jsonPath -Destination $bak

        $newRaw = $raw.Substring(0, $valStart) + $xmlEsc + $raw.Substring($valStart + $valLen)
        # Write without BOM and without adding a trailing newline
        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($jsonPath, $newRaw, $utf8NoBom)
        Write-Host "Replaced XmlUI value in: $jsonPath (backup at $bak)"
        exit 0
    }
}
catch {
    Write-ErrAndExit $_.Exception.Message
}

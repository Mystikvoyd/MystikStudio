# ============================================================
# LoRA Tester - Session Report Module
# Drop-in replacement for the session functions in Start-Lab.ps1
#
# HOW IT WORKS:
#   1. Each generation appends a JSON entry to a temp file in %TEMP%
#   2. Stop-Session calls Write-LoraReport.py which reads the JSON,
#      embeds images as base64, and writes a self-contained HTML file.
#   3. Python handles ALL file I/O - no PowerShell path interpolation.
#
# INTEGRATION:
#   Copy the SESSION FUNCTIONS block into Start-Lab.ps1.
#   Replace calls to your old session-save code with the new ones below.
#   Keep Write-LoraReport.py in the same folder as the .ps1.
# ============================================================

# ---- CONFIG (adjust to match your existing script variables) ----
$script:ReportsFolder  = [System.IO.Path]::Combine($env:USERPROFILE, "Documents", "ComfyUI", "Reports")
$script:SessionActive  = $false
$script:SessionJsonFile = ""   # path to temp JSON file while session is running
$script:LastReportPath  = ""   # path to last saved HTML, for the Open Folder button

# Path to the Python script (same folder as this .ps1)
$script:PyScript = [System.IO.Path]::Combine($PSScriptRoot, "Write-LoraReport.py")

# Ensure Reports folder exists
if (-not [System.IO.Directory]::Exists($script:ReportsFolder)) {
    [System.IO.Directory]::CreateDirectory($script:ReportsFolder) | Out-Null
}

# ============================================================
# SESSION FUNCTIONS
# ============================================================

function Start-Session {
    # Create a temp JSON file to accumulate entries
    $tmpPath = [System.IO.Path]::Combine(
        $env:TEMP,
        "lora-session-" + [DateTime]::Now.ToString("yyyyMMdd_HHmmss") + ".json"
    )
    
    # Write initial JSON structure
    $init = [ordered]@{
        generated = [DateTime]::Now.ToString("yyyy-MM-dd HH:mm:ss")
        entries   = @()
    }
    $initJson = $init | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText($tmpPath, $initJson, [System.Text.Encoding]::UTF8)
    
    $script:SessionJsonFile = $tmpPath
    $script:SessionActive   = $true
    
    Write-Host "Session started. Data file: $tmpPath"
}

function Stop-Session {
    if (-not $script:SessionActive) {
        Write-Host "No active session."
        return
    }
    $script:SessionActive = $false
    
    if (-not [System.IO.File]::Exists($script:SessionJsonFile)) {
        Write-Host "Session data file missing - nothing to save."
        return
    }

    # Build output HTML path
    $stamp   = [DateTime]::Now.ToString("yyyyMMdd_HHmmss")
    $outHtml = [System.IO.Path]::Combine($script:ReportsFolder, "lora-session-" + $stamp + ".html")

    # Call Python to do ALL the file work (image reading, base64, HTML writing)
    # We pass paths as arguments - Python receives them as plain strings, no interpolation.
    $pyExe = "python"
    $result = & $pyExe $script:PyScript $script:SessionJsonFile $outHtml 2>&1
    Write-Host "Python reporter: $result"

    if ([System.IO.File]::Exists($outHtml)) {
        $script:LastReportPath = $outHtml
        Write-Host "Report saved: $outHtml"
        
        # Open in default browser
        Start-Process $outHtml
    } else {
        Write-Host "ERROR: Report file was not created. Check Python output above."
    }
    
    # Clean up temp JSON
    if ([System.IO.File]::Exists($script:SessionJsonFile)) {
        [System.IO.File]::Delete($script:SessionJsonFile)
    }
    $script:SessionJsonFile = ""
}

function Add-SessionEntry {
    <#
    .SYNOPSIS
        Call this after each successful image generation.
    .PARAMETER ImagePath
        Full absolute path to the generated PNG in ComfyUI's output folder.
        Pass it as a variable, NOT interpolated inside a string.
    .EXAMPLE
        Add-SessionEntry -ImagePath $resolvedImagePath -Seed $seed -Steps $steps `
                         -Cfg $cfg -Width $width -Height $height -Sampler $sampler `
                         -Prompt $prompt -Negative $negPrompt `
                         -LoraEnabled $loraOn -LoraName $loraName -LoraStrength $loraStr
    #>
    param(
        [string]$ImagePath,
        [object]$Seed        = -1,
        [int]   $Steps       = 20,
        [float] $Cfg         = 7.0,
        [int]   $Width       = 1024,
        [int]   $Height      = 1024,
        [string]$Sampler     = "",
        [string]$Prompt      = "",
        [string]$Negative    = "",
        [bool]  $LoraEnabled = $false,
        [string]$LoraName    = "",
        [float] $LoraStrength = 0.0
    )

    if (-not $script:SessionActive) { return }
    if (-not [System.IO.File]::Exists($script:SessionJsonFile)) { return }

    # ---- THE FIX: use .NET IO to read and write JSON, never PS string interpolation on paths ----
    
    # Read existing JSON
    $raw  = [System.IO.File]::ReadAllText($script:SessionJsonFile, [System.Text.Encoding]::UTF8)
    $data = $raw | ConvertFrom-Json

    # Resolve image path using .NET - zero PS interpolation
    $absPath = ""
    if ($ImagePath -ne "") {
        # If it's already absolute, GetFullPath just normalizes slashes
        # If it somehow came in relative, this resolves it from the PS working dir
        # Either way, store it as a plain .NET string, never re-interpolated
        $absPath = [System.IO.Path]::GetFullPath($ImagePath)
    }

    # Build new entry as a hashtable
    $entry = [ordered]@{
        time          = [DateTime]::Now.ToString("yyyy-MM-dd HH:mm:ss")
        image_path    = $absPath        # plain .NET string, full path
        lora_enabled  = $LoraEnabled
        lora_name     = $LoraName
        lora_strength = $LoraStrength
        seed          = $Seed
        steps         = $Steps
        cfg           = $Cfg
        width         = $Width
        height        = $Height
        sampler       = $Sampler
        prompt        = $Prompt
        negative      = $Negative
    }

    # Append to entries array
    $entries = [System.Collections.ArrayList]@($data.entries)
    $entries.Add($entry) | Out-Null

    # Write updated JSON back using .NET writer
    $newData = [ordered]@{
        generated = $data.generated
        entries   = $entries.ToArray()
    }
    $newJson = $newData | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText($script:SessionJsonFile, $newJson, [System.Text.Encoding]::UTF8)

    Write-Host ("Session entry added: " + [System.IO.Path]::GetFileName($absPath))
}

function Open-ReportsFolder {
    if ($script:LastReportPath -ne "" -and [System.IO.File]::Exists($script:LastReportPath)) {
        $folder = [System.IO.Path]::GetDirectoryName($script:LastReportPath)
        Start-Process "explorer.exe" $folder
    } else {
        Start-Process "explorer.exe" $script:ReportsFolder
    }
}

# ============================================================
# EXAMPLE: how to call Add-SessionEntry after a generation
# Replace the variables below with your actual generation result variables.
# ============================================================
<#
# After Wait-ComfyImages returns $images:
if ($script:SessionActive -and $images.Count -gt 0) {
    # Get the image path WITHOUT any string interpolation
    # Join-Path returns a plain .NET string - assign directly to a variable first
    $imgFile = $images[0]  # already full path from Wait-ComfyImages
    
    Add-SessionEntry `
        -ImagePath     $imgFile `
        -Seed          $currentSeed `
        -Steps         $steps `
        -Cfg           $cfg `
        -Width         $width `
        -Height        $height `
        -Sampler       $sampler `
        -Prompt        $positivePrompt `
        -Negative      $negativePrompt `
        -LoraEnabled   $loraEnabled `
        -LoraName      $selectedLora `
        -LoraStrength  $loraStrength
}
#>

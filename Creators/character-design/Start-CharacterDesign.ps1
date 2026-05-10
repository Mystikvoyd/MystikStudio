param(
    [switch]$ValidateOnly,
    [switch]$SmokeTest
)

$ErrorActionPreference = "Stop"

$LoraTesterRoot     = $PSScriptRoot
$ProjectRoot        = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$ConfigPath         = Join-Path $LoraTesterRoot "character-design.config.json"
$InvokeScriptPath   = Join-Path $ProjectRoot "Creators\comfyui\scripts\Invoke-ComfyTripleLoraTestImage.ps1"
$PrefsPath   = Join-Path $LoraTesterRoot "character-design.prefs.json"
$RunLogPath  = Join-Path $LoraTesterRoot "character-design.runlog.json"

# Session state
$script:SessionActive    = $false
$script:SessionEntries   = New-Object System.Collections.Generic.List[hashtable]
$script:ReportsFolder    = "C:\Users\Michael\Documents\ComfyUI\Reports"
$script:LastReportFolder = $script:ReportsFolder
if (-not (Test-Path -LiteralPath $script:ReportsFolder -PathType Container)) {
    New-Item -ItemType Directory -Path $script:ReportsFolder -Force | Out-Null
}

# ---------------------------------------------------------------------------
# Prefs: save/load last-used values so nothing resets between sessions
# ---------------------------------------------------------------------------
function Save-Prefs {
    $prefs = [ordered]@{
        lora1Name       = [string]$comboLora1.SelectedItem
        lora1Enabled    = $chkLora1.Checked
        lora1Strength   = [string]$numLora1.Value
        lora2Name       = [string]$comboLora2.SelectedItem
        lora2Enabled    = $chkLora2.Checked
        lora2Strength   = [string]$numLora2.Value
        lora3Name       = [string]$comboLora3.SelectedItem
        lora3Enabled    = $chkLora3.Checked
        lora3Strength   = [string]$numLora3.Value
        seed            = [string][int]$numSeed.Value
        randomSeed      = $chkRandomSeed.Checked
        steps           = [string][int]$numSteps.Value
        cfg             = [string]$numCfg.Value
        width           = [string][int]$numWidth.Value
        height          = [string][int]$numHeight.Value
        sampler         = [string]$comboSampler.SelectedItem
        scheduler       = [string]$comboScheduler.SelectedItem
        ckptStyle       = [string]$comboCkptStyle.SelectedItem
        ckptName        = [string]$comboCkpt.SelectedItem
        diffuser        = [string]$comboDiffuser.SelectedItem
        cnEnabled       = $chkCN.Checked
        cnModel         = [string]$comboCNModel.SelectedItem
        cnImage         = [string]$comboCNImage.SelectedItem
        cnFilter        = [string]$comboCNFilter.SelectedItem
        cnStrength      = [string]$numCNStrength.Value
        cnStart         = [string]$numCNStart.Value
        cnEnd           = [string]$numCNEnd.Value
        includePrompts  = $chkIncludePrompts.Checked
        prompt          = $txtPrompt.Text
        negativePrompt  = $txtNegative.Text
    }
    try {
        $prefs | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath $PrefsPath -Encoding UTF8
    } catch { }
}

function Load-Prefs {
    if (-not (Test-Path -LiteralPath $PrefsPath -PathType Leaf)) { return $null }
    try { return (Get-Content -LiteralPath $PrefsPath -Raw | ConvertFrom-Json) }
    catch { return $null }
}

function Restore-ComboValue {
    param($Combo, [string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return }
    $idx = $Combo.Items.IndexOf($Value)
    if ($idx -ge 0) { $Combo.SelectedIndex = $idx }
}

# ---------------------------------------------------------------------------
# HTML report builder
# ---------------------------------------------------------------------------
function HtmlEnc {
    param([string]$s)
    return $s -replace '&','&amp;' -replace '<','&lt;' -replace '>','&gt;' -replace '"','&quot;'
}

function New-SessionReport {
    param([string]$SavePath, [bool]$IncludePrompts)

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $count     = $script:SessionEntries.Count
    $sb        = New-Object System.Text.StringBuilder

    [void]$sb.Append('<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8">')
    [void]$sb.Append('<title>Character Design Session Report</title>')
    [void]$sb.Append('<style>')
    [void]$sb.Append('*{box-sizing:border-box;margin:0;padding:0}')
    [void]$sb.Append('body{font-family:"Segoe UI",sans-serif;background:#111116;color:#e0ddd8;padding:32px}')
    [void]$sb.Append('h1{font-size:1.5rem;font-weight:700;margin-bottom:6px;color:#f0ece4}')
    [void]$sb.Append('.toolbar{display:flex;align-items:center;gap:14px;margin-bottom:28px;flex-wrap:wrap}')
    [void]$sb.Append('.session-meta{font-size:.82rem;color:#666}')
    [void]$sb.Append('.toggle-wrap{display:flex;align-items:center;gap:8px;font-size:.82rem;color:#aaa;cursor:pointer;user-select:none}')
    [void]$sb.Append('.toggle-track{width:42px;height:22px;border-radius:11px;background:#2a2a38;border:1px solid #444;position:relative;transition:background .2s;flex-shrink:0}')
    [void]$sb.Append('.toggle-track.on{background:#1a3d2a;border-color:#2a6040}')
    [void]$sb.Append('.toggle-thumb{width:16px;height:16px;border-radius:50%;background:#aaa;position:absolute;top:2px;left:2px;transition:left .2s,background .2s}')
    [void]$sb.Append('.toggle-track.on .toggle-thumb{left:22px;background:#5ef09a}')
    [void]$sb.Append('.entry{display:grid;grid-template-columns:340px 1fr;gap:24px;background:#1c1c24;border:1px solid #2a2a38;border-radius:12px;padding:20px;margin-bottom:24px}')
    [void]$sb.Append('.entry-img img{width:100%;height:auto;border-radius:8px;display:block;border:1px solid #333}')
    [void]$sb.Append('.no-img{color:#c0392b;font-size:.83rem;padding:12px;background:#2a1a1a;border-radius:6px;border:1px solid #5a2020}')
    [void]$sb.Append('.entry-time{font-size:.78rem;color:#555;margin-bottom:12px}')
    [void]$sb.Append('.meta-table{width:100%;border-collapse:collapse;font-size:.87rem}')
    [void]$sb.Append('.meta-table th{text-align:left;width:80px;padding:5px 10px 5px 0;color:#777;vertical-align:top;white-space:nowrap;font-weight:600}')
    [void]$sb.Append('.meta-table td{padding:5px 0;color:#ccc;vertical-align:top}')
    [void]$sb.Append('.prompt-row{display:none}.prompt-row.visible{display:table-row}')
    [void]$sb.Append('.prompt-wrap{position:relative}')
    [void]$sb.Append('.prompt-cell{white-space:pre-wrap;word-break:break-word;color:#b0aa9e;font-size:.82rem;line-height:1.5;padding-right:68px}')
    [void]$sb.Append('.copy-btn{position:absolute;top:0;right:0;font-size:.7rem;font-weight:700;padding:2px 8px;border-radius:4px;border:1px solid #444;background:#2a2a38;color:#aaa;cursor:pointer;transition:background .15s,color .15s}')
    [void]$sb.Append('.copy-btn:hover{background:#3a3a50;color:#fff}')
    [void]$sb.Append('.copy-btn.copied{background:#1a3d2a;color:#5ef09a;border-color:#2a6040}')
    [void]$sb.Append('.file-path{font-size:.72rem;color:#444;word-break:break-all;font-family:"Consolas",monospace}')
    [void]$sb.Append('.badge{display:inline-block;font-size:.7rem;font-weight:800;padding:2px 8px;border-radius:4px;margin-right:6px;vertical-align:middle;letter-spacing:.05em}')
    [void]$sb.Append('.lora-on{background:#1a3d2a;color:#5ef09a;border:1px solid #2a6040}')
    [void]$sb.Append('.lora-off{background:#3d1a1a;color:#f07070;border:1px solid #602a2a}')
    [void]$sb.Append('</style>')

    # Only include the toggle JS if prompts were included in the report
    if ($IncludePrompts) {
        [void]$sb.Append('<script>')
        [void]$sb.Append('var promptsVisible=true;')
        [void]$sb.Append('function togglePrompts(){')
        [void]$sb.Append('  promptsVisible=!promptsVisible;')
        [void]$sb.Append('  var rows=document.querySelectorAll(".prompt-row");')
        [void]$sb.Append('  for(var i=0;i<rows.length;i++){rows[i].classList.toggle("visible",promptsVisible);}')
        [void]$sb.Append('  var track=document.getElementById("ptoggle");')
        [void]$sb.Append('  track.classList.toggle("on",promptsVisible);')
        [void]$sb.Append('  document.getElementById("plabel").textContent=promptsVisible?"Prompts ON":"Prompts OFF";')
        [void]$sb.Append('}')
        [void]$sb.Append('function copyText(btn,text){navigator.clipboard.writeText(text).then(function(){btn.textContent="COPIED";btn.classList.add("copied");setTimeout(function(){btn.textContent="COPY";btn.classList.remove("copied")},1800)})}')
        [void]$sb.Append('window.onload=function(){togglePrompts();}')
        [void]$sb.Append('</script>')
    }

    [void]$sb.Append('</head><body>')
    [void]$sb.Append('<h1>Character Design Session Report</h1>')

    [void]$sb.Append('<div class="toolbar">')
    [void]$sb.Append('<div class="session-meta">Generated: ' + $timestamp + ' &nbsp;&middot;&nbsp; ' + $count + ' generation(s)')
    if ($IncludePrompts) {
        [void]$sb.Append(' &nbsp;&middot;&nbsp; Prompts included')
    } else {
        [void]$sb.Append(' &nbsp;&middot;&nbsp; Prompts omitted')
    }
    [void]$sb.Append('</div>')

    if ($IncludePrompts) {
        [void]$sb.Append('<div class="toggle-wrap" onclick="togglePrompts()">')
        [void]$sb.Append('<div class="toggle-track on" id="ptoggle"><div class="toggle-thumb"></div></div>')
        [void]$sb.Append('<span id="plabel">Prompts ON</span>')
        [void]$sb.Append('</div>')
    }
    [void]$sb.Append('</div>')

    foreach ($e in $script:SessionEntries) {
        $imgPath = [string]$e.ImagePath

        if (-not [string]::IsNullOrWhiteSpace($imgPath) -and (Test-Path -LiteralPath $imgPath -PathType Leaf)) {
            try {
                $bytes  = [System.IO.File]::ReadAllBytes($imgPath)
                $b64    = [Convert]::ToBase64String($bytes)
                $ext    = [System.IO.Path]::GetExtension($imgPath).TrimStart('.').ToLower()
                $mime   = if ($ext -eq 'jpg') { 'jpeg' } else { $ext }
                $imgTag = '<img src="data:image/' + $mime + ';base64,' + $b64 + '" alt="preview">'
            } catch {
                $imgTag = '<p class="no-img">Embed failed: ' + (HtmlEnc $_.Exception.Message) + '</p>'
            }
        } else {
            $imgTag = '<p class="no-img">&#9888; Path not found: ' + (HtmlEnc $imgPath) + '</p>'
        }

        $loraLine = if ($e.Lora1Enabled -and $e.Lora2Enabled -and $e.Lora3Enabled) {
            '<span class="badge lora-on">LoRA 1+2+3 ON</span> ' + (HtmlEnc ([string]$e.Lora1Name)) +
            ' <span style="color:#777;font-size:.83rem">@ ' + ([string]$e.Lora1Strength) + '</span> + ' +
            (HtmlEnc ([string]$e.Lora2Name)) + ' <span style="color:#777;font-size:.83rem">@ ' + ([string]$e.Lora2Strength) + '</span> + ' +
            (HtmlEnc ([string]$e.Lora3Name)) + ' <span style="color:#777;font-size:.83rem">@ ' + ([string]$e.Lora3Strength) + '</span>'
        } elseif ($e.Lora1Enabled -and $e.Lora2Enabled) {
            '<span class="badge lora-on">LoRA 1+2 ON</span> ' + (HtmlEnc ([string]$e.Lora1Name)) +
            ' <span style="color:#777;font-size:.83rem">@ ' + ([string]$e.Lora1Strength) + '</span> + ' +
            (HtmlEnc ([string]$e.Lora2Name)) + ' <span style="color:#777;font-size:.83rem">@ ' + ([string]$e.Lora2Strength) + '</span>'
        } elseif ($e.Lora1Enabled -and $e.Lora3Enabled) {
            '<span class="badge lora-on">LoRA 1+3 ON</span> ' + (HtmlEnc ([string]$e.Lora1Name)) +
            ' <span style="color:#777;font-size:.83rem">@ ' + ([string]$e.Lora1Strength) + '</span> + ' +
            (HtmlEnc ([string]$e.Lora3Name)) + ' <span style="color:#777;font-size:.83rem">@ ' + ([string]$e.Lora3Strength) + '</span>'
        } elseif ($e.Lora2Enabled -and $e.Lora3Enabled) {
            '<span class="badge lora-on">LoRA 2+3 ON</span> ' + (HtmlEnc ([string]$e.Lora2Name)) +
            ' <span style="color:#777;font-size:.83rem">@ ' + ([string]$e.Lora2Strength) + '</span> + ' +
            (HtmlEnc ([string]$e.Lora3Name)) + ' <span style="color:#777;font-size:.83rem">@ ' + ([string]$e.Lora3Strength) + '</span>'
        } elseif ($e.Lora1Enabled) {
            '<span class="badge lora-on">LoRA 1 ON</span> ' + (HtmlEnc ([string]$e.Lora1Name)) +
            ' <span style="color:#777;font-size:.83rem">@ ' + ([string]$e.Lora1Strength) + '</span>'
        } elseif ($e.Lora2Enabled) {
            '<span class="badge lora-on">LoRA 2 ON</span> ' + (HtmlEnc ([string]$e.Lora2Name)) +
            ' <span style="color:#777;font-size:.83rem">@ ' + ([string]$e.Lora2Strength) + '</span>'
        } elseif ($e.Lora3Enabled) {
            '<span class="badge lora-on">LoRA 3 ON</span> ' + (HtmlEnc ([string]$e.Lora3Name)) +
            ' <span style="color:#777;font-size:.83rem">@ ' + ([string]$e.Lora3Strength) + '</span>'
        } else {
            '<span class="badge lora-off">LoRAs OFF</span>'
        }

        [void]$sb.Append('<div class="entry">')
        [void]$sb.Append('<div class="entry-img">' + $imgTag + '</div>')
        [void]$sb.Append('<div class="entry-meta">')
        [void]$sb.Append('<div class="entry-time">' + (HtmlEnc ([string]$e.Time)) + '</div>')
        [void]$sb.Append('<table class="meta-table">')
        [void]$sb.Append('<tr><th>LoRA</th><td>'      + $loraLine + '</td></tr>')
        [void]$sb.Append('<tr><th>Seed</th><td>'      + (HtmlEnc ([string]$e.Seed))      + '</td></tr>')
        [void]$sb.Append('<tr><th>Steps</th><td>'     + (HtmlEnc ([string]$e.Steps))     + '</td></tr>')
        [void]$sb.Append('<tr><th>CFG</th><td>'       + (HtmlEnc ([string]$e.Cfg))       + '</td></tr>')
        [void]$sb.Append('<tr><th>Sampler</th><td>'   + (HtmlEnc ([string]$e.Sampler))   + ' / ' + (HtmlEnc ([string]$e.Scheduler)) + '</td></tr>')
        [void]$sb.Append('<tr><th>Size</th><td>'      + (HtmlEnc ([string]$e.Width)) + ' x ' + (HtmlEnc ([string]$e.Height)) + '</td></tr>')
        [void]$sb.Append('<tr><th>Checkpoint</th><td>'+ (HtmlEnc ([string]$e.Checkpoint))+ '</td></tr>')

        if ($IncludePrompts) {
            $promptRaw = [string]$e.Prompt
            $negRaw    = [string]$e.NegativePrompt
            $promptJs  = $promptRaw -replace "\\","\\\\" -replace "'","\'" -replace "`r`n","\\n" -replace "`n","\\n"
            $negJs     = $negRaw    -replace "\\","\\\\" -replace "'","\'" -replace "`r`n","\\n" -replace "`n","\\n"
            $pRow = '<tr class="prompt-row visible"><th>Prompt</th><td><div class="prompt-wrap"><button class="copy-btn" onclick="copyText(this,' + [char]39 + $promptJs + [char]39 + ')">COPY</button><div class="prompt-cell">' + (HtmlEnc $promptRaw) + '</div></div></td></tr>'
            $nRow = '<tr class="prompt-row visible"><th>Negative</th><td><div class="prompt-wrap"><button class="copy-btn" onclick="copyText(this,' + [char]39 + $negJs + [char]39 + ')">COPY</button><div class="prompt-cell">' + (HtmlEnc $negRaw) + '</div></div></td></tr>'
            [void]$sb.Append($pRow)
            [void]$sb.Append($nRow)
        }

        [void]$sb.Append('<tr><th>File</th><td class="file-path">' + (HtmlEnc $imgPath) + '</td></tr>')
        [void]$sb.Append('</table></div></div>')
    }

    [void]$sb.Append('</body></html>')
    [System.IO.File]::WriteAllText($SavePath, $sb.ToString(), [System.Text.Encoding]::UTF8)
}

# ---------------------------------------------------------------------------
# Config / helpers
# ---------------------------------------------------------------------------
function Read-LoraTesterConfig {
    if (-not (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) {
        throw "Missing LoRA tester config: $ConfigPath"
    }
    Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
}

function Get-WorkflowPath {
    param($Config)
    $path = [string]$Config.workflowPath
    if ([System.IO.Path]::IsPathRooted($path)) { return $path }
    return Join-Path $ProjectRoot $path
}

function Get-ComfyLoraRoot {
    param($Config)
    $inputPath = [string]$Config.comfyInputPath
    if ([string]::IsNullOrWhiteSpace($inputPath)) { return $null }
    $loraRoot = Join-Path (Split-Path -Parent $inputPath) "models\loras"
    if (-not (Test-Path -LiteralPath $loraRoot -PathType Container)) { return $null }
    return $loraRoot
}

function Get-ComfyLoraItems {
    param($Config)
    $items = New-Object System.Collections.Generic.List[string]
    [void]$items.Add("None")
    $loraRoot = Get-ComfyLoraRoot -Config $Config
    if ([string]::IsNullOrWhiteSpace($loraRoot)) { return @($items.ToArray()) }
    $rootFull = [System.IO.Path]::GetFullPath($loraRoot)
    if (-not $rootFull.EndsWith([System.IO.Path]::DirectorySeparatorChar)) {
        $rootFull = $rootFull + [System.IO.Path]::DirectorySeparatorChar
    }
    Get-ChildItem -LiteralPath $loraRoot -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Extension -in @(".safetensors", ".ckpt", ".pt") } |
        Sort-Object FullName |
        ForEach-Object {
            $full = [System.IO.Path]::GetFullPath($_.FullName)
            [void]$items.Add($full.Substring($rootFull.Length))
        }
    return @($items.ToArray())
}

function Get-CheckpointItems {
    param([string]$SubFolder = "")
    $items    = New-Object System.Collections.Generic.List[string]
    $ckptRoot = "C:\Users\Michael\Documents\ComfyUI\models\checkpoints"
    $scanBase = if (-not [string]::IsNullOrWhiteSpace($SubFolder)) {
        [System.IO.Path]::Combine($ckptRoot, $SubFolder)
    } else {
        $ckptRoot
    }
    if (-not [System.IO.Directory]::Exists($scanBase)) { return @($items.ToArray()) }

    # Always strip from the checkpoints root so ComfyUI gets e.g. "SDXL\model.safetensors"
    $rootFull = [System.IO.Path]::GetFullPath($ckptRoot)
    if (-not $rootFull.EndsWith([System.IO.Path]::DirectorySeparatorChar)) {
        $rootFull = $rootFull + [System.IO.Path]::DirectorySeparatorChar
    }
    Get-ChildItem -LiteralPath $scanBase -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Extension -in @(".safetensors", ".ckpt", ".pt") } |
        Sort-Object Name |
        ForEach-Object {
            $full = [System.IO.Path]::GetFullPath($_.FullName)
            [void]$items.Add($full.Substring($rootFull.Length))
        }
    return @($items.ToArray())
}

function Get-ControlNetItems {
    $items = New-Object System.Collections.Generic.List[string]
    [void]$items.Add("None")
    $base = "C:\Users\Michael\Documents\ComfyUI\models\controlnet"
    if (-not [System.IO.Directory]::Exists($base)) { return @($items.ToArray()) }
    $rootFull = [System.IO.Path]::GetFullPath($base)
    if (-not $rootFull.EndsWith([System.IO.Path]::DirectorySeparatorChar)) {
        $rootFull = $rootFull + [System.IO.Path]::DirectorySeparatorChar
    }
    Get-ChildItem -LiteralPath $base -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Extension -in @(".safetensors", ".ckpt", ".pt", ".pth") } |
        Sort-Object Name |
        ForEach-Object {
            $full = [System.IO.Path]::GetFullPath($_.FullName)
            [void]$items.Add($full.Substring($rootFull.Length))
        }
    return @($items.ToArray())
}

function Get-ControlNetImages {
    $items = New-Object System.Collections.Generic.List[string]
    [void]$items.Add("None")
    $base = "C:\Users\Michael\Documents\ComfyUI\input"
    if (-not [System.IO.Directory]::Exists($base)) { return @($items.ToArray()) }
    Get-ChildItem -LiteralPath $base -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Extension -in @(".png", ".jpg", ".jpeg", ".webp", ".bmp") } |
        Sort-Object Name |
        ForEach-Object { [void]$items.Add($_.Name) }
    return @($items.ToArray())
}

function Get-SafeFilePart {
    param([string]$Text, [string]$Fallback = "lora_test")
    if ([string]::IsNullOrWhiteSpace($Text)) { return $Fallback }
    $clean = $Text.ToLowerInvariant() -replace "[^a-z0-9]+", "_"
    $clean = $clean.Trim("_")
    if ([string]::IsNullOrWhiteSpace($clean)) { return $Fallback }
    return $clean
}

function Add-Log {
    param([string]$Text)
    if ($null -eq $script:LogBox) { return }
    $script:LogBox.AppendText('[' + (Get-Date -Format 'HH:mm:ss') + '] ' + $Text + "`r`n")
    $script:LogBox.SelectionStart = $script:LogBox.TextLength
    $script:LogBox.ScrollToCaret()
}

function Add-OutputHistoryItem {
    param([string]$Path, [string]$LoraName = "", [string]$Seed = "", [switch]$Select)
    if ([string]::IsNullOrWhiteSpace($Path)) { return }
    for ($i = $gridOutputs.Rows.Count - 1; $i -ge 0; $i--) {
        if (-not $gridOutputs.Rows[$i].IsNewRow -and
            [string]$gridOutputs.Rows[$i].Cells["Path"].Value -eq $Path) {
            $gridOutputs.Rows.RemoveAt($i)
        }
    }
    $name  = [System.IO.Path]::GetFileName($Path)
    $stamp = ""
    if (Test-Path -LiteralPath $Path -PathType Leaf) {
        $stamp = (Get-Item -LiteralPath $Path).LastWriteTime.ToString("HH:mm:ss")
    }
    $gridOutputs.Rows.Insert(0, $stamp, $name, $LoraName, $Seed, $Path)
    if ($Select) {
        $gridOutputs.ClearSelection()
        $gridOutputs.Rows[0].Selected = $true
        $gridOutputs.CurrentCell = $gridOutputs.Rows[0].Cells["File"]
    }
}

function Get-SelectedOutputPath {
    if ($gridOutputs.SelectedRows.Count -lt 1) { return $null }
    return [string]$gridOutputs.SelectedRows[0].Cells["Path"].Value
}

function Append-RunLog {
    param([hashtable]$Entry)
    try {
        $existing = @()
        if ([System.IO.File]::Exists($RunLogPath)) {
            $raw = [System.IO.File]::ReadAllText($RunLogPath)
            if (-not [string]::IsNullOrWhiteSpace($raw)) {
                $existing = $raw | ConvertFrom-Json
                if ($existing -isnot [array]) { $existing = @($existing) }
            }
        }
        $existing += [pscustomobject]@{
            Time       = $Entry.Time
            ImagePath  = $Entry.ImagePath
            Lora1Name   = $Entry.Lora1Name
            Lora1Enabled= $Entry.Lora1Enabled
            Lora1Strength = $Entry.Lora1Strength
            Lora2Name   = $Entry.Lora2Name
            Lora2Enabled= $Entry.Lora2Enabled
            Lora2Strength = $Entry.Lora2Strength
            Lora3Name   = $Entry.Lora3Name
            Lora3Enabled= $Entry.Lora3Enabled
            Lora3Strength = $Entry.Lora3Strength
            Seed       = $Entry.Seed
            Steps      = $Entry.Steps
            Cfg        = $Entry.Cfg
            Width      = $Entry.Width
            Height     = $Entry.Height
            Sampler    = $Entry.Sampler
            Scheduler  = $Entry.Scheduler
            Checkpoint = $Entry.Checkpoint
            Prompt     = $Entry.Prompt
            NegativePrompt = $Entry.NegativePrompt
        }
        # Keep last 200 runs
        if ($existing.Count -gt 200) { $existing = $existing[($existing.Count - 200)..($existing.Count - 1)] }
        $existing | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $RunLogPath -Encoding UTF8
    } catch { }
}

function Load-RunHistory {
    if (-not [System.IO.File]::Exists($RunLogPath)) {
        # No log yet — fall back to scanning output folder (no metadata)
        Load-OutputFolderHistory
        return
    }
    try {
        $raw = [System.IO.File]::ReadAllText($RunLogPath)
        if ([string]::IsNullOrWhiteSpace($raw)) { Load-OutputFolderHistory; return }
        $entries = $raw | ConvertFrom-Json
        if ($entries -isnot [array]) { $entries = @($entries) }
        # Most recent first
        [array]::Reverse($entries)
        foreach ($e in $entries) {
            $imgPath   = [string]$e.ImagePath
        $lora1Name = if ($e.Lora1Enabled) { [System.IO.Path]::GetFileNameWithoutExtension([string]$e.Lora1Name) } else { $null }
        $lora2Name = if ($e.Lora2Enabled) { [System.IO.Path]::GetFileNameWithoutExtension([string]$e.Lora2Name) } else { $null }
        $lora3Name = if ($e.Lora3Enabled) { [System.IO.Path]::GetFileNameWithoutExtension([string]$e.Lora3Name) } else { $null }
        $loraLabel = @()
        if ($lora1Name) { $loraLabel += $lora1Name }
        if ($lora2Name) { $loraLabel += $lora2Name }
        if ($lora3Name) { $loraLabel += $lora3Name }
        if ($loraLabel.Count -eq 0) { $loraLabel = "LoRAs off" } else { $loraLabel = $loraLabel -join " + " }
            $seed      = [string]$e.Seed
            $ckpt      = [string]$e.Checkpoint
            $time      = [string]$e.Time
            if ([string]::IsNullOrWhiteSpace($imgPath)) { continue }
            $name     = [System.IO.Path]::GetFileName($imgPath)
            $stamp    = if ($time.Length -ge 16) { $time.Substring(0, 16) } else { $time }
            $ckptShort = [System.IO.Path]::GetFileNameWithoutExtension([string]$e.Checkpoint)
            $gridOutputs.Rows.Add($stamp, $name, $loraLabel, $seed, $imgPath, $ckptShort) | Out-Null
        }
        if ($gridOutputs.Rows.Count -gt 0) {
            $gridOutputs.Rows[0].Selected = $true
            $gridOutputs.CurrentCell      = $gridOutputs.Rows[0].Cells["File"]
            $p = [string]$gridOutputs.Rows[0].Cells["Path"].Value
            if (-not [string]::IsNullOrWhiteSpace($p)) { Set-PreviewImage -Path $p }
        }
    } catch {
        Load-OutputFolderHistory
    }
}

function Load-OutputFolderHistory {
    param($Config = $script:Config)
    $outputPath = [string]$Config.comfyOutputPath
    if ([string]::IsNullOrWhiteSpace($outputPath) -or
        -not (Test-Path -LiteralPath $outputPath -PathType Container)) { return }
    $prefix = [string]$Config.defaults.prefix
    Get-ChildItem -LiteralPath $outputPath -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like ($prefix + "*") -and $_.Extension -in @(".png", ".jpg", ".jpeg", ".webp") } |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 100 |
        ForEach-Object { Add-OutputHistoryItem -Path $_.FullName }
}

function Set-PreviewImage {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path) -or
        -not (Test-Path -LiteralPath $Path -PathType Leaf)) { return }
    if ($null -ne $script:PreviewBox.Image) {
        $script:PreviewBox.Image.Dispose()
        $script:PreviewBox.Image = $null
    }
    $bytes  = [System.IO.File]::ReadAllBytes($Path)
    $stream = New-Object System.IO.MemoryStream(,$bytes)
    $script:PreviewBox.Image = [System.Drawing.Image]::FromStream($stream)
}

function Wait-ComfyImages {
    param([string]$PromptId, [string]$ComfyUrl, [string]$OutputPath)
    $script:LastImagePaths = New-Object System.Collections.Generic.List[string]
    for ($i = 0; $i -lt 180; $i++) {
        Start-Sleep -Seconds 1
        $history = Invoke-RestMethod -Method Get -Uri ($ComfyUrl + "/history/" + $PromptId) -TimeoutSec 10
        $entry   = $history.$PromptId
        if ($null -eq $entry) { continue }
        $script:LastImagePaths.Clear()
        foreach ($prop in $entry.outputs.PSObject.Properties) {
            foreach ($image in @($prop.Value.images)) {
                if ($null -ne $image -and -not [string]::IsNullOrWhiteSpace([string]$image.filename)) {
                    $fullPath = [System.IO.Path]::Combine($OutputPath, [string]$image.filename)
                    $script:LastImagePaths.Add($fullPath)
                }
            }
        }
        if ($script:LastImagePaths.Count -gt 0) { return }
    }
    throw "Timed out waiting for ComfyUI output."
}

function Update-SessionButton {
    if ($script:SessionActive) {
        $script:btnSession.Text      = "[ STOP SESSION ]"
        $script:btnSession.BackColor = [System.Drawing.Color]::FromArgb(180, 40, 40)
        $script:btnSession.ForeColor = [System.Drawing.Color]::White
    } else {
        $script:btnSession.Text      = "[ START SESSION ]"
        $script:btnSession.BackColor = [System.Drawing.Color]::FromArgb(34, 120, 64)
        $script:btnSession.ForeColor = [System.Drawing.Color]::White
    }
}

# ---------------------------------------------------------------------------
# Bootstrap
# ---------------------------------------------------------------------------
$script:Config = Read-LoraTesterConfig
$Config        = $script:Config
if ($ValidateOnly) {
    "LoRA tester config OK: $ConfigPath"
    "Workflow: $(Get-WorkflowPath -Config $Config)"
    return
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# ---------------------------------------------------------------------------
# Form
# ---------------------------------------------------------------------------
$form               = New-Object System.Windows.Forms.Form
$form.Text          = "ComfyUI Character Design"
$form.Width         = 1280
$form.Height        = 860
$form.StartPosition = "CenterScreen"
$form.Font          = New-Object System.Drawing.Font("Segoe UI", 9)

# Right panel FIRST so Dock=Fill works correctly
$right             = New-Object System.Windows.Forms.TableLayoutPanel
$right.Dock        = "Fill"
$right.ColumnCount = 1
$right.RowCount    = 2
$right.Padding     = New-Object System.Windows.Forms.Padding(8)
[void]$right.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 68)))
[void]$right.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 32)))
$form.Controls.Add($right)

$left         = New-Object System.Windows.Forms.Panel
$left.Dock    = "Left"
$left.Width   = 430
$left.Padding = New-Object System.Windows.Forms.Padding(6)
$form.Controls.Add($left)

function New-Label {
    param([string]$Text, [int]$Top, $Parent)
    $lbl        = New-Object System.Windows.Forms.Label
    $lbl.Text   = $Text
    $lbl.Left   = 8
    $lbl.Top    = $Top
    $lbl.Width  = 390
    $lbl.Height = 18
    $Parent.Controls.Add($lbl)
    return $lbl
}

# TabControl
$tabs        = New-Object System.Windows.Forms.TabControl
$tabs.Left   = 2
$tabs.Top    = 2
$tabs.Width  = 422
$tabs.Height = 800
$tabs.Font   = New-Object System.Drawing.Font("Segoe UI", 8.5)
$left.Controls.Add($tabs)

$tabMain  = New-Object System.Windows.Forms.TabPage; $tabMain.Text  = "Generation"; $tabMain.Padding  = New-Object System.Windows.Forms.Padding(6); $tabs.TabPages.Add($tabMain)
$tabModel = New-Object System.Windows.Forms.TabPage; $tabModel.Text = "Models";     $tabModel.Padding = New-Object System.Windows.Forms.Padding(6); $tabs.TabPages.Add($tabModel)
$tabCN    = New-Object System.Windows.Forms.TabPage; $tabCN.Text    = "ControlNet"; $tabCN.Padding    = New-Object System.Windows.Forms.Padding(6); $tabs.TabPages.Add($tabCN)

# ===========================================================================
# TAB 1: Generation  (prompt, neg, LoRA, seed/steps/cfg, size, sampler/sched,
#                     session controls, include-prompts checkbox, log)
# ===========================================================================
$gy = 4

New-Label -Text "Prompt" -Top $gy -Parent $tabMain | Out-Null
$txtPrompt            = New-Object System.Windows.Forms.TextBox
$txtPrompt.Multiline  = $true
$txtPrompt.Left       = 8; $txtPrompt.Top = $gy + 18; $txtPrompt.Width = 392; $txtPrompt.Height = 90
$txtPrompt.ScrollBars = "Vertical"
$txtPrompt.Text       = [string]$Config.prompt
$tabMain.Controls.Add($txtPrompt)
$gy += 116

New-Label -Text "Negative prompt" -Top $gy -Parent $tabMain | Out-Null
$txtNegative            = New-Object System.Windows.Forms.TextBox
$txtNegative.Multiline  = $true
$txtNegative.Left       = 8; $txtNegative.Top = $gy + 18; $txtNegative.Width = 392; $txtNegative.Height = 70
$txtNegative.ScrollBars = "Vertical"
$txtNegative.Text       = [string]$Config.negativePrompt
$tabMain.Controls.Add($txtNegative)
$gy += 96

New-Label -Text "LoRA 1 (Character)" -Top $gy -Parent $tabMain | Out-Null
$comboLora1               = New-Object System.Windows.Forms.ComboBox
$comboLora1.Left          = 8; $comboLora1.Top = $gy + 18; $comboLora1.Width = 392
$comboLora1.DropDownStyle = "DropDownList"
foreach ($item in (Get-ComfyLoraItems -Config $Config)) { [void]$comboLora1.Items.Add($item) }
$comboLora1.SelectedIndex = 0
$tabMain.Controls.Add($comboLora1)
$gy += 46

$chkLora1         = New-Object System.Windows.Forms.CheckBox
$chkLora1.Text    = "Use LoRA 1"; $chkLora1.Left = 8; $chkLora1.Top = $gy; $chkLora1.Width = 170; $chkLora1.Checked = $true
$tabMain.Controls.Add($chkLora1)

$lblLora1Str      = New-Object System.Windows.Forms.Label
$lblLora1Str.Text = "Strength:"; $lblLora1Str.Left = 186; $lblLora1Str.Top = $gy + 2; $lblLora1Str.Width = 58
$tabMain.Controls.Add($lblLora1Str)

$numLora1              = New-Object System.Windows.Forms.NumericUpDown
$numLora1.Left         = 248; $numLora1.Top = $gy; $numLora1.Width = 76
$numLora1.DecimalPlaces= 2; $numLora1.Minimum = 0; $numLora1.Maximum = 2; $numLora1.Increment = 0.05
$numLora1.Value        = [decimal]$Config.defaults.lora1Strength
$tabMain.Controls.Add($numLora1)
$gy += 32

New-Label -Text "LoRA 2 (Enhancement)" -Top $gy -Parent $tabMain | Out-Null
$comboLora2               = New-Object System.Windows.Forms.ComboBox
$comboLora2.Left          = 8; $comboLora2.Top = $gy + 18; $comboLora2.Width = 392
$comboLora2.DropDownStyle = "DropDownList"
foreach ($item in (Get-ComfyLoraItems -Config $Config)) { [void]$comboLora2.Items.Add($item) }
$comboLora2.SelectedIndex = 0
$tabMain.Controls.Add($comboLora2)
$gy += 46

$chkLora2         = New-Object System.Windows.Forms.CheckBox
$chkLora2.Text    = "Use LoRA 2"; $chkLora2.Left = 8; $chkLora2.Top = $gy; $chkLora2.Width = 170; $chkLora2.Checked = $true
$tabMain.Controls.Add($chkLora2)

$lblLora2Str      = New-Object System.Windows.Forms.Label
$lblLora2Str.Text = "Strength:"; $lblLora2Str.Left = 186; $lblLora2Str.Top = $gy + 2; $lblLora2Str.Width = 58
$tabMain.Controls.Add($lblLora2Str)

$numLora2              = New-Object System.Windows.Forms.NumericUpDown
$numLora2.Left         = 248; $numLora2.Top = $gy; $numLora2.Width = 76
$numLora2.DecimalPlaces= 2; $numLora2.Minimum = 0; $numLora2.Maximum = 2; $numLora2.Increment = 0.05
$numLora2.Value        = [decimal]$Config.defaults.lora2Strength
$tabMain.Controls.Add($numLora2)
$gy += 32

New-Label -Text "LoRA 3 (Style/Detail)" -Top $gy -Parent $tabMain | Out-Null
$comboLora3               = New-Object System.Windows.Forms.ComboBox
$comboLora3.Left          = 8; $comboLora3.Top = $gy + 18; $comboLora3.Width = 392
$comboLora3.DropDownStyle = "DropDownList"
foreach ($item in (Get-ComfyLoraItems -Config $Config)) { [void]$comboLora3.Items.Add($item) }
$comboLora3.SelectedIndex = 0
$tabMain.Controls.Add($comboLora3)
$gy += 46

$chkLora3         = New-Object System.Windows.Forms.CheckBox
$chkLora3.Text    = "Use LoRA 3"; $chkLora3.Left = 8; $chkLora3.Top = $gy; $chkLora3.Width = 170; $chkLora3.Checked = $false
$tabMain.Controls.Add($chkLora3)

$lblLora3Str      = New-Object System.Windows.Forms.Label
$lblLora3Str.Text = "Strength:"; $lblLora3Str.Left = 186; $lblLora3Str.Top = $gy + 2; $lblLora3Str.Width = 58
$tabMain.Controls.Add($lblLora3Str)

$numLora3              = New-Object System.Windows.Forms.NumericUpDown
$numLora3.Left         = 248; $numLora3.Top = $gy; $numLora3.Width = 76
$numLora3.DecimalPlaces= 2; $numLora3.Minimum = 0; $numLora3.Maximum = 2; $numLora3.Increment = 0.05
$numLora3.Value        = [decimal]$Config.defaults.lora3Strength
$tabMain.Controls.Add($numLora3)
$gy += 32

# Seed row: checkbox + spinner + Steps + CFG
$chkRandomSeed         = New-Object System.Windows.Forms.CheckBox
$chkRandomSeed.Text    = "Random seed"
$chkRandomSeed.Left    = 8; $chkRandomSeed.Top = $gy; $chkRandomSeed.Width = 110; $chkRandomSeed.Height = 18
$chkRandomSeed.Checked = $true
$tabMain.Controls.Add($chkRandomSeed)

$numSeed         = New-Object System.Windows.Forms.NumericUpDown
$numSeed.Left    = 8; $numSeed.Top = $gy + 18; $numSeed.Width = 110
$numSeed.Maximum = 2147483647; $numSeed.Minimum = 1; $numSeed.Value = (Get-Random -Minimum 1 -Maximum 2147483647)
$numSeed.Enabled = $false
$tabMain.Controls.Add($numSeed)

$lblSteps      = New-Object System.Windows.Forms.Label
$lblSteps.Text = "Steps"; $lblSteps.Left = 128; $lblSteps.Top = $gy; $lblSteps.Width = 50
$tabMain.Controls.Add($lblSteps)
$numSteps         = New-Object System.Windows.Forms.NumericUpDown
$numSteps.Left    = 128; $numSteps.Top = $gy + 18; $numSteps.Width = 70
$numSteps.Minimum = 1; $numSteps.Maximum = 150; $numSteps.Value = [decimal]$Config.defaults.steps
$tabMain.Controls.Add($numSteps)

$lblCfg      = New-Object System.Windows.Forms.Label
$lblCfg.Text = "CFG"; $lblCfg.Left = 210; $lblCfg.Top = $gy; $lblCfg.Width = 40
$tabMain.Controls.Add($lblCfg)
$numCfg              = New-Object System.Windows.Forms.NumericUpDown
$numCfg.Left         = 210; $numCfg.Top = $gy + 18; $numCfg.Width = 70
$numCfg.DecimalPlaces= 1; $numCfg.Minimum = 1; $numCfg.Maximum = 20; $numCfg.Increment = 0.1
$numCfg.Value        = [decimal]$Config.defaults.cfg
$tabMain.Controls.Add($numCfg)
$gy += 46

# Size row
New-Label -Text "Size (W x H)" -Top $gy -Parent $tabMain | Out-Null
$numWidth         = New-Object System.Windows.Forms.NumericUpDown
$numWidth.Left    = 8; $numWidth.Top = $gy + 18; $numWidth.Width = 90
$numWidth.Minimum = 256; $numWidth.Maximum = 2048; $numWidth.Increment = 64
$numWidth.Value   = [decimal]$Config.defaults.width
$tabMain.Controls.Add($numWidth)

$lblX = New-Object System.Windows.Forms.Label; $lblX.Text = "x"; $lblX.Left = 104; $lblX.Top = $gy + 20; $lblX.Width = 14
$tabMain.Controls.Add($lblX)

$numHeight         = New-Object System.Windows.Forms.NumericUpDown
$numHeight.Left    = 120; $numHeight.Top = $gy + 18; $numHeight.Width = 90
$numHeight.Minimum = 256; $numHeight.Maximum = 2048; $numHeight.Increment = 64
$numHeight.Value   = [decimal]$Config.defaults.height
$tabMain.Controls.Add($numHeight)
$gy += 46

# Sampler / Scheduler on Generation tab (no more tab-switching for these)
$lblSampler = New-Object System.Windows.Forms.Label; $lblSampler.Text = "Sampler"; $lblSampler.Left = 8; $lblSampler.Top = $gy; $lblSampler.Width = 190; $lblSampler.Height = 18
$tabMain.Controls.Add($lblSampler)
$lblScheduler = New-Object System.Windows.Forms.Label; $lblScheduler.Text = "Scheduler"; $lblScheduler.Left = 212; $lblScheduler.Top = $gy; $lblScheduler.Width = 180; $lblScheduler.Height = 18
$tabMain.Controls.Add($lblScheduler)

$comboSampler               = New-Object System.Windows.Forms.ComboBox
$comboSampler.Left          = 8; $comboSampler.Top = $gy + 18; $comboSampler.Width = 192; $comboSampler.DropDownStyle = "DropDownList"
@("dpmpp_2m","dpmpp_2m_sde","dpmpp_3m_sde","euler","euler_ancestral","heun","dpm_2","dpm_2_ancestral","lms","ddim","uni_pc") |
    ForEach-Object { [void]$comboSampler.Items.Add($_) }
$idx = $comboSampler.Items.IndexOf([string]$Config.defaults.sampler)
$comboSampler.SelectedIndex = if ($idx -ge 0) { $idx } else { 0 }
$tabMain.Controls.Add($comboSampler)

$comboScheduler               = New-Object System.Windows.Forms.ComboBox
$comboScheduler.Left          = 212; $comboScheduler.Top = $gy + 18; $comboScheduler.Width = 180; $comboScheduler.DropDownStyle = "DropDownList"
@("karras","exponential","simple","ddim_uniform","beta","sgm_uniform","normal") |
    ForEach-Object { [void]$comboScheduler.Items.Add($_) }
$sidx = $comboScheduler.Items.IndexOf([string]$Config.defaults.scheduler)
$comboScheduler.SelectedIndex = if ($sidx -ge 0) { $sidx } else { 0 }
$tabMain.Controls.Add($comboScheduler)
$gy += 46

# Buttons row
$btnGenerate        = New-Object System.Windows.Forms.Button
$btnGenerate.Text   = "Generate"; $btnGenerate.Left = 8; $btnGenerate.Top = $gy; $btnGenerate.Width = 118; $btnGenerate.Height = 30
$tabMain.Controls.Add($btnGenerate)

$btnRefresh        = New-Object System.Windows.Forms.Button
$btnRefresh.Text   = "Refresh LoRAs"; $btnRefresh.Left = 134; $btnRefresh.Top = $gy; $btnRefresh.Width = 118; $btnRefresh.Height = 30
$tabMain.Controls.Add($btnRefresh)

$btnOutput        = New-Object System.Windows.Forms.Button
$btnOutput.Text   = "Open Output"; $btnOutput.Left = 260; $btnOutput.Top = $gy; $btnOutput.Width = 118; $btnOutput.Height = 30
$tabMain.Controls.Add($btnOutput)
$gy += 38

# Session row
$script:btnSession           = New-Object System.Windows.Forms.Button
$script:btnSession.Left      = 8; $script:btnSession.Top = $gy; $script:btnSession.Width = 232; $script:btnSession.Height = 30
$script:btnSession.FlatStyle = "Flat"
$script:btnSession.Font      = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$tabMain.Controls.Add($script:btnSession)
Update-SessionButton

$script:btnOpenReport           = New-Object System.Windows.Forms.Button
$script:btnOpenReport.Left      = 248; $script:btnOpenReport.Top = $gy; $script:btnOpenReport.Width = 74; $script:btnOpenReport.Height = 30
$script:btnOpenReport.Text      = "Reports"
$script:btnOpenReport.FlatStyle = "Flat"
$script:btnOpenReport.BackColor = [System.Drawing.Color]::FromArgb(50, 50, 60)
$script:btnOpenReport.ForeColor = [System.Drawing.Color]::FromArgb(200, 200, 210)
$tabMain.Controls.Add($script:btnOpenReport)
$gy += 36

# Include prompts checkbox - visible on Generation tab, controls session report content
$chkIncludePrompts         = New-Object System.Windows.Forms.CheckBox
$chkIncludePrompts.Text    = "Include prompts in session report"
$chkIncludePrompts.Left    = 8; $chkIncludePrompts.Top = $gy; $chkIncludePrompts.Width = 280; $chkIncludePrompts.Height = 20
$chkIncludePrompts.Checked = $false
$tabMain.Controls.Add($chkIncludePrompts)
$gy += 26

# Log box
$script:LogBox            = New-Object System.Windows.Forms.TextBox
$script:LogBox.Multiline  = $true
$script:LogBox.Left       = 8; $script:LogBox.Top = $gy; $script:LogBox.Width = 392; $script:LogBox.Height = 110
$script:LogBox.ScrollBars = "Vertical"; $script:LogBox.ReadOnly = $true
$tabMain.Controls.Add($script:LogBox)

# ===========================================================================
# TAB 2: Models (checkpoint style/picker, VAE, note about sampler moved)
# ===========================================================================
$my = 6

$lblCkptStyle = New-Object System.Windows.Forms.Label; $lblCkptStyle.Text = "Checkpoint style"; $lblCkptStyle.Left = 8; $lblCkptStyle.Top = $my; $lblCkptStyle.Width = 200; $lblCkptStyle.Height = 18
$tabModel.Controls.Add($lblCkptStyle)

$comboCkptStyle               = New-Object System.Windows.Forms.ComboBox
$comboCkptStyle.Left          = 8; $comboCkptStyle.Top = $my + 20; $comboCkptStyle.Width = 180; $comboCkptStyle.DropDownStyle = "DropDownList"
@("All checkpoints","SDXL","SD1.5","Flux","SD3") | ForEach-Object { [void]$comboCkptStyle.Items.Add($_) }
$comboCkptStyle.SelectedIndex = 1
$tabModel.Controls.Add($comboCkptStyle)

$btnRefreshCkpt        = New-Object System.Windows.Forms.Button
$btnRefreshCkpt.Text   = "Refresh"; $btnRefreshCkpt.Left = 200; $btnRefreshCkpt.Top = $my + 18; $btnRefreshCkpt.Width = 80; $btnRefreshCkpt.Height = 26
$tabModel.Controls.Add($btnRefreshCkpt)
$my += 54

$lblCkpt = New-Object System.Windows.Forms.Label; $lblCkpt.Text = "Checkpoint"; $lblCkpt.Left = 8; $lblCkpt.Top = $my; $lblCkpt.Width = 390; $lblCkpt.Height = 18
$tabModel.Controls.Add($lblCkpt)
$comboCkpt               = New-Object System.Windows.Forms.ComboBox
$comboCkpt.Left          = 8; $comboCkpt.Top = $my + 20; $comboCkpt.Width = 392; $comboCkpt.DropDownStyle = "DropDownList"
foreach ($item in (Get-CheckpointItems -SubFolder "SDXL")) { [void]$comboCkpt.Items.Add($item) }
if ($comboCkpt.Items.Count -gt 0) { $comboCkpt.SelectedIndex = 0 }
$tabModel.Controls.Add($comboCkpt)
$my += 50

$lblDiffuser = New-Object System.Windows.Forms.Label; $lblDiffuser.Text = "Diffuser / VAE  (leave blank to use checkpoint default)"; $lblDiffuser.Left = 8; $lblDiffuser.Top = $my; $lblDiffuser.Width = 390; $lblDiffuser.Height = 18
$tabModel.Controls.Add($lblDiffuser)
$comboDiffuser               = New-Object System.Windows.Forms.ComboBox
$comboDiffuser.Left          = 8; $comboDiffuser.Top = $my + 20; $comboDiffuser.Width = 392; $comboDiffuser.DropDownStyle = "DropDownList"
[void]$comboDiffuser.Items.Add("(checkpoint default)")
$vaeRoot = "C:\Users\Michael\Documents\ComfyUI\models\vae"
if ([System.IO.Directory]::Exists($vaeRoot)) {
    Get-ChildItem -LiteralPath $vaeRoot -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Extension -in @(".safetensors", ".ckpt", ".pt") } |
        Sort-Object Name |
        ForEach-Object { [void]$comboDiffuser.Items.Add($_.Name) }
}
$comboDiffuser.SelectedIndex = 0
$tabModel.Controls.Add($comboDiffuser)
$my += 50

$lblModelNote = New-Object System.Windows.Forms.Label
$lblModelNote.Text = "Sampler and Scheduler are on the Generation tab."
$lblModelNote.Left = 8; $lblModelNote.Top = $my; $lblModelNote.Width = 390; $lblModelNote.Height = 32
$lblModelNote.ForeColor = [System.Drawing.Color]::FromArgb(120,120,150)
$tabModel.Controls.Add($lblModelNote)

# ===========================================================================
# TAB 3: ControlNet
# ===========================================================================
$cy = 6

$chkCN = New-Object System.Windows.Forms.CheckBox; $chkCN.Text = "Enable ControlNet"; $chkCN.Left = 8; $chkCN.Top = $cy; $chkCN.Width = 200; $chkCN.Checked = $false
$chkCN.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$tabCN.Controls.Add($chkCN); $cy += 30

$lblCNModel = New-Object System.Windows.Forms.Label; $lblCNModel.Text = "ControlNet model"; $lblCNModel.Left = 8; $lblCNModel.Top = $cy; $lblCNModel.Width = 390; $lblCNModel.Height = 18
$tabCN.Controls.Add($lblCNModel)
$comboCNModel               = New-Object System.Windows.Forms.ComboBox
$comboCNModel.Left          = 8; $comboCNModel.Top = $cy + 20; $comboCNModel.Width = 392; $comboCNModel.DropDownStyle = "DropDownList"
foreach ($item in (Get-ControlNetItems)) { [void]$comboCNModel.Items.Add($item) }
$comboCNModel.SelectedIndex = 0
$tabCN.Controls.Add($comboCNModel); $cy += 50

$lblCNImage = New-Object System.Windows.Forms.Label; $lblCNImage.Text = "ControlNet input image  (from ComfyUI\input folder)"; $lblCNImage.Left = 8; $lblCNImage.Top = $cy; $lblCNImage.Width = 390; $lblCNImage.Height = 18
$tabCN.Controls.Add($lblCNImage)
$comboCNImage               = New-Object System.Windows.Forms.ComboBox
$comboCNImage.Left          = 8; $comboCNImage.Top = $cy + 20; $comboCNImage.Width = 310; $comboCNImage.DropDownStyle = "DropDownList"
foreach ($item in (Get-ControlNetImages)) { [void]$comboCNImage.Items.Add($item) }
$comboCNImage.SelectedIndex = 0
$tabCN.Controls.Add($comboCNImage)
$btnRefreshCNImg = New-Object System.Windows.Forms.Button; $btnRefreshCNImg.Text = "Refresh"; $btnRefreshCNImg.Left = 326; $btnRefreshCNImg.Top = $cy + 18; $btnRefreshCNImg.Width = 74; $btnRefreshCNImg.Height = 26
$tabCN.Controls.Add($btnRefreshCNImg); $cy += 50

$lblCNFilter = New-Object System.Windows.Forms.Label; $lblCNFilter.Text = "Preprocessor filter"; $lblCNFilter.Left = 8; $lblCNFilter.Top = $cy; $lblCNFilter.Width = 190; $lblCNFilter.Height = 18
$tabCN.Controls.Add($lblCNFilter)
$lblCNStrength = New-Object System.Windows.Forms.Label; $lblCNStrength.Text = "Strength"; $lblCNStrength.Left = 210; $lblCNStrength.Top = $cy; $lblCNStrength.Width = 80; $lblCNStrength.Height = 18
$tabCN.Controls.Add($lblCNStrength)

$comboCNFilter               = New-Object System.Windows.Forms.ComboBox
$comboCNFilter.Left          = 8; $comboCNFilter.Top = $cy + 20; $comboCNFilter.Width = 190; $comboCNFilter.DropDownStyle = "DropDownList"
@("canny","depth","openpose","lineart","mlsd","scribble","seg","shuffle","tile","inpaint","none") | ForEach-Object { [void]$comboCNFilter.Items.Add($_) }
$comboCNFilter.SelectedIndex = 0
$tabCN.Controls.Add($comboCNFilter)

$numCNStrength = New-Object System.Windows.Forms.NumericUpDown; $numCNStrength.Left = 210; $numCNStrength.Top = $cy + 20; $numCNStrength.Width = 80
$numCNStrength.DecimalPlaces = 2; $numCNStrength.Minimum = 0; $numCNStrength.Maximum = 2; $numCNStrength.Increment = 0.05; $numCNStrength.Value = 0.75
$tabCN.Controls.Add($numCNStrength); $cy += 50

$lblCNStart = New-Object System.Windows.Forms.Label; $lblCNStart.Text = "Start step %"; $lblCNStart.Left = 8; $lblCNStart.Top = $cy; $lblCNStart.Width = 120; $lblCNStart.Height = 18
$tabCN.Controls.Add($lblCNStart)
$lblCNEnd = New-Object System.Windows.Forms.Label; $lblCNEnd.Text = "End step %"; $lblCNEnd.Left = 150; $lblCNEnd.Top = $cy; $lblCNEnd.Width = 120; $lblCNEnd.Height = 18
$tabCN.Controls.Add($lblCNEnd)

$numCNStart = New-Object System.Windows.Forms.NumericUpDown; $numCNStart.Left = 8; $numCNStart.Top = $cy + 20; $numCNStart.Width = 80
$numCNStart.DecimalPlaces = 2; $numCNStart.Minimum = 0; $numCNStart.Maximum = 1; $numCNStart.Increment = 0.05; $numCNStart.Value = 0.00
$tabCN.Controls.Add($numCNStart)

$numCNEnd = New-Object System.Windows.Forms.NumericUpDown; $numCNEnd.Left = 150; $numCNEnd.Top = $cy + 20; $numCNEnd.Width = 80
$numCNEnd.DecimalPlaces = 2; $numCNEnd.Minimum = 0; $numCNEnd.Maximum = 1; $numCNEnd.Increment = 0.05; $numCNEnd.Value = 1.00
$tabCN.Controls.Add($numCNEnd); $cy += 50

$btnRefreshCNImg.Add_Click({
    $cur = [string]$comboCNImage.SelectedItem
    $comboCNImage.Items.Clear()
    foreach ($item in (Get-ControlNetImages)) { [void]$comboCNImage.Items.Add($item) }
    $idx3 = $comboCNImage.Items.IndexOf($cur)
    $comboCNImage.SelectedIndex = if ($idx3 -ge 0) { $idx3 } elseif ($comboCNImage.Items.Count -gt 0) { 0 } else { -1 }
    Add-Log "ControlNet image list refreshed."
})

$lblCNNote = New-Object System.Windows.Forms.Label
$lblCNNote.Text = "Note: ControlNet applies only if your workflow JSON includes a ControlNet node and the Invoke script passes these parameters."
$lblCNNote.Left = 8; $lblCNNote.Top = $cy; $lblCNNote.Width = 392; $lblCNNote.Height = 48
$lblCNNote.ForeColor = [System.Drawing.Color]::FromArgb(130, 130, 150)
$tabCN.Controls.Add($lblCNNote)

# ===========================================================================
# Right panel: preview + history grid
# ===========================================================================
$previewFrame           = New-Object System.Windows.Forms.Panel
$previewFrame.Dock      = "Fill"
$previewFrame.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 36)
$previewFrame.Padding   = New-Object System.Windows.Forms.Padding(6)
$right.Controls.Add($previewFrame, 0, 0)

$script:PreviewBox          = New-Object System.Windows.Forms.PictureBox
$script:PreviewBox.Dock     = "Fill"
$script:PreviewBox.SizeMode = "Zoom"
$script:PreviewBox.BackColor= [System.Drawing.Color]::FromArgb(30, 30, 36)
$previewFrame.Controls.Add($script:PreviewBox)

$historyLayout             = New-Object System.Windows.Forms.TableLayoutPanel
$historyLayout.Dock        = "Fill"
$historyLayout.ColumnCount = 1
$historyLayout.RowCount    = 2
[void]$historyLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 22)))
[void]$historyLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
$right.Controls.Add($historyLayout, 0, 1)

$historyLabel = New-Object System.Windows.Forms.Label; $historyLabel.Dock = "Fill"; $historyLabel.Text = "Output history"; $historyLabel.TextAlign = "MiddleLeft"
$historyLayout.Controls.Add($historyLabel, 0, 0)

$gridOutputs                             = New-Object System.Windows.Forms.DataGridView
$gridOutputs.Dock                        = "Fill"
$gridOutputs.AllowUserToAddRows          = $false
$gridOutputs.AllowUserToDeleteRows       = $false
$gridOutputs.AllowUserToResizeRows       = $false
$gridOutputs.AutoSizeColumnsMode         = "Fill"
$gridOutputs.BackgroundColor             = [System.Drawing.Color]::White
$gridOutputs.BorderStyle                 = "FixedSingle"
$gridOutputs.ColumnHeadersHeightSizeMode = "AutoSize"
$gridOutputs.MultiSelect                 = $false
$gridOutputs.ReadOnly                    = $true
$gridOutputs.RowHeadersVisible           = $false
$gridOutputs.SelectionMode               = "FullRowSelect"
$gridOutputs.ScrollBars                  = "Vertical"
[void]$gridOutputs.Columns.Add("Time", "Date / Time")
[void]$gridOutputs.Columns.Add("File", "File")
[void]$gridOutputs.Columns.Add("Lora", "LoRA")
[void]$gridOutputs.Columns.Add("Seed", "Seed")
[void]$gridOutputs.Columns.Add("Path", "Path")
[void]$gridOutputs.Columns.Add("Ckpt", "Checkpoint")
$gridOutputs.Columns["Time"].FillWeight = 14
$gridOutputs.Columns["File"].FillWeight = 32
$gridOutputs.Columns["Lora"].FillWeight = 16
$gridOutputs.Columns["Seed"].FillWeight = 10
$gridOutputs.Columns["Ckpt"].FillWeight = 18
$gridOutputs.Columns["Path"].Visible    = $false
$historyLayout.Controls.Add($gridOutputs, 0, 1)

# ===========================================================================
# Event handlers (all registered after every control is built)
# ===========================================================================

$chkRandomSeed.Add_CheckedChanged({
    $numSeed.Enabled = -not $chkRandomSeed.Checked
    if ($chkRandomSeed.Checked) {
        $numSeed.Value = Get-Random -Minimum 1 -Maximum 2147483647
    }
})

$btnRefresh.Add_Click({
    $current1 = [string]$comboLora1.SelectedItem
    $current2 = [string]$comboLora2.SelectedItem
    $current3 = [string]$comboLora3.SelectedItem
    $comboLora1.Items.Clear()
    $comboLora2.Items.Clear()
    $comboLora3.Items.Clear()
    foreach ($item in (Get-ComfyLoraItems -Config $Config)) {
        [void]$comboLora1.Items.Add($item)
        [void]$comboLora2.Items.Add($item)
        [void]$comboLora3.Items.Add($item)
    }
    $index1 = $comboLora1.Items.IndexOf($current1)
    $index2 = $comboLora2.Items.IndexOf($current2)
    $index3 = $comboLora3.Items.IndexOf($current3)
    $comboLora1.SelectedIndex = if ($index1 -ge 0) { $index1 } else { 0 }
    $comboLora2.SelectedIndex = if ($index2 -ge 0) { $index2 } else { 0 }
    $comboLora3.SelectedIndex = if ($index3 -ge 0) { $index3 } else { 0 }
    Add-Log "LoRA list refreshed."
})

$comboCkptStyle.Add_SelectedIndexChanged({
    $style = [string]$comboCkptStyle.SelectedItem
    $sub   = if ($style -eq "All checkpoints") { "" } else { $style }
    $cur   = [string]$comboCkpt.SelectedItem
    $comboCkpt.Items.Clear()
    foreach ($item in (Get-CheckpointItems -SubFolder $sub)) { [void]$comboCkpt.Items.Add($item) }
    $idx2 = $comboCkpt.Items.IndexOf($cur)
    $comboCkpt.SelectedIndex = if ($idx2 -ge 0) { $idx2 } elseif ($comboCkpt.Items.Count -gt 0) { 0 } else { -1 }
})

$btnRefreshCkpt.Add_Click({
    $style = [string]$comboCkptStyle.SelectedItem
    $sub   = if ($style -eq "All checkpoints") { "" } else { $style }
    $cur   = [string]$comboCkpt.SelectedItem
    $comboCkpt.Items.Clear()
    foreach ($item in (Get-CheckpointItems -SubFolder $sub)) { [void]$comboCkpt.Items.Add($item) }
    $idx2 = $comboCkpt.Items.IndexOf($cur)
    $comboCkpt.SelectedIndex = if ($idx2 -ge 0) { $idx2 } elseif ($comboCkpt.Items.Count -gt 0) { 0 } else { -1 }
    Add-Log "Checkpoints refreshed."
})

$btnOutput.Add_Click({ Start-Process ([string]$Config.comfyOutputPath) })

$script:btnSession.Add_Click({
    if (-not $script:SessionActive) {
        $script:SessionEntries.Clear()
        $script:SessionActive = $true
        Update-SessionButton
        Add-Log "Session started. Generate images then click Stop Session to save."
    } else {
        if ($script:SessionEntries.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show("No images were generated during this session.", "Empty session", "OK", "Information") | Out-Null
            $script:SessionActive = $false
            Update-SessionButton
            return
        }
        $dlg                  = New-Object System.Windows.Forms.SaveFileDialog
        $dlg.Title            = "Save Session Report"
        $dlg.Filter           = "HTML file (*.html)|*.html"
        $dlg.FileName         = "char-design-$(Get-Date -Format 'yyyyMMdd_HHmmss').html"
        $dlg.InitialDirectory = $script:ReportsFolder
        if ($dlg.ShowDialog() -eq "OK") {
            try {
                New-SessionReport -SavePath $dlg.FileName -IncludePrompts $chkIncludePrompts.Checked
                $script:LastReportFolder = [System.IO.Path]::GetDirectoryName($dlg.FileName)
                Add-Log "Report saved: $($dlg.FileName)"
                Start-Process $dlg.FileName
            } catch {
                Add-Log "ERROR saving report: $($_.Exception.Message)"
                [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, "Save failed", "OK", "Error") | Out-Null
            }
        }
        $script:SessionActive = $false
        Update-SessionButton
    }
})

$script:btnOpenReport.Add_Click({
    $folder = if (-not [string]::IsNullOrWhiteSpace($script:LastReportFolder) -and
                  (Test-Path -LiteralPath $script:LastReportFolder -PathType Container)) {
        $script:LastReportFolder
    } else {
        [string]$Config.comfyOutputPath
    }
    Start-Process $folder
})

$btnGenerate.Add_Click({
    try {
        $btnGenerate.Enabled  = $false
        $selectedLora1        = [string]$comboLora1.SelectedItem
        $selectedLora2        = [string]$comboLora2.SelectedItem
        $selectedLora3        = [string]$comboLora3.SelectedItem
        $useLora1             = $chkLora1.Checked -and $selectedLora1 -ne "None"
        $useLora2             = $chkLora2.Checked -and $selectedLora2 -ne "None"
        $useLora3             = $chkLora3.Checked -and $selectedLora3 -ne "None"
        $selectedCkpt         = [string]$comboCkpt.SelectedItem
        $selectedSampler      = [string]$comboSampler.SelectedItem
        $selectedScheduler    = [string]$comboScheduler.SelectedItem
        $selectedDiffuser     = [string]$comboDiffuser.SelectedItem
        $useCN                = $chkCN.Checked -and [string]$comboCNModel.SelectedItem -ne "None"

        $prefixParts = @([string]$Config.defaults.prefix)
        if ($useLora1) { $prefixParts += Get-SafeFilePart -Text ([System.IO.Path]::GetFileNameWithoutExtension($selectedLora1)) -Fallback "lora1" } else { $prefixParts += "no_lora1" }
        if ($useLora2) { $prefixParts += Get-SafeFilePart -Text ([System.IO.Path]::GetFileNameWithoutExtension($selectedLora2)) -Fallback "lora2" } else { $prefixParts += "no_lora2" }
        if ($useLora3) { $prefixParts += Get-SafeFilePart -Text ([System.IO.Path]::GetFileNameWithoutExtension($selectedLora3)) -Fallback "lora3" } else { $prefixParts += "no_lora3" }
        $prefixParts += Get-Date -Format "yyyyMMdd_HHmmss"
        $prefix = $prefixParts -join "_"

        $lora1Display = if ($useLora1) { "$selectedLora1 @ $($numLora1.Value)" } else { "off" }
        $lora2Display = if ($useLora2) { "$selectedLora2 @ $($numLora2.Value)" } else { "off" }
        $lora3Display = if ($useLora3) { "$selectedLora3 @ $($numLora3.Value)" } else { "off" }
        Add-Log "Sending. LoRA1: $lora1Display | LoRA2: $lora2Display | LoRA3: $lora3Display | Ckpt: $selectedCkpt"
        # Build a hashtable of params and dot-source the invoke script directly.
        # This avoids all stdout/stderr capture issues from spawning a child process.
        $invokeParams = @{
            Prompt            = $txtPrompt.Text
            NegativePrompt    = $txtNegative.Text
            Lora1Name         = $selectedLora1
            Lora1Strength     = [double]$numLora1.Value
            Lora2Name         = $selectedLora2
            Lora2Strength     = [double]$numLora2.Value
            Lora3Name         = $selectedLora3
            Lora3Strength     = [double]$numLora3.Value
            Width             = [int]$numWidth.Value
            Height            = [int]$numHeight.Value
            BatchSize         = [int]$Config.defaults.batchSize
            Steps             = [int]$numSteps.Value
            Cfg               = [double]$numCfg.Value
            Sampler           = $selectedSampler
            Scheduler         = $selectedScheduler
            Seed              = [int]$script:ActualSeed
            Prefix            = $prefix
            ComfyUrl          = [string]$Config.comfyUrl
            WorkflowPath      = (Get-WorkflowPath -Config $Config)
            Checkpoint        = $selectedCkpt
        }
        if ($useLora1)                                         { $invokeParams.Lora1Enabled      = $true }
        if ($useLora2)                                         { $invokeParams.Lora2Enabled      = $true }
        if ($useLora3)                                         { $invokeParams.Lora3Enabled      = $true }
        if ($selectedDiffuser -ne "(checkpoint default)")      { $invokeParams.Diffuser           = $selectedDiffuser }
        if ($useCN) {
            $invokeParams.ControlNetEnabled  = $true
            $invokeParams.ControlNetModel    = [string]$comboCNModel.SelectedItem
            $invokeParams.ControlNetImage    = [string]$comboCNImage.SelectedItem
            $invokeParams.ControlNetFilter   = [string]$comboCNFilter.SelectedItem
            $invokeParams.ControlNetStrength = [double]$numCNStrength.Value
            $invokeParams.ControlNetStart    = [double]$numCNStart.Value
            $invokeParams.ControlNetEnd      = [double]$numCNEnd.Value
        }

        # Resolve seed before building args so the same value goes to ComfyUI and the report
        $script:ActualSeed = if ($chkRandomSeed.Checked) {
            Get-Random -Minimum 1 -Maximum 2147483647
        } else {
            [int]$numSeed.Value
        }

        $promptId = & $InvokeScriptPath @invokeParams
        if ([string]::IsNullOrWhiteSpace($promptId)) {
            throw "Invoke script returned no prompt ID. Check ComfyUI is running at $($Config.comfyUrl)."
        }
        Add-Log ('Queued: ' + $promptId)
        [System.Windows.Forms.Application]::DoEvents()

        Wait-ComfyImages -PromptId $promptId -ComfyUrl ([string]$Config.comfyUrl) -OutputPath ([string]$Config.comfyOutputPath)

        # Show the actual seed used in the spinner so it can be reused
        $numSeed.Value = [decimal]$script:ActualSeed
        $seedLabel     = [string]$script:ActualSeed
        $lora1Label = if ($useLora1) { [System.IO.Path]::GetFileNameWithoutExtension($selectedLora1) } else { $null }
        $lora2Label = if ($useLora2) { [System.IO.Path]::GetFileNameWithoutExtension($selectedLora2) } else { $null }
        $lora3Label = if ($useLora3) { [System.IO.Path]::GetFileNameWithoutExtension($selectedLora3) } else { $null }
        $loraLabels = @()
        if ($lora1Label) { $loraLabels += $lora1Label }
        if ($lora2Label) { $loraLabels += $lora2Label }
        if ($lora3Label) { $loraLabels += $lora3Label }
        $loraLabel = if ($loraLabels.Count -gt 0) { $loraLabels -join " + " } else { "LoRAs off" }

        $first = $true
        foreach ($imgPath in $script:LastImagePaths) {
            Add-OutputHistoryItem -Path $imgPath -LoraName $loraLabel -Seed $seedLabel -Select:$first
            $first = $false
        }

        if ($script:LastImagePaths.Count -gt 0) {
            $firstPath = $script:LastImagePaths[0]
            Set-PreviewImage -Path $firstPath

            $runEntry = @{
                Time           = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                ImagePath      = $firstPath
                Lora1Enabled    = $useLora1
                Lora1Name       = $lora1Label
                Lora1Strength   = if ($useLora1) { [string]$numLora1.Value } else { "" }
                Lora2Enabled    = $useLora2
                Lora2Name       = $lora2Label
                Lora2Strength   = if ($useLora2) { [string]$numLora2.Value } else { "" }
                Lora3Enabled    = $useLora3
                Lora3Name       = $lora3Label
                Lora3Strength   = if ($useLora3) { [string]$numLora3.Value } else { "" }
                Prompt         = $txtPrompt.Text
                NegativePrompt = $txtNegative.Text
                Seed           = $seedLabel
                Steps          = [string][int]$numSteps.Value
                Cfg            = [string]$numCfg.Value
                Width          = [string][int]$numWidth.Value
                Height         = [string][int]$numHeight.Value
                Sampler        = $selectedSampler
                Scheduler      = $selectedScheduler
                Checkpoint     = $selectedCkpt
            }

            # Save to persistent run log
            Append-RunLog -Entry $runEntry

            # Add to grid with full metadata
            $name      = [System.IO.Path]::GetFileName($firstPath)
            $stamp     = Get-Date -Format "yyyy-MM-dd HH:mm"
            $ckptShort = [System.IO.Path]::GetFileNameWithoutExtension($selectedCkpt)
            $gridOutputs.Rows.Insert(0, $stamp, $name, $loraLabel, $seedLabel, $firstPath, $ckptShort)
            $gridOutputs.ClearSelection()
            $gridOutputs.Rows[0].Selected = $true
            $gridOutputs.CurrentCell      = $gridOutputs.Rows[0].Cells["File"]

            if ($script:SessionActive) {
                $script:SessionEntries.Add($runEntry)
                Add-Log ('Session entry added (' + $script:SessionEntries.Count + ' total).')
            }
        }

        Save-Prefs
        Add-Log "Done. $($script:LastImagePaths.Count) image(s)."
    }
    catch {
        Add-Log "Error: $($_.Exception.Message)"
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, "LoRA test failed", "OK", "Error") | Out-Null
    }
    finally {
        $btnGenerate.Enabled = $true
    }
})

$gridOutputs.Add_SelectionChanged({
    $path = Get-SelectedOutputPath
    if (-not [string]::IsNullOrWhiteSpace($path)) { Set-PreviewImage -Path $path }
})

$gridOutputs.Add_CellDoubleClick({
    $path = Get-SelectedOutputPath
    if (-not [string]::IsNullOrWhiteSpace($path)) { Start-Process $path }
})

# ===========================================================================
# Startup: restore last-used prefs, then load history
# ===========================================================================
$prefs = Load-Prefs
if ($null -ne $prefs) {
    # Generation tab
    Restore-ComboValue -Combo $comboLora1     -Value ([string]$prefs.lora1Name)
    if ($null -ne $prefs.lora1Enabled)    { $chkLora1.Checked = [bool]$prefs.lora1Enabled }
    if ($null -ne $prefs.lora1Strength)   { try { $numLora1.Value  = [decimal]$prefs.lora1Strength  } catch {} }
    Restore-ComboValue -Combo $comboLora2     -Value ([string]$prefs.lora2Name)
    if ($null -ne $prefs.lora2Enabled)    { $chkLora2.Checked = [bool]$prefs.lora2Enabled }
    if ($null -ne $prefs.lora2Strength)   { try { $numLora2.Value  = [decimal]$prefs.lora2Strength  } catch {} }
    Restore-ComboValue -Combo $comboLora3     -Value ([string]$prefs.lora3Name)
    if ($null -ne $prefs.lora3Enabled)    { $chkLora3.Checked = [bool]$prefs.lora3Enabled }
    if ($null -ne $prefs.lora3Strength)   { try { $numLora3.Value  = [decimal]$prefs.lora3Strength  } catch {} }
    if ($null -ne $prefs.randomSeed)     { $chkRandomSeed.Checked = [bool]$prefs.randomSeed }
    $numSeed.Enabled = -not $chkRandomSeed.Checked
    if ($null -ne $prefs.seed -and -not $chkRandomSeed.Checked) { try { $numSeed.Value = [decimal]$prefs.seed } catch {} }
    if ($null -ne $prefs.steps)          { try { $numSteps.Value = [decimal]$prefs.steps         } catch {} }
    if ($null -ne $prefs.cfg)            { try { $numCfg.Value   = [decimal]$prefs.cfg           } catch {} }
    if ($null -ne $prefs.width)          { try { $numWidth.Value = [decimal]$prefs.width         } catch {} }
    if ($null -ne $prefs.height)         { try { $numHeight.Value= [decimal]$prefs.height        } catch {} }
    Restore-ComboValue -Combo $comboSampler   -Value ([string]$prefs.sampler)
    Restore-ComboValue -Combo $comboScheduler -Value ([string]$prefs.scheduler)
    if ($null -ne $prefs.includePrompts) { $chkIncludePrompts.Checked = [bool]$prefs.includePrompts }
    if (-not [string]::IsNullOrWhiteSpace([string]$prefs.prompt))         { $txtPrompt.Text   = [string]$prefs.prompt }
    if (-not [string]::IsNullOrWhiteSpace([string]$prefs.negativePrompt)) { $txtNegative.Text = [string]$prefs.negativePrompt }
    # Models tab
    Restore-ComboValue -Combo $comboCkptStyle -Value ([string]$prefs.ckptStyle)
    # Trigger checkpoint reload for the saved style before restoring ckptName
    $style = [string]$comboCkptStyle.SelectedItem
    $sub   = if ($style -eq "All checkpoints") { "" } else { $style }
    $comboCkpt.Items.Clear()
    foreach ($item in (Get-CheckpointItems -SubFolder $sub)) { [void]$comboCkpt.Items.Add($item) }
    if ($comboCkpt.Items.Count -gt 0) { $comboCkpt.SelectedIndex = 0 }
    Restore-ComboValue -Combo $comboCkpt      -Value ([string]$prefs.ckptName)
    # If saved ckptName didn't match (old format without subfolder), try prepending the style subfolder
    if ($comboCkpt.SelectedIndex -lt 0 -and -not [string]::IsNullOrWhiteSpace([string]$prefs.ckptName)) {
        $tryName = ([string]$prefs.ckptStyle) + '\' + ([string]$prefs.ckptName)
        Restore-ComboValue -Combo $comboCkpt -Value $tryName
    }
    Restore-ComboValue -Combo $comboDiffuser  -Value ([string]$prefs.diffuser)
    # ControlNet tab
    if ($null -ne $prefs.cnEnabled)   { $chkCN.Checked = [bool]$prefs.cnEnabled }
    Restore-ComboValue -Combo $comboCNModel  -Value ([string]$prefs.cnModel)
    Restore-ComboValue -Combo $comboCNImage  -Value ([string]$prefs.cnImage)
    Restore-ComboValue -Combo $comboCNFilter -Value ([string]$prefs.cnFilter)
    if ($null -ne $prefs.cnStrength) { try { $numCNStrength.Value = [decimal]$prefs.cnStrength } catch {} }
    if ($null -ne $prefs.cnStart)    { try { $numCNStart.Value    = [decimal]$prefs.cnStart    } catch {} }
    if ($null -ne $prefs.cnEnd)      { try { $numCNEnd.Value      = [decimal]$prefs.cnEnd      } catch {} }
}

Add-Log ('Ready. ComfyUI: ' + $Config.comfyUrl)
Add-Log ('LoRAs found: ' + ($comboLora1.Items.Count - 1))
Load-RunHistory

if ($SmokeTest) { $form.Dispose(); "LoRA tester UI smoke OK"; return }
[void]$form.ShowDialog()
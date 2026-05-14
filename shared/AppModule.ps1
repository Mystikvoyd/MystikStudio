# AppModule.ps1 - Shared module for MystikStudio generators
# Version: 001.003.000
# Dot-source this from Forge, Fusion, Lab starters

# ── Model Profiling ─────────────────────────────────────────────────────────
$script:ModelProfiles = [ordered]@{
    "Custom"            = $null
    "Realistic Character" = [ordered]@{
        checkpointPref = @("Juggernaut", "RealVis", "CyberRealistic")
        label          = "Realistic Character"
        steps          = 30; cfg = 6.0; sampler = "dpmpp_2m"; scheduler = "karras"
        width = 1024; height = 1024
        promptPrefix   = "photorealistic, realistic human, detailed skin texture, natural lighting"
        negative       = "anime, cartoon, illustration, painting, cgi, 3d render, plastic skin, wax skin, doll, bad anatomy"
        workflow       = "sdxl-basic-book-image.api.json"
    }
    "Fantasy Realism"   = [ordered]@{
        checkpointPref = @("Juggernaut", "DreamShaper", "RealVis")
        label          = "Fantasy Realism"
        steps          = 30; cfg = 6.0; sampler = "dpmpp_2m"; scheduler = "karras"
        width = 1024; height = 1024
        promptPrefix   = "fantasy realism, epic fantasy, magical atmosphere, detailed, cinematic lighting"
        negative       = "anime, cartoon, illustration, painting, cgi, 3d render, plastic skin, bad anatomy"
        workflow       = "sdxl-basic-book-image.api.json"
    }
    "LoRA Validation"   = [ordered]@{
        checkpointPref = @("Juggernaut", "RealVis")
        label          = "LoRA Validation"
        steps          = 28; cfg = 5.5; sampler = "dpmpp_2m"; scheduler = "karras"
        width = 1024; height = 1024
        promptPrefix   = "realistic character reference, neutral studio lighting, clean background"
        negative       = "low quality, blurry, bad anatomy, deformed body, extra limbs, bad hands, bad feet, text, watermark, logo, anime, cartoon, cgi, plastic skin"
        workflow       = "sdxl-basic-book-image.api.json"
    }
    "Line Art / Coloring" = [ordered]@{
        checkpointPref = @("lineart", "DreamShaper", "")
        label          = "Line Art / Coloring"
        steps          = 25; cfg = 7.0; sampler = "dpmpp_2m"; scheduler = "karras"
        width = 1024; height = 1024
        promptPrefix   = "line art, black and white, clean outlines, coloring page, thick lines, white background"
        negative       = "color, shading, gradient, blurry, messy lines, sketchy, watercolor, painted, filled colors, digital color, grey tones"
        workflow       = "sdxl-basic-book-image.api.json"
    }
    "Fast Draft"        = [ordered]@{
        checkpointPref = @()
        label          = "Fast Draft"
        steps          = 15; cfg = 5.0; sampler = "dpmpp_2m"; scheduler = "karras"
        width = 768; height = 1024
        promptPrefix   = ""
        negative       = "anime, cartoon, illustration, bad anatomy"
        workflow       = "sdxl-basic-book-image.api.json"
    }
}

function Get-ProfileList {
    return @($script:ModelProfiles.Keys)
}

function Resolve-ProfileCheckpoint {
    param([string[]]$PreferenceList, [System.Collections.Generic.List[string]]$InstalledCkpts)
    foreach ($pref in $PreferenceList) {
        $match = $InstalledCkpts | Where-Object { $_ -like "*$pref*" } | Select-Object -First 1
        if ($match) { return $match }
    }
    return $null
}

function Apply-Profile {
    param(
        [string]$ProfileName,
        $ProfileDef,
        [System.Collections.Generic.List[string]]$InstalledCkpts,
        [System.Collections.Generic.List[string]]$InstalledVAEs,
        [hashtable]$UiRef  # hashtable with keys: ckptCombo, vaeCombo, numSteps, numCfg, comboSmpl, comboSched, numW, numH, txtPrompt, txtNeg
    )
    if ($ProfileName -eq "Custom" -or $null -eq $ProfileDef) { return }

    $ckpt = Resolve-ProfileCheckpoint -PreferenceList $ProfileDef.checkpointPref -InstalledCkpts $InstalledCkpts
    if ($ckpt) {
        $idx = $UiRef.ckptCombo.Items.IndexOf($ckpt)
        if ($idx -ge 0) { $UiRef.ckptCombo.SelectedIndex = $idx }
    } elseif ($InstalledCkpts.Count -gt 0) {
        Add-Log "Profile checkpoint not found - keeping current selection."
    } else {
        Add-Log "No compatible checkpoint found for profile '$ProfileName'. Please select or install a checkpoint."
    }

    if ($ProfileDef.steps -and $UiRef.numSteps)     { try { $UiRef.numSteps.Value   = [decimal]$ProfileDef.steps } catch {} }
    if ($ProfileDef.cfg -and $UiRef.numCfg)          { try { $UiRef.numCfg.Value     = [decimal]$ProfileDef.cfg } catch {} }
    if ($ProfileDef.width -and $UiRef.numW)          { try { $UiRef.numW.Value       = [decimal]$ProfileDef.width } catch {} }
    if ($ProfileDef.height -and $UiRef.numH)         { try { $UiRef.numH.Value       = [decimal]$ProfileDef.height } catch {} }
    if ($ProfileDef.sampler -and $UiRef.comboSmpl)   { $idx = $UiRef.comboSmpl.Items.IndexOf($ProfileDef.sampler); if ($idx -ge 0) { $UiRef.comboSmpl.SelectedIndex = $idx } }
    if ($ProfileDef.scheduler -and $UiRef.comboSched) { $idx = $UiRef.comboSched.Items.IndexOf($ProfileDef.scheduler); if ($idx -ge 0) { $UiRef.comboSched.SelectedIndex = $idx } }
    if ($ProfileDef.promptPrefix -and $UiRef.txtPrompt) { $UiRef.txtPrompt.Text = $ProfileDef.promptPrefix }
    if ($ProfileDef.negative -and $UiRef.txtNeg)     { $UiRef.txtNeg.Text = $ProfileDef.negative }
    Add-Log "Applied profile: $ProfileName"
}

# ── Prompt Presets ──────────────────────────────────────────────────────────
$script:PromptPresets = [ordered]@{
    "Custom"                 = @{ prompt = ""; negative = "" }
    "Realistic Woman"        = @{ prompt = "realistic woman portrait, natural skin texture, detailed face, soft natural lighting"; negative = "anime, cartoon, illustration, painting, cgi, 3d render, plastic skin, doll, bad anatomy" }
    "Realistic Man"          = @{ prompt = "realistic man portrait, natural skin texture, detailed face, masculine features, soft natural lighting"; negative = "anime, cartoon, illustration, painting, cgi, 3d render, plastic skin, doll, bad anatomy" }
    "Fantasy Character"      = @{ prompt = "fantasy character concept art, mythical creature, detailed armor and clothing, dramatic lighting, epic fantasy style"; negative = "low quality, blurry, bad anatomy, deformed, extra limbs, cartoon, anime, cgi" }
    "Clothing Fit Reference" = @{ prompt = "clothing fit reference, mannequin style, plain background, front view, back view, clean lines, fashion design"; negative = "low quality, blurry, bad anatomy, deformed, extra limbs, cartoon, anime, background detail" }
    "Full Body Character"    = @{ prompt = "full body character design, standing pose, centered, neutral expression, character reference sheet"; negative = "low quality, blurry, bad anatomy, deformed body, extra limbs, bad hands, bad feet, cropped, cartoon, anime" }
    "Upper Body Character"   = @{ prompt = "upper body portrait, character design, shoulders and above, neutral expression, clean background"; negative = "low quality, blurry, bad anatomy, deformed, extra limbs, bad hands, cropped, cartoon, anime" }
    "Portrait"               = @{ prompt = "portrait photography, head and shoulders, professional lighting, detailed eyes, natural expression"; negative = "anime, cartoon, illustration, painting, cgi, 3d render, plastic skin, doll, bad anatomy, extra limbs" }
    "Coloring Book Line Art" = @{ prompt = "line art, black and white, coloring page, clean lines, thick outlines, white background, no color"; negative = "color, shading, gradient, blurry, messy lines, sketchy, watercolor, painted, filled colors, grey tones" }
}

function Get-PresetList {
    return @($script:PromptPresets.Keys)
}

function Apply-PromptPreset {
    param([string]$Name, [hashtable]$UiRef)
    if ($Name -eq "Custom" -or -not $script:PromptPresets.Contains($Name)) { return }
    $p = $script:PromptPresets[$Name]
    if ($p.prompt -and $UiRef.txtPrompt)   { $UiRef.txtPrompt.Text   = $p.prompt }
    if ($p.negative -and $UiRef.txtNeg)    { $UiRef.txtNeg.Text      = $p.negative }
    Add-Log "Applied prompt preset: $Name"
}

function Append-PromptPreset {
    param([string]$Name, [hashtable]$UiRef)
    if ($Name -eq "Custom" -or -not $script:PromptPresets.Contains($Name)) { return }
    $p = $script:PromptPresets[$Name]
    if ($p.prompt -and $UiRef.txtPrompt)   { $UiRef.txtPrompt.AppendText(", " + $p.prompt) }
    if ($p.negative -and $UiRef.txtNeg)    { $UiRef.txtNeg.AppendText(", " + $p.negative) }
    Add-Log "Appended prompt preset: $Name"
}

function Save-CustomPreset {
    param([string]$Prompt, [string]$Negative, [string]$PrefsPath)
    $name = "Custom_" + (Get-Date -Format "yyyyMMdd_HHmmss")
    $script:PromptPresets[$name] = @{ prompt = $Prompt; negative = $Negative }
    Add-Log "Saved custom preset: $name"
    return $name
}

# ── Realism Helper ──────────────────────────────────────────────────────────
$script:RealismPosAppend  = "photorealistic, realistic human, natural skin texture, skin pores, natural asymmetry, realistic eyes, realistic hands, realistic clothing folds, realistic fabric, realistic shadows, DSLR photo look, lifelike, believable"
$script:RealismNegAppend  = "anime, cartoon, illustration, painting, cgi, 3d render, doll, plastic skin, wax skin, porcelain skin, fake face, uncanny face, oversmoothed skin, bad anatomy, malformed hands, extra fingers, fused fingers, distorted eyes, bad teeth, unrealistic proportions"

function Build-FinalPrompts {
    param(
        [string]$BasePrompt,
        [string]$BaseNegative,
        [bool]$RealismEnabled,
        [string]$OutfitAppend = ""
    )
    $pos = $BasePrompt
    if (-not [string]::IsNullOrWhiteSpace($OutfitAppend)) {
        $pos = "$OutfitAppend, $pos"
    }
    if ($RealismEnabled) {
        if ($pos -notmatch "(?i)photorealistic|realistic human|natural skin texture") {
            $pos = "$pos, $script:RealismPosAppend"
        }
        if ($BaseNegative -notmatch "(?i)anime|cartoon|illustration|cgi|3d render") {
            $BaseNegative = "$BaseNegative, $script:RealismNegAppend"
        }
    }
    return @{ Prompt = $pos; Negative = $BaseNegative }
}

# ── Quick Outfits ───────────────────────────────────────────────────────────
$script:QuickOutfits = @(
    "fitted turtleneck sweater",
    "button front blouse",
    "leather jacket over shirt",
    "athletic zip top",
    "hoodie and jeans",
    "formal business suit",
    "medieval travel outfit",
    "fantasy noble outfit",
    "cloak and tunic",
    "armor inspired outfit",
    "casual T shirt",
    "long coat"
)

function Get-QuickOutfits { return $script:QuickOutfits }

# ── Model Scanner ───────────────────────────────────────────────────────────
function Get-ModelRoot {
    param($Config)
    $inputPath = [string]$Config.comfyInputPath
    if ([string]::IsNullOrWhiteSpace($inputPath)) { return $null }
    return Split-Path -Parent $inputPath
}

function Get-ComfyModels {
    param($Config, [string]$SubFolder, [string[]]$Extensions = @(".safetensors", ".ckpt", ".pt", ".pth", ".bin"))
    $items = New-Object System.Collections.Generic.List[string]
    $root = Get-ModelRoot -Config $Config
    if ([string]::IsNullOrWhiteSpace($root)) { return @($items.ToArray()) }
    $scanDir = [System.IO.Path]::Combine($root, "models", $SubFolder)
    if (-not [System.IO.Directory]::Exists($scanDir)) { return @($items.ToArray()) }
    $rootFull = [System.IO.Path]::GetFullPath($scanDir)
    if (-not $rootFull.EndsWith([System.IO.Path]::DirectorySeparatorChar)) {
        $rootFull = $rootFull + [System.IO.Path]::DirectorySeparatorChar
    }
    Get-ChildItem -LiteralPath $scanDir -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Extension -in $Extensions } |
        Sort-Object FullName |
        ForEach-Object {
            $full = [System.IO.Path]::GetFullPath($_.FullName)
            $rel = $full.Substring($rootFull.Length)
            [void]$items.Add($rel)
        }
    return @($items.ToArray())
}

function Get-AllCheckpointItems {
    param($Config, [string]$SubFolder = "")
    $items = New-Object System.Collections.Generic.List[string]
    $ckptRoot = "C:\Users\Michael\Documents\ComfyUI\models\checkpoints"
    $scanBase = if (-not [string]::IsNullOrWhiteSpace($SubFolder)) {
        [System.IO.Path]::Combine($ckptRoot, $SubFolder)
    } else { $ckptRoot }
    if (-not [System.IO.Directory]::Exists($scanBase)) { return @($items.ToArray()) }
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

function Get-AllVAEItems {
    param($Config)
    $items = New-Object System.Collections.Generic.List[string]
    [void]$items.Add("(checkpoint default)")
    $vaeRoot = "C:\Users\Michael\Documents\ComfyUI\models\vae"
    if ([System.IO.Directory]::Exists($vaeRoot)) {
        Get-ChildItem -LiteralPath $vaeRoot -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Extension -in @(".safetensors", ".ckpt", ".pt") } |
            Sort-Object Name |
            ForEach-Object { [void]$items.Add($_.Name) }
    }
    return @($items.ToArray())
}

function Get-AllControlNetItems {
    param($Config)
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

function Get-AllLoraItems {
    param($Config)
    $items = New-Object System.Collections.Generic.List[string]
    [void]$items.Add("None")
    $inputPath = [string]$Config.comfyInputPath
    if ([string]::IsNullOrWhiteSpace($inputPath)) { return @($items.ToArray()) }
    $loraRoot = Join-Path (Split-Path -Parent $inputPath) "models\loras"
    if (-not (Test-Path -LiteralPath $loraRoot -PathType Container)) { return @($items.ToArray()) }
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

function Get-InputImages {
    param($Config)
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
    param([string]$Text, [string]$Fallback = "gen")
    if ([string]::IsNullOrWhiteSpace($Text)) { return $Fallback }
    $clean = $Text.ToLowerInvariant() -replace "[^a-z0-9]+", "_"
    $clean = $clean.Trim("_")
    if ([string]::IsNullOrWhiteSpace($clean)) { return $Fallback }
    return $clean
}

# ── Workflow Presets ────────────────────────────────────────────────────────
$script:WorkflowPresetDefs = [ordered]@{
    "Basic SDXL"                 = "sdxl-basic-book-image.api.json"
    "SDXL with LoRA"             = "sdxl-basic-book-image.api.json"
    "SDXL with dual LoRA"        = "sdxl-basic-book-image.api.json"
    "SDXL with triple LoRA"      = "sdxl-basic-book-image.api.json"
    "SDXL with ControlNet"       = "sdxl-basic-book-image.api.json"
    "SDXL with Identity Lock"    = "sdxl-character-lock-openpose-square.api.json"
    "SDXL upscale and repair"    = "sdxl-reference-img2img-book-image.api.json"
}

function Get-WorkflowPresetNames {
    return @($script:WorkflowPresetDefs.Keys)
}

function Resolve-WorkflowPreset {
    param([string]$PresetName, [string]$WorkflowDir)
    $file = $script:WorkflowPresetDefs[$PresetName]
    if ([string]::IsNullOrWhiteSpace($file)) { return $null }
    return [System.IO.Path]::Combine($WorkflowDir, $file)
}

function Test-WorkflowExists {
    param([string]$PresetName, [string]$WorkflowDir)
    $path = Resolve-WorkflowPreset -PresetName $PresetName -WorkflowDir $WorkflowDir
    if ([string]::IsNullOrWhiteSpace($path)) { return $false }
    return (Test-Path -LiteralPath $path -PathType Leaf)
}

# ── Improved HTML Report Builder ────────────────────────────────────────────
function New-EnhancedSessionReport {
    param(
        [string]$SavePath,
        $Entries,  # List of hashtable entries
        [string]$AppName = "Generator",
        [string]$AppVersion = "",
        [string]$WorkflowName = "",
        [string]$ModelProfile = "",
        [string]$PromptPreset = "",
        [string]$OutfitField = "",
        [string]$VariationNotes = ""
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $count     = $Entries.Count
    $sb        = New-Object System.Text.StringBuilder

    [void]$sb.Append('<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8">')
    [void]$sb.Append("<title>$AppName Session Report</title>")
    [void]$sb.Append('<style>')
    [void]$sb.Append('*{box-sizing:border-box;margin:0;padding:0}')
    [void]$sb.Append('body{font-family:"Segoe UI",sans-serif;background:#111116;color:#e0ddd8;padding:32px;max-width:1600px}')
    [void]$sb.Append('h1{font-size:1.5rem;font-weight:700;margin-bottom:2px;color:#f0ece4}')
    [void]$sb.Append('.app-info{font-size:.82rem;color:#666;margin-bottom:16px}')
    [void]$sb.Append('.session-meta{font-size:.82rem;color:#666;margin-bottom:16px}')
    [void]$sb.Append('.settings-grid{display:flex;flex-wrap:wrap;gap:8px 24px;margin-bottom:16px;background:#1c1c24;border:1px solid #2a2a38;border-radius:8px;padding:12px 16px}')
    [void]$sb.Append('.settings-grid .kv{flex:0 0 auto;min-width:160px;font-size:.82rem}')
    [void]$sb.Append('.settings-grid .kv .k{color:#777;font-weight:600}')
    [void]$sb.Append('.settings-grid .kv .v{color:#ccc;margin-left:4px}')
    [void]$sb.Append('.entry{background:#1c1c24;border:1px solid #2a2a38;border-radius:12px;padding:16px;margin-bottom:20px}')
    [void]$sb.Append('.entry-header{display:flex;align-items:center;gap:12px;margin-bottom:12px;flex-wrap:wrap}')
    [void]$sb.Append('.entry-img{float:left;width:240px;margin-right:16px;margin-bottom:8px}')
    [void]$sb.Append('.entry-img img{width:100%;height:auto;border-radius:8px;display:block;border:1px solid #333}')
    [void]$sb.Append('.no-img{color:#c0392b;font-size:.83rem;padding:12px;background:#2a1a1a;border-radius:6px;border:1px solid #5a2020}')
    [void]$sb.Append('.entry-time{font-size:.78rem;color:#555;margin-bottom:8px}')
    [void]$sb.Append('.entry-settings{display:flex;flex-wrap:wrap;gap:4px 20px}')
    [void]$sb.Append('.entry-settings .kv{flex:0 0 auto;min-width:140px;font-size:.82rem;padding:2px 0}')
    [void]$sb.Append('.entry-settings .kv .k{color:#777;font-weight:600}')
    [void]$sb.Append('.entry-settings .kv .v{color:#ccc;margin-left:4px}')
    [void]$sb.Append('.prompt-box{clear:both;margin-top:8px;padding:8px;background:#22222e;border-radius:6px;border:1px solid #333;position:relative}')
    [void]$sb.Append('.prompt-box .label{font-size:.72rem;color:#888;font-weight:600;margin-bottom:2px}')
    [void]$sb.Append('.prompt-box .text{font-size:.8rem;color:#b0aa9e;white-space:pre-wrap;word-break:break-word;padding-right:56px}')
    [void]$sb.Append('.copy-btn{font-size:.7rem;font-weight:700;padding:2px 8px;border-radius:4px;border:1px solid #444;background:#2a2a38;color:#aaa;cursor:pointer;display:inline-block}')
    [void]$sb.Append('.copy-btn:hover{background:#3a3a50;color:#fff}')
    [void]$sb.Append('.copy-btn.copied{background:#1a3d2a;color:#5ef09a;border-color:#2a6040}')
    [void]$sb.Append('.file-path{font-size:.72rem;color:#555;word-break:break-all;font-family:"Consolas",monospace;clear:both;padding-top:4px}')
    [void]$sb.Append('.badge{display:inline-block;font-size:.7rem;font-weight:800;padding:2px 6px;border-radius:4px;margin-right:4px;vertical-align:middle}')
    [void]$sb.Append('.lora-on{background:#1a3d2a;color:#5ef09a;border:1px solid #2a6040}')
    [void]$sb.Append('.lora-off{background:#3d1a1a;color:#f07070;border:1px solid #602a2a}')
    [void]$sb.Append('</style>')
    [void]$sb.Append('<script>')
    [void]$sb.Append('function copyText(btn,text){navigator.clipboard.writeText(text).then(function(){btn.textContent="COPIED";btn.classList.add("copied");setTimeout(function(){btn.textContent="COPY";btn.classList.remove("copied")},1800)})}')
    [void]$sb.Append('</script>')
    [void]$sb.Append('</head><body>')
    [void]$sb.Append("<h1>$AppName Session Report</h1>")
    if ($AppVersion) { [void]$sb.Append("<div class='app-info'>Version: $AppVersion</div>") }
    [void]$sb.Append("<div class='session-meta'>Generated: $timestamp  &middot;  $count generation(s)</div>")

    # Session-level metadata wrapping grid
    [void]$sb.Append('<div class="settings-grid">')
    $sessionInfo = @()
    if ($ModelProfile)  { $sessionInfo += "<div class='kv'><span class='k'>Profile:</span><span class='v'>$([System.Net.WebUtility]::HtmlEncode($ModelProfile))</span></div>" }
    if ($WorkflowName)  { $sessionInfo += "<div class='kv'><span class='k'>Workflow:</span><span class='v'>$([System.Net.WebUtility]::HtmlEncode($WorkflowName))</span></div>" }
    if ($PromptPreset)  { $sessionInfo += "<div class='kv'><span class='k'>Preset:</span><span class='v'>$([System.Net.WebUtility]::HtmlEncode($PromptPreset))</span></div>" }
    if ($OutfitField)   { $sessionInfo += "<div class='kv'><span class='k'>Outfit:</span><span class='v'>$([System.Net.WebUtility]::HtmlEncode($OutfitField))</span></div>" }
    if ($VariationNotes){ $sessionInfo += "<div class='kv'><span class='k'>Notes:</span><span class='v'>$([System.Net.WebUtility]::HtmlEncode($VariationNotes))</span></div>" }
    [void]$sb.Append(($sessionInfo -join ''))
    [void]$sb.Append('</div>')

    foreach ($e in $Entries) {
        $imgPath = [string]$e.ImagePath
        if (-not [string]::IsNullOrWhiteSpace($imgPath) -and (Test-Path -LiteralPath $imgPath -PathType Leaf)) {
            try {
                $bytes  = [System.IO.File]::ReadAllBytes($imgPath)
                $b64    = [Convert]::ToBase64String($bytes)
                $ext    = [System.IO.Path]::GetExtension($imgPath).TrimStart('.').ToLower()
                $mime   = if ($ext -eq 'jpg') { 'jpeg' } else { $ext }
                $imgTag = '<img src="data:image/' + $mime + ';base64,' + $b64 + '" alt="preview">'
            } catch {
                $imgTag = '<p class="no-img">Embed failed: ' + [System.Net.WebUtility]::HtmlEncode($_.Exception.Message) + '</p>'
            }
        } else {
            $imgTag = '<p class="no-img">&#9888; Path not found: ' + [System.Net.WebUtility]::HtmlEncode($imgPath) + '</p>'
        }

        $seedVal = [System.Net.WebUtility]::HtmlEncode([string]$e.Seed)
        $seedJs = ([string]$e.Seed) -replace "'","\'"
        if ([string]::IsNullOrWhiteSpace($seedVal)) { $seedVal = "N/A"; $seedJs = "N/A" }

        [void]$sb.Append('<div class="entry">')
        [void]$sb.Append('<div class="entry-img">' + $imgTag + '</div>')
        [void]$sb.Append('<div class="entry-settings">')

        # LoRA info
        $loraParts = @()
        if ($e.Lora1Enabled -and $e.Lora1Name)  { $loraParts += "<span class='badge lora-on'>LoRA1</span> $([System.Net.WebUtility]::HtmlEncode([string]$e.Lora1Name)) @ $([System.Net.WebUtility]::HtmlEncode([string]$e.Lora1Strength))" }
        if ($e.Lora2Enabled -and $e.Lora2Name)  { $loraParts += "<span class='badge lora-on'>LoRA2</span> $([System.Net.WebUtility]::HtmlEncode([string]$e.Lora2Name)) @ $([System.Net.WebUtility]::HtmlEncode([string]$e.Lora2Strength))" }
        if ($e.Lora3Enabled -and $e.Lora3Name)  { $loraParts += "<span class='badge lora-on'>LoRA3</span> $([System.Net.WebUtility]::HtmlEncode([string]$e.Lora3Name)) @ $([System.Net.WebUtility]::HtmlEncode([string]$e.Lora3Strength))" }
        if ($e.LoraEnabled -and $e.LoraName)    { $loraParts += "<span class='badge lora-on'>LoRA</span> $([System.Net.WebUtility]::HtmlEncode([string]$e.LoraName)) @ $([System.Net.WebUtility]::HtmlEncode([string]$e.LoraStrength))" }
        if ($loraParts.Count -eq 0) { $loraParts += "<span class='badge lora-off'>LoRA OFF</span>" }
        [void]$sb.Append("<div class='kv' style='min-width:220px'><span class='k'>LoRA:</span><span class='v'>$($loraParts -join ' ')</span></div>")

        [void]$sb.Append("<div class='kv'><span class='k'>Seed:</span><span class='v'>$seedVal</span><button class='copy-btn' onclick='copyText(this,&quot;$seedJs&quot;)' style='margin-left:4px'>Copy Seed</button></div>")
        [void]$sb.Append("<div class='kv'><span class='k'>Steps:</span><span class='v'>$([System.Net.WebUtility]::HtmlEncode([string]$e.Steps))</span></div>")
        [void]$sb.Append("<div class='kv'><span class='k'>CFG:</span><span class='v'>$([System.Net.WebUtility]::HtmlEncode([string]$e.Cfg))</span></div>")
        [void]$sb.Append("<div class='kv'><span class='k'>Sampler:</span><span class='v'>$([System.Net.WebUtility]::HtmlEncode([string]$e.Sampler)) / $([System.Net.WebUtility]::HtmlEncode([string]$e.Scheduler))</span></div>")
        [void]$sb.Append("<div class='kv'><span class='k'>Size:</span><span class='v'>$([System.Net.WebUtility]::HtmlEncode([string]$e.Width)) x $([System.Net.WebUtility]::HtmlEncode([string]$e.Height))</span></div>")
        [void]$sb.Append("<div class='kv'><span class='k'>Checkpoint:</span><span class='v'>$([System.Net.WebUtility]::HtmlEncode([string]$e.Checkpoint))</span></div>")
        if ($e.VAE -and [string]$e.VAE -ne "(checkpoint default)") { [void]$sb.Append("<div class='kv'><span class='k'>VAE:</span><span class='v'>$([System.Net.WebUtility]::HtmlEncode([string]$e.VAE))</span></div>") }
        if ($e.Diffuser -and [string]$e.Diffuser -ne "(checkpoint default)") { [void]$sb.Append("<div class='kv'><span class='k'>Diff:</span><span class='v'>$([System.Net.WebUtility]::HtmlEncode([string]$e.Diffuser))</span></div>") }
        $cnEnabled = $e.CnEnabled -or $e.ControlNetEnabled
        if ($cnEnabled) {
            $cnModel = [string]($e.CnModel -or $e.ControlNetModel -or "")
            $cnFilter = [string]($e.CnFilter -or $e.ControlNetFilter -or "")
            $cnStrength = [string]($e.CnStrength -or $e.ControlNetStrength -or "")
            [void]$sb.Append("<div class='kv'><span class='k'>CN:</span><span class='v'>$([System.Net.WebUtility]::HtmlEncode($cnModel)) / $([System.Net.WebUtility]::HtmlEncode($cnFilter)) @ $([System.Net.WebUtility]::HtmlEncode($cnStrength))</span></div>")
        }
        [void]$sb.Append('</div>')

        # Prompt boxes
        $promptRaw = [string]$e.Prompt
        $negRaw    = [string]$e.NegativePrompt
        $promptJs  = $promptRaw -replace "\\","\\\\" -replace "'","\'" -replace "`r`n","\\n" -replace "`n","\\n"
        $negJs     = $negRaw    -replace "\\","\\\\" -replace "'","\'" -replace "`r`n","\\n" -replace "`n","\\n"
        if (-not [string]::IsNullOrWhiteSpace($promptRaw)) {
            [void]$sb.Append('<div class="prompt-box"><div class="label">Prompt</div><div class="text">' + [System.Net.WebUtility]::HtmlEncode($promptRaw) + '</div><button class="copy-btn" onclick="copyText(this,' + [char]39 + $promptJs + [char]39 + ')" style="position:absolute;top:6px;right:6px">Copy</button></div>')
        }
        if (-not [string]::IsNullOrWhiteSpace($negRaw)) {
            [void]$sb.Append('<div class="prompt-box"><div class="label">Negative</div><div class="text">' + [System.Net.WebUtility]::HtmlEncode($negRaw) + '</div><button class="copy-btn" onclick="copyText(this,' + [char]39 + $negJs + [char]39 + ')" style="position:absolute;top:6px;right:6px">Copy</button></div>')
        }

        [void]$sb.Append('<div class="file-path">' + [System.Net.WebUtility]::HtmlEncode($imgPath) + '</div>')
        [void]$sb.Append('</div>')
    }

    [void]$sb.Append('</body></html>')
    [System.IO.File]::WriteAllText($SavePath, $sb.ToString(), [System.Text.Encoding]::UTF8)
}

# ── Identity / Control Slot UI Helpers ─────────────────────────────────────
function Add-IdentitySlotUI {
    param(
        $Parent, [int]$Top, [string]$SlotName,
        [ref]$ChkRef, [ref]$ComboRef, [ref]$NumStrengthRef,
        [System.Collections.Generic.List[string]]$ImageItems
    )
    $chk = New-Object System.Windows.Forms.CheckBox
    $chk.Text = $SlotName; $chk.Left = 8; $chk.Top = $Top; $chk.Width = 200; $chk.Checked = $false
    $Parent.Controls.Add($chk)

    $combo = New-Object System.Windows.Forms.ComboBox
    $combo.Left = 210; $combo.Top = $Top; $combo.Width = 180; $combo.DropDownStyle = "DropDownList"
    foreach ($item in $ImageItems) { [void]$combo.Items.Add($item) }
    if ($combo.Items.Count -gt 0) { $combo.SelectedIndex = 0 }
    $Parent.Controls.Add($combo)
    $chk.Add_CheckedChanged({ $combo.Enabled = $chk.Checked }).GetNewClosure()

    $num = New-Object System.Windows.Forms.NumericUpDown
    $num.Left = 210; $num.Top = $Top + 24; $num.Width = 70; $num.DecimalPlaces = 2
    $num.Minimum = 0; $num.Maximum = 2; $num.Increment = 0.05; $num.Value = 0.75; $num.Enabled = $false
    $Parent.Controls.Add($num)
    $chk.Add_CheckedChanged({ $num.Enabled = $chk.Checked }).GetNewClosure()

    $lblWorkflowNote = New-Object System.Windows.Forms.Label
    $lblWorkflowNote.Text = "This workflow does not use this module yet."
    $lblWorkflowNote.Left = 8; $lblWorkflowNote.Top = $Top + 48; $lblWorkflowNote.Width = 390; $lblWorkflowNote.Height = 18
    $lblWorkflowNote.ForeColor = [System.Drawing.Color]::FromArgb(130, 130, 150)
    $lblWorkflowNote.Font = New-Object System.Drawing.Font("Segoe UI", 7.5, [System.Drawing.FontStyle]::Italic)
    $Parent.Controls.Add($lblWorkflowNote)
}

# ── Shared Data Lists ────────────────────────────────────────────────────────
$script:SharedDataDir = Join-Path (Split-Path -Parent $PSScriptRoot) "Creators\data"

$script:DefaultClothingCategories = @(
    "Tops","Dresses","Skirts","Pants","Outerwear","Fantasy","Formal","Casual"
)

$script:DefaultClothingItems = @(
    "Tops|fitted turtleneck sweater","Tops|button front blouse","Tops|linen shirt",
    "Tops|silk blouse","Tops|crop top","Tops|peasant blouse","Tops|corset top",
    "Tops|off-shoulder blouse","Tops|wrap top","Tops|long-sleeve shirt","Tops|tank top",
    "Tops|hoodie","Dresses|floor-length gown","Dresses|medieval underdress",
    "Dresses|ball gown","Dresses|corset dress","Dresses|wrap dress","Dresses|sundress",
    "Dresses|maxi dress","Dresses|sheath dress","Dresses|slip dress","Dresses|peasant dress",
    "Dresses|tunic dress","Skirts|full circle skirt","Skirts|pleated midi skirt",
    "Skirts|maxi skirt","Skirts|wrap skirt","Skirts|tiered peasant skirt",
    "Skirts|pencil skirt","Skirts|mini skirt","Pants|high-waist trousers",
    "Pants|wide-leg pants","Pants|fitted leggings","Pants|linen trousers",
    "Pants|flared trousers","Pants|skinny jeans","Pants|cargo pants",
    "Outerwear|hooded cloak","Outerwear|full-length cape","Outerwear|leather jacket",
    "Outerwear|fitted blazer","Outerwear|duster coat","Outerwear|traveling cloak",
    "Outerwear|bolero jacket","Outerwear|cardigan","Fantasy|chainmail tunic",
    "Fantasy|plate armor breastplate","Fantasy|leather armor vest","Fantasy|elven robes",
    "Fantasy|mage robes","Fantasy|dark sorcerer robes","Fantasy|battle dress",
    "Fantasy|noble court dress","Fantasy|rogue leathers","Fantasy|ranger armor",
    "Formal|royal court gown","Formal|evening gown","Formal|cocktail dress",
    "Formal|tailored blazer suit","Formal|brocade coat","Formal|renaissance court dress",
    "Formal|victorian bustle gown","Casual|fitted t-shirt","Casual|oversized hoodie",
    "Casual|denim jacket","Casual|casual button-down","Casual|sweater",
    "Casual|yoga pants and top","Casual|athletic wear set","Casual|lounge set"
)

$script:DefaultColors = @(
    "white","off-white","ivory","cream","beige","tan","gray","charcoal","black","deep black",
    "crimson","scarlet","ruby red","burgundy","maroon","rose pink","blush pink","hot pink","coral",
    "sky blue","powder blue","steel blue","cobalt blue","royal blue","navy blue","midnight blue",
    "sage green","mint green","forest green","emerald green","olive green",
    "lavender","lilac","violet","purple","deep purple","plum",
    "golden yellow","amber","honey","mustard","burnt orange","terracotta","copper",
    "chocolate brown","caramel","chestnut","silver","gold","bronze"
)

$script:DefaultMaterials = @(
    "linen","cotton","silk","wool","cashmere","velvet","satin","chiffon","muslin","canvas","denim",
    "leather","suede","lace","tulle","organza","brocade","tweed","knit","crochet","mesh",
    "chainmail","scales","fur"
)

$script:DefaultOutfitPresets = @(
    "fitted turtleneck sweater","button front blouse","leather jacket over shirt",
    "athletic zip top","hoodie and jeans","formal business suit","medieval travel outfit",
    "fantasy noble outfit","cloak and tunic","armor inspired outfit","casual T shirt","long coat",
    "floor-length velvet gown with lace sleeves","elven silk robes with gold embroidery",
    "ranger leather armor with hooded cloak","platinum chainmail tunic under crimson surcoat",
    "black mage robes with silver runes","peasant blouse with full circle skirt",
    "corset top with tiered peasant skirt","off-shoulder blouse with high-waist trousers",
    "sundress with cardigan and sandals","wrap dress with leather belt",
    "tank top with cargo pants and combat boots","silk blouse with pencil skirt",
    "linen shirt with flared trousers and vest","hooded cloak over leather armor",
    "royal court gown with brocade bodice","riding outfit with fitted blazer and boots",
    "battle dress with scale mail accents","casual sweater with skinny jeans",
    "formal tuxedo with satin lapels","renaissance chemise with corset and full skirt"
)

function Read-SharedList {
    param([string]$FileName, [string[]]$Defaults)
    $path = Join-Path $script:SharedDataDir $FileName
    if (-not (Test-Path -LiteralPath $script:SharedDataDir -PathType Container)) {
        New-Item -ItemType Directory -Path $script:SharedDataDir -Force | Out-Null
    }
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        $Defaults | Set-Content -LiteralPath $path -Encoding UTF8
        return @($Defaults)
    }
    $seen = New-Object 'System.Collections.Generic.HashSet[string]'
    $result = New-Object System.Collections.Generic.List[string]
    try {
        Get-Content -LiteralPath $path -Encoding UTF8 | ForEach-Object {
            $line = $_.Trim()
            if ($line -ne "" -and $line -notlike "#*" -and -not $seen.Contains($line)) {
                [void]$seen.Add($line)
                [void]$result.Add($line)
            }
        }
    } catch {
        foreach ($d in $Defaults) {
            if (-not $seen.Contains($d)) { [void]$seen.Add($d); [void]$result.Add($d) }
        }
    }
    return @($result.ToArray())
}

function Read-SharedCategoryMap {
    param([string]$FileName, [string[]]$Defaults)
    $path = Join-Path $script:SharedDataDir $FileName
    if (-not (Test-Path -LiteralPath $script:SharedDataDir -PathType Container)) {
        New-Item -ItemType Directory -Path $script:SharedDataDir -Force | Out-Null
    }
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        $Defaults | Set-Content -LiteralPath $path -Encoding UTF8
    }
    $map = @{}
    $seen = New-Object 'System.Collections.Generic.HashSet[string]'
    try {
        Get-Content -LiteralPath $path -Encoding UTF8 | ForEach-Object {
            $line = $_.Trim()
            if ($line -ne "" -and $line -notlike "#*") {
                if (-not $seen.Contains($line)) {
                    [void]$seen.Add($line)
                    $parts = $line -split '\|', 2
                    if ($parts.Count -eq 2) {
                        $cat = $parts[0].Trim(); $item = $parts[1].Trim()
                        if (-not $map.ContainsKey($cat)) { $map[$cat] = New-Object System.Collections.Generic.List[string] }
                        if (-not $map[$cat].Contains($item)) { [void]$map[$cat].Add($item) }
                    }
                }
            }
        }
    } catch {}
    return $map
}

function Initialize-SharedData {
    if (-not (Test-Path -LiteralPath $script:SharedDataDir -PathType Container)) {
        New-Item -ItemType Directory -Path $script:SharedDataDir -Force | Out-Null
    }
    $labDataDir = Join-Path (Split-Path -Parent $PSScriptRoot) "Creators\Lab\data"
    $files = @(
        @{Name="clothing_categories.txt"; Defaults=$script:DefaultClothingCategories; IsMap=$false},
        @{Name="clothing_items.txt"; Defaults=$script:DefaultClothingItems; IsMap=$true},
        @{Name="colors.txt"; Defaults=$script:DefaultColors; IsMap=$false},
        @{Name="materials.txt"; Defaults=$script:DefaultMaterials; IsMap=$false},
        @{Name="outfit_presets.txt"; Defaults=$script:DefaultOutfitPresets; IsMap=$false}
    )
    foreach ($f in $files) {
        $sharedPath = Join-Path $script:SharedDataDir $f.Name
        if (Test-Path -LiteralPath $sharedPath -PathType Leaf) { continue }
        $labPath = Join-Path $labDataDir $f.Name
        if (Test-Path -LiteralPath $labPath -PathType Leaf) {
            Copy-Item -LiteralPath $labPath -Destination $sharedPath -Force
        } else {
            $f.Defaults | Set-Content -LiteralPath $sharedPath -Encoding UTF8
        }
    }
}

function Get-RefreshSharedLists {
    $script:ClothingCategories = Read-SharedList -FileName "clothing_categories.txt" -Defaults $script:DefaultClothingCategories
    $script:ClothingItemsByCat = Read-SharedCategoryMap -FileName "clothing_items.txt" -Defaults $script:DefaultClothingItems
    $script:ColorList = Read-SharedList -FileName "colors.txt" -Defaults $script:DefaultColors
    $script:MaterialList = Read-SharedList -FileName "materials.txt" -Defaults $script:DefaultMaterials
    $script:OutfitPresets = Read-SharedList -FileName "outfit_presets.txt" -Defaults $script:DefaultOutfitPresets
}

function Get-SharedItemsForCategory {
    param([string]$Category)
    if ([string]::IsNullOrWhiteSpace($Category) -or $Category -eq "-- All --") {
        $all = New-Object System.Collections.Generic.List[string]
        foreach ($k in $script:ClothingItemsByCat.Keys) { foreach ($i in $script:ClothingItemsByCat[$k]) { if (-not $all.Contains($i)) { [void]$all.Add($i) } } }
        return @($all.ToArray())
    }
    if ($script:ClothingItemsByCat.ContainsKey($Category)) { return @($script:ClothingItemsByCat[$Category].ToArray()) }
    return @()
}

# Initialize shared data on module load
Initialize-SharedData
Get-RefreshSharedLists

# Generate-BustTrainingImages.ps1
# Generates 10 bust size reference images of Gwenevere wearing a neutral fitted top.
# Output goes to ComfyUI output folder. Run this once, then use the images to retrain the BustSize LoRA.
#
# HOW TO RUN:
#   1. Make sure ComfyUI is running
#   2. Right-click this file -> Run with PowerShell
#   3. Wait ~10-15 minutes for all 10 images to generate
#   4. Find the images in your ComfyUI output folder
#   5. Use them as training data for the BustSize LoRA (caption each one with the cup size trigger)

$ErrorActionPreference = "Stop"

# ── CONFIGURATION ────────────────────────────────────────────────────────────
# Path to your Invoke script — adjust if yours is in a different location
$InvokeScript  = Join-Path $PSScriptRoot "scripts\Invoke-ComfyCharacterLockImage.ps1"
$ComfyUrl      = "http://127.0.0.1:8000"

# Gwen's face reference — must already be in ComfyUI input folder
$FaceImage     = "gwenevere-face-clean-square-reference.png"

# Locked seed so all 10 images have the same pose/lighting/composition
# Change this number if you want a different base pose
$LockedSeed    = 2014666293

# LoRA settings — your identity LoRA for face lock
$IdentityLora  = "Gwenevere_V0-1.safetensors"
$IdentityStr   = 0.75

# BustSize LoRA
$BustLora      = "BustSize_V0-1.safetensors"

# Image size
$Width  = 1024
$Height = 1024
# ─────────────────────────────────────────────────────────────────────────────

# Cup size definitions — trigger word, LoRA strength, label
$bustSizes = @(
    [pscustomobject]@{ Index=1;  Trigger="a cup bust";  Strength=0.45; Label="01_a_cup" }
    [pscustomobject]@{ Index=2;  Trigger="b cup bust";  Strength=0.49; Label="02_b_cup" }
    [pscustomobject]@{ Index=3;  Trigger="c cup bust";  Strength=0.53; Label="03_c_cup" }
    [pscustomobject]@{ Index=4;  Trigger="d cup bust";  Strength=0.58; Label="04_d_cup" }
    [pscustomobject]@{ Index=5;  Trigger="dd cup bust"; Strength=0.62; Label="05_dd_cup" }
    [pscustomobject]@{ Index=6;  Trigger="e cup bust";  Strength=0.67; Label="06_e_cup" }
    [pscustomobject]@{ Index=7;  Trigger="f cup bust";  Strength=0.71; Label="07_f_cup" }
    [pscustomobject]@{ Index=8;  Trigger="g cup bust";  Strength=0.76; Label="08_g_cup" }
    [pscustomobject]@{ Index=9;  Trigger="i cup bust";  Strength=0.80; Label="09_i_cup" }
    [pscustomobject]@{ Index=10; Trigger="j cup bust";  Strength=0.85; Label="10_j_cup" }
)

# Neutral fitted top prompt — no gown, no flowing fabric, clear body silhouette
# PhotoMaker prefix is added automatically by the invoke script
$basePrompt = "photomaker woman, gwenevere woman, fair freckled skin, soft green eyes, dark brown wavy loose hair, wearing a simple fitted neutral linen top, medieval tavern interior, warm candlelight, cinematic realism, upper body visible, clear body silhouette"

$styleBase  = "standing portrait, simple fitted top, plain linen shirt, body proportions clearly visible, soft natural lighting, neutral background, photorealistic, medieval fantasy realism, upper body and waist visible, full figure, no gown, no flowing fabric, no cloak"

Write-Host ""
Write-Host "=== Gwenevere Bust Training Image Generator ===" -ForegroundColor Cyan
Write-Host "Generating 10 images. Each takes ~1-2 minutes." -ForegroundColor Gray
Write-Host "DO NOT close ComfyUI while this runs." -ForegroundColor Yellow
Write-Host ""

if (-not (Test-Path $InvokeScript)) {
    Write-Host "ERROR: Invoke script not found at: $InvokeScript" -ForegroundColor Red
    Write-Host "Make sure this script is in the same folder as your Start-Studio.ps1" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

# Check ComfyUI is reachable
try {
    $null = Invoke-RestMethod -Uri "$ComfyUrl/system_stats" -TimeoutSec 5
    Write-Host "ComfyUI is running. Starting generation..." -ForegroundColor Green
} catch {
    Write-Host "ERROR: Cannot reach ComfyUI at $ComfyUrl" -ForegroundColor Red
    Write-Host "Make sure ComfyUI is open and running before starting." -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

$results = @()

foreach ($size in $bustSizes) {
    Write-Host ""
    Write-Host "[$($size.Index)/10] Generating $($size.Label) — trigger: '$($size.Trigger)'" -ForegroundColor Cyan

    # Inject trigger into both prompts
    $prompt      = "$($size.Trigger), $basePrompt"
    $stylePrompt = "$($size.Trigger), $styleBase, $($size.Trigger)"  # doubled for emphasis

    $prefix = "gwen_bust_training_$($size.Label)"

    try {
        $queueJson = & $InvokeScript `
            -Prompt          $prompt `
            -StylePrompt     $stylePrompt `
            -IdentityImageName $FaceImage `
            -OutfitImageName $FaceImage `
            -Width           $Width `
            -Height          $Height `
            -BatchSize       1 `
            -Steps           42 `
            -Cfg             5.0 `
            -FaceWeight      1.10 `
            -OutfitWeight    0.0 `
            -PoseStrength    0.75 `
            -IdentityLoraName   $IdentityLora `
            -IdentityLoraStrength $IdentityStr `
            -ClothingLoraName   $BustLora `
            -ClothingLoraStrength $size.Strength `
            -Seed            $LockedSeed `
            -Prefix          $prefix `
            -ComfyUrl        $ComfyUrl | Out-String

        $queueResponse = $queueJson | ConvertFrom-Json
        $promptId = $queueResponse.prompt_id

        if ([string]::IsNullOrWhiteSpace($promptId)) {
            throw "No prompt_id returned from ComfyUI"
        }

        Write-Host "  Queued — prompt_id: $promptId" -ForegroundColor Gray
        Write-Host "  Waiting for completion..." -ForegroundColor Gray

        # Poll until done
        $maxWait  = 300  # 5 minutes max per image
        $elapsed  = 0
        $interval = 10
        $done     = $false

        while (-not $done -and $elapsed -lt $maxWait) {
            Start-Sleep -Seconds $interval
            $elapsed += $interval

            try {
                $history = Invoke-RestMethod -Uri "$ComfyUrl/history/$promptId" -TimeoutSec 10
                $entry   = $history.PSObject.Properties[$promptId]
                if ($null -ne $entry -and $null -ne $entry.Value.outputs) {
                    $done = $true
                }
            } catch {
                # Still processing, keep waiting
            }

            if (-not $done) {
                Write-Host "  Still waiting... ($elapsed s)" -ForegroundColor DarkGray
            }
        }

        if ($done) {
            Write-Host "  DONE — $($size.Label) complete." -ForegroundColor Green
            $results += [pscustomobject]@{ Size=$size.Label; Trigger=$size.Trigger; Status="OK"; PromptId=$promptId }
        } else {
            Write-Host "  TIMEOUT — took too long. Check ComfyUI manually." -ForegroundColor Yellow
            $results += [pscustomobject]@{ Size=$size.Label; Trigger=$size.Trigger; Status="TIMEOUT"; PromptId=$promptId }
        }

    } catch {
        Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
        $results += [pscustomobject]@{ Size=$size.Label; Trigger=$size.Trigger; Status="ERROR: $($_.Exception.Message)"; PromptId="" }
    }
}

# Summary
Write-Host ""
Write-Host "=== Generation Complete ===" -ForegroundColor Cyan
Write-Host ""
$results | ForEach-Object {
    $color = if ($_.Status -eq "OK") { "Green" } else { "Red" }
    Write-Host "  $($_.Size) [$($_.Trigger)] — $($_.Status)" -ForegroundColor $color
}

Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Open your ComfyUI output folder" -ForegroundColor White
Write-Host "  2. Find the 10 images named gwen_bust_training_01_a_cup... through ...10_j_cup" -ForegroundColor White
Write-Host "  3. Put them in a new folder: bust_kohya_dataset_v3\img\10_gwenevere woman\" -ForegroundColor White
Write-Host "  4. Create a .txt file next to each image with its trigger word (e.g. 'a cup bust, gwenevere woman')" -ForegroundColor White
Write-Host "  5. Retrain the BustSize LoRA using kohya with these new images" -ForegroundColor White
Write-Host ""

Read-Host "Press Enter to close"

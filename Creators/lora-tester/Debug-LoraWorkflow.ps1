# Debug-LoraWorkflow.ps1
# Run this to see EXACTLY what JSON gets sent to ComfyUI when LoRA is enabled.
# Usage: .\Debug-LoraWorkflow.ps1
# It will NOT actually send anything to ComfyUI - just prints the JSON so you can inspect it.

param(
    [string]$WorkflowPath = (Join-Path $PSScriptRoot "..\comfyui\workflows\sdxl-basic-book-image.api.json"),
    [string]$LoraName     = "ColoringBook_Redmond.safetensors",   # change to a real LoRA filename
    [double]$LoraStrength = 1.0,
    [string]$Checkpoint   = "SDXL\dreamshaperXL_lightningDPMSDE.safetensors"
)

Write-Host ""
Write-Host "=== DEBUG: LoRA Workflow Inspector ===" -ForegroundColor Cyan
Write-Host "Workflow: $WorkflowPath"
Write-Host "LoRA:     $LoraName @ $LoraStrength"
Write-Host "Ckpt:     $Checkpoint"
Write-Host ""

# ---- Load workflow ----
if (-not (Test-Path -LiteralPath $WorkflowPath)) {
    Write-Host "ERROR: Workflow file not found at: $WorkflowPath" -ForegroundColor Red
    Write-Host "Edit the WorkflowPath param at the top of this script." -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    return
}

$workflow = Get-Content -LiteralPath $WorkflowPath -Raw | ConvertFrom-Json

# ---- Apply checkpoint ----
$workflow."3".inputs.ckpt_name = $Checkpoint

# ---- Inject dummy prompts/settings ----
$workflow."4".inputs.text  = "test positive prompt"
$workflow."5".inputs.text  = "test negative prompt"
$workflow."7".inputs.seed  = 12345
$workflow."9".inputs.filename_prefix = "debug_test"

# ---- Show what node 7 model input looks like BEFORE LoRA ----
Write-Host "--- Node 7 model input BEFORE LoRA injection ---" -ForegroundColor Yellow
$workflow."7".inputs.model | ConvertTo-Json
Write-Host ""

# ---- Inject LoRA node 100 ----
Write-Host "Injecting LoRA node 100..." -ForegroundColor Green

$workflow | Add-Member -NotePropertyName "100" -NotePropertyValue ([pscustomobject]@{
    class_type = "LoraLoader"
    inputs     = [pscustomobject]@{
        model          = @("3", 0)
        clip           = @("3", 1)
        lora_name      = $LoraName
        strength_model = $LoraStrength
        strength_clip  = $LoraStrength
    }
}) -Force

$workflow."4".inputs.clip  = @("100", 1)
$workflow."5".inputs.clip  = @("100", 1)
$workflow."7".inputs.model = @("100", 0)

# ---- Show what node 7 model input looks like AFTER LoRA ----
Write-Host "--- Node 7 model input AFTER LoRA injection ---" -ForegroundColor Yellow
$workflow."7".inputs.model | ConvertTo-Json
Write-Host ""

# ---- Show node 100 ----
Write-Host "--- Node 100 (LoraLoader) ---" -ForegroundColor Yellow
$workflow."100" | ConvertTo-Json -Depth 10
Write-Host ""

# ---- Full JSON ----
$body = [pscustomobject]@{
    prompt    = $workflow
    client_id = "lora-tester-debug"
} | ConvertTo-Json -Depth 100

Write-Host "--- Full JSON body (check for node 100 and wiring) ---" -ForegroundColor Cyan
Write-Host $body
Write-Host ""

# ---- Key checks ----
Write-Host "=== KEY CHECKS ===" -ForegroundColor Cyan

if ($body -match '"100"') {
    Write-Host "[PASS] Node 100 is present in the JSON" -ForegroundColor Green
} else {
    Write-Host "[FAIL] Node 100 is MISSING from the JSON - LoRA never gets sent!" -ForegroundColor Red
}

if ($body -match '"lora_name"') {
    Write-Host "[PASS] lora_name field is present" -ForegroundColor Green
} else {
    Write-Host "[FAIL] lora_name field is missing" -ForegroundColor Red
}

if ($body -match '\"100\".*?"model"' -or $body -match '"model".*?100') {
    Write-Host "[INFO] Node 7 model references node 100 (check manually above)" -ForegroundColor Yellow
}

# Check if arrays serialized correctly (should be ["100", 0] not {"value":"100"...})
if ($body -match '\["100",\s*0\]') {
    Write-Host "[PASS] Node wiring arrays look correct: [""100"", 0]" -ForegroundColor Green
} else {
    Write-Host "[WARN] Node wiring may have serialization issues - check JSON above" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Copy the full JSON above and paste into https://jsonlint.com to validate." -ForegroundColor Gray
Write-Host "Or paste the prompt value into ComfyUI's API to test directly." -ForegroundColor Gray
Write-Host ""
Read-Host "Press Enter to exit"
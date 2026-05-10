# Debug-CharacterWorkflow.ps1
# Run this to see EXACTLY what JSON gets sent to ComfyUI when dual LoRA is enabled.
# Usage: .\Debug-CharacterWorkflow.ps1
# It will NOT actually send anything to ComfyUI - just prints the JSON so you can inspect it.

param(
    [string]$WorkflowPath = (Join-Path $PSScriptRoot "..\comfyui\workflows\sdxl-basic-book-image.api.json"),
    [string]$Lora1Name     = "character_lora.safetensors",
    [double]$Lora1Strength = 0.75,
    [string]$Lora2Name     = "breast_size_lora.safetensors",
    [double]$Lora2Strength = 0.65,
    [string]$Checkpoint   = "SDXL\dreamshaperXL_lightningDPMSDE.safetensors"
)

Write-Host ""
Write-Host "=== DEBUG: Dual LoRA Workflow Inspector ===" -ForegroundColor Cyan
Write-Host "Workflow: $WorkflowPath"
Write-Host "LoRA 1:   $Lora1Name @ $Lora1Strength"
Write-Host "LoRA 2:   $Lora2Name @ $Lora2Strength"
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

# ---- Inject LoRA node 100 (LoRA 1) ----
Write-Host "Injecting LoRA 1 node 100..." -ForegroundColor Green
$workflow | Add-Member -NotePropertyName "100" -NotePropertyValue ([pscustomobject]@{
    class_type = "LoraLoader"
    inputs     = [ordered]@{
        model          = @("3", 0)
        clip           = @("3", 1)
        lora_name      = $Lora1Name
        strength_model = $Lora1Strength
        strength_clip  = $Lora1Strength
    }
}) -Force

# ---- Inject LoRA node 101 (LoRA 2, chained after LoRA 1) ----
Write-Host "Injecting LoRA 2 node 101 (chained after LoRA 1)..." -ForegroundColor Green
$workflow | Add-Member -NotePropertyName "101" -NotePropertyValue ([pscustomobject]@{
    class_type = "LoraLoader"
    inputs     = [ordered]@{
        model          = @("100", 0)
        clip           = @("100", 1)
        lora_name      = $Lora2Name
        strength_model = $Lora2Strength
        strength_clip  = $Lora2Strength
    }
}) -Force

# Rewire downstream to go through LoRA 2 (last in chain)
$workflow."4".inputs.clip  = @("101", 1)
$workflow."5".inputs.clip  = @("101", 1)
$workflow."7".inputs.model = @("101", 0)

# ---- Show what node 7 model input looks like AFTER LoRA ----
Write-Host "--- Node 7 model input AFTER dual LoRA injection ---" -ForegroundColor Yellow
$workflow."7".inputs.model | ConvertTo-Json
Write-Host ""

# ---- Show nodes 100 and 101 ----
Write-Host "--- Node 100 (LoraLoader 1) ---" -ForegroundColor Yellow
$workflow."100" | ConvertTo-Json -Depth 10
Write-Host ""
Write-Host "--- Node 101 (LoraLoader 2) ---" -ForegroundColor Yellow
$workflow."101" | ConvertTo-Json -Depth 10
Write-Host ""

# ---- Full JSON ----
$body = [pscustomobject]@{
    prompt    = $workflow
    client_id = "character-enhancer-debug"
} | ConvertTo-Json -Depth 100

Write-Host "--- Full JSON body (check for nodes 100+101 and wiring) ---" -ForegroundColor Cyan
Write-Host $body
Write-Host ""

# ---- Key checks ----
Write-Host "=== KEY CHECKS ===" -ForegroundColor Cyan

if ($body -match '"100"') {
    Write-Host "[PASS] Node 100 is present in the JSON" -ForegroundColor Green
} else {
    Write-Host "[FAIL] Node 100 is MISSING from the JSON" -ForegroundColor Red
}

if ($body -match '"101"') {
    Write-Host "[PASS] Node 101 is present in the JSON" -ForegroundColor Green
} else {
    Write-Host "[FAIL] Node 101 is MISSING from the JSON" -ForegroundColor Red
}

if ($body -match '"lora_name"') {
    Write-Host "[PASS] lora_name field is present" -ForegroundColor Green
} else {
    Write-Host "[FAIL] lora_name field is missing" -ForegroundColor Red
}

if ($body -match '\["101",\s*0\]') {
    Write-Host "[PASS] Node wiring to node 101 looks correct: [""101"", 0]" -ForegroundColor Green
} else {
    Write-Host "[WARN] Node wiring to 101 may have serialization issues - check JSON above" -ForegroundColor Yellow
}

if ($body -match '\["100",\s*0\]') {
    Write-Host "[PASS] Node 100->101 wiring looks correct: [""100"", 0]" -ForegroundColor Green
} else {
    Write-Host "[WARN] Node 100->101 wiring may have issues - check JSON above" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Copy the full JSON above and paste into https://jsonlint.com to validate." -ForegroundColor Gray
Write-Host "Or paste the prompt value into ComfyUI's API to test directly." -ForegroundColor Gray
Write-Host ""
Read-Host "Press Enter to exit"

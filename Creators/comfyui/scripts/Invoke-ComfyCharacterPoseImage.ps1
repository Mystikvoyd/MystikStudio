param(
    [string]$Prompt = "full body photomaker woman, teal medieval gown",
    [string]$NegativePrompt = "close up, portrait, headshot, cropped feet, cropped head, bad anatomy, deformed body, extra limbs, extra arms, extra hands, extra legs, extra feet, duplicate feet, malformed feet, text, watermark, labels, dots",
    [string]$IdentityImageName = "gwenevere-face-clean-square-reference.png",
    [string]$PoseImageName = "standing-full-body-openpose-square.png",
    [string]$ControlNetName = "control-lora-openposeXL2-rank256.safetensors",
    [int]$Width = 1024,
    [int]$Height = 1024,
    [int]$BatchSize = 1,
    [int]$Steps = 36,
    [double]$Cfg = 5.5,
    [double]$ControlStrength = 0.85,
    [double]$ControlEnd = 0.9,
    [string]$Sampler = "dpmpp_2m_sde_gpu",
    [string]$Scheduler = "karras",
    [int]$Seed = 0,
    [string]$Prefix = "gwenevere_photomaker_openpose_square",
    [string]$ComfyUrl = "http://127.0.0.1:8000",
    [string]$WorkflowPath = (Join-Path $PSScriptRoot "..\workflows\sdxl-photomaker-openpose-square.api.json")
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $WorkflowPath -PathType Leaf)) {
    throw "Workflow not found: $WorkflowPath"
}

if ($Prompt -notmatch "(?i)\bphotomaker\b") {
    $Prompt = "photomaker woman, $Prompt"
}

$workflow = Get-Content -LiteralPath $WorkflowPath -Raw | ConvertFrom-Json
$workflow."5".inputs.image = $IdentityImageName
$workflow."6".inputs.text = $Prompt
$workflow."7".inputs.text = $NegativePrompt
$workflow."8".inputs.width = $Width
$workflow."8".inputs.height = $Height
$workflow."8".inputs.batch_size = $BatchSize
$workflow."9".inputs.steps = $Steps
$workflow."9".inputs.cfg = $Cfg
$workflow."9".inputs.sampler_name = $Sampler
$workflow."9".inputs.scheduler = $Scheduler
if ($Seed -gt 0) {
    $workflow."9".inputs.seed = $Seed
}
else {
    $workflow."9".inputs.seed = Get-Random -Minimum 1 -Maximum ([int]::MaxValue)
}
$workflow."11".inputs.filename_prefix = $Prefix
$workflow."12".inputs.control_net_name = $ControlNetName
$workflow."13".inputs.image = $PoseImageName
$workflow."14".inputs.strength = $ControlStrength
$workflow."14".inputs.end_percent = $ControlEnd

$body = [pscustomobject]@{
    prompt = $workflow
    client_id = "book-dashboard"
} | ConvertTo-Json -Depth 80

$response = Invoke-RestMethod -Method Post -Uri "$ComfyUrl/prompt" -Body $body -ContentType "application/json"
$response | ConvertTo-Json -Depth 10
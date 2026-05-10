param(
    [string]$Prompt = "square portrait of photomaker woman, dark fantasy realism",
    [string]$NegativePrompt = "low quality, blurry, distorted anatomy, watermark, text, logo, cartoon, anime",
    [string]$InputImageName = "gwenevere-face-clean-square-reference.png",
    [int]$Width = 1024,
    [int]$Height = 1024,
    [int]$BatchSize = 1,
    [int]$Steps = 36,
    [double]$Cfg = 6,
    [string]$Sampler = "dpmpp_2m_sde_gpu",
    [string]$Scheduler = "karras",
    [int]$Seed = 0,
    [string]$Prefix = "gwenevere_photomaker_square",
    [string]$ComfyUrl = "http://127.0.0.1:8000",
    [string]$WorkflowPath = (Join-Path $PSScriptRoot "..\workflows\sdxl-photomaker-square.api.json")
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $WorkflowPath -PathType Leaf)) {
    throw "Workflow not found: $WorkflowPath"
}

if ($Prompt -notmatch "(?i)\bphotomaker\b") {
    $Prompt = "photomaker woman, $Prompt"
}

$workflow = Get-Content -LiteralPath $WorkflowPath -Raw | ConvertFrom-Json
$workflow."5".inputs.image = $InputImageName
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

$body = [pscustomobject]@{
    prompt = $workflow
    client_id = "book-dashboard"
} | ConvertTo-Json -Depth 80

$response = Invoke-RestMethod -Method Post -Uri "$ComfyUrl/prompt" -Body $body -ContentType "application/json"
$response | ConvertTo-Json -Depth 10

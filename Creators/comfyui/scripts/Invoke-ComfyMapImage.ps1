param(
    [string]$Prompt = "square fantasy world map, parchment scroll cartography, mountains, rivers, forests, coastlines, islands, old ink, no readable labels",
    [string]$NegativePrompt = "text, letters, words, labels, watermark, logo, blurry, low quality, modern satellite photo, city street, people, characters",
    [int]$Width = 1024,
    [int]$Height = 1024,
    [int]$BatchSize = 1,
    [int]$Steps = 36,
    [double]$Cfg = 7,
    [double]$LoraStrength = 0.85,
    [string]$Sampler = "dpmpp_2m_sde_gpu",
    [string]$Scheduler = "karras",
    [int]$Seed = 0,
    [string]$Prefix = "fantasy_map_test",
    [string]$ComfyUrl = "http://127.0.0.1:8000",
    [string]$WorkflowPath = (Join-Path $PSScriptRoot "..\workflows\sdxl-fantasy-map.api.json")
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $WorkflowPath -PathType Leaf)) {
    throw "Workflow not found: $WorkflowPath"
}

$workflow = Get-Content -LiteralPath $WorkflowPath -Raw | ConvertFrom-Json
$workflow."4".inputs.strength_model = $LoraStrength
$workflow."4".inputs.strength_clip = $LoraStrength
$workflow."5".inputs.text = $Prompt
$workflow."6".inputs.text = $NegativePrompt
$workflow."7".inputs.width = $Width
$workflow."7".inputs.height = $Height
$workflow."7".inputs.batch_size = $BatchSize
$workflow."8".inputs.steps = $Steps
$workflow."8".inputs.cfg = $Cfg
$workflow."8".inputs.sampler_name = $Sampler
$workflow."8".inputs.scheduler = $Scheduler
if ($Seed -gt 0) {
    $workflow."8".inputs.seed = $Seed
}
else {
    $workflow."8".inputs.seed = Get-Random -Minimum 1 -Maximum ([int]::MaxValue)
}
$workflow."10".inputs.filename_prefix = $Prefix

$body = [pscustomobject]@{
    prompt = $workflow
    client_id = "book-dashboard"
} | ConvertTo-Json -Depth 80

$response = Invoke-RestMethod -Method Post -Uri "$ComfyUrl/prompt" -Body $body -ContentType "application/json"
$response | ConvertTo-Json -Depth 10

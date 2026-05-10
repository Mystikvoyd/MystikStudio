param(
    [string]$Prompt = "A serious mythic fantasy concept art portrait for a dark fantasy novel, cinematic painterly realism, detailed costume, dramatic lighting",
    [string]$NegativePrompt = "low quality, blurry, distorted anatomy, extra fingers, bad hands, watermark, text, logo, modern clothing, cartoon, anime, joke, clown",
    [int]$Width = 1024,
    [int]$Height = 1024,
    [int]$BatchSize = 1,
    [int]$Steps = 30,
    [double]$Cfg = 7,
    [string]$Sampler = "dpmpp_2m",
    [string]$Scheduler = "karras",
    [int]$Seed = 0,
    [string]$Prefix = "book_test",
    [string]$ComfyUrl = "http://127.0.0.1:8000",
    [string]$WorkflowPath = (Join-Path $PSScriptRoot "..\workflows\sdxl-basic-book-image.api.json")
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $WorkflowPath -PathType Leaf)) {
    throw "Workflow not found: $WorkflowPath"
}

$workflow = Get-Content -LiteralPath $WorkflowPath -Raw | ConvertFrom-Json
$workflow."4".inputs.text = $Prompt
$workflow."5".inputs.text = $NegativePrompt
$workflow."6".inputs.width = $Width
$workflow."6".inputs.height = $Height
$workflow."6".inputs.batch_size = $BatchSize
$workflow."7".inputs.steps = $Steps
$workflow."7".inputs.cfg = $Cfg
$workflow."7".inputs.sampler_name = $Sampler
$workflow."7".inputs.scheduler = $Scheduler
if ($Seed -gt 0) {
    $workflow."7".inputs.seed = $Seed
}
else {
    $workflow."7".inputs.seed = Get-Random -Minimum 1 -Maximum ([int]::MaxValue)
}
$workflow."9".inputs.filename_prefix = $Prefix

$body = [pscustomobject]@{
    prompt = $workflow
    client_id = "book-dashboard"
} | ConvertTo-Json -Depth 80

$response = Invoke-RestMethod -Method Post -Uri "$ComfyUrl/prompt" -Body $body -ContentType "application/json"
$response | ConvertTo-Json -Depth 10

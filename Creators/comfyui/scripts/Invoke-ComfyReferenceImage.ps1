param(
    [string]$Prompt = "A square dark fantasy character portrait guided by the provided reference image.",
    [string]$NegativePrompt = "low quality, blurry, distorted anatomy, watermark, text, logo, cartoon, anime",
    [string]$InputImageName = "gwenevere-face-square-reference.png",
    [int]$Steps = 30,
    [double]$Cfg = 6,
    [double]$Denoise = 0.35,
    [string]$Sampler = "dpmpp_2m_sde_gpu",
    [string]$Scheduler = "karras",
    [int]$Seed = 0,
    [string]$Prefix = "book_reference_img2img",
    [string]$ComfyUrl = "http://127.0.0.1:8000",
    [string]$WorkflowPath = (Join-Path $PSScriptRoot "..\workflows\sdxl-reference-img2img-book-image.api.json")
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $WorkflowPath -PathType Leaf)) {
    throw "Workflow not found: $WorkflowPath"
}

$workflow = Get-Content -LiteralPath $WorkflowPath -Raw | ConvertFrom-Json
$workflow."4".inputs.text = $Prompt
$workflow."5".inputs.text = $NegativePrompt
$workflow."7".inputs.steps = $Steps
$workflow."7".inputs.cfg = $Cfg
$workflow."7".inputs.denoise = $Denoise
$workflow."7".inputs.sampler_name = $Sampler
$workflow."7".inputs.scheduler = $Scheduler
if ($Seed -gt 0) {
    $workflow."7".inputs.seed = $Seed
}
else {
    $workflow."7".inputs.seed = Get-Random -Minimum 1 -Maximum ([int]::MaxValue)
}
$workflow."9".inputs.filename_prefix = $Prefix
$workflow."10".inputs.image = $InputImageName

$body = [pscustomobject]@{
    prompt = $workflow
    client_id = "book-dashboard"
} | ConvertTo-Json -Depth 80

$response = Invoke-RestMethod -Method Post -Uri "$ComfyUrl/prompt" -Body $body -ContentType "application/json"
$response | ConvertTo-Json -Depth 10

param(
    [string]$Prompt,
    [string]$NegativePrompt,
    [string]$LoraName           = "None",
    [double]$LoraStrength       = 0.75,
    [bool]$LoraEnabled   = $false,
    [int]$Width                 = 1024,
    [int]$Height                = 1024,
    [int]$BatchSize             = 1,
    [int]$Steps                 = 30,
    [double]$Cfg                = 7,
    [string]$Sampler            = "dpmpp_2m",
    [string]$Scheduler          = "karras",
    [int]$Seed                  = 0,
    [string]$Prefix             = "lora_test",
    [string]$ComfyUrl           = "http://127.0.0.1:8000",
    [string]$WorkflowPath       = "",
    [string]$Checkpoint         = "",
    [string]$Diffuser           = "",
    [bool]$ControlNetEnabled = $false,
    [string]$ControlNetModel    = "",
    [string]$ControlNetImage    = "",
    [string]$ControlNetFilter   = "none",
    [double]$ControlNetStrength = 1.0,
    [double]$ControlNetStart    = 0.0,
    [double]$ControlNetEnd      = 1.0
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($WorkflowPath) -or -not (Test-Path -LiteralPath $WorkflowPath -PathType Leaf)) {
    throw "Workflow not found: $WorkflowPath"
}

$workflow = Get-Content -LiteralPath $WorkflowPath -Raw | ConvertFrom-Json

# Inject checkpoint into node 3
if (-not [string]::IsNullOrWhiteSpace($Checkpoint) -and $Checkpoint -ne "None") {
    $workflow."3".inputs.ckpt_name = $Checkpoint
}

# Inject generation settings
$workflow."4".inputs.text            = $Prompt
$workflow."5".inputs.text            = $NegativePrompt
$workflow."6".inputs.width           = $Width
$workflow."6".inputs.height          = $Height
$workflow."6".inputs.batch_size      = $BatchSize
$workflow."7".inputs.steps           = $Steps
$workflow."7".inputs.cfg             = $Cfg
$workflow."7".inputs.sampler_name    = $Sampler
$workflow."7".inputs.scheduler       = $Scheduler
$workflow."7".inputs.seed            = if ($Seed -gt 0) { $Seed } else { Get-Random -Minimum 1 -Maximum ([int]::MaxValue) }
$workflow."9".inputs.filename_prefix = $Prefix

# Inject LoRA as node 100 if enabled
if ($LoraEnabled -and -not [string]::IsNullOrWhiteSpace($LoraName) -and $LoraName -ne "None" -and $LoraStrength -gt 0) {
    $workflow | Add-Member -NotePropertyName "100" -NotePropertyValue ([pscustomobject]@{
        class_type = "LoraLoader"
        inputs     = [ordered]@{
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
}

$body = [pscustomobject]@{
    prompt    = $workflow
    client_id = "lora-tester"
} | ConvertTo-Json -Depth 100

$response = Invoke-RestMethod -Method Post -Uri ($ComfyUrl + "/prompt") -Body $body -ContentType "application/json"

# Return just the prompt_id as a simple string - no JSON wrapping that can break
return [string]$response.prompt_id
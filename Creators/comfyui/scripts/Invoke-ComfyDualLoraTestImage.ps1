param(
    [string]$Prompt,
    [string]$NegativePrompt,
    [string]$Lora1Name           = "None",
    [double]$Lora1Strength       = 0.75,
    [bool]$Lora1Enabled          = $false,
    [string]$Lora2Name           = "None",
    [double]$Lora2Strength       = 0.65,
    [bool]$Lora2Enabled          = $false,
    [int]$Width                  = 1024,
    [int]$Height                 = 1024,
    [int]$BatchSize              = 1,
    [int]$Steps                  = 30,
    [double]$Cfg                 = 7,
    [string]$Sampler             = "dpmpp_2m",
    [string]$Scheduler           = "karras",
    [int]$Seed                   = 0,
    [string]$Prefix              = "char_enhance",
    [string]$ComfyUrl            = "http://127.0.0.1:8000",
    [string]$WorkflowPath        = "",
    [string]$Checkpoint          = "",
    [string]$Diffuser            = "",
    [bool]$ControlNetEnabled     = $false,
    [string]$ControlNetModel     = "",
    [string]$ControlNetImage     = "",
    [string]$ControlNetFilter    = "none",
    [double]$ControlNetStrength  = 1.0,
    [double]$ControlNetStart     = 0.0,
    [double]$ControlNetEnd       = 1.0
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

# Determine which LoRAs to apply
$useLora1 = $Lora1Enabled -and -not [string]::IsNullOrWhiteSpace($Lora1Name) -and $Lora1Name -ne "None" -and $Lora1Strength -gt 0
$useLora2 = $Lora2Enabled -and -not [string]::IsNullOrWhiteSpace($Lora2Name) -and $Lora2Name -ne "None" -and $Lora2Strength -gt 0

if ($useLora1 -and $useLora2) {
    # Chain: Checkpoint -> LoRA1 (node 100) -> LoRA2 (node 101) -> downstream
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

    # Rewire downstream nodes to go through LoRA 2 (the last in chain)
    $workflow."4".inputs.clip  = @("101", 1)
    $workflow."5".inputs.clip  = @("101", 1)
    $workflow."7".inputs.model = @("101", 0)
}
elseif ($useLora1) {
    # Only LoRA 1
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

    $workflow."4".inputs.clip  = @("100", 1)
    $workflow."5".inputs.clip  = @("100", 1)
    $workflow."7".inputs.model = @("100", 0)
}
elseif ($useLora2) {
    # Only LoRA 2 (treat as single LoRA)
    $workflow | Add-Member -NotePropertyName "100" -NotePropertyValue ([pscustomobject]@{
        class_type = "LoraLoader"
        inputs     = [ordered]@{
            model          = @("3", 0)
            clip           = @("3", 1)
            lora_name      = $Lora2Name
            strength_model = $Lora2Strength
            strength_clip  = $Lora2Strength
        }
    }) -Force

    $workflow."4".inputs.clip  = @("100", 1)
    $workflow."5".inputs.clip  = @("100", 1)
    $workflow."7".inputs.model = @("100", 0)
}

$body = [pscustomobject]@{
    prompt    = $workflow
    client_id = "fusion"
} | ConvertTo-Json -Depth 100

$response = Invoke-RestMethod -Method Post -Uri ($ComfyUrl + "/prompt") -Body $body -ContentType "application/json"

return [string]$response.prompt_id

param(
    [string]$Prompt,
    [string]$NegativePrompt,
    [string]$Lora1Name           = "None",
    [double]$Lora1Strength       = 0.80,
    [bool]$Lora1Enabled          = $false,
    [string]$Lora2Name           = "None",
    [double]$Lora2Strength       = 0.65,
    [bool]$Lora2Enabled          = $false,
    [string]$Lora3Name           = "None",
    [double]$Lora3Strength       = 0.50,
    [bool]$Lora3Enabled          = $false,
    [int]$Width                  = 1024,
    [int]$Height                 = 1024,
    [int]$BatchSize              = 1,
    [int]$Steps                  = 30,
    [double]$Cfg                 = 7,
    [string]$Sampler             = "dpmpp_2m",
    [string]$Scheduler           = "karras",
    [int]$Seed                   = 0,
    [string]$Prefix              = "char_design",
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
$useLora3 = $Lora3Enabled -and -not [string]::IsNullOrWhiteSpace($Lora3Name) -and $Lora3Name -ne "None" -and $Lora3Strength -gt 0

$activeLoras = @()
if ($useLora1) { $activeLoras += 1 }
if ($useLora2) { $activeLoras += 2 }
if ($useLora3) { $activeLoras += 3 }

$loraCount = $activeLoras.Count

if ($loraCount -eq 3) {
    # Chain: Checkpoint -> LoRA1 (100) -> LoRA2 (101) -> LoRA3 (102) -> downstream
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

    $workflow | Add-Member -NotePropertyName "102" -NotePropertyValue ([pscustomobject]@{
        class_type = "LoraLoader"
        inputs     = [ordered]@{
            model          = @("101", 0)
            clip           = @("101", 1)
            lora_name      = $Lora3Name
            strength_model = $Lora3Strength
            strength_clip  = $Lora3Strength
        }
    }) -Force

    $workflow."4".inputs.clip  = @("102", 1)
    $workflow."5".inputs.clip  = @("102", 1)
    $workflow."7".inputs.model = @("102", 0)
}
elseif ($loraCount -eq 2) {
    # Two LoRAs: Checkpoint -> First -> Second -> downstream
    if ($useLora1 -and $useLora2) {
        $firstName = $Lora1Name; $firstStrength = $Lora1Strength
        $secondName = $Lora2Name; $secondStrength = $Lora2Strength
    } elseif ($useLora1 -and $useLora3) {
        $firstName = $Lora1Name; $firstStrength = $Lora1Strength
        $secondName = $Lora3Name; $secondStrength = $Lora3Strength
    } else {
        $firstName = $Lora2Name; $firstStrength = $Lora2Strength
        $secondName = $Lora3Name; $secondStrength = $Lora3Strength
    }

    $workflow | Add-Member -NotePropertyName "100" -NotePropertyValue ([pscustomobject]@{
        class_type = "LoraLoader"
        inputs     = [ordered]@{
            model          = @("3", 0)
            clip           = @("3", 1)
            lora_name      = $firstName
            strength_model = $firstStrength
            strength_clip  = $firstStrength
        }
    }) -Force

    $workflow | Add-Member -NotePropertyName "101" -NotePropertyValue ([pscustomobject]@{
        class_type = "LoraLoader"
        inputs     = [ordered]@{
            model          = @("100", 0)
            clip           = @("100", 1)
            lora_name      = $secondName
            strength_model = $secondStrength
            strength_clip  = $secondStrength
        }
    }) -Force

    $workflow."4".inputs.clip  = @("101", 1)
    $workflow."5".inputs.clip  = @("101", 1)
    $workflow."7".inputs.model = @("101", 0)
}
elseif ($loraCount -eq 1) {
    # Single LoRA
    if ($useLora1) { $name = $Lora1Name; $strength = $Lora1Strength }
    elseif ($useLora2) { $name = $Lora2Name; $strength = $Lora2Strength }
    else { $name = $Lora3Name; $strength = $Lora3Strength }

    $workflow | Add-Member -NotePropertyName "100" -NotePropertyValue ([pscustomobject]@{
        class_type = "LoraLoader"
        inputs     = [ordered]@{
            model          = @("3", 0)
            clip           = @("3", 1)
            lora_name      = $name
            strength_model = $strength
            strength_clip  = $strength
        }
    }) -Force

    $workflow."4".inputs.clip  = @("100", 1)
    $workflow."5".inputs.clip  = @("100", 1)
    $workflow."7".inputs.model = @("100", 0)
}

$body = [pscustomobject]@{
    prompt    = $workflow
    client_id = "forge"
} | ConvertTo-Json -Depth 100

$response = Invoke-RestMethod -Method Post -Uri ($ComfyUrl + "/prompt") -Body $body -ContentType "application/json"

return [string]$response.prompt_id

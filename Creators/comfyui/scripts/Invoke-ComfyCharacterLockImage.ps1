param(
    [string]$Prompt = "full body photomaker woman, teal medieval gown",
    [string]$StylePrompt = "",
    [string]$NegativePrompt = "close up, portrait, headshot, cropped feet, cropped head, bad anatomy, deformed body, extra limbs, extra arms, extra hands, extra legs, extra feet, duplicate feet, malformed feet, text, watermark, labels, dots, callout circles",
    [string]$IdentityImageName = "gwenevere-face-clean-square-reference.png",
    [string]$OutfitImageName = "gwenevere-full-body-retouched-square-reference.png",
    [string]$PoseImageName = "standing-full-body-openpose-square.png",
    [int]$Width = 1024,
    [int]$Height = 1024,
    [int]$BatchSize = 1,
    [int]$Steps = 38,
    [double]$Cfg = 5.2,
    [double]$PoseStrength = 0.9,
    [double]$FaceWeight = 0.65,
    [double]$OutfitWeight = 0.18,
    [string]$InitImageName = "",
    [double]$Denoise = 1.0,
    [string]$IdentityLoraName = "",
    [double]$IdentityLoraStrength = 0,
    [string]$ClothingLoraName = "",
    [double]$ClothingLoraStrength = 0,
    [string]$RealmLoraName = "",
    [double]$RealmLoraStrength = 0,
    [string]$QualityLoraName = "",
    [double]$QualityLoraStrength = 0,
    [string]$Sampler = "dpmpp_2m_sde_gpu",
    [string]$Scheduler = "karras",
    [int]$Seed = 0,
    [string]$Prefix = "gwenevere_character_lock_square",
    [string]$ComfyUrl = "http://127.0.0.1:8000",
    [string]$WorkflowPath = (Join-Path $PSScriptRoot "..\workflows\sdxl-character-lock-openpose-square.api.json")
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $WorkflowPath -PathType Leaf)) {
    throw "Workflow not found: $WorkflowPath"
}

if ($Prompt -notmatch "(?i)\bphotomaker\b") {
    $Prompt = "photomaker woman, $Prompt"
}

if ([string]::IsNullOrWhiteSpace($StylePrompt)) {
    $StylePrompt = $Prompt
}

function Add-LoraNode {
    param(
        [Parameter(Mandatory = $true)]$Workflow,
        [Parameter(Mandatory = $true)][ref]$NextNodeId,
        [Parameter(Mandatory = $true)]$ModelRef,
        [Parameter(Mandatory = $true)]$ClipRef,
        [string]$LoraName,
        [double]$Strength
    )

    if ([string]::IsNullOrWhiteSpace($LoraName) -or $LoraName -eq "None" -or $Strength -le 0) {
        return [pscustomobject]@{
            Model = $ModelRef
            Clip = $ClipRef
        }
    }

    $nodeId = [string]$NextNodeId.Value
    $NextNodeId.Value = $NextNodeId.Value + 1
    $node = [pscustomobject]@{
        class_type = "LoraLoader"
        inputs = [ordered]@{
            model = $ModelRef
            clip = $ClipRef
            lora_name = $LoraName
            strength_model = $Strength
            strength_clip = $Strength
        }
    }

    $Workflow | Add-Member -NotePropertyName $nodeId -NotePropertyValue $node

    return [pscustomobject]@{
        Model = @($nodeId, 0)
        Clip = @($nodeId, 1)
    }
}

$workflow = Get-Content -LiteralPath $WorkflowPath -Raw | ConvertFrom-Json
$modelRef = @("3", 0)
$clipRef = @("3", 1)
$numericNodeIds = @($workflow.PSObject.Properties.Name | Where-Object { $_ -match "^\d+$" } | ForEach-Object { [int]$_ })
$maxNodeId = 99
if ($numericNodeIds.Count -gt 0) {
    $maxNodeId = ($numericNodeIds | Measure-Object -Maximum).Maximum
}
$nextNodeId = [math]::Max(100, ([int]$maxNodeId + 1))

foreach ($lora in @(
    [pscustomobject]@{ Name = $IdentityLoraName; Strength = $IdentityLoraStrength },
    [pscustomobject]@{ Name = $ClothingLoraName; Strength = $ClothingLoraStrength },
    [pscustomobject]@{ Name = $RealmLoraName; Strength = $RealmLoraStrength },
    [pscustomobject]@{ Name = $QualityLoraName; Strength = $QualityLoraStrength }
)) {
    $refs = Add-LoraNode -Workflow $workflow -NextNodeId ([ref]$nextNodeId) -ModelRef $modelRef -ClipRef $clipRef -LoraName ([string]$lora.Name) -Strength ([double]$lora.Strength)
    $modelRef = $refs.Model
    $clipRef = $refs.Clip
}

$workflow."5".inputs.image = $IdentityImageName
$workflow."6".inputs.clip = $clipRef
$workflow."6".inputs.text = $Prompt
$workflow."7".inputs.clip = $clipRef
$workflow."7".inputs.text = $NegativePrompt
if ($null -ne $workflow.PSObject.Properties["24"]) {
    $workflow."24".inputs.clip = $clipRef
    $workflow."24".inputs.text = $StylePrompt
}
$workflow."8".inputs.width = $Width
$workflow."8".inputs.height = $Height
$workflow."8".inputs.batch_size = $BatchSize
$workflow."9".inputs.steps = $Steps
$workflow."9".inputs.cfg = $Cfg
$workflow."9".inputs.sampler_name = $Sampler
$workflow."9".inputs.scheduler = $Scheduler
$workflow."9".inputs.denoise = $Denoise
if ($Seed -gt 0) {
    $workflow."9".inputs.seed = $Seed
}
else {
    $workflow."9".inputs.seed = Get-Random -Minimum 1 -Maximum ([int]::MaxValue)
}
$workflow."11".inputs.filename_prefix = $Prefix
$workflow."13".inputs.image = $PoseImageName
$workflow."14".inputs.strength = $PoseStrength
$workflow."18".inputs.model = $modelRef
$workflow."18".inputs.weight = $FaceWeight
$workflow."20".inputs.image = $OutfitImageName
$workflow."23".inputs.weight = $OutfitWeight

if (-not [string]::IsNullOrWhiteSpace($InitImageName) -and $Denoise -lt 1) {
    $workflow."20".inputs.image = $InitImageName
    $vaeEncodeId = [string]$nextNodeId
    $nextNodeId = $nextNodeId + 1
    $workflow | Add-Member -NotePropertyName $vaeEncodeId -NotePropertyValue ([pscustomobject]@{
        class_type = "VAEEncode"
        inputs = [ordered]@{
            pixels = @("20", 0)
            vae = @("3", 2)
        }
    })
    $workflow."9".inputs.latent_image = @($vaeEncodeId, 0)
}

$body = [pscustomobject]@{
    prompt = $workflow
    client_id = "book-dashboard"
} | ConvertTo-Json -Depth 100

$response = Invoke-RestMethod -Method Post -Uri "$ComfyUrl/prompt" -Body $body -ContentType "application/json"
$response | ConvertTo-Json -Depth 10
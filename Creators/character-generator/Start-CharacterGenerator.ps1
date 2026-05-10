param(
    [switch]$ValidateOnly,
    [switch]$SelfTestGuides
)

$ErrorActionPreference = "Stop"

$GeneratorRoot      = $PSScriptRoot
$ProjectRoot        = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$ConfigPath         = Join-Path $GeneratorRoot "character-generator.config.json"
$SavesPath          = Join-Path $GeneratorRoot "character-generator-saves.json"
$WorkflowScriptPath = Join-Path $ProjectRoot "Creators\comfyui\scripts\Invoke-ComfyCharacterLockImage.ps1"
$AssetsRoot         = Join-Path $ProjectRoot "book-design\assets"

function Read-GeneratorConfig {
    if (-not (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) {
        throw "Missing generator config: $ConfigPath"
    }

    Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
}

function Get-ConfigArray {
    param(
        [Parameter(Mandatory = $true)]$Value
    )

    if ($null -eq $Value) {
        return @()
    }

    return ,@($Value)
}

function Get-SafeFilePart {
    param(
        [string]$Text,
        [string]$Fallback = "image"
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $Fallback
    }

    $clean = $Text.ToLowerInvariant()
    $clean = $clean -replace "[^a-z0-9]+", "_"
    $clean = $clean.Trim("_")

    if ([string]::IsNullOrWhiteSpace($clean)) {
        return $Fallback
    }

    return $clean
}

function Test-CharacterReferenceReady {
    param(
        [Parameter(Mandatory = $true)]$Character
    )

    if ([string]::IsNullOrWhiteSpace([string]$Character.identityImageName)) {
        return $false
    }

    if ([string]::IsNullOrWhiteSpace([string]$Character.outfitImageName)) {
        return $false
    }

    return $true
}

function Get-CharacterDisplayName {
    param(
        [Parameter(Mandatory = $true)]$Character
    )

    $name = [string]$Character.name
    if ($null -ne $Character.PSObject.Properties["selectionName"] -and -not [string]::IsNullOrWhiteSpace([string]$Character.selectionName)) {
        $name = [string]$Character.selectionName
    }

    if (Test-CharacterReferenceReady -Character $Character) {
        return "$name (ready)"
    }

    return "$name (needs refs)"
}

function New-EmptySavesDocument {
    [pscustomobject]@{
        version = 1
        saves = @()
    }
}

function Read-GeneratorSaves {
    if (-not (Test-Path -LiteralPath $SavesPath -PathType Leaf)) {
        return New-EmptySavesDocument
    }

    $doc = Get-Content -LiteralPath $SavesPath -Raw | ConvertFrom-Json
    if ($null -eq $doc) {
        return New-EmptySavesDocument
    }

    if ($null -eq $doc.PSObject.Properties["version"]) {
        $doc | Add-Member -NotePropertyName "version" -NotePropertyValue 1
    }

    if ($null -eq $doc.PSObject.Properties["saves"] -or $null -eq $doc.saves) {
        if ($null -ne $doc.PSObject.Properties["saves"]) {
            $doc.saves = @()
        }
        else {
            $doc | Add-Member -NotePropertyName "saves" -NotePropertyValue @()
        }
    }

    return $doc
}

function Write-GeneratorSaves {
    param(
        [Parameter(Mandatory = $true)]$SavesDocument
    )

    $folder = Split-Path -Parent $SavesPath
    if (-not (Test-Path -LiteralPath $folder -PathType Container)) {
        throw "Save folder was not found: $folder"
    }

    $SavesDocument | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $SavesPath -Encoding UTF8
}

function Get-SavesForCharacter {
    param(
        [Parameter(Mandatory = $true)][string]$CharacterId
    )

    if ($null -eq $script:SavesDoc) {
        return @()
    }

    @(Get-ConfigArray -Value $script:SavesDoc.saves) |
        Where-Object { [string]$_.characterId -eq $CharacterId } |
        Sort-Object updatedAt, name -Descending
}

function New-SaveId {
    ([guid]::NewGuid()).ToString("N")
}

function Get-DefaultSaveName {
    param(
        [Parameter(Mandatory = $true)]$Character,
        [Parameter(Mandatory = $true)]$Pose,
        [Parameter(Mandatory = $true)]$Scene
    )

    "{0} - {1} - {2} - {3}" -f ([string]$Character.name), ([string]$Pose.name), ([string]$Scene.name), (Get-Date -Format "yyyy-MM-dd HHmm")
}

function Get-FirstWords {
    param(
        [string]$Text,
        [int]$MaxWords = 16
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return ""
    }

    $clean = ($Text -replace "\s+", " ").Trim()
    $words = @($clean -split " ")
    if ($words.Count -le $MaxWords) {
        return $clean
    }

    return (($words | Select-Object -First $MaxWords) -join " ")
}

function Get-PhotoMakerSafePrompt {
    param(
        [Parameter(Mandatory = $true)]$Character,
        [Parameter(Mandatory = $true)]$Pose,
        [Parameter(Mandatory = $true)]$Scene,
        [string]$UserPrompt
    )

    $subject = [string]$Character.photomakerPrompt
    if ([string]::IsNullOrWhiteSpace($subject)) {
        $subject = [string]$Character.basePrompt
    }

    if ([string]::IsNullOrWhiteSpace($subject)) {
        $subject = "full body photomaker person, $($Character.name), dark fantasy realism"
    }

    if ($subject -notmatch "(?i)\bphotomaker\b") {
        $subject = "photomaker person, $subject"
    }

    # Keep PhotoMaker focused on identity only. Pose and scene are handled
    # separately by ControlNet and the style prompt.
    $prompt = $subject
    $words = @($prompt -replace "\s+", " " -split " ")
    if ($words.Count -gt 22) {
        $prompt = (($words | Select-Object -First 22) -join " ")
    }

    return $prompt
}

function Get-StableCharacterSeed {
    param(
        [Parameter(Mandatory = $true)]$Character
    )

    if ($null -ne $Character.PSObject.Properties["defaultSeed"] -and [int]$Character.defaultSeed -gt 0) {
        return [int]$Character.defaultSeed
    }

    $source = [string]$Character.id
    if ([string]::IsNullOrWhiteSpace($source)) {
        $source = [string]$Character.name
    }

    $hash = 1729
    foreach ($ch in $source.ToCharArray()) {
        $hash = (($hash * 31) + [int][char]$ch) % 2147483646
    }

    return [math]::Max(1, $hash)
}

function Get-SafeUserPromptForGeneration {
    param(
        [string]$UserPrompt,
        [string]$EffectiveProfile
    )

    $prompt = ""
    if (-not [string]::IsNullOrWhiteSpace($UserPrompt)) {
        $prompt = $UserPrompt.Trim()
    }

    $nudityPattern = "(?i)\b(nude|naked|topless|bottomless|undressed|unclothed|no clothes|without clothes|bare breasts?|exposed breasts?|genitals?|explicit nude)\b"
    $unsafeClothingRemovalPattern = "(?i)\b(shirt off|top off|remove clothing|remove clothes|no shirt|no top)\b"
    $usesBaseLayer = $false

    if ($prompt -match $nudityPattern -or ([string]$EffectiveProfile -eq "female" -and $prompt -match $unsafeClothingRemovalPattern)) {
        $usesBaseLayer = $true
        $prompt = "neutral clothing-design base reference, plain smooth close-fitting matte base layer, body proportions preserved, no ornament, no costume detail, same character identity, same face, same hair, full body, tasteful nonsexual design reference"
    }

    [pscustomobject]@{
        Prompt = $prompt
        WasSubstituted = $usesBaseLayer
    }
}

function Get-SafeExtraNegativePrompt {
    param(
        [string]$ExtraNegativePrompt,
        [bool]$UsingBaseLayer
    )

    if ([string]::IsNullOrWhiteSpace($ExtraNegativePrompt)) {
        return ""
    }

    $negative = $ExtraNegativePrompt.Trim()
    if ($UsingBaseLayer) {
        $negative = $negative -replace "(?i)\b(no clothes|clothes|clothing|cloths|shirt|top|dress|fabric|garment|covered torso)\b", " "
        $negative = ($negative -replace "\s+", " ").Trim(" ,")
    }

    return $negative
}

function Get-CharacterIdentityPrompt {
    param(
        [Parameter(Mandatory = $true)]$Character
    )

    if ($null -ne $Character.PSObject.Properties["identityPrompt"] -and -not [string]::IsNullOrWhiteSpace([string]$Character.identityPrompt)) {
        return [string]$Character.identityPrompt
    }

    return [string]$Character.basePrompt
}

function Get-HipGuidePrompt {
    param(
        [int]$HipIndex
    )

    if ($HipIndex -lt 1) { $HipIndex = 1 }
    if ($HipIndex -gt 10) { $HipIndex = 10 }

    switch ($HipIndex) {
        1 { return "clothed hip silhouette: very narrow hips, size 1 on a 1 to 10 body-shape guide" }
        2 { return "clothed hip silhouette: narrow hips, size 2 on a 1 to 10 body-shape guide" }
        3 { return "clothed hip silhouette: slim natural hips, size 3 on a 1 to 10 body-shape guide" }
        4 { return "clothed hip silhouette: balanced natural hips, size 4 on a 1 to 10 body-shape guide" }
        5 { return "clothed hip silhouette: moderate feminine hips, size 5 on a 1 to 10 body-shape guide" }
        6 { return "clothed hip silhouette: softly curvy hips, size 6 on a 1 to 10 body-shape guide" }
        7 { return "clothed hip silhouette: clearly curvy hips, size 7 on a 1 to 10 body-shape guide" }
        8 { return "clothed hip silhouette: wide curvy hips, size 8 on a 1 to 10 body-shape guide" }
        9 { return "clothed hip silhouette: very wide curvy hips, size 9 on a 1 to 10 body-shape guide" }
        10 { return "clothed hip silhouette: maximum wide curvy hips, size 10 on a 1 to 10 body-shape guide" }
        default { return "clothed hip silhouette follows the requested body-shape guide" }
    }
}

function Get-BodyAdjustmentPromptParts {
    param(
        [string]$RawPrompt,
        [string]$EffectiveProfile
    )

    $parts = New-Object System.Collections.Generic.List[string]
    if ([string]::IsNullOrWhiteSpace($RawPrompt)) {
        return @()
    }

    if ([string]$EffectiveProfile -eq "female") {
        $chestMatch = [regex]::Match($RawPrompt, "(?i)\b(?:bust|chest|breast)\s*(?:size|chart|level)?\s*(?:=|:)?\s*(\d{1,2})\b|\b(?:size|level)\s*(\d{1,2})\s*(?:bust|chest|breast)\b")
        if ($chestMatch.Success) {
            $rawIndex = if ($chestMatch.Groups[1].Success) { $chestMatch.Groups[1].Value } else { $chestMatch.Groups[2].Value }
            $chestIndex = [int]$rawIndex
            if ($chestIndex -lt 1) { $chestIndex = 1 }
            if ($chestIndex -gt 10) { $chestIndex = 10 }
            $entry = Get-FemaleChestGuideEntry -ChestIndex $chestIndex
            if ($null -ne $entry) {
                [void]$parts.Add("$($entry.Prompt), requested by the typed prompt, prioritize this body silhouette over the locked outfit reference")
            }
        }
        elseif ($RawPrompt -match "(?i)\b(smaller|reduced|less|modest)\s+(bust|chest|breast)") {
            [void]$parts.Add("clothed upper-body proportions: smaller more modest bust silhouette, natural anatomy, requested by the typed prompt")
        }
        elseif ($RawPrompt -match "(?i)\b(larger|bigger|fuller|more)\s+(bust|chest|breast)") {
            [void]$parts.Add("clothed upper-body proportions: fuller bust silhouette, natural anatomy, requested by the typed prompt")
        }
    }

    $hipMatch = [regex]::Match($RawPrompt, "(?i)\b(?:hip|hips)\s*(?:size|chart|level)?\s*(?:=|:)?\s*(\d{1,2})\b|\b(?:size|level)\s*(\d{1,2})\s*(?:hip|hips)\b")
    if ($hipMatch.Success) {
        $rawIndex = if ($hipMatch.Groups[1].Success) { $hipMatch.Groups[1].Value } else { $hipMatch.Groups[2].Value }
        $hipIndex = [int]$rawIndex
        [void]$parts.Add("$(Get-HipGuidePrompt -HipIndex $hipIndex), requested by the typed prompt, preserve natural anatomy")
    }
    elseif ($RawPrompt -match "(?i)\b(narrower|slimmer|smaller)\s+(hip|hips)") {
        [void]$parts.Add("clothed hip silhouette: narrower slimmer hips, natural anatomy, requested by the typed prompt")
    }
    elseif ($RawPrompt -match "(?i)\b(wider|curvier|larger|fuller)\s+(hip|hips)") {
        [void]$parts.Add("clothed hip silhouette: wider curvier hips, natural anatomy, requested by the typed prompt")
    }

    return @($parts.ToArray())
}

function Get-ModeNegativePromptParts {
    param(
        [string]$GenerationMode,
        [string]$UserPrompt,
        [bool]$UsingBaseLayer
    )

    $parts = New-Object System.Collections.Generic.List[string]
    if ($GenerationMode -eq "Prompt Freedom" -and -not [string]::IsNullOrWhiteSpace($UserPrompt)) {
        [void]$parts.Add("copied reference background, unchanged reference background, copied reference outfit, unchanged reference outfit, copied reference pose, ignored prompt, wrong requested action, missing requested subject, same flower arrangement, same stone columns from reference")
    }

    if ($UsingBaseLayer) {
        [void]$parts.Add("ornate gown, teal gown, aqua gown, rose gown, display dress, ceremonial dress, chainwork dress, gold waist clasp, translucent sleeves, front slit, reference outfit, ornate jewelry costume, heavy costume detail")
    }

    return @($parts.ToArray())
}

function Test-GenerationPromptAllowsSecondarySubject {
    param(
        [string]$Prompt
    )

    if ([string]::IsNullOrWhiteSpace($Prompt)) {
        return $false
    }

    return ($Prompt -match "(?i)\b(child|children|baby|infant|toddler|boy|girl|mercy|refugee|family|mother|father|crowd|courtiers|warriors|guards|people|person)\b")
}

function Remove-NegativePromptPhrase {
    param(
        [string]$NegativePrompt,
        [string]$Phrase
    )

    if ([string]::IsNullOrWhiteSpace($NegativePrompt) -or [string]::IsNullOrWhiteSpace($Phrase)) {
        return $NegativePrompt
    }

    $escaped = [regex]::Escape($Phrase)
    $clean = $NegativePrompt -replace "(?i)(^|,\s*)$escaped\s*(?=,|$)", ""
    $clean = $clean -replace "\s*,\s*,+", ", "
    return $clean.Trim(" ,")
}

function Get-GenerationNegativePrompt {
    param(
        [string[]]$Parts,
        [bool]$AllowSecondarySubject
    )

    $negative = (@($Parts) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) -join ", "

    if ($AllowSecondarySubject) {
        foreach ($phrase in @(
            "extra body",
            "duplicate body",
            "multiple versions of same character",
            "repeated character",
            "duplicate character"
        )) {
            $negative = Remove-NegativePromptPhrase -NegativePrompt $negative -Phrase $phrase
        }
    }

    return $negative
}

function Test-ComfyConnection {
    param(
        [string]$ComfyUrl
    )

    try {
        [void](Invoke-RestMethod -Method Get -Uri "$ComfyUrl/system_stats" -TimeoutSec 5)
        return $true
    }
    catch {
        return $false
    }
}

function Get-ProjectAssetByName {
    param(
        [string]$FileName
    )

    if ([string]::IsNullOrWhiteSpace($FileName)) {
        return $null
    }

    if (-not (Test-Path -LiteralPath $AssetsRoot -PathType Container)) {
        return $null
    }

    $match = Get-ChildItem -LiteralPath $AssetsRoot -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -eq $FileName } |
        Select-Object -First 1

    if ($null -eq $match) {
        return $null
    }

    return $match.FullName
}

function Get-ComfyLoraRoot {
    $inputPath = [string]$script:Config.comfyInputPath
    if ([string]::IsNullOrWhiteSpace($inputPath)) {
        return $null
    }

    $comfyRoot = Split-Path -Parent $inputPath
    $loraRoot = Join-Path $comfyRoot "models\loras"
    if (-not (Test-Path -LiteralPath $loraRoot -PathType Container)) {
        return $null
    }

    return $loraRoot
}

function Get-ComfyLoraItems {
    $items = New-Object System.Collections.Generic.List[string]
    [void]$items.Add("None")

    $loraRoot = Get-ComfyLoraRoot
    if ([string]::IsNullOrWhiteSpace($loraRoot)) {
        return @($items)
    }

    $rootFull = [System.IO.Path]::GetFullPath($loraRoot)
    $rootWithSlash = $rootFull
    if (-not $rootWithSlash.EndsWith([System.IO.Path]::DirectorySeparatorChar)) {
        $rootWithSlash = $rootWithSlash + [System.IO.Path]::DirectorySeparatorChar
    }

    Get-ChildItem -LiteralPath $loraRoot -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Extension -in @(".safetensors", ".ckpt", ".pt") } |
        Sort-Object FullName |
        ForEach-Object {
            $full = [System.IO.Path]::GetFullPath($_.FullName)
            $relative = $full.Substring($rootWithSlash.Length)
            [void]$items.Add($relative)
        }

    return @($items)
}

function Get-CharacterLoraSearchTerms {
    param(
        $Character
    )

    $terms = New-Object System.Collections.Generic.List[string]
    foreach ($source in @(
        [string]$Character.id,
        [string]$Character.name,
        $(if ($null -ne $Character.PSObject.Properties["selectionName"]) { [string]$Character.selectionName } else { "" })
    )) {
        if ([string]::IsNullOrWhiteSpace($source)) {
            continue
        }

        $compact = ($source.ToLowerInvariant() -replace "[^a-z0-9]", "")
        if ($compact.Length -ge 3 -and -not $terms.Contains($compact)) {
            [void]$terms.Add($compact)
        }

        foreach ($word in @($source.ToLowerInvariant() -split "[^a-z0-9]+")) {
            if ($word.Length -ge 4 -and -not $terms.Contains($word)) {
                [void]$terms.Add($word)
            }
        }
    }

    return @($terms.ToArray())
}

function Get-IdentityLoraItemsForCharacter {
    param(
        $Character,
        [string[]]$AllItems,
        [string]$PreferredIdentity
    )

    $items = New-Object System.Collections.Generic.List[string]
    [void]$items.Add("None")

    if ($null -eq $Character) {
        foreach ($item in $AllItems) {
            if ($item -ne "None") {
                [void]$items.Add($item)
            }
        }
        return @($items.ToArray())
    }

    $terms = @(Get-CharacterLoraSearchTerms -Character $Character)
    foreach ($item in $AllItems) {
        if ($item -eq "None") {
            continue
        }

        $normalized = ([System.IO.Path]::GetFileNameWithoutExtension([string]$item).ToLowerInvariant() -replace "[^a-z0-9]", "")
        foreach ($term in $terms) {
            if ($normalized.Contains($term)) {
                [void]$items.Add($item)
                break
            }
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($PreferredIdentity) -and $PreferredIdentity -ne "None" -and -not $items.Contains($PreferredIdentity)) {
        $preferredNormalized = ([System.IO.Path]::GetFileNameWithoutExtension($PreferredIdentity).ToLowerInvariant() -replace "[^a-z0-9]", "")
        $characterDefault = if ($null -ne $Character.PSObject.Properties["identityLoraName"]) { [string]$Character.identityLoraName } else { "" }
        $preferredMatchesCharacter = ([string]$characterDefault -eq $PreferredIdentity)
        foreach ($term in $terms) {
            if ($preferredNormalized.Contains($term)) {
                $preferredMatchesCharacter = $true
                break
            }
        }

        if ($preferredMatchesCharacter) {
            [void]$items.Add($PreferredIdentity)
        }
    }

    return @($items.ToArray())
}

function Set-LoraComboItems {
    param(
        $Combo,
        [string[]]$Items,
        [string]$Preferred
    )

    if ($null -eq $Combo) {
        return
    }

    $Combo.Items.Clear()
    foreach ($item in $Items) {
        [void]$Combo.Items.Add($item)
    }
    $Combo.Enabled = ($Items.Count -gt 1)
    Set-ComboSelectionByText -Combo $Combo -Text $Preferred
}

function Refresh-LoraDropdownItems {
    param(
        $Character,
        [string]$PreferredIdentity,
        [string]$PreferredClothing,
        [string]$PreferredRealm,
        [string]$PreferredQuality
    )

    $allItems = @(Get-ComfyLoraItems)
    $identityItems = @(Get-IdentityLoraItemsForCharacter -Character $Character -AllItems $allItems -PreferredIdentity $PreferredIdentity)

    Set-LoraComboItems -Combo $comboIdentityLora -Items $identityItems -Preferred $PreferredIdentity
    Set-LoraComboItems -Combo $comboClothingLora -Items $allItems -Preferred $PreferredClothing
    Set-LoraComboItems -Combo $comboRealmLora -Items $allItems -Preferred $PreferredRealm
    Set-LoraComboItems -Combo $comboQualityLora -Items $allItems -Preferred $PreferredQuality
}

function Get-SelectedLoraName {
    param(
        $Combo
    )

    if ($null -eq $Combo -or $Combo.SelectedIndex -lt 0) {
        return ""
    }

    $selected = [string]$Combo.SelectedItem
    if ([string]::IsNullOrWhiteSpace($selected) -or $selected -eq "None") {
        return ""
    }

    return $selected
}

function Get-EffectiveLoraStrength {
    param(
        [string]$LoraName,
        $Control
    )

    if ([string]::IsNullOrWhiteSpace($LoraName) -or $null -eq $Control) {
        return 0.0
    }

    return [double]$Control.Value
}

function Get-LoraStackSummary {
    param(
        [string]$IdentityName,
        [double]$IdentityStrength,
        [string]$ClothingName,
        [double]$ClothingStrength,
        [string]$RealmName,
        [double]$RealmStrength,
        [string]$QualityName,
        [double]$QualityStrength
    )

    $parts = New-Object System.Collections.Generic.List[string]
    foreach ($item in @(
        [pscustomobject]@{ Label = "identity"; Name = $IdentityName; Strength = $IdentityStrength },
        [pscustomobject]@{ Label = "clothing"; Name = $ClothingName; Strength = $ClothingStrength },
        [pscustomobject]@{ Label = "realm"; Name = $RealmName; Strength = $RealmStrength },
        [pscustomobject]@{ Label = "quality"; Name = $QualityName; Strength = $QualityStrength }
    )) {
        if (-not [string]::IsNullOrWhiteSpace([string]$item.Name) -and [double]$item.Strength -gt 0) {
            [void]$parts.Add(("{0}: {1} @ {2:N2}" -f $item.Label, $item.Name, [double]$item.Strength))
        }
    }

    return (($parts.ToArray()) -join "; ")
}

function Set-ComboSelectionByText {
    param(
        $Combo,
        [string]$Text
    )

    if ($null -eq $Combo -or $Combo.Items.Count -eq 0) {
        return
    }

    if ([string]::IsNullOrWhiteSpace($Text)) {
        $Combo.SelectedIndex = 0
        return
    }

    for ($index = 0; $index -lt $Combo.Items.Count; $index++) {
        if ([string]$Combo.Items[$index] -eq $Text) {
            $Combo.SelectedIndex = $index
            return
        }
    }

    $Combo.SelectedIndex = 0
}

function Get-CharacterGuideProfile {
    param(
        [Parameter(Mandatory = $true)]$Character
    )

    $explicit = [string]$Character.sex
    if (-not [string]::IsNullOrWhiteSpace($explicit)) {
        switch -Regex ($explicit.Trim().ToLowerInvariant()) {
            "^f" { return "female" }
            "^m" { return "male" }
        }
    }

    $source = @(
        [string]$Character.photomakerPrompt,
        [string]$Character.basePrompt,
        [string]$Character.notes
    ) -join " "

    if ($source -match "(?i)\b(woman|female|queen|maiden|mother|widow|sister|daughter|girl)\b") {
        return "female"
    }

    if ($source -match "(?i)\b(man|male|king|father|brother|son|beard|mustache)\b") {
        return "male"
    }

    return "none"
}

function Get-EffectiveGuideProfile {
    param(
        [Parameter(Mandatory = $true)]$Character,
        [string]$ProfileSelection
    )

    switch (([string]$ProfileSelection).Trim().ToLowerInvariant()) {
        "female" { return "female" }
        "female guides" { return "female" }
        "male" { return "male" }
        "male guides" { return "male" }
        "none" { return "none" }
        "reference" { return "none" }
        "reference only" { return "none" }
        "auto" { return (Get-CharacterGuideProfile -Character $Character) }
        "auto guides" { return (Get-CharacterGuideProfile -Character $Character) }
        default { return "none" }
    }
}

function Get-SharedHairItems {
    param(
        [string]$EffectiveProfile
    )

    $items = New-Object System.Collections.Generic.List[string]
    [void]$items.Add("None")

    switch ($EffectiveProfile) {
        "female" {
            foreach ($code in 1..70) {
                [void]$items.Add(("{0:D2}" -f $code))
            }
        }
        "male" {
            foreach ($code in 1..50) {
                [void]$items.Add(("{0:D2}" -f $code))
            }
        }
    }

    return @($items)
}

function Get-SharedFacialHairItems {
    $items = @(
        "None",
        "C1","C2","C3","C4",
        "S1","S2","S3","S4","S5",
        "M1","M2","M3","M4","M5","M6",
        "B1","B2","B3","B4",
        "F1","F2","F3","F4","F5","F6","F7","F8",
        "H1","H2","H3","H4"
    )

    return $items
}

function Get-FemaleChestLabels {
    return @(
        "None",
        "1 - Small (A)",
        "2 - Small-Moderate (B)",
        "3 - Moderate (C)",
        "4 - Moderate-Large (D)",
        "5 - Large (DD)",
        "6 - Very Large (DDD)",
        "7 - Very Large+ (G)",
        "8 - Extra Large (H)",
        "9 - Extreme (I)",
        "10 - Maximum (J+)"
    )
}

function New-ChartCropEntry {
    param(
        [string]$Code,
        [string]$Label,
        [string]$Prompt,
        [string]$ChartImageName,
        [int]$X,
        [int]$Y,
        [int]$Width,
        [int]$Height
    )

    $chartPath = Get-ProjectAssetByName -FileName $ChartImageName
    if ([string]::IsNullOrWhiteSpace($chartPath)) {
        return $null
    }

    [pscustomobject]@{
        Code = $Code
        Label = $Label
        Prompt = $Prompt
        ChartImageName = $ChartImageName
        SourcePath = $chartPath
        Rect = New-Object System.Drawing.Rectangle -ArgumentList $X, $Y, $Width, $Height
    }
}

function Get-FemaleChestGuideEntry {
    param(
        [int]$ChestIndex
    )

    if ($ChestIndex -lt 1 -or $ChestIndex -gt 10) {
        return $null
    }

    $labels = Get-FemaleChestLabels
    $col = ($ChestIndex - 1) % 5
    $row = [math]::Floor(($ChestIndex - 1) / 5)
    $x = [int]([math]::Round($col * 307.2))
    $y = if ($row -eq 0) { 132 } else { 592 }
    $chestPrompt = switch ($ChestIndex) {
        1  { "a cup bust" }
        2  { "b cup bust" }
        3  { "c cup bust" }
        4  { "d cup bust" }
        5  { "dd cup bust" }
        6  { "e cup bust" }
        7  { "f cup bust" }
        8  { "g cup bust" }
        9  { "i cup bust" }
        10 { "j cup bust" }
        default { "clothed upper-body proportions follow the selected shared female chest chart" }
    }

    return (New-ChartCropEntry `
        -Code ("{0:D2}" -f $ChestIndex) `
        -Label $labels[$ChestIndex] `
        -Prompt $chestPrompt `
        -ChartImageName "female-chest-size-reference-chart.png" `
        -X $x -Y $y -Width 304 -Height 304)
}

function Get-FemaleHairGuideEntry {
    param(
        [string]$HairCode
    )

    if ([string]::IsNullOrWhiteSpace($HairCode) -or $HairCode -eq "None") {
        return $null
    }

    $number = 0
    if (-not [int]::TryParse($HairCode, [ref]$number) -or $number -lt 1 -or $number -gt 70) {
        return $null
    }

    $col = ($number - 1) % 10
    $row = [math]::Floor(($number - 1) / 10)
    $x = 100 + ($col * 130)
    $y = 119 + ($row * 107)

    return (New-ChartCropEntry `
        -Code ("{0:D2}" -f $number) `
        -Label ("Female Hair {0:D2}" -f $number) `
        -Prompt ("female hair silhouette, length, and styling follow shared reference code {0:D2}" -f $number) `
        -ChartImageName "female-hair-reference-guide.png" `
        -X $x -Y $y -Width 128 -Height 104)
}

function Get-MaleHairGuideEntry {
    param(
        [string]$HairCode
    )

    if ([string]::IsNullOrWhiteSpace($HairCode) -or $HairCode -eq "None") {
        return $null
    }

    $number = 0
    if (-not [int]::TryParse($HairCode, [ref]$number) -or $number -lt 1 -or $number -gt 50) {
        return $null
    }

    $col = ($number - 1) % 10
    $row = [math]::Floor(($number - 1) / 10)
    $x = 114 + ($col * 142)
    $y = 120 + ($row * 152)

    return (New-ChartCropEntry `
        -Code ("{0:D2}" -f $number) `
        -Label ("Male Hair {0:D2}" -f $number) `
        -Prompt ("male hair silhouette, length, and styling follow shared reference code {0:D2}" -f $number) `
        -ChartImageName "male-hair-reference-guide.png" `
        -X $x -Y $y -Width 140 -Height 148)
}

function Get-MaleFacialHairGuideEntry {
    param(
        [string]$FacialHairCode
    )

    if ([string]::IsNullOrWhiteSpace($FacialHairCode) -or $FacialHairCode -eq "None") {
        return $null
    }

    $code = $FacialHairCode.Trim().ToUpperInvariant()

    if ($code -match "^C([1-4])$") {
        $index = [int]$Matches[1] - 1
        return (New-ChartCropEntry -Code $code -Label "Facial Hair $code" -Prompt ("male facial hair shape and density follow shared reference code {0}" -f $code) -ChartImageName "male-facial-hair-reference-guide.png" -X (224 + ($index * 143)) -Y 114 -Width 140 -Height 188)
    }

    if ($code -match "^S([1-5])$") {
        $index = [int]$Matches[1] - 1
        return (New-ChartCropEntry -Code $code -Label "Facial Hair $code" -Prompt ("male facial hair shape and density follow shared reference code {0}" -f $code) -ChartImageName "male-facial-hair-reference-guide.png" -X (808 + ($index * 136)) -Y 114 -Width 134 -Height 188)
    }

    if ($code -match "^M([1-6])$") {
        $index = [int]$Matches[1] - 1
        return (New-ChartCropEntry -Code $code -Label "Facial Hair $code" -Prompt ("male facial hair shape and density follow shared reference code {0}" -f $code) -ChartImageName "male-facial-hair-reference-guide.png" -X (224 + ($index * 164)) -Y 341 -Width 160 -Height 190)
    }

    if ($code -match "^B([1-4])$") {
        $index = [int]$Matches[1] - 1
        return (New-ChartCropEntry -Code $code -Label "Facial Hair $code" -Prompt ("male facial hair shape and density follow shared reference code {0}" -f $code) -ChartImageName "male-facial-hair-reference-guide.png" -X (224 + ($index * 156)) -Y 580 -Width 154 -Height 174)
    }

    if ($code -match "^F([1-4])$") {
        $index = [int]$Matches[1] - 1
        return (New-ChartCropEntry -Code $code -Label "Facial Hair $code" -Prompt ("male facial hair shape and density follow shared reference code {0}" -f $code) -ChartImageName "male-facial-hair-reference-guide.png" -X (859 + ($index * 156)) -Y 580 -Width 154 -Height 174)
    }

    if ($code -match "^F([5-8])$") {
        $index = ([int]$Matches[1] - 5)
        return (New-ChartCropEntry -Code $code -Label "Facial Hair $code" -Prompt ("male facial hair shape and density follow shared reference code {0}" -f $code) -ChartImageName "male-facial-hair-reference-guide.png" -X (224 + ($index * 132)) -Y 782 -Width 130 -Height 172)
    }

    if ($code -match "^H([1-3])$") {
        $index = [int]$Matches[1] - 1
        return (New-ChartCropEntry -Code $code -Label "Facial Hair $code" -Prompt ("male facial hair shape and density follow shared reference code {0}" -f $code) -ChartImageName "male-facial-hair-reference-guide.png" -X (758 + ($index * 125)) -Y 782 -Width 123 -Height 172)
    }

    if ($code -eq "H4") {
        return (New-ChartCropEntry -Code $code -Label "Facial Hair $code" -Prompt ("male facial hair shape and density follow shared reference code {0}" -f $code) -ChartImageName "male-facial-hair-reference-guide.png" -X 1217 -Y 341 -Width 270 -Height 190)
    }

    return $null
}

function Draw-FittedImage {
    param(
        [Parameter(Mandatory = $true)]$Graphics,
        [Parameter(Mandatory = $true)][System.Drawing.Image]$Image,
        [Parameter(Mandatory = $true)][System.Drawing.Rectangle]$Bounds
    )

    $scaleX = $Bounds.Width / [double]$Image.Width
    $scaleY = $Bounds.Height / [double]$Image.Height
    $scale = [math]::Min($scaleX, $scaleY)
    $drawWidth = [int][math]::Round($Image.Width * $scale)
    $drawHeight = [int][math]::Round($Image.Height * $scale)
    $drawX = $Bounds.X + [int][math]::Round(($Bounds.Width - $drawWidth) / 2)
    $drawY = $Bounds.Y + [int][math]::Round(($Bounds.Height - $drawHeight) / 2)
    $destRect = New-Object System.Drawing.Rectangle -ArgumentList $drawX, $drawY, $drawWidth, $drawHeight
    $Graphics.DrawImage($Image, $destRect)
}

function New-SharedGuideCompositeReference {
    param(
        [Parameter(Mandatory = $true)][string]$BaseImageName,
        [Parameter(Mandatory = $true)]$GuideState,
        [Parameter(Mandatory = $true)][string]$CharacterId
    )

    $entries = New-Object System.Collections.Generic.List[object]
    $promptParts = New-Object System.Collections.Generic.List[string]

    # Inject chest prompt whenever slider is set (1-10), regardless of guide mode.
    # This allows bust size to work even in "Reference only" mode.
    $chestIndexValue = [int]$GuideState.ChestIndex
    if ($chestIndexValue -ge 1 -and $chestIndexValue -le 10) {
        $chestEntry = Get-FemaleChestGuideEntry -ChestIndex $chestIndexValue
        if ($null -ne $chestEntry) {
            [void]$entries.Add($chestEntry)
            [void]$promptParts.Add([string]$chestEntry.Prompt)
        }
    }

    if ([string]$GuideState.EffectiveProfile -eq "female") {
        $hairEntry = Get-FemaleHairGuideEntry -HairCode ([string]$GuideState.HairCode)
        if ($null -ne $hairEntry) {
            [void]$entries.Add($hairEntry)
            [void]$promptParts.Add([string]$hairEntry.Prompt)
        }
    }
    elseif ([string]$GuideState.EffectiveProfile -eq "male") {
        $hairEntry = Get-MaleHairGuideEntry -HairCode ([string]$GuideState.HairCode)
        if ($null -ne $hairEntry) {
            [void]$entries.Add($hairEntry)
            [void]$promptParts.Add([string]$hairEntry.Prompt)
        }

        $facialHairEntry = Get-MaleFacialHairGuideEntry -FacialHairCode ([string]$GuideState.FacialHairCode)
        if ($null -ne $facialHairEntry) {
            [void]$entries.Add($facialHairEntry)
            [void]$promptParts.Add([string]$facialHairEntry.Prompt)
        }
    }

    if ($entries.Count -eq 0) {
        return [pscustomobject]@{
            OutfitImageName = $BaseImageName
            PromptParts = @()
            Summary = ""
        }
    }

    return [pscustomobject]@{
        OutfitImageName = $BaseImageName
        PromptParts = @($promptParts.ToArray())
        Summary = (($entries | ForEach-Object { $_.Label }) -join "; ")
    }
}

function Sync-ComfyInputFiles {
    param(
        [Parameter(Mandatory = $true)]$Config,
        [Parameter(Mandatory = $true)]$Character,
        [Parameter(Mandatory = $true)]$Pose,
        [string]$IdentityImageName,
        [string]$OutfitImageName,
        [string[]]$ExtraImageNames
    )

    $inputPath = [string]$Config.comfyInputPath
    if ([string]::IsNullOrWhiteSpace($inputPath)) {
        throw "Config does not define comfyInputPath."
    }

    if (-not (Test-Path -LiteralPath $inputPath -PathType Container)) {
        throw "ComfyUI input folder was not found: $inputPath"
    }

    if ([string]::IsNullOrWhiteSpace($IdentityImageName)) {
        $IdentityImageName = [string]$Character.identityImageName
    }

    if ([string]::IsNullOrWhiteSpace($OutfitImageName)) {
        $OutfitImageName = [string]$Character.outfitImageName
    }

    $neededList = New-Object System.Collections.Generic.List[string]
    foreach ($name in @(
        [string]$IdentityImageName,
        [string]$OutfitImageName,
        [string]$Pose.poseImageName
    )) {
        if (-not [string]::IsNullOrWhiteSpace($name)) {
            [void]$neededList.Add($name)
        }
    }

    foreach ($name in @($ExtraImageNames)) {
        if (-not [string]::IsNullOrWhiteSpace([string]$name)) {
            [void]$neededList.Add([string]$name)
        }
    }

    $needed = @($neededList.ToArray() | Select-Object -Unique)

    $synced = New-Object System.Collections.Generic.List[string]
    $missing = New-Object System.Collections.Generic.List[string]

    foreach ($name in $needed) {
        $destination = Join-Path $inputPath $name
        if (Test-Path -LiteralPath $destination -PathType Leaf) {
            continue
        }

        $source = Get-ProjectAssetByName -FileName $name
        if ([string]::IsNullOrWhiteSpace($source)) {
            [void]$missing.Add($name)
            continue
        }

        Copy-Item -LiteralPath $source -Destination $destination -Force
        [void]$synced.Add($name)
    }

    [pscustomobject]@{
        Synced = @($synced)
        Missing = @($missing)
    }
}

function Get-HistoryImages {
    param(
        [Parameter(Mandatory = $true)]$HistoryEntry,
        [Parameter(Mandatory = $true)][string]$OutputPath
    )

    $images = New-Object System.Collections.Generic.List[string]

    if ($null -eq $HistoryEntry.outputs) {
        return @()
    }

    foreach ($nodeProperty in $HistoryEntry.outputs.PSObject.Properties) {
        $nodeOutput = $nodeProperty.Value
        if ($null -eq $nodeOutput.images) {
            continue
        }

        foreach ($image in $nodeOutput.images) {
            if ([string]::IsNullOrWhiteSpace([string]$image.filename)) {
                continue
            }

            $path = Join-Path $OutputPath ([string]$image.filename)
            [void]$images.Add($path)
        }
    }

    return @($images)
}

function Write-GenerationProgress {
    param(
        $Worker,
        [string]$Message
    )

    if ($null -ne $Worker) {
        $Worker.ReportProgress(0, $Message)
        return
    }

    Add-Log $Message
    [System.Windows.Forms.Application]::DoEvents()
}

function Invoke-CharacterGeneration {
    param(
        [Parameter(Mandatory = $true)]$Job,
        $Worker
    )

    if (-not (Test-Path -LiteralPath $WorkflowScriptPath -PathType Leaf)) {
        throw "Missing workflow helper script: $WorkflowScriptPath"
    }

    if (-not (Test-ComfyConnection -ComfyUrl $Job.ComfyUrl)) {
        throw "ComfyUI did not answer at $($Job.ComfyUrl). Start ComfyUI first, then generate again."
    }

    Write-GenerationProgress -Worker $Worker -Message "Syncing selected references into ComfyUI input..."
    $sync = Sync-ComfyInputFiles -Config $Job.Config -Character $Job.Character -Pose $Job.Pose -IdentityImageName ([string]$Job.IdentityImageName) -OutfitImageName ([string]$Job.OutfitImageName)

    if ($sync.Synced.Count -gt 0) {
        Write-GenerationProgress -Worker $Worker -Message "Copied input file(s): $($sync.Synced -join ', ')"
    }

    if ($sync.Missing.Count -gt 0) {
        throw "Missing input file(s) for ComfyUI: $($sync.Missing -join ', ')"
    }

    Write-GenerationProgress -Worker $Worker -Message "Sending prompt to ComfyUI..."

    $queueJson = & $WorkflowScriptPath `
        -Prompt $Job.Prompt `
        -StylePrompt $Job.StylePrompt `
        -NegativePrompt $Job.NegativePrompt `
        -IdentityImageName ([string]$Job.IdentityImageName) `
        -OutfitImageName ([string]$Job.OutfitImageName) `
        -PoseImageName ([string]$Job.Pose.poseImageName) `
        -Width $Job.Width `
        -Height $Job.Height `
        -BatchSize $Job.BatchSize `
        -Steps $Job.Steps `
        -Cfg $Job.Cfg `
        -PoseStrength $Job.PoseStrength `
        -FaceWeight $Job.FaceWeight `
        -OutfitWeight $Job.OutfitWeight `
        -IdentityLoraName ([string]$Job.IdentityLoraName) `
        -IdentityLoraStrength $Job.IdentityLoraStrength `
        -ClothingLoraName ([string]$Job.ClothingLoraName) `
        -ClothingLoraStrength $Job.ClothingLoraStrength `
        -RealmLoraName ([string]$Job.RealmLoraName) `
        -RealmLoraStrength $Job.RealmLoraStrength `
        -QualityLoraName ([string]$Job.QualityLoraName) `
        -QualityLoraStrength $Job.QualityLoraStrength `
        -Seed $Job.Seed `
        -Prefix $Job.Prefix `
        -ComfyUrl $Job.ComfyUrl | Out-String

    $queueResponse = $queueJson | ConvertFrom-Json
    $promptId = [string]$queueResponse.prompt_id

    if ([string]::IsNullOrWhiteSpace($promptId)) {
        throw "ComfyUI did not return a prompt id. Raw response: $queueJson"
    }

    Write-GenerationProgress -Worker $Worker -Message "Queued in ComfyUI. Prompt id: $promptId"

    $historyEntry = $null
    for ($attempt = 1; $attempt -le 240; $attempt++) {
        Start-Sleep -Seconds 2

        $history = Invoke-RestMethod -Method Get -Uri "$($Job.ComfyUrl)/history/$promptId" -TimeoutSec 15
        $property = $history.PSObject.Properties[$promptId]

        if ($null -eq $property) {
            if (($attempt % 10) -eq 0) {
                Write-GenerationProgress -Worker $Worker -Message "Still waiting for ComfyUI history..."
            }
            continue
        }

        $historyEntry = $property.Value

        if ($null -ne $historyEntry.status -and [string]$historyEntry.status.status_str -eq "error") {
            $errorText = $historyEntry.status.messages | ConvertTo-Json -Depth 10
            throw "ComfyUI reported an error: $errorText"
        }

        if ($null -ne $historyEntry.status -and $historyEntry.status.completed) {
            break
        }

        if (($attempt % 8) -eq 0) {
            Write-GenerationProgress -Worker $Worker -Message "Generating... waited $($attempt * 2) seconds."
        }
    }

    if ($null -eq $historyEntry -or -not $historyEntry.status.completed) {
        throw "Timed out waiting for ComfyUI to finish."
    }

    $images = Get-HistoryImages -HistoryEntry $historyEntry -OutputPath $Job.OutputPath
    if ($images.Count -eq 0) {
        throw "ComfyUI finished, but no output images were found in history."
    }

    [pscustomobject]@{
        PromptId = $promptId
        Images = @($images)
        Prompt = $Job.Prompt
        NegativePrompt = $Job.NegativePrompt
    }
}

function Assert-GeneratorConfig {
    param(
        [Parameter(Mandatory = $true)]$Config
    )

    if (-not (Test-Path -LiteralPath $WorkflowScriptPath -PathType Leaf)) {
        throw "Missing workflow helper script: $WorkflowScriptPath"
    }

    if ([string]::IsNullOrWhiteSpace([string]$Config.comfyUrl)) {
        throw "Config is missing comfyUrl."
    }

    if ([string]::IsNullOrWhiteSpace([string]$Config.comfyInputPath)) {
        throw "Config is missing comfyInputPath."
    }

    if ([string]::IsNullOrWhiteSpace([string]$Config.comfyOutputPath)) {
        throw "Config is missing comfyOutputPath."
    }

    if (-not (Test-Path -LiteralPath ([string]$Config.comfyOutputPath) -PathType Container)) {
        throw "ComfyUI output folder was not found: $($Config.comfyOutputPath)"
    }

    $characters = Get-ConfigArray -Value $Config.characters
    $poses = Get-ConfigArray -Value $Config.poses
    $scenes = Get-ConfigArray -Value $Config.scenes

    if ($characters.Count -eq 0) {
        throw "Config has no characters."
    }

    if ($poses.Count -eq 0) {
        throw "Config has no poses."
    }

    if ($scenes.Count -eq 0) {
        throw "Config has no scenes."
    }

    foreach ($character in $characters) {
        $markedReady = $false
        if ($null -ne $character.referenceReady) {
            $markedReady = [bool]$character.referenceReady
        }

        if ($markedReady -and -not (Test-CharacterReferenceReady -Character $character)) {
            throw "Character '$($character.name)' is marked referenceReady but is missing identityImageName or outfitImageName."
        }
    }

    foreach ($pose in $poses) {
        if ([string]::IsNullOrWhiteSpace([string]$pose.poseImageName)) {
            throw "Pose '$($pose.name)' is missing poseImageName."
        }
    }
}

$Config = Read-GeneratorConfig
Assert-GeneratorConfig -Config $Config
$script:SavesDoc = Read-GeneratorSaves

if ($ValidateOnly) {
    $characterCount = (Get-ConfigArray -Value $Config.characters).Count
    $poseCount = (Get-ConfigArray -Value $Config.poses).Count
    $sceneCount = (Get-ConfigArray -Value $Config.scenes).Count
    $saveCount = (Get-ConfigArray -Value $script:SavesDoc.saves).Count
    "Character generator config OK. Characters: $characterCount. Poses: $poseCount. Scenes: $sceneCount. Saved setups: $saveCount."
    return
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$Characters = Get-ConfigArray -Value $Config.characters
$Poses = Get-ConfigArray -Value $Config.poses
$Scenes = Get-ConfigArray -Value $Config.scenes

$form = New-Object System.Windows.Forms.Form
$form.Text = "Book Character Generator - ComfyUI"
$form.StartPosition = "CenterScreen"
$form.Size = New-Object System.Drawing.Size(1450, 980)
$form.MinimumSize = New-Object System.Drawing.Size(1320, 900)
$form.BackColor = [System.Drawing.Color]::FromArgb(245, 242, 236)
$form.Font = New-Object System.Drawing.Font("Segoe UI", 9)

$toolTip = New-Object System.Windows.Forms.ToolTip
$toolTip.AutoPopDelay = 20000
$toolTip.InitialDelay = 350
$toolTip.ReshowDelay = 100
$toolTip.ShowAlways = $true

$leftPanel = New-Object System.Windows.Forms.Panel
$leftPanel.Location = New-Object System.Drawing.Point(12, 12)
$leftPanel.Size = New-Object System.Drawing.Size(430, 920)
$leftPanel.Anchor = "Top,Bottom,Left"
$leftPanel.BackColor = [System.Drawing.Color]::FromArgb(255, 253, 248)
$leftPanel.BorderStyle = "FixedSingle"
$form.Controls.Add($leftPanel)

$rightPanel = New-Object System.Windows.Forms.Panel
$rightPanel.Location = New-Object System.Drawing.Point(454, 12)
$rightPanel.Size = New-Object System.Drawing.Size(964, 920)
$rightPanel.Anchor = "Top,Bottom,Left,Right"
$rightPanel.BackColor = [System.Drawing.Color]::FromArgb(255, 253, 248)
$rightPanel.BorderStyle = "FixedSingle"
$form.Controls.Add($rightPanel)

function New-UiLabel {
    param(
        [string]$Text,
        [int]$X,
        [int]$Y,
        [int]$Width = 380
    )

    $label = New-Object System.Windows.Forms.Label
    $label.Text = $Text
    $label.Location = New-Object System.Drawing.Point($X, $Y)
    $label.Size = New-Object System.Drawing.Size($Width, 18)
    $label.ForeColor = [System.Drawing.Color]::FromArgb(60, 52, 46)
    $label.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    return $label
}

function New-ComboBox {
    param(
        [int]$X,
        [int]$Y,
        [int]$Width = 380
    )

    $combo = New-Object System.Windows.Forms.ComboBox
    $combo.Location = New-Object System.Drawing.Point($X, $Y)
    $combo.Size = New-Object System.Drawing.Size($Width, 26)
    $combo.DropDownStyle = "DropDownList"
    return $combo
}

function New-Numeric {
    param(
        [int]$X,
        [int]$Y,
        [decimal]$Minimum,
        [decimal]$Maximum,
        [decimal]$Value,
        [decimal]$Increment = 1,
        [int]$DecimalPlaces = 0
    )

    $numeric = New-Object System.Windows.Forms.NumericUpDown
    $numeric.Location = New-Object System.Drawing.Point($X, $Y)
    $numeric.Size = New-Object System.Drawing.Size(80, 26)
    $numeric.Minimum = $Minimum
    $numeric.Maximum = $Maximum
    $numeric.Value = $Value
    $numeric.Increment = $Increment
    $numeric.DecimalPlaces = $DecimalPlaces
    return $numeric
}

$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Text = "Character Image Generator"
$titleLabel.Location = New-Object System.Drawing.Point(16, 14)
$titleLabel.Size = New-Object System.Drawing.Size(350, 28)
$titleLabel.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 15)
$titleLabel.ForeColor = [System.Drawing.Color]::FromArgb(32, 28, 24)
$leftPanel.Controls.Add($titleLabel)

$y = 54
$leftPanel.Controls.Add((New-UiLabel -Text "Character" -X 16 -Y $y))
$comboCharacter = New-ComboBox -X 16 -Y ($y + 20)
foreach ($character in $Characters) {
    [void]$comboCharacter.Items.Add((Get-CharacterDisplayName -Character $character))
}
$comboCharacter.SelectedIndex = 0
$leftPanel.Controls.Add($comboCharacter)

$y += 56
$leftPanel.Controls.Add((New-UiLabel -Text "Pose / Action Guide" -X 16 -Y $y))
$comboPose = New-ComboBox -X 16 -Y ($y + 20)
foreach ($pose in $Poses) {
    [void]$comboPose.Items.Add([string]$pose.name)
}
$comboPose.SelectedIndex = 0
$leftPanel.Controls.Add($comboPose)

$y += 56
$leftPanel.Controls.Add((New-UiLabel -Text "Scene / Background" -X 16 -Y $y))
$comboScene = New-ComboBox -X 16 -Y ($y + 20)
foreach ($scene in $Scenes) {
    [void]$comboScene.Items.Add([string]$scene.name)
}
$comboScene.SelectedIndex = 0
$leftPanel.Controls.Add($comboScene)

$y += 56
$leftPanel.Controls.Add((New-UiLabel -Text "What should happen in the image?" -X 16 -Y $y))
$txtPrompt = New-Object System.Windows.Forms.TextBox
$txtPrompt.Location = New-Object System.Drawing.Point(16, ($y + 20))
$txtPrompt.Size = New-Object System.Drawing.Size(380, 92)
$txtPrompt.Multiline = $true
$txtPrompt.ScrollBars = "Vertical"
$txtPrompt.Text = "She protects a frightened child while standing apart from the court, vulnerable but dignified."
$leftPanel.Controls.Add($txtPrompt)

$y += 120
$leftPanel.Controls.Add((New-UiLabel -Text "Extra negative prompt" -X 16 -Y $y))
$txtNegative = New-Object System.Windows.Forms.TextBox
$txtNegative.Location = New-Object System.Drawing.Point(16, ($y + 20))
$txtNegative.Size = New-Object System.Drawing.Size(380, 60)
$txtNegative.Multiline = $true
$txtNegative.ScrollBars = "Vertical"
$txtNegative.Text = ""
$leftPanel.Controls.Add($txtNegative)

$y += 86
$leftPanel.Controls.Add((New-UiLabel -Text "Image Settings" -X 16 -Y $y))

$labelBatch = New-Object System.Windows.Forms.Label
$labelBatch.Text = "Batch - count"
$labelBatch.Location = New-Object System.Drawing.Point(16, ($y + 26))
$labelBatch.Size = New-Object System.Drawing.Size(90, 20)
$leftPanel.Controls.Add($labelBatch)
$numBatch = New-Numeric -X 106 -Y ($y + 22) -Minimum 1 -Maximum 4 -Value ([decimal]$Config.defaults.batchSize)
$numBatch.Size = New-Object System.Drawing.Size(58, 26)
$leftPanel.Controls.Add($numBatch)
$toolTip.SetToolTip($labelBatch, "Batch (image count): + = more images each click, slower and uses more memory. - = fewer images, safer and faster.")
$toolTip.SetToolTip($numBatch, "Batch (image count): + = more images each click, slower and uses more memory. - = fewer images, safer and faster.")

$labelSteps = New-Object System.Windows.Forms.Label
$labelSteps.Text = "Steps - polish"
$labelSteps.Location = New-Object System.Drawing.Point(178, ($y + 26))
$labelSteps.Size = New-Object System.Drawing.Size(94, 20)
$leftPanel.Controls.Add($labelSteps)
$numSteps = New-Numeric -X 278 -Y ($y + 22) -Minimum 10 -Maximum 80 -Value ([decimal]$Config.defaults.steps)
$numSteps.Size = New-Object System.Drawing.Size(58, 26)
$leftPanel.Controls.Add($numSteps)
$toolTip.SetToolTip($labelSteps, "Steps (polish passes): + = more detail and cleanup, slower. - = faster, rougher, less refined.")
$toolTip.SetToolTip($numSteps, "Steps (polish passes): + = more detail and cleanup, slower. - = faster, rougher, less refined.")

$labelCfg = New-Object System.Windows.Forms.Label
$labelCfg.Text = "CFG - prompt"
$labelCfg.Location = New-Object System.Drawing.Point(16, ($y + 58))
$labelCfg.Size = New-Object System.Drawing.Size(90, 20)
$leftPanel.Controls.Add($labelCfg)
$numCfg = New-Numeric -X 106 -Y ($y + 54) -Minimum 1 -Maximum 12 -Value ([decimal]$Config.defaults.cfg) -Increment 0.1 -DecimalPlaces 1
$numCfg.Size = New-Object System.Drawing.Size(58, 26)
$leftPanel.Controls.Add($numCfg)
$toolTip.SetToolTip($labelCfg, "CFG (prompt force): + = tries harder to obey your prompt, but can get stiff or distorted. - = freer, softer, sometimes less exact.")
$toolTip.SetToolTip($numCfg, "CFG (prompt force): + = tries harder to obey your prompt, but can get stiff or distorted. - = freer, softer, sometimes less exact.")

$labelPoseStrength = New-Object System.Windows.Forms.Label
$labelPoseStrength.Text = "Pose - action"
$labelPoseStrength.Location = New-Object System.Drawing.Point(178, ($y + 58))
$labelPoseStrength.Size = New-Object System.Drawing.Size(94, 20)
$leftPanel.Controls.Add($labelPoseStrength)
$numPoseStrength = New-Numeric -X 278 -Y ($y + 54) -Minimum 0 -Maximum 1.5 -Value ([decimal]$Config.defaults.poseStrength) -Increment 0.05 -DecimalPlaces 2
$numPoseStrength.Size = New-Object System.Drawing.Size(58, 26)
$leftPanel.Controls.Add($numPoseStrength)
$toolTip.SetToolTip($labelPoseStrength, "Pose (action match): + = follows the selected pose guide more closely. - = lets the model improvise more.")
$toolTip.SetToolTip($numPoseStrength, "Pose (action match): + = follows the selected pose guide more closely. - = lets the model improvise more.")

$labelFace = New-Object System.Windows.Forms.Label
$labelFace.Text = "Face - match"
$labelFace.Location = New-Object System.Drawing.Point(16, ($y + 90))
$labelFace.Size = New-Object System.Drawing.Size(90, 20)
$leftPanel.Controls.Add($labelFace)
$numFace = New-Numeric -X 106 -Y ($y + 86) -Minimum 0 -Maximum 1.5 -Value ([decimal]$Config.defaults.faceWeight) -Increment 0.05 -DecimalPlaces 2
$numFace.Size = New-Object System.Drawing.Size(58, 26)
$leftPanel.Controls.Add($numFace)
$toolTip.SetToolTip($labelFace, "Face (identity match): + = closer to the face reference, but can fight the scene. - = more flexible, less exact.")
$toolTip.SetToolTip($numFace, "Face (identity match): + = closer to the face reference, but can fight the scene. - = more flexible, less exact.")

$labelOutfit = New-Object System.Windows.Forms.Label
$labelOutfit.Text = "Outfit - clothes"
$labelOutfit.Location = New-Object System.Drawing.Point(178, ($y + 90))
$labelOutfit.Size = New-Object System.Drawing.Size(94, 20)
$leftPanel.Controls.Add($labelOutfit)
$numOutfit = New-Numeric -X 278 -Y ($y + 86) -Minimum 0 -Maximum 1.5 -Value ([decimal]$Config.defaults.outfitWeight) -Increment 0.05 -DecimalPlaces 2
$numOutfit.Size = New-Object System.Drawing.Size(58, 26)
$leftPanel.Controls.Add($numOutfit)
$toolTip.SetToolTip($labelOutfit, "Outfit (clothing match): + = keeps clothing closer to the reference. - = allows more costume and scene change.")
$toolTip.SetToolTip($numOutfit, "Outfit (clothing match): + = keeps clothing closer to the reference. - = allows more costume and scene change.")

$y += 124
$leftPanel.Controls.Add((New-UiLabel -Text "Consistency" -X 16 -Y $y))

$comboGenerationMode = New-ComboBox -X 16 -Y ($y + 20) -Width 380
[void]$comboGenerationMode.Items.Add("Strict Character Lock")
[void]$comboGenerationMode.Items.Add("Balanced")
[void]$comboGenerationMode.Items.Add("Prompt Freedom")
[void]$comboGenerationMode.Items.Add("Base Layer Clothing Design")
$comboGenerationMode.SelectedIndex = 0
$leftPanel.Controls.Add($comboGenerationMode)
$toolTip.SetToolTip($comboGenerationMode, "Strict keeps the selected character closest. Prompt Freedom allows larger clothing/style changes. Base Layer creates a safe clothing-design base layer.")

$chkLockSeed = New-Object System.Windows.Forms.CheckBox
$chkLockSeed.Text = "Seed - repeat"
$chkLockSeed.Location = New-Object System.Drawing.Point(16, ($y + 54))
$chkLockSeed.Size = New-Object System.Drawing.Size(112, 24)
$chkLockSeed.Checked = $true
$leftPanel.Controls.Add($chkLockSeed)
$toolTip.SetToolTip($chkLockSeed, "Checked = same prompt and settings can repeat the same image path. Unchecked = fresh random seed each run.")

$numSeed = New-Numeric -X 132 -Y ($y + 52) -Minimum 1 -Maximum 2147483647 -Value 1000001 -Increment 1 -DecimalPlaces 0
$numSeed.Size = New-Object System.Drawing.Size(142, 26)
$leftPanel.Controls.Add($numSeed)
$toolTip.SetToolTip($numSeed, "Seed (repeat number): keep this fixed for repeatable output. Change it to explore a new variation while keeping character settings.")

$btnCharacterSeed = New-Object System.Windows.Forms.Button
$btnCharacterSeed.Text = "Use Character Seed"
$btnCharacterSeed.Location = New-Object System.Drawing.Point(282, ($y + 50))
$btnCharacterSeed.Size = New-Object System.Drawing.Size(114, 30)
$leftPanel.Controls.Add($btnCharacterSeed)
$toolTip.SetToolTip($btnCharacterSeed, "Loads a stable seed based on the selected character.")

$y += 92
$leftPanel.Controls.Add((New-UiLabel -Text "Filename prefix" -X 16 -Y $y))
$txtPrefix = New-Object System.Windows.Forms.TextBox
$txtPrefix.Location = New-Object System.Drawing.Point(16, ($y + 20))
$txtPrefix.Size = New-Object System.Drawing.Size(380, 24)
$txtPrefix.Text = [string]$Config.defaults.prefix
$leftPanel.Controls.Add($txtPrefix)

$y += 58
$btnGenerate = New-Object System.Windows.Forms.Button
$btnGenerate.Text = "Generate"
$btnGenerate.Location = New-Object System.Drawing.Point(16, $y)
$btnGenerate.Size = New-Object System.Drawing.Size(108, 34)
$btnGenerate.BackColor = [System.Drawing.Color]::FromArgb(77, 92, 78)
$btnGenerate.ForeColor = [System.Drawing.Color]::White
$leftPanel.Controls.Add($btnGenerate)

$btnOpenComfy = New-Object System.Windows.Forms.Button
$btnOpenComfy.Text = "Open ComfyUI"
$btnOpenComfy.Location = New-Object System.Drawing.Point(132, $y)
$btnOpenComfy.Size = New-Object System.Drawing.Size(108, 34)
$leftPanel.Controls.Add($btnOpenComfy)

$btnOpenOutput = New-Object System.Windows.Forms.Button
$btnOpenOutput.Text = "Output Folder"
$btnOpenOutput.Location = New-Object System.Drawing.Point(248, $y)
$btnOpenOutput.Size = New-Object System.Drawing.Size(108, 34)
$leftPanel.Controls.Add($btnOpenOutput)

$y += 42
$btnOpenConfig = New-Object System.Windows.Forms.Button
$btnOpenConfig.Text = "Edit Config"
$btnOpenConfig.Location = New-Object System.Drawing.Point(16, $y)
$btnOpenConfig.Size = New-Object System.Drawing.Size(108, 30)
$leftPanel.Controls.Add($btnOpenConfig)

$btnRefreshConfig = New-Object System.Windows.Forms.Button
$btnRefreshConfig.Text = "Refresh"
$btnRefreshConfig.Location = New-Object System.Drawing.Point(132, $y)
$btnRefreshConfig.Size = New-Object System.Drawing.Size(108, 30)
$leftPanel.Controls.Add($btnRefreshConfig)

$btnSync = New-Object System.Windows.Forms.Button
$btnSync.Text = "Sync Inputs"
$btnSync.Location = New-Object System.Drawing.Point(248, $y)
$btnSync.Size = New-Object System.Drawing.Size(108, 30)
$leftPanel.Controls.Add($btnSync)

$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Location = New-Object System.Drawing.Point(16, 870)
$statusLabel.Size = New-Object System.Drawing.Size(380, 36)
$statusLabel.Anchor = "Left,Right,Bottom"
$statusLabel.Text = "Ready. Choose a character, pose, scene, and prompt."
$statusLabel.ForeColor = [System.Drawing.Color]::FromArgb(64, 58, 52)
$leftPanel.Controls.Add($statusLabel)

$previewTitle = New-Object System.Windows.Forms.Label
$previewTitle.Text = "Latest Output"
$previewTitle.Location = New-Object System.Drawing.Point(16, 14)
$previewTitle.Size = New-Object System.Drawing.Size(220, 28)
$previewTitle.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 15)
$previewTitle.ForeColor = [System.Drawing.Color]::FromArgb(32, 28, 24)
$rightPanel.Controls.Add($previewTitle)

$pictureBox = New-Object System.Windows.Forms.PictureBox
$pictureBox.Location = New-Object System.Drawing.Point(16, 50)
$pictureBox.Size = New-Object System.Drawing.Size(560, 560)
$pictureBox.Anchor = "Top,Left"
$pictureBox.BorderStyle = "FixedSingle"
$pictureBox.SizeMode = "Zoom"
$pictureBox.BackColor = [System.Drawing.Color]::FromArgb(34, 31, 28)
$rightPanel.Controls.Add($pictureBox)

$outputsTitle = New-Object System.Windows.Forms.Label
$outputsTitle.Text = "Generated Files"
$outputsTitle.Location = New-Object System.Drawing.Point(16, 620)
$outputsTitle.Size = New-Object System.Drawing.Size(220, 18)
$outputsTitle.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$outputsTitle.ForeColor = [System.Drawing.Color]::FromArgb(60, 52, 46)
$rightPanel.Controls.Add($outputsTitle)

$listOutputs = New-Object System.Windows.Forms.ListBox
$listOutputs.Location = New-Object System.Drawing.Point(16, 642)
$listOutputs.Size = New-Object System.Drawing.Size(560, 56)
$listOutputs.Anchor = "Left,Bottom"
$listOutputs.HorizontalScrollbar = $true
$rightPanel.Controls.Add($listOutputs)

$savedTitle = New-Object System.Windows.Forms.Label
$savedTitle.Text = "Saved Setup"
$savedTitle.Location = New-Object System.Drawing.Point(600, 14)
$savedTitle.Size = New-Object System.Drawing.Size(330, 22)
$savedTitle.Anchor = "Top,Right"
$savedTitle.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$savedTitle.ForeColor = [System.Drawing.Color]::FromArgb(60, 52, 46)
$rightPanel.Controls.Add($savedTitle)

$comboSavedSetup = New-ComboBox -X 600 -Y 38 -Width 330
$comboSavedSetup.Anchor = "Top,Right"
$rightPanel.Controls.Add($comboSavedSetup)
$toolTip.SetToolTip($comboSavedSetup, "Saved setups are filtered to the selected character. Pick New setup to start a fresh one.")

$saveNameLabel = New-Object System.Windows.Forms.Label
$saveNameLabel.Text = "Save name / append"
$saveNameLabel.Location = New-Object System.Drawing.Point(600, 70)
$saveNameLabel.Size = New-Object System.Drawing.Size(330, 18)
$saveNameLabel.Anchor = "Top,Right"
$saveNameLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$saveNameLabel.ForeColor = [System.Drawing.Color]::FromArgb(60, 52, 46)
$rightPanel.Controls.Add($saveNameLabel)

$txtSaveName = New-Object System.Windows.Forms.TextBox
$txtSaveName.Location = New-Object System.Drawing.Point(600, 90)
$txtSaveName.Size = New-Object System.Drawing.Size(330, 24)
$txtSaveName.Anchor = "Top,Right"
$rightPanel.Controls.Add($txtSaveName)
$toolTip.SetToolTip($txtSaveName, "Auto-filled from character, pose, and scene. You can add your own words here before saving.")

$btnSaveNew = New-Object System.Windows.Forms.Button
$btnSaveNew.Text = "Save New"
$btnSaveNew.Location = New-Object System.Drawing.Point(600, 122)
$btnSaveNew.Size = New-Object System.Drawing.Size(158, 30)
$btnSaveNew.Anchor = "Top,Right"
$rightPanel.Controls.Add($btnSaveNew)

$btnUpdateSave = New-Object System.Windows.Forms.Button
$btnUpdateSave.Text = "Update"
$btnUpdateSave.Location = New-Object System.Drawing.Point(772, 122)
$btnUpdateSave.Size = New-Object System.Drawing.Size(158, 30)
$btnUpdateSave.Anchor = "Top,Right"
$rightPanel.Controls.Add($btnUpdateSave)

$savedHelp = New-Object System.Windows.Forms.Label
$savedHelp.Text = "Dropdown loads saved prompt, negative, pose, scene, settings, and LoRA stack."
$savedHelp.Location = New-Object System.Drawing.Point(600, 158)
$savedHelp.Size = New-Object System.Drawing.Size(330, 34)
$savedHelp.Anchor = "Top,Right"
$savedHelp.ForeColor = [System.Drawing.Color]::FromArgb(80, 72, 64)
$rightPanel.Controls.Add($savedHelp)

$guidesTitle = New-Object System.Windows.Forms.Label
$guidesTitle.Text = "Reference / Guides"
$guidesTitle.Location = New-Object System.Drawing.Point(600, 204)
$guidesTitle.Size = New-Object System.Drawing.Size(330, 18)
$guidesTitle.Anchor = "Top,Right"
$guidesTitle.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$guidesTitle.ForeColor = [System.Drawing.Color]::FromArgb(60, 52, 46)
$rightPanel.Controls.Add($guidesTitle)

$guideProfileLabel = New-Object System.Windows.Forms.Label
$guideProfileLabel.Text = "Guide mode"
$guideProfileLabel.Location = New-Object System.Drawing.Point(600, 226)
$guideProfileLabel.Size = New-Object System.Drawing.Size(330, 18)
$guideProfileLabel.Anchor = "Top,Right"
$guideProfileLabel.ForeColor = [System.Drawing.Color]::FromArgb(60, 52, 46)
$rightPanel.Controls.Add($guideProfileLabel)

$comboGuideProfile = New-ComboBox -X 600 -Y 246 -Width 330
$comboGuideProfile.Anchor = "Top,Right"
[void]$comboGuideProfile.Items.Add("Reference only")
[void]$comboGuideProfile.Items.Add("Female guides")
[void]$comboGuideProfile.Items.Add("Male guides")
[void]$comboGuideProfile.Items.Add("Auto guides")
$comboGuideProfile.SelectedIndex = 0
$rightPanel.Controls.Add($comboGuideProfile)
$toolTip.SetToolTip($comboGuideProfile, "Reference only uses the locked character image and does not apply hair, chest, or facial-hair chart prompts. Use guide modes only when you want those charts to alter the result.")

$guideHairLabel = New-Object System.Windows.Forms.Label
$guideHairLabel.Text = "Hair chart code"
$guideHairLabel.Location = New-Object System.Drawing.Point(600, 278)
$guideHairLabel.Size = New-Object System.Drawing.Size(330, 18)
$guideHairLabel.Anchor = "Top,Right"
$guideHairLabel.ForeColor = [System.Drawing.Color]::FromArgb(60, 52, 46)
$rightPanel.Controls.Add($guideHairLabel)

$comboGuideHair = New-ComboBox -X 600 -Y 298 -Width 330
$comboGuideHair.Anchor = "Top,Right"
[void]$comboGuideHair.Items.Add("None")
$comboGuideHair.SelectedIndex = 0
$rightPanel.Controls.Add($comboGuideHair)
$toolTip.SetToolTip($comboGuideHair, "Use the style number from the shared hair chart. Female profile uses the female hair guide, male profile uses the male hair guide.")

$guideChestLabel = New-Object System.Windows.Forms.Label
$guideChestLabel.Text = "Chest / bust chart"
$guideChestLabel.Location = New-Object System.Drawing.Point(600, 330)
$guideChestLabel.Size = New-Object System.Drawing.Size(330, 18)
$guideChestLabel.Anchor = "Top,Right"
$guideChestLabel.ForeColor = [System.Drawing.Color]::FromArgb(60, 52, 46)
$rightPanel.Controls.Add($guideChestLabel)

$trackGuideChest = New-Object System.Windows.Forms.TrackBar
$trackGuideChest.Location = New-Object System.Drawing.Point(600, 350)
$trackGuideChest.Size = New-Object System.Drawing.Size(330, 32)
$trackGuideChest.Anchor = "Top,Right"
$trackGuideChest.Minimum = 0
$trackGuideChest.Maximum = 10
$trackGuideChest.TickStyle = "None"
$trackGuideChest.SmallChange = 1
$trackGuideChest.LargeChange = 1
$trackGuideChest.Value = 0
$rightPanel.Controls.Add($trackGuideChest)
$toolTip.SetToolTip($trackGuideChest, "Female chest chart selector. 0 means no shared chest guide. Higher values follow the shared female size chart.")

$labelGuideChestValue = New-Object System.Windows.Forms.Label
$labelGuideChestValue.Location = New-Object System.Drawing.Point(600, 376)
$labelGuideChestValue.Size = New-Object System.Drawing.Size(330, 20)
$labelGuideChestValue.Anchor = "Top,Right"
$labelGuideChestValue.ForeColor = [System.Drawing.Color]::FromArgb(80, 72, 64)
$labelGuideChestValue.Text = "None"
$rightPanel.Controls.Add($labelGuideChestValue)

$guideFacialHairLabel = New-Object System.Windows.Forms.Label
$guideFacialHairLabel.Text = "Facial hair code"
$guideFacialHairLabel.Location = New-Object System.Drawing.Point(600, 330)
$guideFacialHairLabel.Size = New-Object System.Drawing.Size(330, 18)
$guideFacialHairLabel.Anchor = "Top,Right"
$guideFacialHairLabel.ForeColor = [System.Drawing.Color]::FromArgb(60, 52, 46)
$rightPanel.Controls.Add($guideFacialHairLabel)

$comboGuideFacialHair = New-ComboBox -X 600 -Y 350 -Width 330
$comboGuideFacialHair.Anchor = "Top,Right"
[void]$comboGuideFacialHair.Items.Add("None")
$comboGuideFacialHair.SelectedIndex = 0
$rightPanel.Controls.Add($comboGuideFacialHair)
$toolTip.SetToolTip($comboGuideFacialHair, "Use the code from the male facial hair guide, like C2, S4, M3, or F6.")

$guideHelp = New-Object System.Windows.Forms.Label
$guideHelp.Location = New-Object System.Drawing.Point(600, 404)
$guideHelp.Size = New-Object System.Drawing.Size(330, 40)
$guideHelp.Anchor = "Top,Right"
$guideHelp.ForeColor = [System.Drawing.Color]::FromArgb(80, 72, 64)
$guideHelp.Text = "Guide codes follow your shared chart images."
$rightPanel.Controls.Add($guideHelp)

$guidePreviewTitle = New-Object System.Windows.Forms.Label
$guidePreviewTitle.Text = "Live Guide Previews"
$guidePreviewTitle.Location = New-Object System.Drawing.Point(600, 452)
$guidePreviewTitle.Size = New-Object System.Drawing.Size(330, 18)
$guidePreviewTitle.Anchor = "Top,Right"
$guidePreviewTitle.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$guidePreviewTitle.ForeColor = [System.Drawing.Color]::FromArgb(60, 52, 46)
$rightPanel.Controls.Add($guidePreviewTitle)

$guidePreviewPrimaryLabel = New-Object System.Windows.Forms.Label
$guidePreviewPrimaryLabel.Text = "Hair preview"
$guidePreviewPrimaryLabel.Location = New-Object System.Drawing.Point(600, 474)
$guidePreviewPrimaryLabel.Size = New-Object System.Drawing.Size(158, 18)
$guidePreviewPrimaryLabel.Anchor = "Top,Right"
$guidePreviewPrimaryLabel.ForeColor = [System.Drawing.Color]::FromArgb(60, 52, 46)
$rightPanel.Controls.Add($guidePreviewPrimaryLabel)

$guidePreviewSecondaryLabel = New-Object System.Windows.Forms.Label
$guidePreviewSecondaryLabel.Text = "Shared preview"
$guidePreviewSecondaryLabel.Location = New-Object System.Drawing.Point(772, 474)
$guidePreviewSecondaryLabel.Size = New-Object System.Drawing.Size(158, 18)
$guidePreviewSecondaryLabel.Anchor = "Top,Right"
$guidePreviewSecondaryLabel.ForeColor = [System.Drawing.Color]::FromArgb(60, 52, 46)
$rightPanel.Controls.Add($guidePreviewSecondaryLabel)

$guidePreviewPrimaryBox = New-Object System.Windows.Forms.PictureBox
$guidePreviewPrimaryBox.Location = New-Object System.Drawing.Point(600, 496)
$guidePreviewPrimaryBox.Size = New-Object System.Drawing.Size(158, 158)
$guidePreviewPrimaryBox.Anchor = "Top,Right"
$guidePreviewPrimaryBox.BorderStyle = "FixedSingle"
$guidePreviewPrimaryBox.SizeMode = "Zoom"
$guidePreviewPrimaryBox.BackColor = [System.Drawing.Color]::FromArgb(34, 31, 28)
$rightPanel.Controls.Add($guidePreviewPrimaryBox)

$guidePreviewSecondaryBox = New-Object System.Windows.Forms.PictureBox
$guidePreviewSecondaryBox.Location = New-Object System.Drawing.Point(772, 496)
$guidePreviewSecondaryBox.Size = New-Object System.Drawing.Size(158, 158)
$guidePreviewSecondaryBox.Anchor = "Top,Right"
$guidePreviewSecondaryBox.BorderStyle = "FixedSingle"
$guidePreviewSecondaryBox.SizeMode = "Zoom"
$guidePreviewSecondaryBox.BackColor = [System.Drawing.Color]::FromArgb(34, 31, 28)
$rightPanel.Controls.Add($guidePreviewSecondaryBox)

$loraTitle = New-Object System.Windows.Forms.Label
$loraTitle.Text = "LoRA Stack"
$loraTitle.Location = New-Object System.Drawing.Point(600, 664)
$loraTitle.Size = New-Object System.Drawing.Size(330, 18)
$loraTitle.Anchor = "Top,Right"
$loraTitle.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$loraTitle.ForeColor = [System.Drawing.Color]::FromArgb(60, 52, 46)
$rightPanel.Controls.Add($loraTitle)

$loraHelp = New-Object System.Windows.Forms.Label
$loraHelp.Text = "Layer repeatable identity, changeable clothing, realm style, and cleanup."
$loraHelp.Location = New-Object System.Drawing.Point(600, 684)
$loraHelp.Size = New-Object System.Drawing.Size(330, 30)
$loraHelp.Anchor = "Top,Right"
$loraHelp.ForeColor = [System.Drawing.Color]::FromArgb(80, 72, 64)
$rightPanel.Controls.Add($loraHelp)

$labelIdentityLora = New-Object System.Windows.Forms.Label
$labelIdentityLora.Text = "Identity"
$labelIdentityLora.Location = New-Object System.Drawing.Point(600, 720)
$labelIdentityLora.Size = New-Object System.Drawing.Size(70, 20)
$labelIdentityLora.Anchor = "Top,Right"
$rightPanel.Controls.Add($labelIdentityLora)
$comboIdentityLora = New-ComboBox -X 672 -Y 716 -Width 184
$comboIdentityLora.Anchor = "Top,Right"
$rightPanel.Controls.Add($comboIdentityLora)
$numIdentityLora = New-Numeric -X 864 -Y 716 -Minimum 0 -Maximum 1.5 -Value 0.8 -Increment 0.05 -DecimalPlaces 2
$numIdentityLora.Size = New-Object System.Drawing.Size(66, 26)
$numIdentityLora.Anchor = "Top,Right"
$rightPanel.Controls.Add($numIdentityLora)
$toolTip.SetToolTip($comboIdentityLora, "Identity LoRA: trained for one character. Use this to keep the same person across poses and scenes.")
$toolTip.SetToolTip($numIdentityLora, "Identity strength: + = more exact same person, but can resist pose/clothing changes. - = more flexible, less locked.")

$labelClothingLora = New-Object System.Windows.Forms.Label
$labelClothingLora.Text = "Clothing"
$labelClothingLora.Location = New-Object System.Drawing.Point(600, 752)
$labelClothingLora.Size = New-Object System.Drawing.Size(70, 20)
$labelClothingLora.Anchor = "Top,Right"
$rightPanel.Controls.Add($labelClothingLora)
$comboClothingLora = New-ComboBox -X 672 -Y 748 -Width 184
$comboClothingLora.Anchor = "Top,Right"
$rightPanel.Controls.Add($comboClothingLora)
$numClothingLora = New-Numeric -X 864 -Y 748 -Minimum 0 -Maximum 1.5 -Value 0.7 -Increment 0.05 -DecimalPlaces 2
$numClothingLora.Size = New-Object System.Drawing.Size(66, 26)
$numClothingLora.Anchor = "Top,Right"
$rightPanel.Controls.Add($numClothingLora)
$toolTip.SetToolTip($comboClothingLora, "Clothing LoRA: trained for a clothing set, armor, robe, dress, or reusable design piece.")
$toolTip.SetToolTip($numClothingLora, "Clothing strength: + = keeps that clothing/piece more strongly. - = lets prompt and outfit reference change it.")

$labelRealmLora = New-Object System.Windows.Forms.Label
$labelRealmLora.Text = "Realm"
$labelRealmLora.Location = New-Object System.Drawing.Point(600, 784)
$labelRealmLora.Size = New-Object System.Drawing.Size(70, 20)
$labelRealmLora.Anchor = "Top,Right"
$rightPanel.Controls.Add($labelRealmLora)
$comboRealmLora = New-ComboBox -X 672 -Y 780 -Width 184
$comboRealmLora.Anchor = "Top,Right"
$rightPanel.Controls.Add($comboRealmLora)
$numRealmLora = New-Numeric -X 864 -Y 780 -Minimum 0 -Maximum 1.5 -Value 0.5 -Increment 0.05 -DecimalPlaces 2
$numRealmLora.Size = New-Object System.Drawing.Size(66, 26)
$numRealmLora.Anchor = "Top,Right"
$rightPanel.Controls.Add($numRealmLora)
$toolTip.SetToolTip($comboRealmLora, "Realm/style LoRA: map, kingdom, architecture, faction, or visual-world style.")
$toolTip.SetToolTip($numRealmLora, "Realm strength: + = stronger kingdom/style flavor. - = lets the scene prompt dominate.")

$labelQualityLora = New-Object System.Windows.Forms.Label
$labelQualityLora.Text = "Quality"
$labelQualityLora.Location = New-Object System.Drawing.Point(600, 816)
$labelQualityLora.Size = New-Object System.Drawing.Size(70, 20)
$labelQualityLora.Anchor = "Top,Right"
$rightPanel.Controls.Add($labelQualityLora)
$comboQualityLora = New-ComboBox -X 672 -Y 812 -Width 184
$comboQualityLora.Anchor = "Top,Right"
$rightPanel.Controls.Add($comboQualityLora)
$numQualityLora = New-Numeric -X 864 -Y 812 -Minimum 0 -Maximum 1.5 -Value 0.35 -Increment 0.05 -DecimalPlaces 2
$numQualityLora.Size = New-Object System.Drawing.Size(66, 26)
$numQualityLora.Anchor = "Top,Right"
$rightPanel.Controls.Add($numQualityLora)
$toolTip.SetToolTip($comboQualityLora, "Quality/anatomy LoRA: use for realism, hands, anatomy cleanup, or general polish helpers.")
$toolTip.SetToolTip($numQualityLora, "Quality strength: + = stronger cleanup/style. Too high can overpower the character.")

$adjustmentHelp = New-Object System.Windows.Forms.Label
$adjustmentHelp.Location = New-Object System.Drawing.Point(16, 882)
$adjustmentHelp.Size = New-Object System.Drawing.Size(560, 36)
$adjustmentHelp.Anchor = "Left,Bottom"
$adjustmentHelp.ForeColor = [System.Drawing.Color]::FromArgb(64, 58, 52)
$adjustmentHelp.Text = "Adjustment quick guide: Batch=count (+ more images/run, - fewer/faster). Steps=polish (+ cleaner/slower, - rougher/faster). CFG=prompt force (+ obey prompt more, - freer/softer).`r`nPose=action match (+ follow guide, - improvise). Face=identity match (+ closer face, - flexible). Outfit=clothing match (+ closer clothes, - flexible). LoRA strength + = stronger layer."
$rightPanel.Controls.Add($adjustmentHelp)

$logBox = New-Object System.Windows.Forms.TextBox
$logBox.Location = New-Object System.Drawing.Point(16, 706)
$logBox.Size = New-Object System.Drawing.Size(560, 170)
$logBox.Anchor = "Left,Bottom"
$logBox.Multiline = $true
$logBox.ReadOnly = $true
$logBox.ScrollBars = "Vertical"
$logBox.BackColor = [System.Drawing.Color]::FromArgb(34, 31, 28)
$logBox.ForeColor = [System.Drawing.Color]::FromArgb(236, 230, 220)
$rightPanel.Controls.Add($logBox)

function Add-Log {
    param(
        [string]$Message
    )

    $line = "[{0}] {1}" -f (Get-Date -Format "HH:mm:ss"), $Message
    $statusLabel.Text = $Message
    $logBox.AppendText($line + [Environment]::NewLine)
}

function Set-PreviewImage {
    param(
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return
    }

    Clear-PictureBoxImage -PictureBox $pictureBox

    $bytes = [System.IO.File]::ReadAllBytes($Path)
    $stream = New-Object System.IO.MemoryStream(,$bytes)
    $sourceImage = [System.Drawing.Image]::FromStream($stream)
    $bitmap = New-Object System.Drawing.Bitmap($sourceImage)
    $sourceImage.Dispose()
    $stream.Dispose()
    $pictureBox.Image = $bitmap
}

function Clear-PictureBoxImage {
    param(
        [Parameter(Mandatory = $true)]$PictureBox
    )

    if ($null -ne $PictureBox.Image) {
        $oldImage = $PictureBox.Image
        $PictureBox.Image = $null
        $oldImage.Dispose()
    }
}

function Set-PictureBoxBitmap {
    param(
        [Parameter(Mandatory = $true)]$PictureBox,
        [System.Drawing.Image]$Image
    )

    Clear-PictureBoxImage -PictureBox $PictureBox

    if ($null -eq $Image) {
        return
    }

    $PictureBox.Image = New-Object System.Drawing.Bitmap($Image)
}

function Get-GuideEntryPreviewBitmap {
    param(
        $Entry
    )

    if ($null -eq $Entry -or [string]::IsNullOrWhiteSpace([string]$Entry.SourcePath) -or -not (Test-Path -LiteralPath ([string]$Entry.SourcePath) -PathType Leaf)) {
        return $null
    }

    $sourceImage = $null
    $cropBitmap = $null
    $cropGraphics = $null

    try {
        $sourceImage = [System.Drawing.Bitmap]::FromFile([string]$Entry.SourcePath)
        $cropBitmap = New-Object System.Drawing.Bitmap($Entry.Rect.Width, $Entry.Rect.Height)
        $cropGraphics = [System.Drawing.Graphics]::FromImage($cropBitmap)
        $cropGraphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $cropGraphics.DrawImage($sourceImage, (New-Object System.Drawing.Rectangle -ArgumentList 0, 0, $cropBitmap.Width, $cropBitmap.Height), $Entry.Rect, [System.Drawing.GraphicsUnit]::Pixel)
        return $cropBitmap
    }
    finally {
        if ($null -ne $cropGraphics) {
            $cropGraphics.Dispose()
        }
        if ($null -ne $sourceImage) {
            $sourceImage.Dispose()
        }
    }
}

function Set-ComboSelectionById {
    param(
        [Parameter(Mandatory = $true)]$Combo,
        [Parameter(Mandatory = $true)]$Items,
        [string]$Id
    )

    if ([string]::IsNullOrWhiteSpace($Id)) {
        return
    }

    for ($index = 0; $index -lt $Items.Count; $index++) {
        if ([string]$Items[$index].id -eq $Id) {
            $Combo.SelectedIndex = $index
            return
        }
    }
}

function Set-NumericControlValue {
    param(
        [Parameter(Mandatory = $true)]$Control,
        $Value
    )

    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) {
        return
    }

    $decimalValue = [decimal]$Value
    if ($decimalValue -lt $Control.Minimum) {
        $decimalValue = $Control.Minimum
    }
    elseif ($decimalValue -gt $Control.Maximum) {
        $decimalValue = $Control.Maximum
    }

    $Control.Value = $decimalValue
}

function Apply-CharacterDefaults {
    param(
        [Parameter(Mandatory = $true)]$Character
    )

    if ($null -ne $Character.PSObject.Properties["defaultSteps"]) {
        Set-NumericControlValue -Control $numSteps -Value $Character.defaultSteps
    }

    if ($null -ne $Character.PSObject.Properties["defaultCfg"]) {
        Set-NumericControlValue -Control $numCfg -Value $Character.defaultCfg
    }

    if ($null -ne $Character.PSObject.Properties["defaultFaceWeight"]) {
        Set-NumericControlValue -Control $numFace -Value $Character.defaultFaceWeight
    }

    if ($null -ne $Character.PSObject.Properties["defaultOutfitWeight"]) {
        Set-NumericControlValue -Control $numOutfit -Value $Character.defaultOutfitWeight
    }

    if ($null -ne $Character.PSObject.Properties["defaultPoseStrength"]) {
        Set-NumericControlValue -Control $numPoseStrength -Value $Character.defaultPoseStrength
    }

    if ($null -ne $Character.PSObject.Properties["defaultGenerationMode"] -and -not [string]::IsNullOrWhiteSpace([string]$Character.defaultGenerationMode)) {
        Set-ComboSelectionByText -Combo $comboGenerationMode -Text ([string]$Character.defaultGenerationMode)
    }
    else {
        Set-ComboSelectionByText -Combo $comboGenerationMode -Text "Strict Character Lock"
    }

    $defaultGuideProfile = "Reference only"
    if ($null -ne $Character.PSObject.Properties["defaultGuideProfileSelection"] -and -not [string]::IsNullOrWhiteSpace([string]$Character.defaultGuideProfileSelection)) {
        $defaultGuideProfile = [string]$Character.defaultGuideProfileSelection
    }
    Set-ComboSelectionByText -Combo $comboGuideProfile -Text $defaultGuideProfile

    $identityLoraName = if ($null -ne $Character.PSObject.Properties["identityLoraName"]) { [string]$Character.identityLoraName } else { "" }
    $clothingLoraName = if ($null -ne $Character.PSObject.Properties["clothingLoraName"]) { [string]$Character.clothingLoraName } else { "" }
    $realmLoraName = if ($null -ne $Character.PSObject.Properties["realmLoraName"]) { [string]$Character.realmLoraName } else { "" }
    $qualityLoraName = if ($null -ne $Character.PSObject.Properties["qualityLoraName"]) { [string]$Character.qualityLoraName } else { "" }
    Refresh-LoraDropdownItems -Character $Character -PreferredIdentity $identityLoraName -PreferredClothing $clothingLoraName -PreferredRealm $realmLoraName -PreferredQuality $qualityLoraName

    Set-NumericControlValue -Control $numIdentityLora -Value $(if ($null -ne $Character.PSObject.Properties["identityLoraStrength"]) { $Character.identityLoraStrength } else { 0.8 })
    Set-NumericControlValue -Control $numClothingLora -Value $(if ($null -ne $Character.PSObject.Properties["clothingLoraStrength"]) { $Character.clothingLoraStrength } else { 0.7 })
    Set-NumericControlValue -Control $numRealmLora -Value $(if ($null -ne $Character.PSObject.Properties["realmLoraStrength"]) { $Character.realmLoraStrength } else { 0.5 })
    Set-NumericControlValue -Control $numQualityLora -Value $(if ($null -ne $Character.PSObject.Properties["qualityLoraStrength"]) { $Character.qualityLoraStrength } else { 0.35 })

    Set-NumericControlValue -Control $numSeed -Value (Get-StableCharacterSeed -Character $Character)
    $chkLockSeed.Checked = $true
}

function Update-ChestGuideValueLabel {
    $labels = Get-FemaleChestLabels
    $index = [int]$trackGuideChest.Value
    if ($index -ge 0 -and $index -lt $labels.Count) {
        $labelGuideChestValue.Text = $labels[$index]
    }
    else {
        $labelGuideChestValue.Text = "None"
    }
}

function Refresh-GuideControls {
    param(
        [Parameter(Mandatory = $true)]$Character,
        [string]$PreferredHairCode,
        [string]$PreferredFacialHairCode,
        [Nullable[int]]$PreferredChestIndex
    )

    $profileSelection = [string]$comboGuideProfile.SelectedItem
    if ([string]::IsNullOrWhiteSpace($profileSelection)) {
        $profileSelection = "Reference only"
    }

    $effectiveProfile = Get-EffectiveGuideProfile -Character $Character -ProfileSelection $profileSelection

    $currentHairCode = if (-not [string]::IsNullOrWhiteSpace($PreferredHairCode)) { $PreferredHairCode } else { [string]$comboGuideHair.SelectedItem }
    $hairItems = Get-SharedHairItems -EffectiveProfile $effectiveProfile
    $comboGuideHair.Items.Clear()
    foreach ($item in $hairItems) {
        [void]$comboGuideHair.Items.Add($item)
    }
    Set-ComboSelectionByText -Combo $comboGuideHair -Text $currentHairCode
    $showHairGuide = ($effectiveProfile -eq "female" -or $effectiveProfile -eq "male")
    $guideHairLabel.Visible = $showHairGuide
    $comboGuideHair.Visible = $showHairGuide
    $comboGuideHair.Enabled = $showHairGuide

    $currentFacialHairCode = if (-not [string]::IsNullOrWhiteSpace($PreferredFacialHairCode)) { $PreferredFacialHairCode } else { [string]$comboGuideFacialHair.SelectedItem }
    $comboGuideFacialHair.Items.Clear()
    foreach ($item in (Get-SharedFacialHairItems)) {
        [void]$comboGuideFacialHair.Items.Add($item)
    }
    Set-ComboSelectionByText -Combo $comboGuideFacialHair -Text $currentFacialHairCode
    $comboGuideFacialHair.Enabled = ($effectiveProfile -eq "male")

    $showFemaleChest = ($effectiveProfile -eq "female")
    $showMaleFacialHair = ($effectiveProfile -eq "male")

    $guideChestLabel.Visible = $showFemaleChest
    $trackGuideChest.Visible = $showFemaleChest
    $labelGuideChestValue.Visible = $showFemaleChest

    $guideFacialHairLabel.Visible = $showMaleFacialHair
    $comboGuideFacialHair.Visible = $showMaleFacialHair

    if ($PreferredChestIndex.HasValue) {
        $value = [math]::Max(0, [math]::Min(10, [int]$PreferredChestIndex.Value))
        $trackGuideChest.Value = $value
    }
    elseif (-not $showFemaleChest) {
        $trackGuideChest.Value = 0
    }

    Update-ChestGuideValueLabel

    switch ($effectiveProfile) {
        "female" {
            $guideHairLabel.Text = "Hair chart code (female)"
            $guideHelp.Text = "Use female hair codes 01-70. Chest slider follows the female size chart."
        }
        "male" {
            $guideHairLabel.Text = "Hair chart code (male)"
            $guideHelp.Text = "Use male hair codes 01-50 and facial hair codes like C2, S4, B1, or F6."
        }
        default {
            $guideHairLabel.Text = "Hair chart code"
            $guideHelp.Text = "Reference only: shared charts are off. Prompt Freedom uses the locked reference for identity, then follows typed changes like chest 6, hips 7, new outfit, or new scene."
        }
    }

    Update-GuidePreviewImages -Character $Character
}

function Get-SharedGuideState {
    param(
        [Parameter(Mandatory = $true)]$Character
    )

    $profileSelection = [string]$comboGuideProfile.SelectedItem
    if ([string]::IsNullOrWhiteSpace($profileSelection)) {
        $profileSelection = "Reference only"
    }

    $effectiveProfile = Get-EffectiveGuideProfile -Character $Character -ProfileSelection $profileSelection

    [pscustomobject]@{
        ProfileSelection = $profileSelection
        EffectiveProfile = $effectiveProfile
        HairCode = [string]$comboGuideHair.SelectedItem
        FacialHairCode = [string]$comboGuideFacialHair.SelectedItem
        ChestIndex = [int]$trackGuideChest.Value
    }
}

function Update-GuidePreviewImages {
    param(
        [Parameter(Mandatory = $true)]$Character
    )

    $guideState = Get-SharedGuideState -Character $Character
    $effectiveProfile = [string]$guideState.EffectiveProfile

    $primaryEntry = $null
    $secondaryEntry = $null
    $primaryLabelText = "Hair preview"
    $secondaryLabelText = "Shared preview"

    switch ($effectiveProfile) {
        "female" {
            $primaryEntry = Get-FemaleHairGuideEntry -HairCode ([string]$guideState.HairCode)
            $secondaryEntry = Get-FemaleChestGuideEntry -ChestIndex ([int]$guideState.ChestIndex)
            $primaryLabelText = if ($null -ne $primaryEntry) { "Hair: $([string]$primaryEntry.Code)" } else { "Hair: none" }
            $secondaryLabelText = if ($null -ne $secondaryEntry) { "Chest: $([string]$secondaryEntry.Label)" } else { "Chest: none" }
        }
        "male" {
            $primaryEntry = Get-MaleHairGuideEntry -HairCode ([string]$guideState.HairCode)
            $secondaryEntry = Get-MaleFacialHairGuideEntry -FacialHairCode ([string]$guideState.FacialHairCode)
            $primaryLabelText = if ($null -ne $primaryEntry) { "Hair: $([string]$primaryEntry.Code)" } else { "Hair: none" }
            $secondaryLabelText = if ($null -ne $secondaryEntry) { "Facial hair: $([string]$secondaryEntry.Code)" } else { "Facial hair: none" }
        }
        default {
            $primaryLabelText = "Hair preview"
            $secondaryLabelText = "Shared preview"
        }
    }

    $guidePreviewTitle.Visible = ($effectiveProfile -ne "none")
    $guidePreviewPrimaryLabel.Visible = ($effectiveProfile -ne "none")
    $guidePreviewSecondaryLabel.Visible = ($effectiveProfile -ne "none")
    $guidePreviewPrimaryBox.Visible = ($effectiveProfile -ne "none")
    $guidePreviewSecondaryBox.Visible = ($effectiveProfile -ne "none")

    $guidePreviewPrimaryLabel.Text = $primaryLabelText
    $guidePreviewSecondaryLabel.Text = $secondaryLabelText

    $primaryBitmap = $null
    $secondaryBitmap = $null

    try {
        if ($null -ne $primaryEntry) {
            $primaryBitmap = Get-GuideEntryPreviewBitmap -Entry $primaryEntry
        }
        if ($null -ne $secondaryEntry) {
            $secondaryBitmap = Get-GuideEntryPreviewBitmap -Entry $secondaryEntry
        }

        Set-PictureBoxBitmap -PictureBox $guidePreviewPrimaryBox -Image $primaryBitmap
        Set-PictureBoxBitmap -PictureBox $guidePreviewSecondaryBox -Image $secondaryBitmap
    }
    finally {
        if ($null -ne $primaryBitmap) {
            $primaryBitmap.Dispose()
        }
        if ($null -ne $secondaryBitmap) {
            $secondaryBitmap.Dispose()
        }
    }
}

function Get-SelectedSave {
    if ($comboSavedSetup.SelectedIndex -le 0) {
        return $null
    }

    $saveIndex = $comboSavedSetup.SelectedIndex - 1
    if ($saveIndex -lt 0 -or $saveIndex -ge $script:VisibleSaves.Count) {
        return $null
    }

    return $script:VisibleSaves[$saveIndex]
}

function Refresh-SaveDropdown {
    param(
        [string]$SelectSaveId
    )

    if ($comboCharacter.SelectedIndex -lt 0) {
        return
    }

    $character = $script:Characters[$comboCharacter.SelectedIndex]
    $pose = $script:Poses[$comboPose.SelectedIndex]
    $scene = $script:Scenes[$comboScene.SelectedIndex]

    $script:IsLoadingSave = $true
    $script:VisibleSaves = @(Get-SavesForCharacter -CharacterId ([string]$character.id))
    $comboSavedSetup.Items.Clear()
    [void]$comboSavedSetup.Items.Add("New setup")

    foreach ($save in $script:VisibleSaves) {
        [void]$comboSavedSetup.Items.Add([string]$save.name)
    }

    $selectedIndex = 0
    if (-not [string]::IsNullOrWhiteSpace($SelectSaveId)) {
        for ($index = 0; $index -lt $script:VisibleSaves.Count; $index++) {
            if ([string]$script:VisibleSaves[$index].id -eq $SelectSaveId) {
                $selectedIndex = $index + 1
                break
            }
        }
    }

    $comboSavedSetup.SelectedIndex = $selectedIndex
    if ($selectedIndex -eq 0) {
        $txtSaveName.Text = Get-DefaultSaveName -Character $character -Pose $pose -Scene $scene
    }

    $script:IsLoadingSave = $false
}

function Apply-SavedSetup {
    param(
        [Parameter(Mandatory = $true)]$Save
    )

    $script:IsLoadingSave = $true

    Set-ComboSelectionById -Combo $comboPose -Items $script:Poses -Id ([string]$Save.poseId)
    Set-ComboSelectionById -Combo $comboScene -Items $script:Scenes -Id ([string]$Save.sceneId)

    $guideProfileSelection = [string]$Save.guideProfileSelection
    if ([string]::IsNullOrWhiteSpace($guideProfileSelection)) {
        $guideProfileSelection = "Reference only"
    }
    switch ($guideProfileSelection) {
        "None" { $guideProfileSelection = "Reference only" }
        "Auto" { $guideProfileSelection = "Reference only" }
        "Female" { $guideProfileSelection = "Female guides" }
        "Male" { $guideProfileSelection = "Male guides" }
    }
    Set-ComboSelectionByText -Combo $comboGuideProfile -Text $guideProfileSelection
    Refresh-GuideControls -Character $script:Characters[$comboCharacter.SelectedIndex] -PreferredHairCode ([string]$Save.sharedHairCode) -PreferredFacialHairCode ([string]$Save.sharedFacialHairCode) -PreferredChestIndex ([Nullable[int]][int]$Save.sharedChestIndex)

    $txtPrompt.Text = [string]$Save.prompt
    $txtNegative.Text = [string]$Save.negativePrompt
    $txtSaveName.Text = [string]$Save.name

    if (-not [string]::IsNullOrWhiteSpace([string]$Save.prefix)) {
        $txtPrefix.Text = [string]$Save.prefix
    }

    Set-NumericControlValue -Control $numBatch -Value $Save.batchSize
    Set-NumericControlValue -Control $numSteps -Value $Save.steps
    Set-NumericControlValue -Control $numCfg -Value $Save.cfg
    Set-NumericControlValue -Control $numPoseStrength -Value $Save.poseStrength
    Set-NumericControlValue -Control $numFace -Value $Save.faceWeight
    Set-NumericControlValue -Control $numOutfit -Value $Save.outfitWeight
    if (-not [string]::IsNullOrWhiteSpace([string]$Save.generationMode)) {
        Set-ComboSelectionByText -Combo $comboGenerationMode -Text ([string]$Save.generationMode)
    }
    if ($null -ne $Save.PSObject.Properties["lockSeed"]) {
        $chkLockSeed.Checked = [bool]$Save.lockSeed
    }
    if ($null -ne $Save.PSObject.Properties["seed"]) {
        Set-NumericControlValue -Control $numSeed -Value $Save.seed
    }
    Refresh-LoraDropdownItems -Character $script:Characters[$comboCharacter.SelectedIndex] -PreferredIdentity ([string]$Save.identityLoraName) -PreferredClothing ([string]$Save.clothingLoraName) -PreferredRealm ([string]$Save.realmLoraName) -PreferredQuality ([string]$Save.qualityLoraName)
    if ($null -ne $Save.PSObject.Properties["identityLoraStrength"]) {
        Set-NumericControlValue -Control $numIdentityLora -Value $Save.identityLoraStrength
    }
    if ($null -ne $Save.PSObject.Properties["clothingLoraStrength"]) {
        Set-NumericControlValue -Control $numClothingLora -Value $Save.clothingLoraStrength
    }
    if ($null -ne $Save.PSObject.Properties["realmLoraStrength"]) {
        Set-NumericControlValue -Control $numRealmLora -Value $Save.realmLoraStrength
    }
    if ($null -ne $Save.PSObject.Properties["qualityLoraStrength"]) {
        Set-NumericControlValue -Control $numQualityLora -Value $Save.qualityLoraStrength
    }

    $script:IsLoadingSave = $false
    Add-Log "Loaded saved setup: $($Save.name)"
}

function Get-CurrentSetupSaveObject {
    param(
        [string]$ExistingId,
        [string]$CreatedAt
    )

    $character = $script:Characters[$comboCharacter.SelectedIndex]
    $pose = $script:Poses[$comboPose.SelectedIndex]
    $scene = $script:Scenes[$comboScene.SelectedIndex]
    $now = (Get-Date).ToString("o")
    $saveName = $txtSaveName.Text.Trim()

    if ([string]::IsNullOrWhiteSpace($saveName)) {
        $saveName = Get-DefaultSaveName -Character $character -Pose $pose -Scene $scene
    }

    if ([string]::IsNullOrWhiteSpace($ExistingId)) {
        $ExistingId = New-SaveId
    }

    if ([string]::IsNullOrWhiteSpace($CreatedAt)) {
        $CreatedAt = $now
    }

    [pscustomobject]@{
        id = $ExistingId
        name = $saveName
        characterId = [string]$character.id
        characterName = [string]$character.name
        poseId = [string]$pose.id
        poseName = [string]$pose.name
        sceneId = [string]$scene.id
        sceneName = [string]$scene.name
        guideProfileSelection = [string]$comboGuideProfile.SelectedItem
        sharedHairCode = [string]$comboGuideHair.SelectedItem
        sharedFacialHairCode = [string]$comboGuideFacialHair.SelectedItem
        sharedChestIndex = [int]$trackGuideChest.Value
        prompt = $txtPrompt.Text
        negativePrompt = $txtNegative.Text
        prefix = $txtPrefix.Text
        batchSize = [int]$numBatch.Value
        steps = [int]$numSteps.Value
        cfg = [double]$numCfg.Value
        poseStrength = [double]$numPoseStrength.Value
        faceWeight = [double]$numFace.Value
        outfitWeight = [double]$numOutfit.Value
        generationMode = [string]$comboGenerationMode.SelectedItem
        lockSeed = [bool]$chkLockSeed.Checked
        seed = [int]$numSeed.Value
        identityLoraName = Get-SelectedLoraName -Combo $comboIdentityLora
        identityLoraStrength = [double]$numIdentityLora.Value
        clothingLoraName = Get-SelectedLoraName -Combo $comboClothingLora
        clothingLoraStrength = [double]$numClothingLora.Value
        realmLoraName = Get-SelectedLoraName -Combo $comboRealmLora
        realmLoraStrength = [double]$numRealmLora.Value
        qualityLoraName = Get-SelectedLoraName -Combo $comboQualityLora
        qualityLoraStrength = [double]$numQualityLora.Value
        createdAt = $CreatedAt
        updatedAt = $now
    }
}

function Save-CurrentSetup {
    param(
        [bool]$UpdateExisting
    )

    if ($comboCharacter.SelectedIndex -lt 0) {
        return
    }

    $existing = $null
    if ($UpdateExisting) {
        $existing = Get-SelectedSave
        if ($null -eq $existing) {
            Add-Log "Choose a saved setup first, or use Save New."
            return
        }
    }

    $saves = @(Get-ConfigArray -Value $script:SavesDoc.saves)

    if ($null -ne $existing) {
        $saveObject = Get-CurrentSetupSaveObject -ExistingId ([string]$existing.id) -CreatedAt ([string]$existing.createdAt)
        for ($index = 0; $index -lt $saves.Count; $index++) {
            if ([string]$saves[$index].id -eq [string]$existing.id) {
                $saves[$index] = $saveObject
                break
            }
        }
    }
    else {
        $saveObject = Get-CurrentSetupSaveObject
        $saves = @($saves + $saveObject)
    }

    $script:SavesDoc.saves = @($saves)
    Write-GeneratorSaves -SavesDocument $script:SavesDoc
    Refresh-SaveDropdown -SelectSaveId ([string]$saveObject.id)
    Add-Log "Saved setup: $($saveObject.name)"
}

function Refresh-FromConfig {
    $script:Config = Read-GeneratorConfig
    Assert-GeneratorConfig -Config $script:Config
    $script:Characters = Get-ConfigArray -Value $script:Config.characters
    $script:Poses = Get-ConfigArray -Value $script:Config.poses
    $script:Scenes = Get-ConfigArray -Value $script:Config.scenes

    $comboCharacter.Items.Clear()
    foreach ($character in $script:Characters) {
        [void]$comboCharacter.Items.Add((Get-CharacterDisplayName -Character $character))
    }
    if ($comboCharacter.Items.Count -gt 0) {
        $comboCharacter.SelectedIndex = 0
        Apply-CharacterDefaults -Character $script:Characters[0]
        Refresh-GuideControls -Character $script:Characters[0]
    }

    $comboPose.Items.Clear()
    foreach ($pose in $script:Poses) {
        [void]$comboPose.Items.Add([string]$pose.name)
    }
    if ($comboPose.Items.Count -gt 0) {
        $comboPose.SelectedIndex = 0
    }

    $comboScene.Items.Clear()
    foreach ($scene in $script:Scenes) {
        [void]$comboScene.Items.Add([string]$scene.name)
    }
    if ($comboScene.Items.Count -gt 0) {
        $comboScene.SelectedIndex = 0
    }

    if ($comboCharacter.SelectedIndex -ge 0) {
        $selectedCharacter = $script:Characters[$comboCharacter.SelectedIndex]
        $identityLoraName = if ($null -ne $selectedCharacter.PSObject.Properties["identityLoraName"]) { [string]$selectedCharacter.identityLoraName } else { "" }
        $clothingLoraName = if ($null -ne $selectedCharacter.PSObject.Properties["clothingLoraName"]) { [string]$selectedCharacter.clothingLoraName } else { "" }
        $realmLoraName = if ($null -ne $selectedCharacter.PSObject.Properties["realmLoraName"]) { [string]$selectedCharacter.realmLoraName } else { "" }
        $qualityLoraName = if ($null -ne $selectedCharacter.PSObject.Properties["qualityLoraName"]) { [string]$selectedCharacter.qualityLoraName } else { "" }
        Refresh-LoraDropdownItems -Character $selectedCharacter -PreferredIdentity $identityLoraName -PreferredClothing $clothingLoraName -PreferredRealm $realmLoraName -PreferredQuality $qualityLoraName
    }
    else {
        Refresh-LoraDropdownItems
    }
    $script:SavesDoc = Read-GeneratorSaves
    Refresh-SaveDropdown
    Add-Log "Config refreshed."
}

function Get-SelectedGenerationJob {
    $character = $script:Characters[$comboCharacter.SelectedIndex]
    $pose = $script:Poses[$comboPose.SelectedIndex]
    $scene = $script:Scenes[$comboScene.SelectedIndex]

    if (-not (Test-CharacterReferenceReady -Character $character)) {
        throw "$($character.name) is listed in the generator, but needs locked face and outfit reference images before this exact-character workflow can generate them. Add identityImageName and outfitImageName in the config after the references are created."
    }

    $guideState = Get-SharedGuideState -Character $character
    $userPrompt = $txtPrompt.Text.Trim()
    $safeUserPrompt = Get-SafeUserPromptForGeneration -UserPrompt $userPrompt -EffectiveProfile ([string]$guideState.EffectiveProfile)
    $allowsSecondarySubject = Test-GenerationPromptAllowsSecondarySubject -Prompt ([string]$safeUserPrompt.Prompt)
    $generationMode = [string]$comboGenerationMode.SelectedItem
    if ([string]::IsNullOrWhiteSpace($generationMode)) {
        $generationMode = "Strict Character Lock"
    }
    if ($safeUserPrompt.WasSubstituted) {
        $generationMode = "Base Layer Clothing Design"
    }
    $guideComposite = New-SharedGuideCompositeReference -BaseImageName ([string]$character.outfitImageName) -GuideState $guideState -CharacterId ([string]$character.id)
    $safePrompt = Get-PhotoMakerSafePrompt -Character $character -Pose $pose -Scene $scene -UserPrompt ([string]$safeUserPrompt.Prompt)
    $identityLoraName = Get-SelectedLoraName -Combo $comboIdentityLora
    $clothingLoraName = Get-SelectedLoraName -Combo $comboClothingLora
    $realmLoraName = Get-SelectedLoraName -Combo $comboRealmLora
    $qualityLoraName = Get-SelectedLoraName -Combo $comboQualityLora
    $identityLoraStrength = Get-EffectiveLoraStrength -LoraName $identityLoraName -Control $numIdentityLora
    $clothingLoraStrength = Get-EffectiveLoraStrength -LoraName $clothingLoraName -Control $numClothingLora
    $realmLoraStrength = Get-EffectiveLoraStrength -LoraName $realmLoraName -Control $numRealmLora
    $qualityLoraStrength = Get-EffectiveLoraStrength -LoraName $qualityLoraName -Control $numQualityLora

    # --- Bust size LoRA injection ---
    # BustSize LoRA was trained with cup-size captions: "a cup bust" through "j cup bust"
    # The trigger word is injected into the prompt via Get-FemaleChestGuideEntry (already fixed).
    # Outfit IPAdapter weight is reduced so the LoRA can actually reshape the silhouette.
    $bustLoraFileName = "BustSize_V0-1.safetensors"
    $chestSliderValue = [int]$trackGuideChest.Value
    if ($chestSliderValue -ge 1 -and $chestSliderValue -le 10) {
        # Strength scales: slider 1=0.45, slider 5=0.67, slider 10=0.85
        $bustLoraStrength = [math]::Round(0.45 + ($chestSliderValue - 1) * (0.40 / 9), 2)
        if ([string]::IsNullOrWhiteSpace($clothingLoraName) -or $clothingLoraName -eq "None") {
            $clothingLoraName = $bustLoraFileName
            $clothingLoraStrength = $bustLoraStrength
        }
        else {
            # Manual clothing LoRA selected — move it to realm slot if free, bust LoRA takes clothing slot
            if ([string]::IsNullOrWhiteSpace($realmLoraName) -or $realmLoraName -eq "None") {
                $realmLoraName = $clothingLoraName
                $realmLoraStrength = $clothingLoraStrength
            }
            $clothingLoraName = $bustLoraFileName
            $clothingLoraStrength = $bustLoraStrength
        }
        $bustCupTrigger = switch ($chestSliderValue) {
            1  { "a cup bust" }
            2  { "b cup bust" }
            3  { "c cup bust" }
            4  { "d cup bust" }
            5  { "dd cup bust" }
            6  { "e cup bust" }
            7  { "f cup bust" }
            8  { "g cup bust" }
            9  { "i cup bust" }
            10 { "j cup bust" }
            default { "d cup bust" }
        }
        # Inject trigger into PhotoMaker prompt so body shape encoding matches the LoRA
        if ($safePrompt -notmatch [regex]::Escape($bustCupTrigger)) {
            $safePrompt = "$bustCupTrigger, $safePrompt"
        }
        Add-Log "Bust LoRA: $bustLoraFileName @ $bustLoraStrength, trigger='$bustCupTrigger' (injected into PhotoMaker prompt)"
    }
    $loraSummary = Get-LoraStackSummary -IdentityName $identityLoraName -IdentityStrength $identityLoraStrength -ClothingName $clothingLoraName -ClothingStrength $clothingLoraStrength -RealmName $realmLoraName -RealmStrength $realmLoraStrength -QualityName $qualityLoraName -QualityStrength $qualityLoraStrength
    $identityPrompt = Get-CharacterIdentityPrompt -Character $character
    $characterPromptForMode = [string]$character.basePrompt
    $identityRule = "identity priority: same selected character identity, clear face, believable anatomy, natural body proportions"
    if ($generationMode -eq "Prompt Freedom") {
        $characterPromptForMode = $identityPrompt
        $identityRule = "locked reference controls identity only: keep the same face, hair identity, age, eye color, and recognizable body type; obey the typed prompt for clothing, pose, body-size changes, scene, props, and action"
    }
    elseif ($generationMode -eq "Base Layer Clothing Design") {
        $characterPromptForMode = $identityPrompt
        $identityRule = "locked reference controls identity only: keep the same face, hair identity, age, and recognizable body type; create the safe base-layer clothing-design reference instead of copying the gown"
    }
    elseif ($generationMode -eq "Balanced") {
        $characterPromptForMode = $identityPrompt
        $identityRule = "balanced identity: keep the selected character recognizable while allowing the typed prompt to change scene, action, clothing, and props"
    }
    $bodyAdjustmentParts = @(Get-BodyAdjustmentPromptParts -RawPrompt $userPrompt -EffectiveProfile ([string]$guideState.EffectiveProfile))
    $compositionRule = if ($allowsSecondarySubject) {
        "single coherent cinematic image, one primary selected character, one visible instance of the selected character, include the requested secondary subject without duplicating the selected character, selected character remains visually dominant, head-to-toe standing pose for the selected character, centered subject, not a design sheet, not a lineup, not a turnaround, no character sheet, no concept sheet, no reference sheet, no model sheet, no multiple panels, no inset portraits, no side views, no detail crops"
    }
    else {
        "single coherent cinematic image, one character only, one full-body person, one visible instance of the selected character, head-to-toe standing pose, centered subject, not a design sheet, not a lineup, not a turnaround, no character sheet, no concept sheet, no reference sheet, no model sheet, no multiple panels, no inset portraits, no side views, no detail crops, no repeated character, no duplicate character, no three full-body figures"
    }
    $stylePromptList = New-Object System.Collections.Generic.List[string]
    foreach ($part in @(
        $(if (-not [string]::IsNullOrWhiteSpace([string]$safeUserPrompt.Prompt)) { "PRIMARY USER INSTRUCTION: $([string]$safeUserPrompt.Prompt)" }),
        $compositionRule,
        "render as one believable real person in the selected scene, not painted onto a flat reference page",
        $(if (-not [string]::IsNullOrWhiteSpace([string]$safeUserPrompt.Prompt)) { "scene requirement: $([string]$safeUserPrompt.Prompt)" }),
        $(if (-not [string]::IsNullOrWhiteSpace([string]$safeUserPrompt.Prompt)) { "must clearly show: $([string]$safeUserPrompt.Prompt)" }),
        $identityRule,
        $(if ($generationMode -eq "Base Layer Clothing Design") { "clothing design base layer, plain smooth fitted base garment, preserve body proportions, no costume details, no revealing treatment" }),
        $(if (-not [string]::IsNullOrWhiteSpace($identityLoraName) -and $null -ne $character.PSObject.Properties["identityLoraTrigger"]) { [string]$character.identityLoraTrigger }),
        $(if (-not [string]::IsNullOrWhiteSpace($clothingLoraName) -and $null -ne $character.PSObject.Properties["clothingLoraTrigger"]) { [string]$character.clothingLoraTrigger }),
        $(if (-not [string]::IsNullOrWhiteSpace($realmLoraName) -and $null -ne $character.PSObject.Properties["realmLoraTrigger"]) { [string]$character.realmLoraTrigger }),
        $(if (-not [string]::IsNullOrWhiteSpace($qualityLoraName) -and $null -ne $character.PSObject.Properties["qualityLoraTrigger"]) { [string]$character.qualityLoraTrigger }),
        [string]$scene.prompt,
        [string]$pose.prompt
    )) {
        if (-not [string]::IsNullOrWhiteSpace([string]$part)) {
            [void]$stylePromptList.Add([string]$part)
        }
    }
    foreach ($part in @($bodyAdjustmentParts)) {
        if (-not [string]::IsNullOrWhiteSpace([string]$part)) {
            [void]$stylePromptList.Add([string]$part)
        }
    }
    foreach ($part in @($guideComposite.PromptParts)) {
        if (-not [string]::IsNullOrWhiteSpace([string]$part)) {
            [void]$stylePromptList.Add([string]$part)
        }
    }
    foreach ($part in @(
        "full body, clear anatomy, believable natural proportions, no disfigurement",
        $characterPromptForMode
    )) {
        if (-not [string]::IsNullOrWhiteSpace([string]$part)) {
            [void]$stylePromptList.Add([string]$part)
        }
    }
    $stylePromptParts = @($stylePromptList.ToArray())
    $stylePrompt = ($stylePromptParts -join ", ")

    $negativeParts = @(
        [string]$script:Config.globalNegativePrompt,
        $(if ($null -ne $script:Config.PSObject.Properties["qualityNegativePrompt"]) { [string]$script:Config.qualityNegativePrompt }),
        [string]$character.negativePrompt,
        @(Get-ModeNegativePromptParts -GenerationMode $generationMode -UserPrompt ([string]$safeUserPrompt.Prompt) -UsingBaseLayer ([bool]$safeUserPrompt.WasSubstituted)),
        (Get-SafeExtraNegativePrompt -ExtraNegativePrompt $txtNegative.Text.Trim() -UsingBaseLayer ([bool]$safeUserPrompt.WasSubstituted))
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    $negativePrompt = Get-GenerationNegativePrompt -Parts @($negativeParts) -AllowSecondarySubject $allowsSecondarySubject

    $prefixBase = Get-SafeFilePart -Text $txtPrefix.Text -Fallback "book_character"
    $characterPart = Get-SafeFilePart -Text ([string]$character.id) -Fallback "character"
    $posePart = Get-SafeFilePart -Text ([string]$pose.id) -Fallback "pose"
    $timePart = Get-Date -Format "yyyyMMdd_HHmmss"
    $prefix = "{0}_{1}_{2}_{3}" -f $prefixBase, $characterPart, $posePart, $timePart

    $requestedFaceWeight = [double]$numFace.Value
    $requestedOutfitWeight = [double]$numOutfit.Value
    $effectiveFaceWeight = $requestedFaceWeight
    $effectiveOutfitWeight = $requestedOutfitWeight
    $requestedIdentityLoraStrength = $identityLoraStrength
    $effectiveIdentityLoraStrength = $identityLoraStrength
    $hasSharedGuideReference = -not [string]::IsNullOrWhiteSpace([string]$guideComposite.Summary)
    switch ($generationMode) {
        "Strict Character Lock" {
            if ($effectiveFaceWeight -lt 1.15) { $effectiveFaceWeight = 1.15 }
            if ($effectiveOutfitWeight -lt 0.55) { $effectiveOutfitWeight = 0.55 }
        }
        "Balanced" {
            if ($effectiveFaceWeight -lt 0.8) { $effectiveFaceWeight = 0.8 }
            if ($effectiveFaceWeight -gt 1.0) { $effectiveFaceWeight = 1.0 }
            if ($hasSharedGuideReference -and $effectiveOutfitWeight -lt 0.2) { $effectiveOutfitWeight = 0.2 }
            if ($effectiveOutfitWeight -gt 0.3) { $effectiveOutfitWeight = 0.3 }
            if ($effectiveIdentityLoraStrength -gt 0.7) { $effectiveIdentityLoraStrength = 0.7 }
        }
        "Prompt Freedom" {
            if ($effectiveFaceWeight -lt 0.55) { $effectiveFaceWeight = 0.55 }
            if ($effectiveFaceWeight -gt 0.75) { $effectiveFaceWeight = 0.75 }
            if ($effectiveOutfitWeight -gt 0.08) { $effectiveOutfitWeight = 0.08 }
            if ($effectiveIdentityLoraStrength -gt 0.6) { $effectiveIdentityLoraStrength = 0.6 }
            # When bust slider is active, raise face floor and allow outfit weight so LoRA can work
            $bustSliderActive = ([int]$trackGuideChest.Value -ge 1)
            if ($bustSliderActive) {
                if ($effectiveFaceWeight -lt 0.70) { $effectiveFaceWeight = 0.70 }
                $effectiveOutfitWeight = 0.0  # Let bust LoRA drive shape, not IPAdapter outfit
            }
        }
        "Base Layer Clothing Design" {
            if ($effectiveFaceWeight -lt 0.65) { $effectiveFaceWeight = 0.65 }
            if ($effectiveFaceWeight -gt 0.85) { $effectiveFaceWeight = 0.85 }
            if ($effectiveOutfitWeight -gt 0.05) { $effectiveOutfitWeight = 0.05 }
            if ($effectiveIdentityLoraStrength -gt 0.55) { $effectiveIdentityLoraStrength = 0.55 }
        }
        default {
            if ($hasSharedGuideReference -and $effectiveOutfitWeight -lt 0.35) {
                $effectiveOutfitWeight = 0.35
            }
        }
    }

    $loraSummary = Get-LoraStackSummary -IdentityName $identityLoraName -IdentityStrength $effectiveIdentityLoraStrength -ClothingName $clothingLoraName -ClothingStrength $clothingLoraStrength -RealmName $realmLoraName -RealmStrength $realmLoraStrength -QualityName $qualityLoraName -QualityStrength $qualityLoraStrength

    $seed = 0
    if ($chkLockSeed.Checked) {
        $seed = [int]$numSeed.Value
    }

    [pscustomobject]@{
        Config = $script:Config
        Character = $character
        Pose = $pose
        Scene = $scene
        Prompt = $safePrompt
        StylePrompt = $stylePrompt
        UserPrompt = $userPrompt
        GenerationPrompt = [string]$safeUserPrompt.Prompt
        UsedBaseLayerSubstitute = [bool]$safeUserPrompt.WasSubstituted
        NegativePrompt = $negativePrompt
        IdentityImageName = [string]$character.identityImageName
        OutfitImageName = [string]$guideComposite.OutfitImageName
        GuideState = $guideState
        GuideSummary = [string]$guideComposite.Summary
        Width = [int]$script:Config.defaults.width
        Height = [int]$script:Config.defaults.height
        BatchSize = [int]$numBatch.Value
        Steps = [int]$numSteps.Value
        Cfg = [double]$numCfg.Value
        PoseStrength = [double]$numPoseStrength.Value
        FaceWeight = $effectiveFaceWeight
        RequestedFaceWeight = $requestedFaceWeight
        OutfitWeight = $effectiveOutfitWeight
        RequestedOutfitWeight = $requestedOutfitWeight
        GenerationMode = $generationMode
        Seed = $seed
        IdentityLoraName = $identityLoraName
        IdentityLoraStrength = $effectiveIdentityLoraStrength
        RequestedIdentityLoraStrength = $requestedIdentityLoraStrength
        ClothingLoraName = $clothingLoraName
        ClothingLoraStrength = $clothingLoraStrength
        RealmLoraName = $realmLoraName
        RealmLoraStrength = $realmLoraStrength
        QualityLoraName = $qualityLoraName
        QualityLoraStrength = $qualityLoraStrength
        LoraSummary = $loraSummary
        Prefix = $prefix
        ComfyUrl = [string]$script:Config.comfyUrl
        OutputPath = [string]$script:Config.comfyOutputPath
    }
}

$btnGenerate.Add_Click({
    if ($script:IsGenerating) {
        return
    }

    try {
        $script:IsGenerating = $true
        $job = Get-SelectedGenerationJob
        $btnGenerate.Enabled = $false
        $btnSync.Enabled = $false
        Add-Log "Starting $($job.Character.name): $($job.Pose.name) in $($job.Scene.name)."
        Add-Log "Generation mode: $($job.GenerationMode). Seed: $(if ($job.Seed -gt 0) { $job.Seed } else { 'random' })."
        Add-Log "PhotoMaker-safe prompt: $($job.Prompt)"
        Add-Log "Scene/style prompt length: $($job.StylePrompt.Length) characters."
        if ($job.UsedBaseLayerSubstitute) {
            Add-Log "Used safe base-layer clothing-design prompt in place of a nude/clothing-removal request."
        }
        if ($job.RequestedFaceWeight -ne $job.FaceWeight) {
            Add-Log ("Identity assist adjusted Face - match from {0:N2} to {1:N2}." -f $job.RequestedFaceWeight, $job.FaceWeight)
        }
        if ($job.RequestedOutfitWeight -ne $job.OutfitWeight) {
            Add-Log ("Reference assist adjusted Outfit - clothes from {0:N2} to {1:N2}." -f $job.RequestedOutfitWeight, $job.OutfitWeight)
        }
        if ($job.RequestedIdentityLoraStrength -ne $job.IdentityLoraStrength) {
            Add-Log ("Prompt Freedom adjusted Identity LoRA from {0:N2} to {1:N2}." -f $job.RequestedIdentityLoraStrength, $job.IdentityLoraStrength)
        }
        if (-not [string]::IsNullOrWhiteSpace([string]$job.GuideSummary)) {
            Add-Log "Shared guides: $($job.GuideSummary)"
        }
        if (-not [string]::IsNullOrWhiteSpace([string]$job.LoraSummary)) {
            Add-Log "LoRA stack: $($job.LoraSummary)"
        }
        $bustSlot = [int]$trackGuideChest.Value
        if ($bustSlot -ge 1 -and $bustSlot -le 10) {
            $bustCupLabel = switch ($bustSlot) {
                1  { "a cup bust" }  2  { "b cup bust" }  3  { "c cup bust" }
                4  { "d cup bust" }  5  { "dd cup bust" } 6  { "e cup bust" }
                7  { "f cup bust" }  8  { "g cup bust" }  9  { "i cup bust" }
                10 { "j cup bust" }  default { "d cup bust" }
            }
            $bustStr = [math]::Round(0.45 + ($bustSlot - 1) * (0.40 / 9), 2)
            Add-Log ("Bust LoRA: BustSize_V0-1 @ {0:N2}, trigger='{1}'" -f $bustStr, $bustCupLabel)
        }
        [System.Windows.Forms.Application]::DoEvents()

        $result = Invoke-CharacterGeneration -Job $job -Worker $null

        $listOutputs.Items.Clear()
        foreach ($imagePath in $result.Images) {
            [void]$listOutputs.Items.Add($imagePath)
        }

        if ($result.Images.Count -gt 0) {
            $listOutputs.SelectedIndex = 0
            Set-PreviewImage -Path ([string]$result.Images[0])
        }

        Add-Log "Finished. Generated $($result.Images.Count) image(s)."
    }
    catch {
        Add-Log "Error: $($_.Exception.Message)"
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, "Generation failed", "OK", "Error") | Out-Null
    }
    finally {
        $btnGenerate.Enabled = $true
        $btnSync.Enabled = $true
        $script:IsGenerating = $false
    }
})

$btnOpenComfy.Add_Click({
    Start-Process ([string]$script:Config.comfyUrl)
})

$btnOpenOutput.Add_Click({
    Start-Process ([string]$script:Config.comfyOutputPath)
})

$btnOpenConfig.Add_Click({
    Start-Process $ConfigPath
})

$btnRefreshConfig.Add_Click({
    try {
        Refresh-FromConfig
    }
    catch {
        Add-Log "Error: $($_.Exception.Message)"
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, "Config problem", "OK", "Error") | Out-Null
    }
})

$btnSync.Add_Click({
    try {
        $job = Get-SelectedGenerationJob
        $sync = Sync-ComfyInputFiles -Config $job.Config -Character $job.Character -Pose $job.Pose -IdentityImageName ([string]$job.IdentityImageName) -OutfitImageName ([string]$job.OutfitImageName)
        if ($sync.Missing.Count -gt 0) {
            Add-Log "Missing: $($sync.Missing -join ', ')"
        }
        elseif ($sync.Synced.Count -gt 0) {
            Add-Log "Copied: $($sync.Synced -join ', ')"
        }
        else {
            Add-Log "All selected inputs are already in ComfyUI."
        }
        if (-not [string]::IsNullOrWhiteSpace([string]$job.GuideSummary)) {
            Add-Log "Prepared shared guide prompt: $($job.GuideSummary)"
        }
        if (-not [string]::IsNullOrWhiteSpace([string]$job.LoraSummary)) {
            Add-Log "Prepared LoRA stack: $($job.LoraSummary)"
        }
    }
    catch {
        Add-Log "Error: $($_.Exception.Message)"
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, "Sync failed", "OK", "Error") | Out-Null
    }
})

$btnCharacterSeed.Add_Click({
    if ($comboCharacter.SelectedIndex -lt 0) {
        return
    }

    $character = $script:Characters[$comboCharacter.SelectedIndex]
    Set-NumericControlValue -Control $numSeed -Value (Get-StableCharacterSeed -Character $character)
    $chkLockSeed.Checked = $true
    Add-Log "Loaded repeat seed for $($character.name)."
})

$listOutputs.Add_SelectedIndexChanged({
    if ($listOutputs.SelectedIndex -lt 0) {
        return
    }

    Set-PreviewImage -Path ([string]$listOutputs.SelectedItem)
})

$comboSavedSetup.Add_SelectedIndexChanged({
    if ($script:IsLoadingSave) {
        return
    }

    $save = Get-SelectedSave
    if ($null -eq $save) {
        if ($comboCharacter.SelectedIndex -ge 0 -and $comboPose.SelectedIndex -ge 0 -and $comboScene.SelectedIndex -ge 0) {
            $txtSaveName.Text = Get-DefaultSaveName -Character $script:Characters[$comboCharacter.SelectedIndex] -Pose $script:Poses[$comboPose.SelectedIndex] -Scene $script:Scenes[$comboScene.SelectedIndex]
        }
        Add-Log "New setup selected."
        return
    }

    Apply-SavedSetup -Save $save
})

$btnSaveNew.Add_Click({
    try {
        Save-CurrentSetup -UpdateExisting $false
    }
    catch {
        Add-Log "Error: $($_.Exception.Message)"
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, "Save failed", "OK", "Error") | Out-Null
    }
})

$btnUpdateSave.Add_Click({
    try {
        Save-CurrentSetup -UpdateExisting $true
    }
    catch {
        Add-Log "Error: $($_.Exception.Message)"
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, "Update failed", "OK", "Error") | Out-Null
    }
})

$comboPose.Add_SelectedIndexChanged({
    if ($script:IsLoadingSave) {
        return
    }

    if ($comboSavedSetup.SelectedIndex -eq 0 -and $comboCharacter.SelectedIndex -ge 0 -and $comboScene.SelectedIndex -ge 0) {
        $txtSaveName.Text = Get-DefaultSaveName -Character $script:Characters[$comboCharacter.SelectedIndex] -Pose $script:Poses[$comboPose.SelectedIndex] -Scene $script:Scenes[$comboScene.SelectedIndex]
    }
})

$comboScene.Add_SelectedIndexChanged({
    if ($script:IsLoadingSave) {
        return
    }

    if ($comboSavedSetup.SelectedIndex -eq 0 -and $comboCharacter.SelectedIndex -ge 0 -and $comboPose.SelectedIndex -ge 0) {
        $txtSaveName.Text = Get-DefaultSaveName -Character $script:Characters[$comboCharacter.SelectedIndex] -Pose $script:Poses[$comboPose.SelectedIndex] -Scene $script:Scenes[$comboScene.SelectedIndex]
    }
})

$comboGuideProfile.Add_SelectedIndexChanged({
    if ($comboCharacter.SelectedIndex -lt 0) {
        return
    }

    Refresh-GuideControls -Character $script:Characters[$comboCharacter.SelectedIndex]
})

$trackGuideChest.Add_ValueChanged({
    Update-ChestGuideValueLabel
    if ($comboCharacter.SelectedIndex -ge 0) {
        Update-GuidePreviewImages -Character $script:Characters[$comboCharacter.SelectedIndex]
    }
})

$comboGuideHair.Add_SelectedIndexChanged({
    if ($comboCharacter.SelectedIndex -ge 0) {
        Update-GuidePreviewImages -Character $script:Characters[$comboCharacter.SelectedIndex]
    }
})

$comboGuideFacialHair.Add_SelectedIndexChanged({
    if ($comboCharacter.SelectedIndex -ge 0) {
        Update-GuidePreviewImages -Character $script:Characters[$comboCharacter.SelectedIndex]
    }
})

$comboCharacter.Add_SelectedIndexChanged({
    if ($comboCharacter.SelectedIndex -lt 0) {
        return
    }

    $character = $script:Characters[$comboCharacter.SelectedIndex]
    Apply-CharacterDefaults -Character $character
    Refresh-GuideControls -Character $character
    if (Test-CharacterReferenceReady -Character $character) {
        $statusLabel.Text = "$($character.name) is ready. Face and outfit references are assigned."
    }
    else {
        $statusLabel.Text = "$($character.name) is listed, but needs locked face and outfit references."
    }

    Refresh-SaveDropdown
})

$listOutputs.Add_DoubleClick({
    if ($listOutputs.SelectedIndex -lt 0) {
        return
    }

    Start-Process ([string]$listOutputs.SelectedItem)
})

$pictureBox.Add_DoubleClick({
    if ($listOutputs.SelectedIndex -lt 0) {
        return
    }

    Start-Process ([string]$listOutputs.SelectedItem)
})

$script:VisibleSaves = @()
$script:IsLoadingSave = $false
$script:IsGenerating = $false
if ($comboCharacter.SelectedIndex -ge 0) {
    Apply-CharacterDefaults -Character $script:Characters[$comboCharacter.SelectedIndex]
    Refresh-GuideControls -Character $script:Characters[$comboCharacter.SelectedIndex]
}
Refresh-SaveDropdown
Add-Log "Ready. ComfyUI: $($Config.comfyUrl)"

if ($SelfTestGuides) {
    $comboCharacter.SelectedIndex = 1
    $comboGuideProfile.SelectedItem = "Female guides"
    Refresh-GuideControls -Character $script:Characters[$comboCharacter.SelectedIndex]
    $comboGuideHair.SelectedItem = "20"
    $trackGuideChest.Value = 6
    $txtPrompt.Text = ""
    $txtNegative.Text = ""
    try {
        $job = Get-SelectedGenerationJob
        [pscustomobject]@{
            Prompt = $job.Prompt
            StylePrompt = $job.StylePrompt
            OutfitImageName = $job.OutfitImageName
            GuideSummary = $job.GuideSummary
            GenerationMode = $job.GenerationMode
            Seed = $job.Seed
            FaceWeight = $job.FaceWeight
            OutfitWeight = $job.OutfitWeight
            IdentityLoraName = $job.IdentityLoraName
            IdentityLoraStrength = $job.IdentityLoraStrength
            RequestedIdentityLoraStrength = $job.RequestedIdentityLoraStrength
            ClothingLoraName = $job.ClothingLoraName
            ClothingLoraStrength = $job.ClothingLoraStrength
            RealmLoraName = $job.RealmLoraName
            RealmLoraStrength = $job.RealmLoraStrength
            QualityLoraName = $job.QualityLoraName
            QualityLoraStrength = $job.QualityLoraStrength
            LoraSummary = $job.LoraSummary
            UsedBaseLayerSubstitute = $job.UsedBaseLayerSubstitute
        } | Format-List | Out-String
    }
    catch {
        "Self-test failed:"
        $_.Exception.Message
        $_.InvocationInfo.PositionMessage
        $_.ScriptStackTrace
    }
    return
}

[void]$form.ShowDialog()
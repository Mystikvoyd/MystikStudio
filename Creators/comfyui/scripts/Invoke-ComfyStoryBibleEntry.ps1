param(
    [string]$Collection = "characters",
    [string]$Id = "the-fool",
    [string]$Style = "serious mythic fantasy concept art, cinematic painterly realism, dramatic lantern light, high detail, book illustration",
    [string]$Prefix = "",
    [string]$StoryBiblePath = (Join-Path $PSScriptRoot "..\..\..\webpage\story-dashboard\story-bible.json")
)

$ErrorActionPreference = "Stop"

function Join-NonEmpty {
    param([string[]]$Parts)
    (@($Parts) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) -join ", "
}

function ConvertTo-Slug {
    param([string]$Text)
    $value = ([string]$Text).ToLowerInvariant().Trim()
    $value = $value -replace "[^a-z0-9]+", "-"
    $value = $value.Trim("-")
    if ([string]::IsNullOrWhiteSpace($value)) { return "entry" }
    $value
}

$bible = Get-Content -LiteralPath $StoryBiblePath -Raw | ConvertFrom-Json
if (-not ($bible.PSObject.Properties.Name -contains $Collection)) {
    throw "Collection not found: $Collection"
}

$entry = @($bible.$Collection) | Where-Object { $_.id -eq $Id -or $_.name -eq $Id } | Select-Object -First 1
if ($null -eq $entry) {
    throw "Entry not found: $Collection/$Id"
}

$physical = ""
if ($entry.PSObject.Properties.Name -contains "physical" -and $null -ne $entry.physical) {
    $physical = (@($entry.physical.PSObject.Properties) | ForEach-Object {
        if (-not [string]::IsNullOrWhiteSpace([string]$_.Value)) {
            "$($_.Name): $($_.Value)"
        }
    }) -join ", "
}

$properties = ""
if ($entry.PSObject.Properties.Name -contains "properties" -and $null -ne $entry.properties) {
    $properties = (@($entry.properties.PSObject.Properties) | ForEach-Object {
        if (-not [string]::IsNullOrWhiteSpace([string]$_.Value)) {
            "$($_.Name): $($_.Value)"
        }
    }) -join ", "
}

$prompt = Join-NonEmpty @(
    $Style,
    $entry.name,
    $entry.category,
    $entry.biography,
    $physical,
    $properties,
    $entry.image.prompt
)

$negative = "low quality, blurry, distorted anatomy, extra fingers, bad hands, watermark, text, logo, modern clothing, cartoon, anime, joke, clown, plastic skin, overexposed"

if ([string]::IsNullOrWhiteSpace($Prefix)) {
    $Prefix = "book_" + (ConvertTo-Slug -Text $entry.name)
}

& (Join-Path $PSScriptRoot "Invoke-ComfyBasicImage.ps1") -Prompt $prompt -NegativePrompt $negative -Prefix $Prefix

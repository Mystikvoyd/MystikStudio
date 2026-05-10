param(
    [string]$SourcePath = "",
    [string]$Name = "",
    [string]$DestinationFolder = (Join-Path $PSScriptRoot "..\..\..\book-design\assets\generated\comfyui")
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($SourcePath)) {
    $SourcePath = Get-ChildItem -LiteralPath "C:\Users\Michael\Documents\ComfyUI\output" -File -Recurse -ErrorAction Stop |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1 -ExpandProperty FullName
}

if (-not (Test-Path -LiteralPath $SourcePath -PathType Leaf)) {
    throw "Source image not found: $SourcePath"
}

New-Item -ItemType Directory -Force -Path $DestinationFolder | Out-Null
$sourceItem = Get-Item -LiteralPath $SourcePath

if ([string]::IsNullOrWhiteSpace($Name)) {
    $Name = $sourceItem.BaseName
}

$safeName = $Name.ToLowerInvariant() -replace "[^a-z0-9]+", "-"
$safeName = $safeName.Trim("-")
if ([string]::IsNullOrWhiteSpace($safeName)) {
    $safeName = "comfyui-image"
}

$destination = Join-Path $DestinationFolder ($safeName + $sourceItem.Extension.ToLowerInvariant())
$counter = 2
while (Test-Path -LiteralPath $destination) {
    $destination = Join-Path $DestinationFolder ("{0}-{1}{2}" -f $safeName, $counter, $sourceItem.Extension.ToLowerInvariant())
    $counter++
}

Copy-Item -LiteralPath $SourcePath -Destination $destination
$item = Get-Item -LiteralPath $destination

[pscustomobject]@{
    source = $SourcePath
    destination = $item.FullName
    assetPath = "/assets/generated/comfyui/$($item.Name)"
    size = $item.Length
} | ConvertTo-Json

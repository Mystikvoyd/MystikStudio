param(
    [string]$ModelUrl = "https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/resolve/main/sd_xl_base_1.0.safetensors",
    [string]$Destination = "C:\Users\Michael\Documents\ComfyUI\models\checkpoints\SDXL\sd_xl_base_1.0.safetensors"
)

$ErrorActionPreference = "Stop"
$destinationFolder = Split-Path -Parent $Destination
New-Item -ItemType Directory -Force -Path $destinationFolder | Out-Null

if (Test-Path -LiteralPath $Destination -PathType Leaf) {
    $existing = Get-Item -LiteralPath $Destination
    if ($existing.Length -gt 1GB) {
        Write-Output "Model already exists: $Destination"
        Write-Output ("Size: {0:N2} GB" -f ($existing.Length / 1GB))
        return
    }
}

$partial = "$Destination.partial"
if (Test-Path -LiteralPath $partial -PathType Leaf) {
    Remove-Item -LiteralPath $partial -Force
}

Write-Output "Downloading starter SDXL checkpoint..."
Write-Output $ModelUrl
Write-Output "Destination: $Destination"

$curl = Get-Command curl.exe -ErrorAction SilentlyContinue
if ($null -ne $curl) {
    & $curl.Source -L --fail --progress-bar -o $partial $ModelUrl
}
else {
    Invoke-WebRequest -Uri $ModelUrl -OutFile $partial
}

Move-Item -LiteralPath $partial -Destination $Destination -Force
$downloaded = Get-Item -LiteralPath $Destination
Write-Output "Download complete."
Write-Output ("Size: {0:N2} GB" -f ($downloaded.Length / 1GB))

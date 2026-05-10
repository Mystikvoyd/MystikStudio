# Test-SessionReport.ps1
# Run this first to confirm Write-LoraReport.py works on your machine
# before integrating into Start-LoraTester.ps1
#
# Usage:  .\Test-SessionReport.ps1
# It will ask you to paste a path to any PNG in your ComfyUI output folder.

$scriptDir   = $PSScriptRoot
$pyScript    = [System.IO.Path]::Combine($scriptDir, "Write-LoraReport.py")
$reportsDir  = [System.IO.Path]::Combine($env:USERPROFILE, "Documents", "ComfyUI", "Reports")
$tmpJson     = [System.IO.Path]::Combine($env:TEMP, "lora-session-test.json")
$outHtml     = [System.IO.Path]::Combine($reportsDir, "lora-session-TEST.html")

Write-Host ""
Write-Host "=== LoRA Session Report Test ===" -ForegroundColor Cyan
Write-Host ""

# Ask for a test image
Write-Host "Paste the full path to any PNG in your ComfyUI output folder:" -ForegroundColor Yellow
$imgPath = Read-Host "> "
$imgPath = $imgPath.Trim('"').Trim("'").Trim()

if (-not [System.IO.File]::Exists($imgPath)) {
    Write-Host "File not found: $imgPath" -ForegroundColor Red
    Write-Host "The test will continue but the image will show as missing in the report."
}

# Ensure reports folder
if (-not [System.IO.Directory]::Exists($reportsDir)) {
    [System.IO.Directory]::CreateDirectory($reportsDir) | Out-Null
}

# Build test JSON - note: we use [System.IO.Path]::GetFullPath to normalize, 
# then store as a plain .NET string in a hashtable, then ConvertTo-Json.
# NO PS string interpolation on the path.
$absImgPath = [System.IO.Path]::GetFullPath($imgPath)

$testData = [ordered]@{
    generated = [DateTime]::Now.ToString("yyyy-MM-dd HH:mm:ss")
    entries   = @(
        [ordered]@{
            time          = [DateTime]::Now.ToString("yyyy-MM-dd HH:mm:ss")
            image_path    = $absImgPath
            lora_enabled  = $true
            lora_name     = "my_character_v1"
            lora_strength = 0.75
            seed          = 1234567890
            steps         = 30
            cfg           = 7.0
            width         = 1024
            height        = 1024
            sampler       = "dpmpp_2m"
            prompt        = "RAW photo, photorealistic, full body portrait, dark fantasy character"
            negative      = "cartoon, anime, 3d render, bad anatomy, extra fingers"
        },
        [ordered]@{
            time          = [DateTime]::Now.AddSeconds(-30).ToString("yyyy-MM-dd HH:mm:ss")
            image_path    = $absImgPath
            lora_enabled  = $false
            lora_name     = ""
            lora_strength = 0.0
            seed          = 9876543210
            steps         = 30
            cfg           = 7.0
            width         = 1024
            height        = 1024
            sampler       = "dpmpp_2m"
            prompt        = "RAW photo, photorealistic, full body portrait, dark fantasy character"
            negative      = "cartoon, anime, 3d render, bad anatomy, extra fingers"
        }
    )
}

$json = $testData | ConvertTo-Json -Depth 10
[System.IO.File]::WriteAllText($tmpJson, $json, [System.Text.Encoding]::UTF8)

Write-Host ""
Write-Host "JSON written to: $tmpJson" -ForegroundColor Gray
Write-Host "Image path stored in JSON: $absImgPath" -ForegroundColor Gray
Write-Host ""
Write-Host "Running Python reporter..." -ForegroundColor Cyan

$result = & python $pyScript $tmpJson $outHtml 2>&1
Write-Host $result

if ([System.IO.File]::Exists($outHtml)) {
    Write-Host ""
    Write-Host "SUCCESS - Report created at:" -ForegroundColor Green
    Write-Host $outHtml -ForegroundColor White
    Write-Host ""
    Write-Host "Opening in browser..." -ForegroundColor Cyan
    Start-Process $outHtml
} else {
    Write-Host ""
    Write-Host "FAILED - HTML file was not created." -ForegroundColor Red
    Write-Host "Check the Python output above for errors." -ForegroundColor Red
}

# Cleanup
if ([System.IO.File]::Exists($tmpJson)) {
    [System.IO.File]::Delete($tmpJson)
}

Write-Host ""
Write-Host "Test complete. Press any key to exit."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

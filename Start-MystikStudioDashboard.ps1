$ErrorActionPreference = "Stop"

$StudioRoot  = $PSScriptRoot
$Creators    = Join-Path $StudioRoot "Creators"
$Webpage     = Join-Path $StudioRoot "webpage"
$BookDesign  = Join-Path $StudioRoot "book-design"
$Shared      = Join-Path $StudioRoot "shared"
$ComfyOutput = "C:\Users\Michael\Documents\ComfyUI\output"
$ComfyInput  = "C:\Users\Michael\Documents\ComfyUI\input"

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$form               = New-Object System.Windows.Forms.Form
$form.Text          = "MystikStudio Dashboard"
$form.Width         = 420
$form.Height        = 620
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox    = $false
$form.Font           = New-Object System.Drawing.Font("Segoe UI", 9)
$form.BackColor      = [System.Drawing.Color]::FromArgb(24, 24, 32)

# Title
$title = New-Object System.Windows.Forms.Label
$title.Text = "MystikStudio"
$title.Font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
$title.ForeColor = [System.Drawing.Color]::FromArgb(220, 180, 100)
$title.AutoSize = $true
$title.Left = 20; $title.Top = 14
$form.Controls.Add($title)

$subtitle = New-Object System.Windows.Forms.Label
$subtitle.Text = "Creative Toolkit Dashboard"
$subtitle.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$subtitle.ForeColor = [System.Drawing.Color]::FromArgb(130, 130, 150)
$subtitle.AutoSize = $true
$subtitle.Left = 22; $subtitle.Top = 42
$form.Controls.Add($subtitle)

# Separator
$sep = New-Object System.Windows.Forms.Label
$sep.BorderStyle = "Fixed3D"
$sep.Left = 16; $sep.Top = 68; $sep.Width = 374; $sep.Height = 2
$form.Controls.Add($sep)

$y = 78

function Add-SectionHeader {
    param([string]$Text, [int]$Y)
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = $Text
    $lbl.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $lbl.ForeColor = [System.Drawing.Color]::FromArgb(140, 160, 200)
    $lbl.AutoSize = $true
    $lbl.Left = 20; $lbl.Top = $Y
    $form.Controls.Add($lbl)
    return $lbl
}

function Add-Button {
    param([string]$Text, [int]$X, [int]$Y, [int]$W, [int]$H, [scriptblock]$Action, [System.Drawing.Color]$BgColor, [string]$Tooltip)
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = $Text
    $btn.Left = $X; $btn.Top = $Y; $btn.Width = $W; $btn.Height = $H
    $btn.FlatStyle = "Flat"
    $btn.BackColor = $BgColor
    $btn.ForeColor = [System.Drawing.Color]::White
    $btn.Font = New-Object System.Drawing.Font("Segoe UI", 8.5)
    $btn.FlatAppearance.BorderSize = 0
    if ($Tooltip) {
        $tip = New-Object System.Windows.Forms.ToolTip
        $tip.SetToolTip($btn, $Tooltip)
    }
    $btn.Add_Click($Action)
    $form.Controls.Add($btn)
    return $btn
}

# ------ Creators Section ------
$y += 2
Add-SectionHeader -Text "CREATORS" -Y $y; $y += 22

Add-Button -Text "LoRA Tester" -X 20 -Y $y -W 175 -H 34 `
    -Action { Start-Process (Join-Path $StudioRoot "Creators\lora-tester\Open LoRA Tester.vbs") } `
    -BgColor [System.Drawing.Color]::FromArgb(50, 90, 140) `
    -Tooltip "Test LoRAs with ComfyUI"

Add-Button -Text "Character Generator" -X 208 -Y $y -W 175 -H 34 `
    -Action { Start-Process (Join-Path $StudioRoot "Creators\character-generator\Open Character Generator.vbs") } `
    -BgColor [System.Drawing.Color]::FromArgb(80, 60, 130) `
    -Tooltip "Generate book characters with pose and identity locking"

$y += 40

Add-Button -Text "Debug LoRA Workflow" -X 20 -Y $y -W 175 -H 34 `
    -Action { Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -NoExit -File `"$StudioRoot\Creators\lora-tester\Debug-LoraWorkflow.ps1`"" } `
    -BgColor [System.Drawing.Color]::FromArgb(60, 60, 70) `
    -Tooltip "Inspect JSON sent to ComfyUI"

Add-Button -Text "Test Session Report" -X 208 -Y $y -W 175 -H 34 `
    -Action { Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -NoExit -File `"$StudioRoot\Creators\lora-tester\Test-SessionReport.ps1`"" } `
    -BgColor [System.Drawing.Color]::FromArgb(60, 60, 70) `
    -Tooltip "Generate session report HTML"

$y += 48

# ------ ComfyUI Section ------
Add-SectionHeader -Text "COMFYUI" -Y $y; $y += 22

Add-Button -Text "Open Workflows Folder" -X 20 -Y $y -W 175 -H 34 `
    -Action { Start-Process (Join-Path $StudioRoot "Creators\comfyui\workflows") } `
    -BgColor [System.Drawing.Color]::FromArgb(50, 80, 50) `
    -Tooltip "SDXL workflow JSON files"

Add-Button -Text "Open Scripts Folder" -X 208 -Y $y -W 175 -H 34 `
    -Action { Start-Process (Join-Path $StudioRoot "Creators\comfyui\scripts") } `
    -BgColor [System.Drawing.Color]::FromArgb(50, 80, 50) `
    -Tooltip "ComfyUI invoke and import scripts"

$y += 40

Add-Button -Text "ComfyUI Output" -X 20 -Y $y -W 175 -H 34 `
    -Action { Start-Process $ComfyOutput } `
    -BgColor [System.Drawing.Color]::FromArgb(70, 55, 40) `
    -Tooltip "Generated images"

Add-Button -Text "ComfyUI Input" -X 208 -Y $y -W 175 -H 34 `
    -Action { Start-Process $ComfyInput } `
    -BgColor [System.Drawing.Color]::FromArgb(70, 55, 40) `
    -Tooltip "ControlNet and input images"

$y += 48

# ------ Webpage Section ------
Add-SectionHeader -Text "WEB APPS" -Y $y; $y += 22

Add-Button -Text "Story Dashboard" -X 20 -Y $y -W 175 -H 34 `
    -Action { Start-Process (Join-Path $StudioRoot "webpage\story-dashboard\Open Story Dashboard.cmd") } `
    -BgColor [System.Drawing.Color]::FromArgb(120, 70, 40) `
    -Tooltip "Local web dashboard for book tracking"

Add-Button -Text "Story Dashboard App" -X 208 -Y $y -W 175 -H 34 `
    -Action { Start-Process (Join-Path $StudioRoot "webpage\story-dashboard-app\Open Story Dashboard App.cmd") } `
    -BgColor [System.Drawing.Color]::FromArgb(120, 70, 40) `
    -Tooltip "Desktop app variant"

$y += 48

# ------ Project Section ------
Add-SectionHeader -Text "PROJECT FILES" -Y $y; $y += 22

Add-Button -Text "Book Design" -X 20 -Y $y -W 113 -H 34 `
    -Action { Start-Process $BookDesign } `
    -BgColor [System.Drawing.Color]::FromArgb(55, 55, 70) `
    -Tooltip "Assets, manuscript, notes, reference"

Add-Button -Text "Shared Modules" -X 140 -Y $y -W 113 -H 34 `
    -Action { Start-Process $Shared } `
    -BgColor [System.Drawing.Color]::FromArgb(55, 55, 70) `
    -Tooltip "SessionModule.ps1, Sizes.ps1"

Add-Button -Text "Reports" -X 260 -Y $y -W 113 -H 34 `
    -Action { Start-Process "C:\Users\Michael\Documents\ComfyUI\Reports" } `
    -BgColor [System.Drawing.Color]::FromArgb(55, 55, 70) `
    -Tooltip "Session report HTML files"

$y += 40

Add-Button -Text "ComfyUI Models/LoRAs" -X 20 -Y $y -W 175 -H 34 `
    -Action { Start-Process "C:\Users\Michael\Documents\ComfyUI\models\loras" } `
    -BgColor [System.Drawing.Color]::FromArgb(55, 55, 70) `
    -Tooltip "Browse LoRA files"

Add-Button -Text "ComfyUI Checkpoints" -X 208 -Y $y -W 175 -H 34 `
    -Action { Start-Process "C:\Users\Michael\Documents\ComfyUI\models\checkpoints" } `
    -BgColor [System.Drawing.Color]::FromArgb(55, 55, 70) `
    -Tooltip "Browse checkpoint files"

$y += 48

# ------ Footer ------
$sep2 = New-Object System.Windows.Forms.Label
$sep2.BorderStyle = "Fixed3D"
$sep2.Left = 16; $sep2.Top = $y + 4; $sep2.Width = 374; $sep2.Height = 2
$form.Controls.Add($sep2)

$version = New-Object System.Windows.Forms.Label
$version.Text = "MystikStudio  |  $StudioRoot"
$version.ForeColor = [System.Drawing.Color]::FromArgb(80, 80, 90)
$version.Font = New-Object System.Drawing.Font("Segoe UI", 7)
$version.AutoSize = $true
$version.Left = 20; $version.Top = $y + 14
$form.Controls.Add($version)

# ------ Close/Dismiss ------
$btnClose = New-Object System.Windows.Forms.Button
$btnClose.Text = "Close"
$btnClose.Left = 318; $btnClose.Top = $y + 10; $btnClose.Width = 56; $btnClose.Height = 24
$btnClose.FlatStyle = "Flat"
$btnClose.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 70)
$btnClose.ForeColor = [System.Drawing.Color]::FromArgb(160, 160, 170)
$btnClose.FlatAppearance.BorderSize = 0
$btnClose.Font = New-Object System.Drawing.Font("Segoe UI", 8)
$btnClose.Add_Click({ $form.Close() })
$form.Controls.Add($btnClose)

$form.Add_Shown({ $form.Activate() })
[void]$form.ShowDialog()

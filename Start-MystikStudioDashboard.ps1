# MystikStudio Modular Dashboard
# Auto-discovers tools by scanning Creators/ and webpage/ for tool.json
# Drop a new folder with tool.json + launcher -> auto button

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$StudioRoot = $PSScriptRoot

# -------------------------------------------------------------------
# Discovery
# -------------------------------------------------------------------
function Find-Tools {
    param([string]$ScanPath, [string]$SectionId)
    $tools = @()
    if (-not (Test-Path $ScanPath)) { return $tools }
    Get-ChildItem $ScanPath -Directory | Where-Object { $_.Name -notlike '_*' } | ForEach-Object {
        $configPath = Join-Path $_.FullName "tool.json"
        if (-not (Test-Path $configPath)) { return }
        try { $cfg = Get-Content $configPath -Raw | ConvertFrom-Json } catch { return }
        $launcher = if ($cfg.launcher) { Join-Path $_.FullName ([string]$cfg.launcher) } else { $null }
        $folder   = if ($cfg.folder)   { Join-Path $_.FullName ([string]$cfg.folder) }     else { $null }
        $tools += [pscustomobject]@{
            Id          = $_.Name
            Name        = if ($cfg.name) { [string]$cfg.name } else { $_.Name }
            Description = if ($cfg.description) { [string]$cfg.description } else { "" }
            Color       = if ($cfg.color) { [string]$cfg.color } else { "#444444" }
            Launcher    = $launcher
            Folder      = $folder
            Section     = $SectionId
        }
    }
    return $tools
}

$allTools = @()
$allTools += Find-Tools -ScanPath (Join-Path $StudioRoot "Creators") -SectionId "creators"
$allTools += Find-Tools -ScanPath (Join-Path $StudioRoot "webpage")  -SectionId "webpage"

# -------------------------------------------------------------------
# Fixed items
# -------------------------------------------------------------------
$fixedCreators = @(
    @{Name="ComfyUI Output"; Desc="Generated images";    Color="#463728"; Path="C:\Users\Michael\Documents\ComfyUI\output"},
    @{Name="ComfyUI Input";  Desc="ControlNet images";   Color="#463728"; Path="C:\Users\Michael\Documents\ComfyUI\input"}
)

$fixedComfy = @(
    @{Name="Workflows Folder"; Desc="SDXL workflow JSONs"; Color="#325032"; Path=(Join-Path $StudioRoot "Creators\comfyui\workflows")},
    @{Name="Scripts Folder";   Desc="ComfyUI scripts";     Color="#325032"; Path=(Join-Path $StudioRoot "Creators\comfyui\scripts")}
)

$fixedProject = @(
    @{Name="Book Design";     Desc="Assets, manuscript";  Color="#373746"; Path=(Join-Path $StudioRoot "book-design")},
    @{Name="Shared Modules";  Desc="Session, Sizes";      Color="#373746"; Path=(Join-Path $StudioRoot "shared")},
    @{Name="Reports";         Desc="Session HTML";        Color="#373746"; Path="C:\Users\Michael\Documents\ComfyUI\Reports"},
    @{Name="LoRA Models";     Desc="Browse LoRA files";   Color="#373746"; Path="C:\Users\Michael\Documents\ComfyUI\models\loras"},
    @{Name="Checkpoints";     Desc="Checkpoint files";   Color="#373746"; Path="C:\Users\Michael\Documents\ComfyUI\models\checkpoints"}
)

$webLinks = @(
    @{Name="GitHub Repo";     Desc="MystikStudio on GitHub"; Color="#24292E"; Url="https://github.com/Mystikvoyd/MystikStudio"}
)

# -------------------------------------------------------------------
# Form
# -------------------------------------------------------------------
$form               = New-Object System.Windows.Forms.Form
$form.Text          = "MystikStudio Dashboard"
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox    = $false
$form.Font           = New-Object System.Drawing.Font("Segoe UI", 9)
$form.BackColor      = [System.Drawing.Color]::FromArgb(24, 24, 32)

function Parse-Color {
    param([string]$Hex)
    if ($Hex -match '^#?([0-9a-fA-F]{2})([0-9a-fA-F]{2})([0-9a-fA-F]{2})$') {
        return [System.Drawing.Color]::FromArgb([convert]::ToInt32($Matches[1], 16),
                                                 [convert]::ToInt32($Matches[2], 16),
                                                 [convert]::ToInt32($Matches[3], 16))
    }
    return [System.Drawing.Color]::FromArgb(60, 60, 70)
}

function Add-SectionLabel {
    param([string]$Text, [int]$Y)
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = $Text
    $lbl.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $lbl.ForeColor = [System.Drawing.Color]::FromArgb(140, 160, 200)
    $lbl.AutoSize = $true; $lbl.Left = 20; $lbl.Top = $Y
    $form.Controls.Add($lbl)
}

function New-Button {
    param([int]$X, [int]$Y, [int]$W, [int]$H, [string]$Text, [string]$Tip, [string]$ColorHex,
          [string]$OpenFolder, [string]$OpenFile, [string]$OpenUrl)
    
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = $Text; $btn.Left = $X; $btn.Top = $Y; $btn.Width = $W; $btn.Height = $H
    $btn.FlatStyle = "Flat"; $btn.ForeColor = [System.Drawing.Color]::White
    $btn.BackColor = Parse-Color -Hex $ColorHex
    $btn.Font = New-Object System.Drawing.Font("Segoe UI", 8.5)
    $btn.FlatAppearance.BorderSize = 0
    
    if ($Tip) { (New-Object System.Windows.Forms.ToolTip).SetToolTip($btn, $Tip) }
    
    # CRITICAL: Resolve paths to strings before creating closure
    if ($OpenFile -and (Test-Path -LiteralPath $OpenFile)) {
        $target = $OpenFile
        $btn.Add_Click({ Start-Process -FilePath $target }.GetNewClosure())
    }
    elseif ($OpenFolder -and (Test-Path -LiteralPath $OpenFolder)) {
        $target = $OpenFolder
        $btn.Add_Click({ Start-Process -FilePath $target }.GetNewClosure())
    }
    elseif ($OpenUrl) {
        $target = $OpenUrl
        $btn.Add_Click({ Start-Process $target }.GetNewClosure())
    }
    else {
        $btn.Enabled = $false
        $btn.Text += " (missing)"
    }
    
    $form.Controls.Add($btn)
    return $btn
}

# ----- Layout -----
$y = 14

$title = New-Object System.Windows.Forms.Label
$title.Text = "MystikStudio"; $title.Font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
$title.ForeColor = [System.Drawing.Color]::FromArgb(220, 180, 100)
$title.AutoSize = $true; $title.Left = 20; $title.Top = $y
$form.Controls.Add($title); $y += 28

$sub = New-Object System.Windows.Forms.Label
$sub.Text = "Modular Creative Toolkit"; $sub.ForeColor = [System.Drawing.Color]::FromArgb(130, 130, 150)
$sub.AutoSize = $true; $sub.Left = 22; $sub.Top = $y
$form.Controls.Add($sub); $y += 24

$sep = New-Object System.Windows.Forms.Label
$sep.BorderStyle = "Fixed3D"; $sep.Left = 16; $sep.Top = $y; $sep.Width = 374; $sep.Height = 2
$form.Controls.Add($sep); $y += 10

# ----- Helper to lay out 2-column button rows -----
function Layout-Buttons {
    param([object[]]$Items, [string]$Type)
    $cx = 20
    foreach ($item in $Items) {
        switch ($Type) {
            'tool' {
                if ($item.Folder) {
                    New-Button -X $cx -Y $y -W 175 -H 34 -Text $item.Name -Tip $item.Description `
                        -ColorHex $item.Color -OpenFolder $item.Folder
                } else {
                    New-Button -X $cx -Y $y -W 175 -H 34 -Text $item.Name -Tip $item.Description `
                        -ColorHex $item.Color -OpenFile $item.Launcher
                }
            }
            'path' {
                New-Button -X $cx -Y $y -W 175 -H 34 -Text $item.Name -Tip $item.Desc `
                    -ColorHex $item.Color -OpenFolder $item.Path
            }
            'url' {
                New-Button -X $cx -Y $y -W 175 -H 34 -Text $item.Name -Tip $item.Desc `
                    -ColorHex $item.Color -OpenUrl $item.Url
            }
        }
        if ($cx -eq 20) { $cx = 208 } else { $cx = 20; $y += 40 }
    }
    if ($cx -eq 208) { $y += 40 }
}

# ----- CREATORS section -----
Add-SectionLabel -Text "CREATORS" -Y $y; $y += 22
Layout-Buttons -Items ($allTools | Where-Object { $_.Section -eq "creators" }) -Type "tool"
Layout-Buttons -Items $fixedCreators -Type "path"
$y += 8

# ----- COMFYUI section -----
Add-SectionLabel -Text "COMFYUI" -Y $y; $y += 22
Layout-Buttons -Items $fixedComfy -Type "path"
$y += 8

# ----- WEB APPS section -----
$webTools = $allTools | Where-Object { $_.Section -eq "webpage" }
if ($webTools) {
    Add-SectionLabel -Text "WEB APPS" -Y $y; $y += 22
    Layout-Buttons -Items $webTools -Type "tool"
    $y += 8
}

# ----- WEB LINKS section -----
Add-SectionLabel -Text "LINKS" -Y $y; $y += 22
Layout-Buttons -Items $webLinks -Type "url"
$y += 8

# ----- PROJECT FILES section -----
Add-SectionLabel -Text "PROJECT FILES" -Y $y; $y += 22
$cx = 20; $count = 0
foreach ($item in $fixedProject) {
    $w = if ($count -ge 3) { 175 } else { 113 }
    if ($count -eq 3) { $cx = 20; $y += 40 }
    New-Button -X $cx -Y $y -W $w -H 34 -Text $item.Name -Tip $item.Desc `
        -ColorHex $item.Color -OpenFolder $item.Path
    $cx += ($w + 7)
    if ($cx -gt 300) { $cx = 20; $y += 40 }
    $count++
}
if ($cx -ne 20) { $y += 40 }
$y += 10

# ----- Footer -----
$sep2 = New-Object System.Windows.Forms.Label
$sep2.BorderStyle = "Fixed3D"; $sep2.Left = 16; $sep2.Top = $y; $sep2.Width = 374; $sep2.Height = 2
$form.Controls.Add($sep2); $y += 12

$ver = New-Object System.Windows.Forms.Label
$ver.Text = "MystikStudio  |  H:\MystikStudio  |  $(@($allTools).Count) tool(s)"
$ver.ForeColor = [System.Drawing.Color]::FromArgb(80, 80, 90)
$ver.Font = New-Object System.Drawing.Font("Segoe UI", 7)
$ver.AutoSize = $true; $ver.Left = 20; $ver.Top = $y
$form.Controls.Add($ver)

$btnClose = New-Object System.Windows.Forms.Button
$btnClose.Text = "Close"; $btnClose.Left = 318; $btnClose.Top = $y - 2
$btnClose.Width = 56; $btnClose.Height = 24; $btnClose.FlatStyle = "Flat"
$btnClose.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 70)
$btnClose.ForeColor = [System.Drawing.Color]::FromArgb(160, 160, 170)
$btnClose.Font = New-Object System.Drawing.Font("Segoe UI", 8)
$btnClose.FlatAppearance.BorderSize = 0
$btnClose.Add_Click({ $form.Close() })
$form.Controls.Add($btnClose)

$form.Height = $y + 60
$form.Width = 420
$form.Add_Shown({ $form.Activate() })
[void]$form.ShowDialog()

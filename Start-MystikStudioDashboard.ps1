# MystikStudio Modular Dashboard
# Auto-discovers tools by scanning Creators/ and webpage/ for tool.json

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$StudioRoot = $PSScriptRoot

# -------------------------------------------------------------------
# Discovery
# -------------------------------------------------------------------
function Find-Tools {
    param([string]$ScanPath)
    $tools = @()
    if (-not (Test-Path $ScanPath)) { return $tools }
    Get-ChildItem $ScanPath -Directory | Where-Object { $_.Name -notlike '_*' } | ForEach-Object {
        $cfgPath = Join-Path $_.FullName "tool.json"
        if (-not (Test-Path $cfgPath)) { return }
        try { $cfg = Get-Content $cfgPath -Raw | ConvertFrom-Json } catch { return }
        $tools += [pscustomobject]@{
            Name        = if ($cfg.name) { [string]$cfg.name } else { $_.Name }
            Description = if ($cfg.description) { [string]$cfg.description } else { "" }
            Color       = if ($cfg.color) { [string]$cfg.color } else { "#444" }
            Launcher    = if ($cfg.launcher) { Join-Path $_.FullName ([string]$cfg.launcher) } else { $null }
            Folder      = if ($cfg.folder)   { Join-Path $_.FullName ([string]$cfg.folder) }     else { $null }
        }
    }
    return $tools
}

$creatorTools = Find-Tools -ScanPath (Join-Path $StudioRoot "Creators")
$webTools     = Find-Tools -ScanPath (Join-Path $StudioRoot "webpage")

# -------------------------------------------------------------------
# Color helper
# -------------------------------------------------------------------
function ColorFromHex([string]$Hex) {
    if ($Hex -match '^#?([0-9a-fA-F]{2})([0-9a-fA-F]{2})([0-9a-fA-F]{2})$') {
        return [System.Drawing.Color]::FromArgb([int]::Parse($Matches[1],'HexNumber'),
                                                 [int]::Parse($Matches[2],'HexNumber'),
                                                 [int]::Parse($Matches[3],'HexNumber'))
    }
    return [System.Drawing.Color]::FromArgb(60,60,70)
}

# -------------------------------------------------------------------
# Form
# -------------------------------------------------------------------
$form = New-Object System.Windows.Forms.Form
$form.Text = "MystikStudio Dashboard"
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$form.BackColor = [System.Drawing.Color]::FromArgb(24,24,32)
$form.AutoScroll = $true
$form.ClientSize = New-Object System.Drawing.Size(400, 600)

$panel = New-Object System.Windows.Forms.Panel
$panel.AutoSize = $true
$panel.AutoSizeMode = "GrowAndShrink"
$panel.BackColor = [System.Drawing.Color]::FromArgb(24,24,32)
$panel.Left = 0; $panel.Top = 0
$panel.MinimumSize = New-Object System.Drawing.Size(400, 0)
$form.Controls.Add($panel)

# ----- Header -----
function Add-Header {
    $p = New-Object System.Windows.Forms.Panel
    $p.Width = 390; $p.Height = 56; $p.Left = 5; $p.Top = $y
    $p.BackColor = [System.Drawing.Color]::FromArgb(24,24,32)
    
    $t = New-Object System.Windows.Forms.Label
    $t.Text = "MystikStudio"; $t.Font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
    $t.ForeColor = [System.Drawing.Color]::FromArgb(220,180,100); $t.AutoSize = $true
    $t.Left = 8; $t.Top = 4; $p.Controls.Add($t)
    
    $s = New-Object System.Windows.Forms.Label
    $s.Text = "Modular Creative Toolkit"; $s.ForeColor = [System.Drawing.Color]::FromArgb(130,130,150)
    $s.AutoSize = $true; $s.Left = 10; $s.Top = 30; $p.Controls.Add($s)
    
    $panel.Controls.Add($p)
    $script:y += 60
}

# ----- Section label -----
function Add-Section([string]$Text) {
    $p = New-Object System.Windows.Forms.Panel
    $p.Width = 390; $p.Height = 22; $p.Left = 5; $p.Top = $script:y
    
    $l = New-Object System.Windows.Forms.Label
    $l.Text = $Text; $l.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $l.ForeColor = [System.Drawing.Color]::FromArgb(140,160,200); $l.AutoSize = $true
    $l.Left = 8; $l.Top = 0; $p.Controls.Add($l)
    
    $panel.Controls.Add($p)
    $script:y += 26
}

# ----- Button grid: 2 columns, 175px each, 40px row height -----
function Add-ButtonGrid([object[]]$Items, [string]$Mode) {
    $cx = 5; $startY = $script:y
    
    for ($i = 0; $i -lt $Items.Count; $i++) {
        $item = $Items[$i]
        $col = $i % 2
        $row = [Math]::Floor($i / 2)
        $bx = 5 + $col * 192
        $by = $startY + $row * 42
        
        $btn = New-Object System.Windows.Forms.Button
        $btn.Text = [string]$item.Name
        $btn.Left = $bx; $btn.Top = $by; $btn.Width = 184; $btn.Height = 36
        $btn.FlatStyle = "Flat"; $btn.ForeColor = [System.Drawing.Color]::White
        $btn.Font = New-Object System.Drawing.Font("Segoe UI", 8.5)
        $btn.FlatAppearance.BorderSize = 0
        
        if ($Mode -eq 'tool') {
            $btn.BackColor = ColorFromHex ([string]$item.Color)
            $target = if ($item.Folder) { $item.Folder } else { $item.Launcher }
        }
        elseif ($Mode -eq 'path') {
            $btn.BackColor = ColorFromHex ([string]$item.Color)
            $target = [string]$item.Path
        }
        elseif ($Mode -eq 'url') {
            $btn.BackColor = ColorFromHex ([string]$item.Color)
            $target = [string]$item.Url
        }
        
        if ($target) {
            $finalTarget = $target
            if ($Mode -eq 'url') {
                $btn.Add_Click({ Start-Process $finalTarget }.GetNewClosure())
            } else {
                $btn.Add_Click({ Start-Process -FilePath $finalTarget }.GetNewClosure())
            }
        } else {
            $btn.Enabled = $false
        }
        
        if ($item.Description) {
            (New-Object System.Windows.Forms.ToolTip).SetToolTip($btn, [string]$item.Description)
        }
        
        $panel.Controls.Add($btn)
    }
    
    $totalRows = [Math]::Ceiling($Items.Count / 2.0)
    if ($totalRows -eq 0) { $totalRows = 0 }
    $script:y += [int]($totalRows * 42) + 10
}

# ----- Thin 3-column row for small buttons -----
function Add-SmallRow([object[]]$Items) {
    $startY = $script:y
    for ($i = 0; $i -lt $Items.Count; $i++) {
        $item = $Items[$i]
        $bx = 5 + $i * 128
        $btn = New-Object System.Windows.Forms.Button
        $btn.Text = [string]$item.Name
        $btn.Left = $bx; $btn.Top = $startY; $btn.Width = 120; $btn.Height = 36
        $btn.FlatStyle = "Flat"; $btn.ForeColor = [System.Drawing.Color]::White
        $btn.Font = New-Object System.Drawing.Font("Segoe UI", 8.5)
        $btn.FlatAppearance.BorderSize = 0
        $btn.BackColor = ColorFromHex ([string]$item.Color)
        
        $finalPath = [string]$item.Path
        $btn.Add_Click({ Start-Process -FilePath $finalPath }.GetNewClosure())
        
        if ($item.Desc) {
            (New-Object System.Windows.Forms.ToolTip).SetToolTip($btn, [string]$item.Desc)
        }
        $panel.Controls.Add($btn)
    }
    $script:y += 46
}

# ----- Separator -----
function Add-Separator {
    $s = New-Object System.Windows.Forms.Label
    $s.BorderStyle = "Fixed3D"; $s.Left = 5; $s.Top = $script:y; $s.Width = 384; $s.Height = 2
    $panel.Controls.Add($s); $script:y += 8
}

# ===================================================================
# Build the dashboard
# ===================================================================
$script:y = 4

Add-Header
Add-Separator

# --- CREATORS ---
Add-Section "CREATORS"
$creatorItems = @($creatorTools) + @(
    [pscustomobject]@{Name="ComfyUI Output"; Description="Generated images";    Color="#463728"; Path="C:\Users\Michael\Documents\ComfyUI\output"}
    [pscustomobject]@{Name="ComfyUI Input";  Description="ControlNet images";   Color="#463728"; Path="C:\Users\Michael\Documents\ComfyUI\input"}
)
Add-ButtonGrid -Items $creatorItems -Mode "tool"

# --- COMFYUI ---
Add-Section "COMFYUI"
Add-ButtonGrid -Items @(
    [pscustomobject]@{Name="Workflows"; Description="SDXL workflow JSONs"; Color="#325032"; Path=(Join-Path $StudioRoot "Creators\comfyui\workflows")}
    [pscustomobject]@{Name="Scripts";   Description="ComfyUI invoke scripts"; Color="#325032"; Path=(Join-Path $StudioRoot "Creators\comfyui\scripts")}
) -Mode "path"

# --- WEB APPS ---
if ($webTools.Count -gt 0) {
    Add-Section "WEB APPS"
    Add-ButtonGrid -Items @($webTools) -Mode "tool"
}

# --- LINKS ---
Add-Section "LINKS"
Add-ButtonGrid -Items @(
    [pscustomobject]@{Name="GitHub Repo"; Description="MystikStudio on GitHub"; Color="#24292E"; Url="https://github.com/Mystikvoyd/MystikStudio"}
) -Mode "url"

# --- PROJECT FILES ---
Add-Section "PROJECT FILES"
Add-SmallRow -Items @(
    [pscustomobject]@{Name="Book Design";    Desc="Assets, manuscript"; Color="#373746"; Path=(Join-Path $StudioRoot "book-design")}
    [pscustomobject]@{Name="Shared";         Desc="Session, Sizes";     Color="#373746"; Path=(Join-Path $StudioRoot "shared")}
    [pscustomobject]@{Name="Reports";        Desc="Session HTML";       Color="#373746"; Path="C:\Users\Michael\Documents\ComfyUI\Reports"}
)
Add-SmallRow -Items @(
    [pscustomobject]@{Name="LoRA Models";    Desc="Browse LoRA files";    Color="#373746"; Path="C:\Users\Michael\Documents\ComfyUI\models\loras"}
    [pscustomobject]@{Name="Checkpoints";    Desc="Checkpoint files";     Color="#373746"; Path="C:\Users\Michael\Documents\ComfyUI\models\checkpoints"}
)

# --- Footer ---
Add-Separator
$footer = New-Object System.Windows.Forms.Label
$footer.Text = "MystikStudio  |  H:\MystikStudio  |  $(@($creatorTools).Count + @($webTools).Count) tools"
$footer.ForeColor = [System.Drawing.Color]::FromArgb(80,80,90)
$footer.Font = New-Object System.Drawing.Font("Segoe UI", 7)
$footer.AutoSize = $true; $footer.Left = 10; $footer.Top = $script:y
$panel.Controls.Add($footer)
$script:y += 30

# Auto-size form to content
$form.ClientSize = New-Object System.Drawing.Size(400, [Math]::Min($script:y + 10, 900))
$form.Add_Shown({ $form.Activate() })
[void]$form.ShowDialog()

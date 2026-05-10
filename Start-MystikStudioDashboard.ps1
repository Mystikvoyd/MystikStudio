# MystikStudio Dashboard — Split Panel: folders left, tools right

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$StudioRoot = $PSScriptRoot
$ComfyRoot  = "C:\Users\Michael\Documents\ComfyUI"

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
$form.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$form.BackColor = [System.Drawing.Color]::FromArgb(24,24,32)
$form.ClientSize = New-Object System.Drawing.Size(800, 700)
$iconPath = Join-Path $PSScriptRoot "Icons\Mytikvoyd Studios.ico"
if (Test-Path $iconPath) { $form.Icon = [System.Drawing.Icon]::new($iconPath) }

# Main split: folders panel (left) | tools panel (right)
$split = New-Object System.Windows.Forms.SplitContainer
$split.Dock = "Fill"
$split.SplitterWidth = 4
$split.SplitterIncrement = 1
$split.BackColor = [System.Drawing.Color]::FromArgb(40,40,48)
$form.Controls.Add($split)
# Set min sizes after adding to form so Width is known
$split.Panel1MinSize = 120
$split.Panel2MinSize = 350
$split.SplitterDistance = 240

# ===================================================================
# LEFT PANEL — Folder browser
# ===================================================================
$leftPanel = $split.Panel1
$leftPanel.BackColor = [System.Drawing.Color]::FromArgb(18,18,24)
$leftPanel.Padding = New-Object System.Windows.Forms.Padding(4)

$lblFolders = New-Object System.Windows.Forms.Label
$lblFolders.Text = "  EXPLORER"
$lblFolders.Font = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Bold)
$lblFolders.ForeColor = [System.Drawing.Color]::FromArgb(140,160,200)
$lblFolders.BackColor = [System.Drawing.Color]::FromArgb(30,30,40)
$lblFolders.Height = 24
$lblFolders.Left = 4; $lblFolders.Top = 4; $lblFolders.TextAlign = "MiddleLeft"
$lblFolders.Anchor = "Top, Left, Right"
$leftPanel.Controls.Add($lblFolders)

$tree = New-Object System.Windows.Forms.TreeView
$tree.Left = 4; $tree.Top = 30
$tree.Width = $leftPanel.ClientSize.Width - 8
$tree.Height = $leftPanel.Height - 36
$tree.Anchor = "Top, Bottom, Left, Right"
$tree.BackColor = [System.Drawing.Color]::FromArgb(22,22,30)
$tree.ForeColor = [System.Drawing.Color]::FromArgb(200,200,210)
$tree.BorderStyle = "None"
$tree.Font = New-Object System.Drawing.Font("Segoe UI", 8.5)
$tree.LineColor = [System.Drawing.Color]::FromArgb(50,50,60)
$tree.HotTracking = $true
$tree.FullRowSelect = $true
$tree.ShowLines = $true
$tree.Indent = 16
$leftPanel.Controls.Add($tree)

# Build tree nodes
function Add-FolderNode {
    param($Parent, [string]$Label, [string]$Path, [string]$Color = "#555")
    $node = New-Object System.Windows.Forms.TreeNode
    $node.Text = $Label
    $node.Tag = $Path
    $node.ForeColor = ColorFromHex $Color
    $Parent.Nodes.Add($node) | Out-Null
    return $node
}

$root = Add-FolderNode -Parent $tree -Label "MystikStudio" -Path $StudioRoot -Color "#DCB464"
Add-FolderNode -Parent $root -Label "Creators"     -Path (Join-Path $StudioRoot "Creators")     -Color "#888"
Add-FolderNode -Parent $root -Label "book-design"  -Path (Join-Path $StudioRoot "book-design")  -Color "#888"
Add-FolderNode -Parent $root -Label "webpage"      -Path (Join-Path $StudioRoot "webpage")      -Color "#888"
Add-FolderNode -Parent $root -Label "shared"       -Path (Join-Path $StudioRoot "shared")       -Color "#888"
Add-FolderNode -Parent $root -Label "Icons"        -Path (Join-Path $StudioRoot "Icons")        -Color "#888"

$comfyNode = Add-FolderNode -Parent $tree -Label "ComfyUI" -Path $ComfyRoot -Color "#7CAB7C"
Add-FolderNode -Parent $comfyNode -Label "output"         -Path (Join-Path $ComfyRoot "output")        -Color "#888"
Add-FolderNode -Parent $comfyNode -Label "input"          -Path (Join-Path $ComfyRoot "input")         -Color "#888"
Add-FolderNode -Parent $comfyNode -Label "models/loras"   -Path (Join-Path $ComfyRoot "models\loras")  -Color "#888"
Add-FolderNode -Parent $comfyNode -Label "models/checkpoints" -Path (Join-Path $ComfyRoot "models\checkpoints") -Color "#888"
Add-FolderNode -Parent $comfyNode -Label "models/controlnet"  -Path (Join-Path $ComfyRoot "models\controlnet") -Color "#888"
Add-FolderNode -Parent $comfyNode -Label "models/vae"         -Path (Join-Path $ComfyRoot "models\vae") -Color "#888"

$root.Expand(); $comfyNode.Expand()

$tree.Add_NodeMouseDoubleClick({
    if ($_.Node.Tag) { Start-Process -FilePath ([string]$_.Node.Tag) }
})

# ===================================================================
# RIGHT PANEL — Tool buttons
# ===================================================================
$rightPanel = $split.Panel2
$rightPanel.BackColor = [System.Drawing.Color]::FromArgb(24,24,32)
$rightPanel.AutoScroll = $true

$rp = New-Object System.Windows.Forms.Panel
$rp.BackColor = [System.Drawing.Color]::FromArgb(24,24,32)
$rp.Anchor = "Top, Left, Right"
$rp.Width = $rightPanel.ClientSize.Width - 4
$rightPanel.Controls.Add($rp)
$rightPanel.Add_Resize({ $rp.Width = $rightPanel.ClientSize.Width - 4 })

$script:y = 4

function Add-Header {
    $p = New-Object System.Windows.Forms.Panel
    $p.Height = 56; $p.Left = 0; $p.Top = $script:y
    $p.Anchor = "Top, Left, Right"
    $p.BackColor = [System.Drawing.Color]::FromArgb(24,24,32)
    
    $logo = $null
    if (Test-Path $iconPath) {
        $logo = New-Object System.Windows.Forms.PictureBox
        $logo.Image = [System.Drawing.Icon]::new($iconPath).ToBitmap()
        $logo.Size = New-Object System.Drawing.Size(32, 32)
        $logo.SizeMode = "StretchImage"
        $logo.Left = 8; $logo.Top = 8
        $p.Controls.Add($logo)
    }
    
    $t = New-Object System.Windows.Forms.Label
    $t.Text = "MystikStudio"; $t.Font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
    $t.ForeColor = [System.Drawing.Color]::FromArgb(220,180,100); $t.AutoSize = $true
    $t.Left = 44; $t.Top = 4; $p.Controls.Add($t)
    
    $s = New-Object System.Windows.Forms.Label
    $s.Text = "Modular Creative Toolkit"; $s.ForeColor = [System.Drawing.Color]::FromArgb(130,130,150)
    $s.AutoSize = $true; $s.Left = 46; $s.Top = 30; $p.Controls.Add($s)
    
    $rp.Controls.Add($p); $script:y += 60
}

function Add-Section([string]$Text) {
    $l = New-Object System.Windows.Forms.Label
    $l.Text = "  $Text"; $l.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $l.ForeColor = [System.Drawing.Color]::FromArgb(140,160,200)
    $l.BackColor = [System.Drawing.Color]::FromArgb(30,30,42)
    $l.Left = 0; $l.Top = $script:y; $l.Height = 24
    $l.Anchor = "Top, Left, Right"
    $l.TextAlign = "MiddleLeft"
    $rp.Controls.Add($l); $script:y += 28
}

function New-Btn([string]$Text, [string]$Color, [string]$Desc, [string]$Target, [string]$Mode) {
    $bx = 5 + [int]$script:col * 192
    $by = $script:y + [int]$script:row * 42
    
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = $Text
    $btn.Left = $bx; $btn.Top = $by; $btn.Width = 184; $btn.Height = 36
    $btn.FlatStyle = "Flat"; $btn.ForeColor = [System.Drawing.Color]::White
    $btn.Font = New-Object System.Drawing.Font("Segoe UI", 8.5)
    $btn.FlatAppearance.BorderSize = 0
    $btn.BackColor = ColorFromHex $Color
    
    if ($Target) {
        $t = $Target
        if ($Mode -eq 'url') { $btn.Add_Click({ Start-Process $t }.GetNewClosure()) }
        else { $btn.Add_Click({ Start-Process -FilePath $t }.GetNewClosure()) }
    } else { $btn.Enabled = $false }
    
    if ($Desc) { (New-Object System.Windows.Forms.ToolTip).SetToolTip($btn, $Desc) }
    
    $rp.Controls.Add($btn)
    $script:col++
    if ([int]$script:col -ge 2) { $script:col = 0; $script:row++ }
}

function New-RowStart { $script:col = 0; $script:row = 0 }
function New-RowEnd { 
    if ([int]$script:col -gt 0) { $script:row++ }
    $script:y += ([int]$script:row * 42) + 6
    $script:col = 0; $script:row = 0 
}

# ===================================================================
# Build tools
# ===================================================================
Add-Header

# --- CREATORS ---
Add-Section "CREATORS"
New-RowStart
foreach ($t in $creatorTools) {
    if ($t.Folder) { New-Btn -Text $t.Name -Color $t.Color -Desc $t.Description -Target $t.Folder }
    else { New-Btn -Text $t.Name -Color $t.Color -Desc $t.Description -Target $t.Launcher }
}
# Creators also have output/input
New-Btn -Text "ComfyUI Output" -Color "#463728" -Desc "Generated images" -Target "C:\Users\Michael\Documents\ComfyUI\output"
New-Btn -Text "ComfyUI Input"  -Color "#463728" -Desc "ControlNet images" -Target "C:\Users\Michael\Documents\ComfyUI\input"
New-RowEnd

# --- COMFYUI ---
Add-Section "COMFYUI"
New-RowStart
New-Btn -Text "Workflows" -Color "#325032" -Desc "SDXL workflow JSONs" -Target (Join-Path $StudioRoot "Creators\comfyui\workflows")
New-Btn -Text "Scripts"   -Color "#325032" -Desc "ComfyUI scripts"    -Target (Join-Path $StudioRoot "Creators\comfyui\scripts")
New-RowEnd

# --- WEB APPS ---
if ($webTools.Count -gt 0) {
    Add-Section "WEB APPS"
    New-RowStart
    foreach ($t in $webTools) {
        if ($t.Folder) { New-Btn -Text $t.Name -Color $t.Color -Desc $t.Description -Target $t.Folder }
        else { New-Btn -Text $t.Name -Color $t.Color -Desc $t.Description -Target $t.Launcher }
    }
    New-RowEnd
}

# --- LINKS ---
Add-Section "LINKS"
New-RowStart
New-Btn -Text "GitHub Repo" -Color "#24292E" -Desc "MystikStudio on GitHub" -Target "https://github.com/Mystikvoyd/MystikStudio" -Mode "url"
New-RowEnd

# --- PROJECT ---
Add-Section "PROJECT FILES"
New-RowStart
New-Btn -Text "Book Design"      -Color "#373746" -Desc "Assets, manuscript" -Target (Join-Path $StudioRoot "book-design")
New-Btn -Text "Shared"           -Color "#373746" -Desc "Session, Sizes"    -Target (Join-Path $StudioRoot "shared")
New-Btn -Text "Reports"          -Color "#373746" -Desc "Session HTML"      -Target "C:\Users\Michael\Documents\ComfyUI\Reports"
New-RowEnd

New-RowStart
New-Btn -Text "LoRA Models"      -Color "#373746" -Desc "Browse LoRA files" -Target "C:\Users\Michael\Documents\ComfyUI\models\loras"
New-Btn -Text "Checkpoints"      -Color "#373746" -Desc "Checkpoint files"  -Target "C:\Users\Michael\Documents\ComfyUI\models\checkpoints"
New-Btn -Text "ControlNet"       -Color "#373746" -Desc "ControlNet models" -Target "C:\Users\Michael\Documents\ComfyUI\models\controlnet"
New-Btn -Text "VAE"              -Color "#373746" -Desc "VAE models"        -Target "C:\Users\Michael\Documents\ComfyUI\models\vae"
New-RowEnd

# --- Footer ---
$script:y += 4
$sep = New-Object System.Windows.Forms.Label
$sep.BorderStyle = "Fixed3D"; $sep.Left = 0; $sep.Top = $script:y; $sep.Anchor = "Top, Left, Right"; $sep.Height = 2
$rp.Controls.Add($sep); $script:y += 14

$footer = New-Object System.Windows.Forms.Label
$footer.Text = "MystikStudio  |  $(@($creatorTools).Count + @($webTools).Count) tools"
$footer.ForeColor = [System.Drawing.Color]::FromArgb(80,80,90)
$footer.Font = New-Object System.Drawing.Font("Segoe UI", 7)
$footer.AutoSize = $true; $footer.Left = 8; $footer.Top = $script:y
$rp.Controls.Add($footer)

# Set inner panel height to fit all content
$rp.Height = $script:y + 20

$form.Add_Shown({ $form.Activate() })
[void]$form.ShowDialog()

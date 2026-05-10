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
$form.ClientSize = New-Object System.Drawing.Size(1000, 760)
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

# Status bar at bottom of the window
$statusBar = New-Object System.Windows.Forms.Panel
$statusBar.Dock = "Bottom"; $statusBar.Height = 24
$statusBar.BackColor = [System.Drawing.Color]::FromArgb(28,28,38)

$statusLbl = New-Object System.Windows.Forms.Label
$statusLbl.Dock = "Fill"
$statusLbl.Text = "MystikStudio  |  $(@($creatorTools).Count + @($webTools).Count) tools"
$statusLbl.Font = New-Object System.Drawing.Font("Segoe UI", 7)
$statusLbl.ForeColor = [System.Drawing.Color]::FromArgb(130,130,140)
$statusLbl.TextAlign = "MiddleLeft"
$statusLbl.Padding = New-Object System.Windows.Forms.Padding(10,0,0,0)
$statusBar.Controls.Add($statusLbl)

# Reorder: status bar first, then split fills the rest
$form.Controls.Remove($split)
$form.Controls.Add($statusBar)
$form.Controls.Add($split)

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
# RIGHT PANEL — Tool buttons in 2-column panel layout
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

$script:y = 16  # top margin to prevent header cutoff

# -------------------------------------------------------------------
# Header
# -------------------------------------------------------------------
$hdr = New-Object System.Windows.Forms.Panel
$hdr.Height = 64; $hdr.Left = 0; $hdr.Top = $script:y
$hdr.Anchor = "Top, Left, Right"
$hdr.BackColor = [System.Drawing.Color]::FromArgb(24,24,32)

if (Test-Path $iconPath) {
    $logo = New-Object System.Windows.Forms.PictureBox
    $logo.Image = [System.Drawing.Icon]::new($iconPath).ToBitmap()
    $logo.Size = New-Object System.Drawing.Size(32, 32)
    $logo.SizeMode = "StretchImage"
    $logo.Left = 8; $logo.Top = 8
    $hdr.Controls.Add($logo)
}

$titleLbl = New-Object System.Windows.Forms.Label
$titleLbl.Text = "MystikStudio"
$titleLbl.Font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
$titleLbl.ForeColor = [System.Drawing.Color]::FromArgb(220,180,100)
$titleLbl.AutoSize = $true
$titleLbl.Left = 44; $titleLbl.Top = 4
$hdr.Controls.Add($titleLbl)

$subLbl = New-Object System.Windows.Forms.Label
$subLbl.Text = "Modular Creative Toolkit"
$subLbl.ForeColor = [System.Drawing.Color]::FromArgb(130,130,150)
$subLbl.AutoSize = $true; $subLbl.Left = 46; $subLbl.Top = 36
$hdr.Controls.Add($subLbl)

$rp.Controls.Add($hdr)
$script:y += 72

# -------------------------------------------------------------------
# Character Suite brand bar (centered, below header)
# -------------------------------------------------------------------
$csBar = New-Object System.Windows.Forms.Panel
$csBar.Height = 36; $csBar.Left = 0; $csBar.Top = $script:y
$csBar.Anchor = "Top, Left, Right"
$csBar.BackColor = [System.Drawing.Color]::FromArgb(22,22,30)

$csData = @(
    @{Text="Studio"; Color="#DC143C"}  # Crimson Red
    @{Text="forge";  Color="#FF69B4"}  # Pink
    @{Text="fusion"; Color="#8B00FF"}  # Purple
    @{Text="lab";    Color="#4169E1"}  # Blue
)
$csGap = 16
$csLabels = @()
foreach ($c in $csData) {
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = $c.Text
    $lbl.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $lbl.ForeColor = ColorFromHex $c.Color
    $lbl.AutoSize = $true
    $lbl.Top = 8
    $csBar.Controls.Add($lbl)
    $csLabels += $lbl
}
function Center-CSItems {
    $tw = 0; foreach ($l in $csLabels) { $tw += $l.Width }
    $tw += $csGap * ($csLabels.Count - 1)
    $lx = [math]::Max(8, ($csBar.Width - $tw) / 2)
    foreach ($l in $csLabels) { $l.Left = $lx; $lx += $l.Width + $csGap }
}
Center-CSItems
$csBar.Add_Resize({ Center-CSItems })
$rp.Controls.Add($csBar)
$script:y += 40

# -------------------------------------------------------------------
# 3-column panel layout
# -------------------------------------------------------------------
$colW = [math]::Floor(($rp.Width - 20) / 3)
$gap = 8

$col1 = New-Object System.Windows.Forms.Panel
$col1.BackColor = [System.Drawing.Color]::FromArgb(24,24,32)
$col1.Left = 4; $col1.Top = $script:y
$col1.Width = $colW
$col1.Anchor = "Top, Left"
$rp.Controls.Add($col1)

$col2 = New-Object System.Windows.Forms.Panel
$col2.BackColor = [System.Drawing.Color]::FromArgb(24,24,32)
$col2.Left = $colW + $gap + 4; $col2.Top = $script:y
$col2.Width = $colW
$col2.Anchor = "Top, Left"
$rp.Controls.Add($col2)

$col3 = New-Object System.Windows.Forms.Panel
$col3.BackColor = [System.Drawing.Color]::FromArgb(24,24,32)
$col3.Left = ($colW + $gap) * 2 + 4; $col3.Top = $script:y
$col3.Width = $rp.Width - ($colW + $gap) * 2 - 8
$col3.Anchor = "Top, Left, Right"
$rp.Controls.Add($col3)

# Panel box helper: creates a GroupBox with stacked buttons
function Add-PanelBox {
    param(
        [System.Windows.Forms.Panel]$Parent,
        [string]$Title,
        [object[]]$Buttons
    )
    $box = New-Object System.Windows.Forms.GroupBox
    $box.Text = "  $Title"
    $box.Left = 1; $box.Top = $Parent.Height + 4
    $box.Width = $Parent.Width - 2
    $box.ForeColor = [System.Drawing.Color]::FromArgb(170,180,200)
    $box.Font = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Bold)
    $box.BackColor = [System.Drawing.Color]::FromArgb(28,28,38)
    
    $yy = 20
    $bw = $box.Width - 16
    foreach ($b in $Buttons) {
        $btn = New-Object System.Windows.Forms.Button
        $btn.Text = $b.Text; $btn.Left = 8; $btn.Top = $yy
        $btn.Width = $bw; $btn.Height = 30
        $btn.FlatStyle = "Flat"; $btn.ForeColor = [System.Drawing.Color]::White
        $btn.Font = New-Object System.Drawing.Font("Segoe UI", 8.5)
        $btn.FlatAppearance.BorderSize = 0
        $btn.BackColor = ColorFromHex $b.Color
        $btn.TextAlign = "MiddleLeft"
        $btn.Padding = New-Object System.Windows.Forms.Padding(6,0,0,0)
        
        if ($b.Target) {
            $t = $b.Target
            $a = if ($b.ContainsKey('Arguments')) { $b.Arguments } else { $null }
            if ($b.Mode -eq 'url') { $btn.Add_Click({ Start-Process $t }.GetNewClosure()) }
            elseif ($a) { $btn.Add_Click({ Start-Process -FilePath $t -ArgumentList $a }.GetNewClosure()) }
            else { $btn.Add_Click({ Start-Process -FilePath $t }.GetNewClosure()) }
        } else { $btn.Enabled = $false }
        
        if ($b.Desc) { (New-Object System.Windows.Forms.ToolTip).SetToolTip($btn, $b.Desc) }
        
        $box.Controls.Add($btn)
        $yy += 34
    }
    
    $box.Height = $yy + 4
    $Parent.Controls.Add($box)
    $Parent.Height = $box.Top + $box.Height + 4
}

# ===================================================================
# COLUMN 1 — Character suite + Creators folders + ComfyUI + Links
# ===================================================================
$launcherTools = @($creatorTools | Where-Object { $_.Launcher })
$folderTools   = @($creatorTools | Where-Object { $_.Folder })

$charTools = @($launcherTools | Where-Object { $_.Name -match 'LoRA Lab|LoRA Fusion|Character Forge|Character Studio' })
$otherLaunchers = @($launcherTools | Where-Object { $_.Name -notmatch 'LoRA Lab|LoRA Fusion|Character Forge|Character Studio' })

$charBtns = @()
foreach ($t in $charTools) {
    $charBtns += @{Text=$t.Name; Color=$t.Color; Desc=$t.Description; Target=$t.Launcher}
}

Add-PanelBox -Parent $col1 -Title "CHARACTER SUITE" -Buttons $charBtns

$otherBtns = @()
foreach ($t in $otherLaunchers) {
    $otherBtns += @{Text=$t.Name; Color=$t.Color; Desc=$t.Description; Target=$t.Launcher}
}
if ($otherBtns.Count -gt 0) {
    Add-PanelBox -Parent $col1 -Title "CREATORS" -Buttons $otherBtns
}

Add-PanelBox -Parent $col1 -Title "CREATORS FOLDERS" -Buttons @(
    @{Text=$folderTools[0].Name; Color="#463728"; Desc=$folderTools[0].Description; Target=$folderTools[0].Folder}
    @{Text="ComfyUI Output"; Color="#463728"; Desc="Generated images"; Target="C:\Users\Michael\Documents\ComfyUI\output"}
    @{Text="ComfyUI Input";  Color="#463728"; Desc="ControlNet images"; Target="C:\Users\Michael\Documents\ComfyUI\input"}
)

Add-PanelBox -Parent $col1 -Title "COMFYUI" -Buttons @(
    @{Text="Scripts"; Color="#325032"; Desc="ComfyUI automation scripts"; Target=(Join-Path $StudioRoot "Creators\comfyui\scripts")}
)

Add-PanelBox -Parent $col1 -Title "LINKS" -Buttons @(
    @{Text="GitHub Repo"; Color="#24292E"; Desc="MystikStudio on GitHub"; Target="https://github.com/Mystikvoyd/MystikStudio"; Mode="url"}
)

# ===================================================================
# COLUMN 2 — 4 panels
# ===================================================================
$webBtnList = @()
foreach ($t in $webTools) {
    $target = if ($t.Folder) { $t.Folder } else { $t.Launcher }
    $webBtnList += @{Text=$t.Name; Color=$t.Color; Desc=$t.Description; Target=$target}
}
Add-PanelBox -Parent $col2 -Title "WEB APPS" -Buttons $webBtnList

Add-PanelBox -Parent $col2 -Title "PROJECT  ·  DESIGN" -Buttons @(
    @{Text="Book Design"; Color="#373746"; Desc="Assets, manuscript"; Target=(Join-Path $StudioRoot "book-design")}
)

Add-PanelBox -Parent $col2 -Title "PROJECT  ·  DATA" -Buttons @(
    @{Text="Shared"; Color="#373746"; Desc="Session module, sizes"; Target=(Join-Path $StudioRoot "shared")}
    @{Text="Reports"; Color="#373746"; Desc="Session HTML reports"; Target="C:\Users\Michael\Documents\ComfyUI\Reports"}
)

Add-PanelBox -Parent $col2 -Title "PROJECT  ·  MODELS" -Buttons @(
    @{Text="LoRA Models"; Color="#373746"; Desc="Browse LoRA files"; Target="C:\Users\Michael\Documents\ComfyUI\models\loras"}
    @{Text="Checkpoints"; Color="#373746"; Desc="Checkpoint files"; Target="C:\Users\Michael\Documents\ComfyUI\models\checkpoints"}
    @{Text="ControlNet"; Color="#373746"; Desc="ControlNet models"; Target="C:\Users\Michael\Documents\ComfyUI\models\controlnet"}
    @{Text="VAE"; Color="#373746"; Desc="VAE models"; Target="C:\Users\Michael\Documents\ComfyUI\models\vae"}
)

# ===================================================================
# COLUMN 3 — 4 panels
# ===================================================================
$comfyRootPath = "C:\Users\Michael\Documents\ComfyUI"

Add-PanelBox -Parent $col3 -Title "COMFYUI TOOLS" -Buttons @(
    @{Text="Open ComfyUI";     Color="#325032"; Desc="Launch ComfyUI web UI"; Target="http://127.0.0.1:8000"; Mode="url"}
    @{Text="ComfyUI Manager";   Color="#325032"; Desc="Open ComfyUI Manager tab"; Target="http://127.0.0.1:8000/manager"; Mode="url"}
    @{Text="ComfyUI Folder";    Color="#463728"; Desc="Browse ComfyUI root"; Target=$comfyRootPath}
)

Add-PanelBox -Parent $col3 -Title "REPORTS & SESSION" -Buttons @(
    @{Text="Reports Folder";    Color="#463728"; Desc="Browse all session reports"; Target="C:\Users\Michael\Documents\ComfyUI\Reports"}
    @{Text="Session Module";    Color="#463728"; Desc="Shared session report module"; Target=(Join-Path $StudioRoot "shared")}
    @{Text="LoRA Config";       Color="#463728"; Desc="LoRA tester configuration"; Target=(Join-Path $StudioRoot "Creators\lora-tester\lora-tester.config.json")}
)

Add-PanelBox -Parent $col3 -Title "DEVELOPMENT" -Buttons @(
    @{Text="Open in VS Code";   Color="#2C2C32"; Desc="Open project in Visual Studio Code"; Target="code"; Arguments=$StudioRoot}
    @{Text="Open Terminal";     Color="#2C2C32"; Desc="PowerShell at project root"; Target="powershell.exe"; Arguments="-NoExit cd `"$StudioRoot`""}
    @{Text="GitHub Issues";     Color="#24292E"; Desc="Open repo issues on GitHub"; Target="https://github.com/Mystikvoyd/MystikStudio/issues"; Mode="url"}
)

Add-PanelBox -Parent $col3 -Title "BOOK RESOURCES" -Buttons @(
    @{Text="Manuscript";        Color="#463728"; Desc="Book manuscript files"; Target=(Join-Path $StudioRoot "book-design\manuscript")}
    @{Text="Reference";         Color="#463728"; Desc="Book reference materials"; Target=(Join-Path $StudioRoot "book-design\reference")}
    @{Text="Assets";            Color="#463728"; Desc="Book design assets"; Target=(Join-Path $StudioRoot "book-design\assets")}
)

# Set column heights to tallest panel bottom
$col1.Height = [math]::Max(1, $col1.Height)
$col2.Height = [math]::Max(1, $col2.Height)
$col3.Height = [math]::Max(1, $col3.Height)
$script:y = [math]::Max($col1.Top + $col1.Height, [math]::Max($col2.Top + $col2.Height, $col3.Top + $col3.Height)) + 8

$rp.Height = $script:y + 4

$form.Add_Shown({ $form.Activate() })
[void]$form.ShowDialog()

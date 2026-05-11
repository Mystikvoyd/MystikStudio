# MystikStudio Dashboard — Split Panel: folders left, tools right
# Fixed: column widths computed after form is shown; row 0 uses placeholder panels
# Release snapshot: 01.01.01xxx

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$StudioRoot = $PSScriptRoot
$ComfyRoot  = "C:\Users\Michael\Documents\ComfyUI"
$StudioVersion = "01.01.01xxx"

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
            Name        = if ($cfg.name)        { [string]$cfg.name }                             else { $_.Name }
            Description = if ($cfg.description) { [string]$cfg.description }                      else { "" }
            Color       = if ($cfg.color)       { [string]$cfg.color }                            else { "#444" }
            Launcher    = if ($cfg.launcher)    { Join-Path $_.FullName ([string]$cfg.launcher) } else { $null }
            Folder      = if ($cfg.folder)      { Join-Path $_.FullName ([string]$cfg.folder) }   else { $null }
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
        return [System.Drawing.Color]::FromArgb(
            [int]::Parse($Matches[1],'HexNumber'),
            [int]::Parse($Matches[2],'HexNumber'),
            [int]::Parse($Matches[3],'HexNumber'))
    }
    return [System.Drawing.Color]::FromArgb(60,60,70)
}

# -------------------------------------------------------------------
# Form
# -------------------------------------------------------------------
$form = New-Object System.Windows.Forms.Form
$form.Text          = "MystikStudio Dashboard v$StudioVersion"
$form.StartPosition = "CenterScreen"
$form.Font          = New-Object System.Drawing.Font("Segoe UI", 9)
$form.BackColor     = [System.Drawing.Color]::FromArgb(24,24,32)
$form.ClientSize    = New-Object System.Drawing.Size(1100, 760)
$form.MinimumSize   = New-Object System.Drawing.Size(900, 600)

$iconPath = Join-Path $PSScriptRoot "Icons\Mytikvoyd Studios.ico"
if (Test-Path $iconPath) { $form.Icon = [System.Drawing.Icon]::new($iconPath) }

# -------------------------------------------------------------------
# Status bar (docked bottom — add FIRST so it reserves space)
# -------------------------------------------------------------------
$statusBar = New-Object System.Windows.Forms.Panel
$statusBar.Dock      = "Bottom"
$statusBar.Height    = 24
$statusBar.BackColor = [System.Drawing.Color]::FromArgb(28,28,38)

$statusLbl = New-Object System.Windows.Forms.Label
$statusLbl.Dock      = "Fill"
$statusLbl.Text      = "MystikStudio v$StudioVersion  |  $(@($creatorTools).Count + @($webTools).Count) tools"
$statusLbl.Font      = New-Object System.Drawing.Font("Segoe UI", 7)
$statusLbl.ForeColor = [System.Drawing.Color]::FromArgb(130,130,140)
$statusLbl.TextAlign = "MiddleLeft"
$statusLbl.Padding   = New-Object System.Windows.Forms.Padding(10,0,0,0)
$statusBar.Controls.Add($statusLbl)
$form.Controls.Add($statusBar)

# -------------------------------------------------------------------
# Main splitter (fills remaining space above status bar)
# -------------------------------------------------------------------
$split = New-Object System.Windows.Forms.SplitContainer
$split.Dock             = "Fill"
$split.SplitterWidth    = 4
$split.SplitterIncrement = 1
$split.BackColor        = [System.Drawing.Color]::FromArgb(40,40,48)
$form.Controls.Add($split)
$split.Panel1MinSize    = 120
$split.Panel2MinSize    = 350
$split.SplitterDistance = 240

# ===================================================================
# LEFT PANEL — Folder browser
# ===================================================================
$leftPanel = $split.Panel1
$leftPanel.BackColor = [System.Drawing.Color]::FromArgb(18,18,24)
$leftPanel.Padding   = New-Object System.Windows.Forms.Padding(4)

$lblFolders = New-Object System.Windows.Forms.Label
$lblFolders.Text      = "  EXPLORER"
$lblFolders.Font      = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Bold)
$lblFolders.ForeColor = [System.Drawing.Color]::FromArgb(140,160,200)
$lblFolders.BackColor = [System.Drawing.Color]::FromArgb(30,30,40)
$lblFolders.Height    = 24
$lblFolders.Left      = 4; $lblFolders.Top = 4
$lblFolders.TextAlign = "MiddleLeft"
$lblFolders.Anchor    = "Top, Left, Right"
$leftPanel.Controls.Add($lblFolders)

$tree = New-Object System.Windows.Forms.TreeView
$tree.Left        = 4; $tree.Top = 30
$tree.Width       = $leftPanel.ClientSize.Width - 8
$tree.Height      = $leftPanel.Height - 36
$tree.Anchor      = "Top, Bottom, Left, Right"
$tree.BackColor   = [System.Drawing.Color]::FromArgb(22,22,30)
$tree.ForeColor   = [System.Drawing.Color]::FromArgb(200,200,210)
$tree.BorderStyle = "None"
$tree.Font        = New-Object System.Drawing.Font("Segoe UI", 8.5)
$tree.LineColor   = [System.Drawing.Color]::FromArgb(50,50,60)
$tree.HotTracking = $true
$tree.FullRowSelect = $true
$tree.ShowLines   = $true
$tree.Indent      = 16
$leftPanel.Controls.Add($tree)

function Add-FolderNode {
    param($Parent, [string]$Label, [string]$Path, [string]$Color = "#555")
    $node = New-Object System.Windows.Forms.TreeNode
    $node.Text     = $Label
    $node.Tag      = $Path
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
Add-FolderNode -Parent $comfyNode -Label "output"              -Path (Join-Path $ComfyRoot "output")                -Color "#888"
Add-FolderNode -Parent $comfyNode -Label "input"               -Path (Join-Path $ComfyRoot "input")                 -Color "#888"
Add-FolderNode -Parent $comfyNode -Label "models/loras"        -Path (Join-Path $ComfyRoot "models\loras")          -Color "#888"
Add-FolderNode -Parent $comfyNode -Label "models/checkpoints"  -Path (Join-Path $ComfyRoot "models\checkpoints")    -Color "#888"
Add-FolderNode -Parent $comfyNode -Label "models/controlnet"   -Path (Join-Path $ComfyRoot "models\controlnet")     -Color "#888"
Add-FolderNode -Parent $comfyNode -Label "models/vae"          -Path (Join-Path $ComfyRoot "models\vae")            -Color "#888"

$root.Expand(); $comfyNode.Expand()

$tree.Add_NodeMouseDoubleClick({
    if ($_.Node.Tag) { Start-Process -FilePath ([string]$_.Node.Tag) }
})

# ===================================================================
# RIGHT PANEL — scrollable inner canvas
# ===================================================================
$rightPanel = $split.Panel2
$rightPanel.BackColor  = [System.Drawing.Color]::FromArgb(24,24,32)
$rightPanel.AutoScroll = $true

# Inner panel — width tracks rightPanel; height grows to fit content
$rp = New-Object System.Windows.Forms.Panel
$rp.BackColor = [System.Drawing.Color]::FromArgb(24,24,32)
$rp.Left      = 0; $rp.Top = 0
$rp.Width     = $rightPanel.ClientSize.Width
# Height will be set after all controls are placed
$rightPanel.Controls.Add($rp)
$rightPanel.Add_Resize({ $rp.Width = $rightPanel.ClientSize.Width })

# -------------------------------------------------------------------
# Header
# -------------------------------------------------------------------
$hdrTop = 8
$hdr = New-Object System.Windows.Forms.Panel
$hdr.Height    = 60
$hdr.Left      = 0; $hdr.Top = $hdrTop
$hdr.Width     = $rp.Width
$hdr.Anchor    = "Top, Left, Right"
$hdr.BackColor = [System.Drawing.Color]::FromArgb(24,24,32)

if (Test-Path $iconPath) {
    $logo = New-Object System.Windows.Forms.PictureBox
    $logo.Image    = [System.Drawing.Icon]::new($iconPath).ToBitmap()
    $logo.Size     = New-Object System.Drawing.Size(32, 32)
    $logo.SizeMode = "StretchImage"
    $logo.Left = 8; $logo.Top = 10
    $hdr.Controls.Add($logo)
}

$titleLbl = New-Object System.Windows.Forms.Label
$titleLbl.Text      = "MystikStudio"
$titleLbl.Font      = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
$titleLbl.ForeColor = [System.Drawing.Color]::FromArgb(220,180,100)
$titleLbl.AutoSize  = $true
$titleLbl.Left = 48; $titleLbl.Top = 4
$hdr.Controls.Add($titleLbl)

$subLbl = New-Object System.Windows.Forms.Label
$subLbl.Text      = "Modular Creative Toolkit"
$subLbl.ForeColor = [System.Drawing.Color]::FromArgb(130,130,150)
$subLbl.AutoSize  = $true
$subLbl.Left = 50; $subLbl.Top = 36
$hdr.Controls.Add($subLbl)
$rp.Controls.Add($hdr)

# -------------------------------------------------------------------
# Layout constants  (resolved once; colW is safe after form is shown)
# -------------------------------------------------------------------
$margin     = 8       # outer left/right margin
$gap        = 6       # gap between columns
$numCols    = 5
$contentTop = $hdrTop + $hdr.Height + 8   # y where row 0 starts

# Helper: compute column width from current $rp.Width
function Get-ColW {
    return [math]::Floor(($rp.Width - ($margin * 2) - ($gap * ($numCols - 1))) / $numCols)
}

# Helper: x-left of column index
function Get-ColX([int]$i) {
    return $margin + $i * ((Get-ColW) + $gap)
}

# -------------------------------------------------------------------
# ROW 0 — Character suite launcher GroupBox
# -------------------------------------------------------------------
$rowBox = New-Object System.Windows.Forms.GroupBox
$rowBox.Text = "  CHARACTER SUITE"
$rowBox.Left  = $margin
$rowBox.Top   = $contentTop
$rowBox.Width = $rp.Width - 2 * $margin
$rowBox.Height = 68
$rowBox.Anchor = "Top, Left, Right"
$rowBox.ForeColor = [System.Drawing.Color]::FromArgb(200,180,120)
$rowBox.Font      = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$rowBox.BackColor = [System.Drawing.Color]::FromArgb(28,28,38)
$rp.Controls.Add($rowBox)

$launcherDefs = @(
    @{Text="Studio"; Color="#DC143C"; Desc="Character Studio - generate characters";  Target=(Join-Path $StudioRoot "Creators\character-generator\Open Character Generator.vbs")}
    @{Text="Forge";  Color="#FF69B4"; Desc="Character Forge - final composition";     Target=(Join-Path $StudioRoot "Creators\character-design\Open Character Design.vbs")}
    @{Text="Fusion"; Color="#8B00FF"; Desc="LoRA Fusion - dual LoRA testing";         Target=(Join-Path $StudioRoot "Creators\lora-tester-2\Open LoRA Tester 2.vbs")}
    @{Text="Lab";    Color="#4169E1"; Desc="LoRA Lab - single LoRA testing";          Target=(Join-Path $StudioRoot "Creators\lora-tester\Open LoRA Tester.vbs")}
)

# 4 buttons evenly distributed inside the GroupBox
$btnGap = 8
$btnW = [math]::Floor(($rowBox.Width - ($launcherDefs.Count + 1) * $btnGap) / $launcherDefs.Count)
$btnH = 36
$btnY = [math]::Floor(($rowBox.Height - 20 - $btnH) / 2) + 16

for ($li = 0; $li -lt $launcherDefs.Count; $li++) {
    $ld  = $launcherDefs[$li]
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text      = $ld.Text
    $btn.Left      = $btnGap + $li * ($btnW + $btnGap)
    $btn.Top       = $btnY
    $btn.Width     = $btnW
    $btn.Height    = $btnH
    $btn.FlatStyle = "Flat"
    $btn.FlatAppearance.BorderSize = 0
    $btn.BackColor = ColorFromHex $ld.Color
    $btn.ForeColor = [System.Drawing.Color]::White
    $btn.Font      = New-Object System.Drawing.Font("Segoe UI", 10.5, [System.Drawing.FontStyle]::Bold)
    $btn.TextAlign = "MiddleCenter"
    $t = $ld.Target
    $btn.Add_Click({ if ($t -and (Test-Path $t)) { Start-Process -FilePath $t } }.GetNewClosure())
    (New-Object System.Windows.Forms.ToolTip).SetToolTip($btn, $ld.Desc)
    $rowBox.Controls.Add($btn)
}

# -------------------------------------------------------------------
# Panel-box helper — stacks GroupBox + buttons, grows the column panel
# -------------------------------------------------------------------
function Add-PanelBox {
    param(
        [System.Windows.Forms.Panel]$Parent,
        [string]$Title,
        [object[]]$Buttons
    )

    $box = New-Object System.Windows.Forms.GroupBox
    $box.Text      = "  $Title"
    $box.Left      = 1
    $box.Top       = $Parent.Height + 2          # stack below whatever's already there
    $box.Width     = $Parent.Width - 2
    $box.ForeColor = [System.Drawing.Color]::FromArgb(170,180,200)
    $box.Font      = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Bold)
    $box.BackColor = [System.Drawing.Color]::FromArgb(28,28,38)

    $yy = 20
    $bw = $box.Width - 16
    foreach ($b in $Buttons) {
        $btn = New-Object System.Windows.Forms.Button
        $btn.Text      = $b.Text
        $btn.Left      = 8; $btn.Top = $yy
        $btn.Width     = $bw; $btn.Height = 30
        $btn.FlatStyle = "Flat"
        $btn.FlatAppearance.BorderSize = 0
        $btn.BackColor = ColorFromHex $b.Color
        $btn.ForeColor = [System.Drawing.Color]::White
        $btn.Font      = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
        $btn.TextAlign = "MiddleLeft"
        $btn.Padding   = New-Object System.Windows.Forms.Padding(6,0,0,0)

        if ($b.Target) {
            $t = $b.Target
            $a = if ($b.ContainsKey('Arguments')) { $b.Arguments } else { $null }
            if     ($b.Mode -eq 'url') { $btn.Add_Click({ Start-Process $t }.GetNewClosure()) }
            elseif ($a)                { $btn.Add_Click({ Start-Process -FilePath $t -ArgumentList $a }.GetNewClosure()) }
            else                       { $btn.Add_Click({ Start-Process -FilePath $t }.GetNewClosure()) }
        } else { $btn.Enabled = $false }

        if ($b.Desc) { (New-Object System.Windows.Forms.ToolTip).SetToolTip($btn, $b.Desc) }
        $box.Controls.Add($btn)
        $yy += 34
    }

    $box.Height    = $yy + 6
    $Parent.Controls.Add($box)
    $Parent.Height = $box.Top + $box.Height + 4  # grow column to fit
}

# -------------------------------------------------------------------
# ROW 1+ — 5 column panels for the content panels
# -------------------------------------------------------------------
$panelRowTop = $rowBox.Top + $rowBox.Height + 6

$cols = @()
for ($i = 0; $i -lt $numCols; $i++) {
    $c = New-Object System.Windows.Forms.Panel
    $c.BackColor = [System.Drawing.Color]::FromArgb(24,24,32)
    $c.Left      = Get-ColX $i
    $c.Top       = $panelRowTop
    $c.Width     = Get-ColW
    $c.Height    = 0      # will grow as panels are added
    $c.Anchor    = "Top, Left"
    $rp.Controls.Add($c)
    $cols += $c
}

# -------------------------------------------------------------------
# Web tools button list (built from discovered tools)
# -------------------------------------------------------------------
$webBtnList = @()
foreach ($t in $webTools) {
    $target = if ($t.Folder) { $t.Folder } else { $t.Launcher }
    $webBtnList += @{Text=$t.Name; Color=$t.Color; Desc=$t.Description; Target=$target}
}

$comfyRootPath  = "C:\Users\Michael\Documents\ComfyUI"
$studioTool = Join-Path $StudioRoot "Creators\character-generator"
$forgeTool  = Join-Path $StudioRoot "Creators\character-design"
$fusionTool = Join-Path $StudioRoot "Creators\lora-tester-2"
$labTool    = Join-Path $StudioRoot "Creators\lora-tester"

# -------------------------------------------------------------------
# Column 0  — STUDIO
# -------------------------------------------------------------------
Add-PanelBox -Parent $cols[0] -Title "STUDIO" -Buttons @(
    @{Text="Open Studio";       Color="#503C82"; Desc="Character Generator - pose and identity locking";    Target=(Join-Path $studioTool "Open Character Generator.vbs")}
    @{Text="Generator Config";  Color="#3C2860"; Desc="Character generator configuration";                Target=(Join-Path $studioTool "character-generator.config.json")}
    @{Text="Studio Folder";     Color="#3C2860"; Desc="Browse character-generator folder";                Target=$studioTool}
)
Add-PanelBox -Parent $cols[0] -Title "COMFYUI" -Buttons @(
    @{Text="Scripts"; Color="#325032"; Desc="ComfyUI automation scripts"; Target=(Join-Path $StudioRoot "Creators\comfyui\scripts")}
)

# -------------------------------------------------------------------
# Column 1  — FORGE
# -------------------------------------------------------------------
Add-PanelBox -Parent $cols[1] -Title "FORGE" -Buttons @(
    @{Text="Open Forge";      Color="#8C325A"; Desc="Character Forge - final composition";            Target=(Join-Path $forgeTool "Open Character Design.vbs")}
    @{Text="Forge Config";    Color="#5A2840"; Desc="Character design configuration";                Target=(Join-Path $forgeTool "character-design.config.json")}
    @{Text="Debug Forge";     Color="#5A2840"; Desc="Debug character design workflow";               Target=(Join-Path $forgeTool "Debug_Character_Design.vbs")}
    @{Text="Forge Folder";    Color="#5A2840"; Desc="Browse character-design folder";                Target=$forgeTool}
)

# -------------------------------------------------------------------
# Column 2  — FUSION + WEB APPS
# -------------------------------------------------------------------
Add-PanelBox -Parent $cols[2] -Title "FUSION" -Buttons @(
    @{Text="Open Fusion";      Color="#5A328C"; Desc="LoRA Fusion - dual LoRA testing";               Target=(Join-Path $fusionTool "Open LoRA Tester 2.vbs")}
    @{Text="Fusion Config";    Color="#3C2860"; Desc="LoRA Fusion tester configuration";             Target=(Join-Path $fusionTool "lora-tester-2_config.json")}
    @{Text="Debug Fusion";     Color="#3C2860"; Desc="Debug LoRA Fusion workflow";                  Target=(Join-Path $fusionTool "Debug_LoRA_Tester_2.vbs")}
    @{Text="Fusion Folder";    Color="#3C2860"; Desc="Browse lora-tester-2 folder";                  Target=$fusionTool}
)
Add-PanelBox -Parent $cols[2] -Title "WEB APPS" -Buttons $webBtnList

# -------------------------------------------------------------------
# Column 3  — LAB + REPORTS
# -------------------------------------------------------------------
Add-PanelBox -Parent $cols[3] -Title "LAB" -Buttons @(
    @{Text="Open Lab";         Color="#325A8C"; Desc="LoRA Lab - single LoRA testing";                Target=(Join-Path $labTool "Open LoRA Tester.vbs")}
    @{Text="Lab Config";       Color="#284A70"; Desc="LoRA Lab tester configuration";                Target=(Join-Path $labTool "lora-tester.config.json")}
    @{Text="Debug Lab";        Color="#284A70"; Desc="Debug LoRA Lab workflow";                      Target=(Join-Path $labTool "Debug_LoRA_Tester.vbs")}
    @{Text="Lab Folder";       Color="#284A70"; Desc="Browse lora-tester folder";                    Target=$labTool}
)
Add-PanelBox -Parent $cols[3] -Title "REPORTS & SESSION" -Buttons @(
    @{Text="Reports Folder";  Color="#463728"; Desc="Browse session reports";                       Target="$comfyRootPath\Reports"}
    @{Text="Session Module";  Color="#463728"; Desc="Shared session report module";                 Target=(Join-Path $StudioRoot "shared")}
    @{Text="LoRA Config";     Color="#463728"; Desc="LoRA tester configuration";                    Target=(Join-Path $labTool "lora-tester.config.json")}
)

# -------------------------------------------------------------------
# Column 4  — COMFYUI + MODELS + DEVELOPMENT
# -------------------------------------------------------------------
Add-PanelBox -Parent $cols[4] -Title "COMFYUI TOOLS" -Buttons @(
    @{Text="Open ComfyUI";    Color="#325032"; Desc="Launch ComfyUI web UI";                        Target="http://127.0.0.1:8000"; Mode="url"}
    @{Text="ComfyUI Manager"; Color="#325032"; Desc="Open ComfyUI Manager tab";                     Target="http://127.0.0.1:8000/manager"; Mode="url"}
    @{Text="ComfyUI Folder";  Color="#463728"; Desc="Browse ComfyUI root";                          Target=$comfyRootPath}
)
Add-PanelBox -Parent $cols[4] -Title "PROJECT  ·  MODELS" -Buttons @(
    @{Text="LoRA Models";   Color="#373746"; Desc="Browse LoRA files";       Target="$comfyRootPath\models\loras"}
    @{Text="Checkpoints";   Color="#373746"; Desc="Checkpoint files";        Target="$comfyRootPath\models\checkpoints"}
    @{Text="ControlNet";    Color="#373746"; Desc="ControlNet models";       Target="$comfyRootPath\models\controlnet"}
    @{Text="VAE";           Color="#373746"; Desc="VAE models";              Target="$comfyRootPath\models\vae"}
)
Add-PanelBox -Parent $cols[4] -Title "DEVELOPMENT" -Buttons @(
    @{Text="Open in VS Code";  Color="#2C2C32"; Desc="Open project in VS Code";                    Target="code";         Arguments=$StudioRoot}
    @{Text="Open Terminal";    Color="#2C2C32"; Desc="PowerShell at project root";                 Target="powershell.exe"; Arguments="-NoExit cd `"$StudioRoot`""}
    @{Text="GitHub Issues";    Color="#24292E"; Desc="Open repo issues";                           Target="https://github.com/Mystikvoyd/MystikStudio/issues"; Mode="url"}
)

# -------------------------------------------------------------------
# Finalise inner panel height so scrolling works correctly
# -------------------------------------------------------------------
$maxBottom = 0
foreach ($c in ($cols + @($rowBox))) {
    $bottom = $c.Top + $c.Height
    if ($bottom -gt $maxBottom) { $maxBottom = $bottom }
}
$rp.Height = $maxBottom + 16

# -------------------------------------------------------------------
# Show
# -------------------------------------------------------------------
$form.Add_Shown({ $form.Activate() })
[void]$form.ShowDialog()

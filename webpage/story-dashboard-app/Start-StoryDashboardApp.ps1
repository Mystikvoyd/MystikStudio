param(
    [string]$BookRoot = (Join-Path $PSScriptRoot "..\..\book-design"),
    [switch]$ValidateOnly
)

$ErrorActionPreference = "Stop"

$ManuscriptRoot = Join-Path $BookRoot "manuscript"
$ReferenceRoot = Join-Path $BookRoot "reference"
$ConfigPath = Join-Path $PSScriptRoot "..\story-dashboard\story-dashboard.config.json"
$script:SessionStarted = Get-Date
$script:SessionBaselineWords = $null
$script:IsRefreshing = $false
$script:LastSettingsJson = ""

function Ensure-Workspace {
    New-Item -ItemType Directory -Force -Path $BookRoot | Out-Null
    New-Item -ItemType Directory -Force -Path $ManuscriptRoot | Out-Null
    New-Item -ItemType Directory -Force -Path $ReferenceRoot | Out-Null

    if (-not (Test-Path -LiteralPath $ConfigPath)) {
        [ordered]@{
            title = "My Book"
            draftWordGoal = 80000
            sessionWordGoal = 500
        } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $ConfigPath -Encoding UTF8
    }
}

function Read-Config {
    $config = $null

    if (Test-Path -LiteralPath $ConfigPath) {
        try {
            $config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
        }
        catch {
            $config = $null
        }
    }

    $title = "My Book"
    $draftWordGoal = 80000
    $sessionWordGoal = 500

    if ($null -ne $config) {
        if (-not [string]::IsNullOrWhiteSpace([string]$config.title)) {
            $title = [string]$config.title
        }

        if ($null -ne $config.draftWordGoal) {
            $draftWordGoal = [int]$config.draftWordGoal
        }

        if ($null -ne $config.sessionWordGoal) {
            $sessionWordGoal = [int]$config.sessionWordGoal
        }
    }

    [pscustomobject]@{
        title = $title
        draftWordGoal = [math]::Max(0, $draftWordGoal)
        sessionWordGoal = [math]::Max(0, $sessionWordGoal)
    }
}

function ConvertTo-SafeInt {
    param(
        [object]$Value,
        [int]$Fallback
    )

    $parsed = 0
    if ([int]::TryParse([string]$Value, [ref]$parsed)) {
        return [math]::Max(0, $parsed)
    }

    return $Fallback
}

function Save-ConfigObject {
    param(
        [string]$Title,
        [object]$DraftWordGoal,
        [object]$SessionWordGoal
    )

    $current = Read-Config
    if ([string]::IsNullOrWhiteSpace($Title)) {
        $Title = $current.title
    }

    [ordered]@{
        title = $Title.Trim()
        draftWordGoal = ConvertTo-SafeInt -Value $DraftWordGoal -Fallback $current.draftWordGoal
        sessionWordGoal = ConvertTo-SafeInt -Value $SessionWordGoal -Fallback $current.sessionWordGoal
    } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $ConfigPath -Encoding UTF8

    Read-Config
}

function ConvertFrom-MarkdownText {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return ""
    }

    $plain = $Text -replace '(?s)^---\s.*?---\s*', ' '
    $plain = $plain -replace '(?s)```.*?```', ' '
    $plain = $plain -replace '(?m)^\s{0,3}#{1,6}\s*', ''
    $plain = $plain -replace '\[([^\]]+)\]\([^)]+\)', '$1'
    $plain = $plain -replace '[*_>#`~|]', ' '

    $plain
}

function Get-WordCount {
    param([string]$Text)

    $plain = ConvertFrom-MarkdownText -Text $Text
    if ([string]::IsNullOrWhiteSpace($plain)) {
        return 0
    }

    [regex]::Matches($plain, "[\p{L}\p{N}]+(?:['-][\p{L}\p{N}]+)*").Count
}

function Get-TextExcerpt {
    param(
        [string]$Text,
        [int]$Limit = 280
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return ""
    }

    $plain = ConvertFrom-MarkdownText -Text $Text
    $plain = [regex]::Replace($plain, "\s+", " ").Trim()

    if ($plain.Length -le $Limit) {
        return $plain
    }

    return $plain.Substring(0, $Limit).Trim() + "..."
}

function Get-MarkdownSection {
    param(
        [string]$Text,
        [string]$Heading
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return ""
    }

    $escapedHeading = [regex]::Escape($Heading)
    $pattern = "(?ms)^##\s+$escapedHeading\s*(.*?)(?=^##\s+|\z)"
    $match = [regex]::Match($Text, $pattern)

    if ($match.Success) {
        return $match.Groups[1].Value.Trim()
    }

    return ""
}

function Read-FileTextSafe {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return ""
    }

    try {
        return Get-Content -LiteralPath $Path -Raw -ErrorAction Stop
    }
    catch {
        return ""
    }
}

function Get-RelativePath {
    param(
        [string]$Root,
        [string]$Path
    )

    $rootFull = [System.IO.Path]::GetFullPath($Root)
    if (-not $rootFull.EndsWith([System.IO.Path]::DirectorySeparatorChar)) {
        $rootFull = $rootFull + [System.IO.Path]::DirectorySeparatorChar
    }

    $rootUri = New-Object System.Uri($rootFull)
    $pathUri = New-Object System.Uri([System.IO.Path]::GetFullPath($Path))

    [System.Uri]::UnescapeDataString($rootUri.MakeRelativeUri($pathUri).ToString()).Replace('/', [System.IO.Path]::DirectorySeparatorChar)
}

function Format-Count {
    param([object]$Value)
    "{0:N0}" -f [double]$Value
}

function Format-TimeAgo {
    param([object]$IsoText)

    if ($null -eq $IsoText -or [string]::IsNullOrWhiteSpace([string]$IsoText)) {
        return "No saves yet"
    }

    $then = [datetime]::Parse([string]$IsoText)
    $span = (Get-Date) - $then

    if ($span.TotalSeconds -lt 5) { return "just now" }
    if ($span.TotalSeconds -lt 60) { return ("{0:N0}s ago" -f $span.TotalSeconds) }
    if ($span.TotalMinutes -lt 60) { return ("{0:N0}m ago" -f $span.TotalMinutes) }
    if ($span.TotalHours -lt 24) { return ("{0:N0}h ago" -f $span.TotalHours) }

    "{0:N0}d ago" -f $span.TotalDays
}

function Get-ProjectReferenceData {
    if (-not (Test-Path -LiteralPath $ReferenceRoot -PathType Container)) {
        return [pscustomobject]@{
            available = $false
            root = $ReferenceRoot
            sourceFileCount = 0
            totalFiles = 0
            textFileCount = 0
            referenceWords = 0
            combinedWords = 0
            projectStatus = ""
            bookDirection = ""
            priorityFiles = @()
            recentFiles = @()
        }
    }

    $textExtensions = @(".md", ".markdown", ".txt")
    $allFiles = @(Get-ChildItem -LiteralPath $ReferenceRoot -Recurse -File -ErrorAction SilentlyContinue)
    $textFiles = @($allFiles | Where-Object { $textExtensions -contains $_.Extension.ToLowerInvariant() })
    $manifestPath = Join-Path $ReferenceRoot "the_fool_and_the_maiden_codex_package\00_READ_ME_FIRST\FILE_MANIFEST.json"
    $latestCanonPath = Join-Path $ReferenceRoot "the_fool_and_the_maiden_codex_package\02_CODEX_CONTEXT\LATEST_CANON_SUPPLEMENT.md"

    $sourceFileCount = 0
    $manifestText = Read-FileTextSafe -Path $manifestPath
    if (-not [string]::IsNullOrWhiteSpace($manifestText)) {
        try {
            $manifest = $manifestText | ConvertFrom-Json
            if ($null -ne $manifest.source_file_count) {
                $sourceFileCount = [int]$manifest.source_file_count
            }
        }
        catch {
            $sourceFileCount = 0
        }
    }

    if ($sourceFileCount -eq 0) {
        $sourceFileCount = @($allFiles | Where-Object { $_.FullName -like "*\01_SOURCE_FILES\*" }).Count
    }

    $referenceWords = 0
    $combinedWords = 0
    $fileRows = @()

    foreach ($file in $textFiles) {
        $text = Read-FileTextSafe -Path $file.FullName
        $words = Get-WordCount -Text $text

        if ($file.FullName -like "*\03_COMBINED_REFERENCE\*") {
            $combinedWords += $words
        }
        else {
            $referenceWords += $words
        }

        $fileRows += [pscustomobject]@{
            name = $file.Name
            file = Get-RelativePath -Root $ReferenceRoot -Path $file.FullName
            words = $words
            modified = $file.LastWriteTime.ToString("o")
        }
    }

    $latestCanonText = Read-FileTextSafe -Path $latestCanonPath
    $projectStatus = Get-TextExcerpt -Text (Get-MarkdownSection -Text $latestCanonText -Heading "Project status") -Limit 420
    $bookDirection = Get-TextExcerpt -Text (Get-MarkdownSection -Text $latestCanonText -Heading "Current Book 1 direction") -Limit 520

    $priorityNames = @(
        "LATEST_CANON_SUPPLEMENT.md",
        "the_fool_and_the_maiden_master_corev1.md",
        "MASTER CREATURE CANON  v1.txt",
        "World Rule-Two Creature Systems.txt",
        "Outline.txt",
        "Ideology Information list.txt"
    )

    $priorityRows = @()
    foreach ($name in $priorityNames) {
        $match = $fileRows | Where-Object { $_.name -eq $name } | Select-Object -First 1
        if ($null -ne $match) {
            $priorityRows += $match
        }
    }

    [pscustomobject]@{
        available = ($textFiles.Count -gt 0)
        root = (Resolve-Path -LiteralPath $ReferenceRoot).Path
        sourceFileCount = $sourceFileCount
        totalFiles = $allFiles.Count
        textFileCount = $textFiles.Count
        referenceWords = $referenceWords
        combinedWords = $combinedWords
        projectStatus = $projectStatus
        bookDirection = $bookDirection
        priorityFiles = $priorityRows
        recentFiles = @($fileRows | Sort-Object modified -Descending | Select-Object -First 5)
    }
}

function Get-DashboardData {
    $config = Read-Config
    $extensions = @(".md", ".markdown", ".txt")
    $files = @(
        Get-ChildItem -LiteralPath $ManuscriptRoot -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object {
                $extensions -contains $_.Extension.ToLowerInvariant() -and
                $_.Name -notmatch '^(README|readme)\.'
            }
    )

    $totalWords = 0
    $chapterRows = @()

    foreach ($file in $files) {
        $text = Read-FileTextSafe -Path $file.FullName
        $words = Get-WordCount -Text $text
        $totalWords += $words

        $chapterRows += [pscustomobject]@{
            name = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
            file = Get-RelativePath -Root $ManuscriptRoot -Path $file.FullName
            words = $words
            modified = $file.LastWriteTime.ToString("o")
        }
    }

    $chapterRows = @($chapterRows | Sort-Object file)

    if ($null -eq $script:SessionBaselineWords) {
        $script:SessionBaselineWords = $totalWords
    }

    $sessionWords = $totalWords - $script:SessionBaselineWords
    $draftGoal = [math]::Max(0, [int]$config.draftWordGoal)
    $sessionGoal = [math]::Max(0, [int]$config.sessionWordGoal)
    $draftProgress = 0
    $sessionProgress = 0

    if ($draftGoal -gt 0) {
        $draftProgress = [math]::Min(100, [math]::Round(($totalWords / $draftGoal) * 100, 1))
    }

    if ($sessionGoal -gt 0) {
        $sessionProgress = [math]::Min(100, [math]::Round(($sessionWords / $sessionGoal) * 100, 1))
    }

    $recentFiles = @($chapterRows | Sort-Object modified -Descending | Select-Object -First 5)
    $lastEdited = $null
    if ($recentFiles.Count -gt 0) {
        $lastEdited = $recentFiles[0].modified
    }

    [pscustomobject]@{
        config = $config
        totalWords = $totalWords
        chapterCount = $chapterRows.Count
        draftProgress = $draftProgress
        remainingWords = [math]::Max(0, $draftGoal - $totalWords)
        sessionWords = $sessionWords
        sessionProgress = $sessionProgress
        sessionStarted = $script:SessionStarted.ToString("o")
        lastEdited = $lastEdited
        manuscriptRoot = (Resolve-Path -LiteralPath $ManuscriptRoot).Path
        reference = Get-ProjectReferenceData
        chapters = $chapterRows
        recentFiles = $recentFiles
        updatedAt = (Get-Date).ToString("o")
    }
}

Ensure-Workspace

if ($ValidateOnly) {
    Get-DashboardData | ConvertTo-Json -Depth 10
    return
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

function New-Color {
    param([string]$Hex)
    [System.Drawing.ColorTranslator]::FromHtml($Hex)
}

function New-Label {
    param(
        [string]$Text = "",
        [int]$Size = 10,
        [switch]$Bold,
        [System.Drawing.Color]$Color = (New-Color "#242423")
    )

    $label = New-Object System.Windows.Forms.Label
    $label.Text = $Text
    $label.AutoSize = $false
    $label.ForeColor = $Color
    $style = [System.Drawing.FontStyle]::Regular
    if ($Bold) {
        $style = [System.Drawing.FontStyle]::Bold
    }
    $label.Font = New-Object System.Drawing.Font("Segoe UI", $Size, $style)
    $label
}

function New-Panel {
    $panel = New-Object System.Windows.Forms.Panel
    $panel.BackColor = [System.Drawing.Color]::White
    $panel.Padding = New-Object System.Windows.Forms.Padding(14)
    $panel
}

function Add-ColumnStylePercent {
    param(
        [System.Windows.Forms.TableLayoutPanel]$Table,
        [float]$Percent
    )

    $style = New-Object System.Windows.Forms.ColumnStyle
    $style.SizeType = [System.Windows.Forms.SizeType]::Percent
    $style.Width = $Percent
    [void]$Table.ColumnStyles.Add($style)
}

function Add-RowStylePercent {
    param(
        [System.Windows.Forms.TableLayoutPanel]$Table,
        [float]$Percent
    )

    $style = New-Object System.Windows.Forms.RowStyle
    $style.SizeType = [System.Windows.Forms.SizeType]::Percent
    $style.Height = $Percent
    [void]$Table.RowStyles.Add($style)
}

function Add-RowStyleAbsolute {
    param(
        [System.Windows.Forms.TableLayoutPanel]$Table,
        [float]$Height
    )

    $style = New-Object System.Windows.Forms.RowStyle
    $style.SizeType = [System.Windows.Forms.SizeType]::Absolute
    $style.Height = $Height
    [void]$Table.RowStyles.Add($style)
}

function New-MetricPanel {
    param([string]$Title)

    $panel = New-Panel
    $layout = New-Object System.Windows.Forms.TableLayoutPanel
    $layout.Dock = [System.Windows.Forms.DockStyle]::Fill
    $layout.RowCount = 3
    $layout.ColumnCount = 1
    Add-RowStyleAbsolute -Table $layout -Height 24
    Add-RowStylePercent -Table $layout -Percent 100
    Add-RowStyleAbsolute -Table $layout -Height 22

    $titleLabel = New-Label -Text $Title -Size 9 -Bold -Color (New-Color "#6c706d")
    $titleLabel.Dock = [System.Windows.Forms.DockStyle]::Fill

    $valueLabel = New-Label -Text "0" -Size 24 -Bold
    $valueLabel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $valueLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft

    $noteLabel = New-Label -Text "" -Size 9 -Color (New-Color "#6c706d")
    $noteLabel.Dock = [System.Windows.Forms.DockStyle]::Fill

    [void]$layout.Controls.Add($titleLabel, 0, 0)
    [void]$layout.Controls.Add($valueLabel, 0, 1)
    [void]$layout.Controls.Add($noteLabel, 0, 2)
    [void]$panel.Controls.Add($layout)

    [pscustomobject]@{
        panel = $panel
        value = $valueLabel
        note = $noteLabel
    }
}

function Update-ProgressBar {
    param(
        [System.Windows.Forms.ProgressBar]$Bar,
        [object]$Percent
    )

    $value = [int]([math]::Max(0, [math]::Min(100, [double]$Percent)) * 10)
    $Bar.Value = [math]::Min($Bar.Maximum, $value)
}

function Set-ListViewRows {
    param(
        [System.Windows.Forms.ListView]$ListView,
        [array]$Rows,
        [scriptblock]$BuildItem
    )

    $ListView.BeginUpdate()
    try {
        $ListView.Items.Clear()
        foreach ($row in $Rows) {
            [void]$ListView.Items.Add((& $BuildItem $row))
        }
    }
    finally {
        $ListView.EndUpdate()
    }
}

$form = New-Object System.Windows.Forms.Form
$form.Text = "Story Dashboard App"
$form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
$form.MinimumSize = New-Object System.Drawing.Size(980, 680)
$form.Size = New-Object System.Drawing.Size(1180, 760)
$form.BackColor = New-Color "#f5f7f6"
$form.Font = New-Object System.Drawing.Font("Segoe UI", 10)

$root = New-Object System.Windows.Forms.TableLayoutPanel
$root.Dock = [System.Windows.Forms.DockStyle]::Fill
$root.Padding = New-Object System.Windows.Forms.Padding(16)
$root.RowCount = 4
$root.ColumnCount = 1
Add-RowStyleAbsolute -Table $root -Height 72
Add-RowStyleAbsolute -Table $root -Height 136
Add-RowStyleAbsolute -Table $root -Height 38
Add-RowStylePercent -Table $root -Percent 100
[void]$form.Controls.Add($root)

$header = New-Object System.Windows.Forms.TableLayoutPanel
$header.Dock = [System.Windows.Forms.DockStyle]::Fill
$header.ColumnCount = 2
$header.RowCount = 2
Add-ColumnStylePercent -Table $header -Percent 70
Add-ColumnStylePercent -Table $header -Percent 30
Add-RowStyleAbsolute -Table $header -Height 25
Add-RowStylePercent -Table $header -Percent 100

$eyebrow = New-Label -Text "LOCAL MANUSCRIPT DASHBOARD" -Size 9 -Bold -Color (New-Color "#6c706d")
$eyebrow.Dock = [System.Windows.Forms.DockStyle]::Fill
$titleLabel = New-Label -Text "Story Progress" -Size 22 -Bold
$titleLabel.Dock = [System.Windows.Forms.DockStyle]::Fill
$statusLabel = New-Label -Text "Live" -Size 10 -Bold -Color (New-Color "#155b57")
$statusLabel.Dock = [System.Windows.Forms.DockStyle]::Fill
$statusLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight

[void]$header.Controls.Add($eyebrow, 0, 0)
[void]$header.Controls.Add($titleLabel, 0, 1)
[void]$header.Controls.Add($statusLabel, 1, 1)
[void]$root.Controls.Add($header, 0, 0)

$metrics = New-Object System.Windows.Forms.TableLayoutPanel
$metrics.Dock = [System.Windows.Forms.DockStyle]::Fill
$metrics.ColumnCount = 4
$metrics.RowCount = 1
Add-ColumnStylePercent -Table $metrics -Percent 25
Add-ColumnStylePercent -Table $metrics -Percent 25
Add-ColumnStylePercent -Table $metrics -Percent 25
Add-ColumnStylePercent -Table $metrics -Percent 25

$totalMetric = New-MetricPanel -Title "Total Words"
$sessionMetric = New-MetricPanel -Title "Session Words"
$remainingMetric = New-MetricPanel -Title "Remaining"
$chapterMetric = New-MetricPanel -Title "Chapters"
[void]$metrics.Controls.Add($totalMetric.panel, 0, 0)
[void]$metrics.Controls.Add($sessionMetric.panel, 1, 0)
[void]$metrics.Controls.Add($remainingMetric.panel, 2, 0)
[void]$metrics.Controls.Add($chapterMetric.panel, 3, 0)
[void]$root.Controls.Add($metrics, 0, 1)

$progressLayout = New-Object System.Windows.Forms.TableLayoutPanel
$progressLayout.Dock = [System.Windows.Forms.DockStyle]::Fill
$progressLayout.ColumnCount = 2
$progressLayout.RowCount = 1
Add-ColumnStylePercent -Table $progressLayout -Percent 50
Add-ColumnStylePercent -Table $progressLayout -Percent 50

$draftProgressBar = New-Object System.Windows.Forms.ProgressBar
$draftProgressBar.Dock = [System.Windows.Forms.DockStyle]::Fill
$draftProgressBar.Maximum = 1000
$sessionProgressBar = New-Object System.Windows.Forms.ProgressBar
$sessionProgressBar.Dock = [System.Windows.Forms.DockStyle]::Fill
$sessionProgressBar.Maximum = 1000
[void]$progressLayout.Controls.Add($draftProgressBar, 0, 0)
[void]$progressLayout.Controls.Add($sessionProgressBar, 1, 0)
[void]$root.Controls.Add($progressLayout, 0, 2)

$tabs = New-Object System.Windows.Forms.TabControl
$tabs.Dock = [System.Windows.Forms.DockStyle]::Fill

$manuscriptTab = New-Object System.Windows.Forms.TabPage
$manuscriptTab.Text = "Manuscript"
$codexTab = New-Object System.Windows.Forms.TabPage
$codexTab.Text = "Project Codex"
$settingsTab = New-Object System.Windows.Forms.TabPage
$settingsTab.Text = "Settings"
[void]$tabs.TabPages.Add($manuscriptTab)
[void]$tabs.TabPages.Add($codexTab)
[void]$tabs.TabPages.Add($settingsTab)
[void]$root.Controls.Add($tabs, 0, 3)

$manuscriptLayout = New-Object System.Windows.Forms.TableLayoutPanel
$manuscriptLayout.Dock = [System.Windows.Forms.DockStyle]::Fill
$manuscriptLayout.Padding = New-Object System.Windows.Forms.Padding(8)
$manuscriptLayout.RowCount = 2
$manuscriptLayout.ColumnCount = 1
Add-RowStyleAbsolute -Table $manuscriptLayout -Height 36
Add-RowStylePercent -Table $manuscriptLayout -Percent 100
[void]$manuscriptTab.Controls.Add($manuscriptLayout)

$manuscriptHeader = New-Object System.Windows.Forms.TableLayoutPanel
$manuscriptHeader.Dock = [System.Windows.Forms.DockStyle]::Fill
$manuscriptHeader.ColumnCount = 3
$manuscriptHeader.RowCount = 1
Add-ColumnStylePercent -Table $manuscriptHeader -Percent 60
Add-ColumnStylePercent -Table $manuscriptHeader -Percent 20
Add-ColumnStylePercent -Table $manuscriptHeader -Percent 20

$manuscriptPathLabel = New-Label -Text $ManuscriptRoot -Size 9 -Color (New-Color "#6c706d")
$manuscriptPathLabel.Dock = [System.Windows.Forms.DockStyle]::Fill
$refreshButton = New-Object System.Windows.Forms.Button
$refreshButton.Text = "Refresh"
$refreshButton.Dock = [System.Windows.Forms.DockStyle]::Fill
$openManuscriptButton = New-Object System.Windows.Forms.Button
$openManuscriptButton.Text = "Open Folder"
$openManuscriptButton.Dock = [System.Windows.Forms.DockStyle]::Fill
[void]$manuscriptHeader.Controls.Add($manuscriptPathLabel, 0, 0)
[void]$manuscriptHeader.Controls.Add($refreshButton, 1, 0)
[void]$manuscriptHeader.Controls.Add($openManuscriptButton, 2, 0)
[void]$manuscriptLayout.Controls.Add($manuscriptHeader, 0, 0)

$chapterList = New-Object System.Windows.Forms.ListView
$chapterList.Dock = [System.Windows.Forms.DockStyle]::Fill
$chapterList.View = [System.Windows.Forms.View]::Details
$chapterList.FullRowSelect = $true
$chapterList.GridLines = $true
[void]$chapterList.Columns.Add("Chapter", 220)
[void]$chapterList.Columns.Add("File", 430)
[void]$chapterList.Columns.Add("Words", 110)
[void]$chapterList.Columns.Add("Last Save", 150)
[void]$manuscriptLayout.Controls.Add($chapterList, 0, 1)

$codexLayout = New-Object System.Windows.Forms.TableLayoutPanel
$codexLayout.Dock = [System.Windows.Forms.DockStyle]::Fill
$codexLayout.Padding = New-Object System.Windows.Forms.Padding(8)
$codexLayout.RowCount = 4
$codexLayout.ColumnCount = 1
Add-RowStyleAbsolute -Table $codexLayout -Height 62
Add-RowStyleAbsolute -Table $codexLayout -Height 118
Add-RowStyleAbsolute -Table $codexLayout -Height 36
Add-RowStylePercent -Table $codexLayout -Percent 100
[void]$codexTab.Controls.Add($codexLayout)

$codexStatsLabel = New-Label -Text "Reference package not loaded" -Size 16 -Bold
$codexStatsLabel.Dock = [System.Windows.Forms.DockStyle]::Fill
[void]$codexLayout.Controls.Add($codexStatsLabel, 0, 0)

$codexText = New-Object System.Windows.Forms.TextBox
$codexText.Dock = [System.Windows.Forms.DockStyle]::Fill
$codexText.Multiline = $true
$codexText.ReadOnly = $true
$codexText.ScrollBars = [System.Windows.Forms.ScrollBars]::Vertical
$codexText.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$codexText.BackColor = [System.Drawing.Color]::White
[void]$codexLayout.Controls.Add($codexText, 0, 1)

$referencePathLabel = New-Label -Text $ReferenceRoot -Size 9 -Color (New-Color "#6c706d")
$referencePathLabel.Dock = [System.Windows.Forms.DockStyle]::Fill
[void]$codexLayout.Controls.Add($referencePathLabel, 0, 2)

$priorityList = New-Object System.Windows.Forms.ListView
$priorityList.Dock = [System.Windows.Forms.DockStyle]::Fill
$priorityList.View = [System.Windows.Forms.View]::Details
$priorityList.FullRowSelect = $true
$priorityList.GridLines = $true
[void]$priorityList.Columns.Add("#", 44)
[void]$priorityList.Columns.Add("Canon Priority File", 430)
[void]$priorityList.Columns.Add("Words", 120)
[void]$priorityList.Columns.Add("Path", 460)
[void]$codexLayout.Controls.Add($priorityList, 0, 3)

$settingsLayout = New-Object System.Windows.Forms.TableLayoutPanel
$settingsLayout.Dock = [System.Windows.Forms.DockStyle]::Fill
$settingsLayout.Padding = New-Object System.Windows.Forms.Padding(18)
$settingsLayout.RowCount = 8
$settingsLayout.ColumnCount = 2
Add-ColumnStylePercent -Table $settingsLayout -Percent 28
Add-ColumnStylePercent -Table $settingsLayout -Percent 72
Add-RowStyleAbsolute -Table $settingsLayout -Height 38
Add-RowStyleAbsolute -Table $settingsLayout -Height 42
Add-RowStyleAbsolute -Table $settingsLayout -Height 42
Add-RowStyleAbsolute -Table $settingsLayout -Height 42
Add-RowStyleAbsolute -Table $settingsLayout -Height 48
Add-RowStyleAbsolute -Table $settingsLayout -Height 48
Add-RowStyleAbsolute -Table $settingsLayout -Height 48
Add-RowStylePercent -Table $settingsLayout -Percent 100
[void]$settingsTab.Controls.Add($settingsLayout)

$settingsTitle = New-Label -Text "Goals and paths" -Size 16 -Bold
$settingsTitle.Dock = [System.Windows.Forms.DockStyle]::Fill
$settingsLayout.SetColumnSpan($settingsTitle, 2)
[void]$settingsLayout.Controls.Add($settingsTitle, 0, 0)

$bookTitleInput = New-Object System.Windows.Forms.TextBox
$bookTitleInput.Dock = [System.Windows.Forms.DockStyle]::Fill
$draftGoalInput = New-Object System.Windows.Forms.NumericUpDown
$draftGoalInput.Dock = [System.Windows.Forms.DockStyle]::Fill
$draftGoalInput.Maximum = 10000000
$draftGoalInput.Increment = 1000
$sessionGoalInput = New-Object System.Windows.Forms.NumericUpDown
$sessionGoalInput.Dock = [System.Windows.Forms.DockStyle]::Fill
$sessionGoalInput.Maximum = 10000000
$sessionGoalInput.Increment = 50

foreach ($row in @(
    @{ label = "Book title"; control = $bookTitleInput; index = 1 },
    @{ label = "Draft target"; control = $draftGoalInput; index = 2 },
    @{ label = "Session target"; control = $sessionGoalInput; index = 3 }
)) {
    $label = New-Label -Text $row.label -Size 10 -Bold -Color (New-Color "#6c706d")
    $label.Dock = [System.Windows.Forms.DockStyle]::Fill
    $label.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    [void]$settingsLayout.Controls.Add($label, 0, $row.index)
    [void]$settingsLayout.Controls.Add($row.control, 1, $row.index)
}

$saveSettingsButton = New-Object System.Windows.Forms.Button
$saveSettingsButton.Text = "Save Goals"
$saveSettingsButton.Dock = [System.Windows.Forms.DockStyle]::Fill
[void]$settingsLayout.Controls.Add($saveSettingsButton, 1, 4)

$settingsStatusLabel = New-Label -Text "" -Size 10 -Color (New-Color "#155b57")
$settingsStatusLabel.Dock = [System.Windows.Forms.DockStyle]::Fill
$settingsLayout.SetColumnSpan($settingsStatusLabel, 2)
[void]$settingsLayout.Controls.Add($settingsStatusLabel, 0, 5)

$pathsLabel = New-Label -Text ("Manuscript: {0}`r`nReference: {1}`r`nApp source: {2}" -f $ManuscriptRoot, $ReferenceRoot, $PSCommandPath) -Size 9 -Color (New-Color "#6c706d")
$pathsLabel.Dock = [System.Windows.Forms.DockStyle]::Fill
$pathsLabel.TextAlign = [System.Drawing.ContentAlignment]::TopLeft
$settingsLayout.SetColumnSpan($pathsLabel, 2)
[void]$settingsLayout.Controls.Add($pathsLabel, 0, 6)

function Update-Ui {
    if ($script:IsRefreshing) {
        return
    }

    $script:IsRefreshing = $true
    try {
        $data = Get-DashboardData
        $config = $data.config
        $reference = $data.reference

        $form.Text = "$($config.title) - Story Dashboard App"
        $titleLabel.Text = $config.title
        $statusLabel.Text = "Live - updated " + (Format-TimeAgo $data.updatedAt)

        $totalMetric.value.Text = Format-Count $data.totalWords
        $totalMetric.note.Text = "$($data.draftProgress)% of " + (Format-Count $config.draftWordGoal) + " words"
        $sessionMetric.value.Text = Format-Count $data.sessionWords
        $sessionMetric.note.Text = "$($data.sessionProgress)% of " + (Format-Count $config.sessionWordGoal) + " words"
        $remainingMetric.value.Text = Format-Count $data.remainingWords
        $remainingMetric.note.Text = "words to draft target"
        $chapterMetric.value.Text = Format-Count $data.chapterCount
        $chapterMetric.note.Text = if ($data.lastEdited) { "Last save " + (Format-TimeAgo $data.lastEdited) } else { "No saves yet" }

        Update-ProgressBar -Bar $draftProgressBar -Percent $data.draftProgress
        Update-ProgressBar -Bar $sessionProgressBar -Percent $data.sessionProgress

        $manuscriptPathLabel.Text = $data.manuscriptRoot
        $referencePathLabel.Text = $reference.root

        $settingsJson = $config | ConvertTo-Json -Compress
        $settingsAreActive = $bookTitleInput.Focused -or $draftGoalInput.Focused -or $sessionGoalInput.Focused
        if (-not $settingsAreActive -and $settingsJson -ne $script:LastSettingsJson) {
            $bookTitleInput.Text = $config.title
            $draftGoalInput.Value = [decimal]$config.draftWordGoal
            $sessionGoalInput.Value = [decimal]$config.sessionWordGoal
            $script:LastSettingsJson = $settingsJson
        }

        Set-ListViewRows -ListView $chapterList -Rows $data.chapters -BuildItem {
            param($chapter)
            $item = New-Object System.Windows.Forms.ListViewItem($chapter.name)
            [void]$item.SubItems.Add($chapter.file)
            [void]$item.SubItems.Add((Format-Count $chapter.words))
            [void]$item.SubItems.Add((Format-TimeAgo $chapter.modified))
            $item
        }

        if ($data.chapters.Count -eq 0) {
            $empty = New-Object System.Windows.Forms.ListViewItem("No manuscript files found")
            [void]$empty.SubItems.Add("Add .md, .markdown, or .txt files to book-design\manuscript")
            [void]$empty.SubItems.Add("0")
            [void]$empty.SubItems.Add("")
            $chapterList.Items.Add($empty) | Out-Null
        }

        if ($reference.available) {
            $codexStatsLabel.Text = "Project Codex: " +
                (Format-Count $reference.sourceFileCount) + " source files, " +
                (Format-Count $reference.referenceWords) + " reference words"
            $codexText.Text = "Project status:`r`n$($reference.projectStatus)`r`n`r`nBook 1 direction:`r`n$($reference.bookDirection)"
        }
        else {
            $codexStatsLabel.Text = "Project Codex: no reference package loaded"
            $codexText.Text = "Reference files placed in book-design\reference will appear here."
        }

        Set-ListViewRows -ListView $priorityList -Rows $reference.priorityFiles -BuildItem {
            param($file)
            $rank = $priorityList.Items.Count + 1
            $item = New-Object System.Windows.Forms.ListViewItem([string]$rank)
            [void]$item.SubItems.Add($file.name)
            [void]$item.SubItems.Add((Format-Count $file.words))
            [void]$item.SubItems.Add($file.file)
            $item
        }

        if ($reference.priorityFiles.Count -eq 0) {
            $empty = New-Object System.Windows.Forms.ListViewItem("-")
            [void]$empty.SubItems.Add("No canon priority files found")
            [void]$empty.SubItems.Add("0")
            [void]$empty.SubItems.Add("")
            $priorityList.Items.Add($empty) | Out-Null
        }
    }
    catch {
        $statusLabel.Text = "Error - " + $_.Exception.Message
        $statusLabel.ForeColor = New-Color "#bf523d"
    }
    finally {
        $script:IsRefreshing = $false
    }
}

$refreshButton.Add_Click({ Update-Ui })
$saveSettingsButton.Add_Click({
    Save-ConfigObject -Title $bookTitleInput.Text -DraftWordGoal $draftGoalInput.Value -SessionWordGoal $sessionGoalInput.Value | Out-Null
    $script:LastSettingsJson = ""
    $settingsStatusLabel.Text = "Saved at " + (Get-Date -Format "h:mm tt")
    Update-Ui
})
$openManuscriptButton.Add_Click({
    Start-Process explorer.exe -ArgumentList "`"$ManuscriptRoot`""
})

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 2000
$timer.Add_Tick({ Update-Ui })

$form.Add_Shown({
    Update-Ui
    $timer.Start()
})
$form.Add_FormClosed({
    $timer.Stop()
    $timer.Dispose()
})

[void][System.Windows.Forms.Application]::Run($form)

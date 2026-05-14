# MystikStudio Dashboard — Split Panel: folders left, tools right
# Fixed: column widths computed after form is shown; row 0 uses placeholder panels
# Release snapshot: 01.02.01xxB

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$StudioRoot = $PSScriptRoot
$ComfyRoot  = "C:\Users\Michael\Documents\ComfyUI"
$StudioVersion = "01.02.01xxB"

Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Text;
public static class MystikWindowHelper {
    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
    [DllImport("user32.dll")]
    public static extern bool IsIconic(IntPtr hWnd);
    [DllImport("user32.dll")]
    public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")]
    public static extern bool MoveWindow(IntPtr hWnd, int X, int Y, int nWidth, int nHeight, bool bRepaint);
    [DllImport("user32.dll")]
    public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);
    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
    [DllImport("user32.dll")]
    public static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll")]
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    public static IntPtr FindWindowByPid(uint targetPid) {
        IntPtr found = IntPtr.Zero;
        EnumWindows((hWnd, lParam) => {
            if (!IsWindowVisible(hWnd)) return true;
            uint pid = 0;
            GetWindowThreadProcessId(hWnd, out pid);
            if (pid == targetPid) { found = hWnd; return false; }
            return true;
        }, IntPtr.Zero);
        return found;
    }

    public static IntPtr FindWindowByPidAndTitle(uint targetPid, string titleHint) {
        IntPtr found = IntPtr.Zero;
        EnumWindows((hWnd, lParam) => {
            if (!IsWindowVisible(hWnd)) return true;
            uint pid = 0;
            GetWindowThreadProcessId(hWnd, out pid);
            if (pid == targetPid) {
                StringBuilder sb = new StringBuilder(512);
                GetWindowText(hWnd, sb, sb.Capacity);
                string t = sb.ToString();
                if (t.IndexOf(titleHint, StringComparison.OrdinalIgnoreCase) >= 0) { found = hWnd; return false; }
                if (found == IntPtr.Zero) found = hWnd;
            }
            return true;
        }, IntPtr.Zero);
        return found;
    }

    public static string GetWindowTitle(IntPtr hWnd) {
        StringBuilder sb = new StringBuilder(512);
        GetWindowText(hWnd, sb, sb.Capacity);
        return sb.ToString();
    }

    public static IntPtr FindWindowByTitle(string titleContains) {
        IntPtr found = IntPtr.Zero;
        EnumWindows((hWnd, lParam) => {
            if (!IsWindowVisible(hWnd)) return true;
            StringBuilder sb = new StringBuilder(512);
            GetWindowText(hWnd, sb, sb.Capacity);
            if (sb.ToString().IndexOf(titleContains, StringComparison.OrdinalIgnoreCase) >= 0) { found = hWnd; return false; }
            return true;
        }, IntPtr.Zero);
        return found;
    }

    public static IntPtr FindWindowByAnyTitle(string[] searchTerms) {
        IntPtr found = IntPtr.Zero;
        EnumWindows((hWnd, lParam) => {
            if (!IsWindowVisible(hWnd)) return true;
            StringBuilder sb = new StringBuilder(512);
            GetWindowText(hWnd, sb, sb.Capacity);
            string t = sb.ToString();
            foreach (string s in searchTerms) {
                if (t.IndexOf(s, StringComparison.OrdinalIgnoreCase) >= 0) { found = hWnd; return false; }
            }
            return true;
        }, IntPtr.Zero);
        return found;
    }
}
public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
"@

function Show-ExistingDashboardWindow {
    param([string]$WindowTitle = "MystikStudio Dashboard*")

    try { Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop } catch {}

    $proc = Get-Process | Where-Object { $_.MainWindowTitle -like $WindowTitle } | Select-Object -First 1
    if ($null -eq $proc) { return $false }
    $handle = $proc.MainWindowHandle
    if ($handle -eq [IntPtr]::Zero) { return $false }

    [void][MystikWindowHelper]::ShowWindowAsync($handle, 9)
    $screen = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
    $width = 1100
    $height = 1000
    $x = [Math]::Max($screen.Left, [Math]::Floor($screen.Left + (($screen.Width - $width) / 2)))
    $y = [Math]::Max($screen.Top, [Math]::Floor($screen.Top + (($screen.Height - $height) / 2)))
    [void][MystikWindowHelper]::MoveWindow($handle, $x, $y, $width, $height, $true)
    [void][MystikWindowHelper]::SetForegroundWindow($handle)
    return $true
}

$mutexCreated = $false
$mutex = New-Object System.Threading.Mutex($true, "Local\MystikStudioDashboard", [ref]$mutexCreated)
if (-not $mutexCreated) {
    [void](Show-ExistingDashboardWindow)
    return
}

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

# Icon helper — loads an .ico from Icons folder and returns a resized bitmap
function Get-ToolImage([string]$Name, [int]$Size=18) {
    $path = Join-Path $StudioRoot "Icons\$Name.ico"
    if (-not (Test-Path $path)) { return $null }
    $icon = [System.Drawing.Icon]::new($path, $Size, $Size)
    return $icon.ToBitmap()
}

# -------------------------------------------------------------------
# Form
# -------------------------------------------------------------------
$form = New-Object System.Windows.Forms.Form
$form.Text          = "MystikStudio Dashboard v$StudioVersion"
$form.StartPosition = "CenterScreen"
$form.Font          = New-Object System.Drawing.Font("Segoe UI", 9)
$form.BackColor     = [System.Drawing.Color]::FromArgb(24,24,32)
$form.ClientSize    = New-Object System.Drawing.Size(1100, 1000)
$form.MinimumSize   = New-Object System.Drawing.Size(1050, 800)

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

# ===================================================================
# MAIN CONTENT PANEL (fills full window below status bar)
# ===================================================================
$rightPanel = New-Object System.Windows.Forms.Panel
$rightPanel.Dock = "Fill"
$rightPanel.BackColor  = [System.Drawing.Color]::FromArgb(24,24,32)
$rightPanel.AutoScroll = $true
$form.Controls.Add($rightPanel)
$rightPanel.BackColor  = [System.Drawing.Color]::FromArgb(24,24,32)
$rightPanel.AutoScroll = $true

# Inner panel — width tracks rightPanel; height grows to fit content
$rp = New-Object System.Windows.Forms.Panel
$rp.BackColor = [System.Drawing.Color]::FromArgb(24,24,32)
$rp.Left      = 0; $rp.Top = 0
$rp.Width     = $rightPanel.ClientSize.Width
# Height will be set after all controls are placed
$rightPanel.Controls.Add($rp)

# -------------------------------------------------------------------
# Header
# -------------------------------------------------------------------
$hdrTop = 8
$hdr = New-Object System.Windows.Forms.Panel
$hdr.Height    = 60
$hdr.Left      = 0; $hdr.Top = $hdrTop
$hdr.Width     = $rp.Width
$hdr.Anchor    = "Top, Left"
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
# Layout constants
# -------------------------------------------------------------------
$contentTop = $hdrTop + $hdr.Height + 8   # y where row 0 starts
$padLeft = 20
$padRight = 32

# (No longer used - tiles and cards use fixed widths)

# Character Suite tile data — defined before GroupBox so resize handler uses correct count
$tileW = 185; $tileH = 195; $imgSz = 128

$launcherDefs = @(
    @{Text="Studio"; Color="#DC143C"; Desc="Character Studio - generate characters";  Target=(Join-Path $StudioRoot "Creators\Studio\Open Studio.vbs")}
    @{Text="Forge";  Color="#8C325A"; Desc="Character Forge - final composition";     Target=(Join-Path $StudioRoot "Creators\C-Forge\Forge.exe")}
    @{Text="Fusion"; Color="#5A328C"; Desc="Fusion - dual LoRA testing (C#)";         Target=(Join-Path $StudioRoot "Creators\C-Fusion\C-Fusion.exe")}
    @{Text="Lab";    Color="#325A8C"; Desc="LoRA Lab - single LoRA testing";          Target=(Join-Path $StudioRoot "Creators\C-Lab\Lab.exe")}
)

# -------------------------------------------------------------------
# ROW 0 — Character suite launcher GroupBox
# -------------------------------------------------------------------
$rowBox = New-Object System.Windows.Forms.GroupBox
$rowBox.Text = "  CHARACTER SUITE"
$rowBox.Left  = $padLeft
$rowBox.Top   = $contentTop
$rowBox.Width = $rp.Width - $padLeft - $padRight
$rowBox.Height = 240
$rowBox.Anchor = "Top, Left"
$rowBox.ForeColor = [System.Drawing.Color]::FromArgb(200,180,120)
$rowBox.Font      = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$rowBox.BackColor = [System.Drawing.Color]::FromArgb(28,28,38)
$rp.Controls.Add($rowBox)

# Wrapper panel centers tiles
$csWrap = New-Object System.Windows.Forms.Panel
$csWrap.Dock = "Fill"
$rowBox.Controls.Add($csWrap)
$csFlow = New-Object System.Windows.Forms.FlowLayoutPanel
$csFlow.Left = 0; $csFlow.Top = 6; $csFlow.Height = $rowBox.Height - 30
$csFlow.WrapContents = $true; $csFlow.AutoScroll = $false
# Set initial width and centering so tiles are visible immediately
$csFlow.Width = $launcherDefs.Count * $tileW + ($launcherDefs.Count - 1) * 6 + 12
$csFlow.Left = [Math]::Max(0, [Math]::Floor(($csWrap.ClientSize.Width - $csFlow.Width) / 2))
$csWrap.Controls.Add($csFlow)
# Resize handler re-centers the flow panel when window is resized
$csWrap.Add_Resize({
    $totalW = $launcherDefs.Count * $tileW + ($launcherDefs.Count - 1) * 6 + 12
    $csFlow.Width = [Math]::Min($totalW, $csWrap.ClientSize.Width - 12)
    $csFlow.Left = [Math]::Max(0, [Math]::Floor(($csWrap.ClientSize.Width - $csFlow.Width) / 2))
})

foreach ($ld in $launcherDefs) {
    $tile = New-Object System.Windows.Forms.Button
    $tile.Text      = $ld.Text
    $tile.Width     = $tileW
    $tile.Height    = $tileH
    $tile.FlatStyle = "Flat"
    $tile.FlatAppearance.BorderSize = 0
    $tile.BackColor = ColorFromHex $ld.Color
    $tile.ForeColor = [System.Drawing.Color]::Black
    $tile.Font      = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
    $tile.TextAlign = "BottomCenter"
    $tile.TextImageRelation = "ImageAboveText"
    $tile.ImageAlign = "MiddleCenter"
    $img = Get-ToolImage $ld.Text $imgSz
    if ($img) { $tile.Image = $img; $tile.Padding = New-Object System.Windows.Forms.Padding(4,0,0,0) }
    $t = $ld.Target
    $isExe = $t -like '*.exe'
    $tile.Add_Click({
        if (-not $t) { return }
        if (-not (Test-Path $t)) {
            [System.Windows.Forms.MessageBox]::Show("File not found:`n$t", "Launch failed", "OK", "Error"); return
        }
        if ($isExe) {
            $workDir = [System.IO.Path]::GetDirectoryName($t)
            try { Start-Process -FilePath $t -WorkingDirectory $workDir -ErrorAction Stop }
            catch {
                $errMsg = $_.Exception.Message
                if ($errMsg -match "blocked|policy|Application Control|Access Denied|740") {
                    [System.Windows.Forms.MessageBox]::Show("$($ld.Text) is blocked by Windows Application Control.`n`nRun trust check:`n  .\tools\signing\Test-CFusionTrust.ps1`n`nInstall policy as Admin:`n  .\tools\signing\Install-CFusionLocalTrustPolicy.ps1 -Install`n`nIf managed, get approval first.", "Launch blocked", "OK", "Error")
                } else {
                    [System.Windows.Forms.MessageBox]::Show("Failed to launch $($ld.Text):`n$errMsg", "Launch failed", "OK", "Error")
                }
            }
        } else {
            try { Start-Process -FilePath $t -ErrorAction Stop } catch { [System.Windows.Forms.MessageBox]::Show("Failed to launch $($ld.Text):`n$($_.Exception.Message)", "Launch failed", "OK", "Error") }
        }
    }.GetNewClosure())
    (New-Object System.Windows.Forms.ToolTip).SetToolTip($tile, $ld.Desc)
    $csFlow.Controls.Add($tile)
}

# -------------------------------------------------------------------
# ROW 0b — Workers launcher GroupBox with embedded status panel
# -------------------------------------------------------------------
$wtileW = 200; $wtileH = 200; $wimgSz = 140

$script:mwProcess = $null
$script:mwOutEvent = $null
$script:mwErrEvent = $null
$script:mwExEvent = $null

function Write-MWLog($line) {
    $logDir = Join-Path (Join-Path $StudioRoot "Creators\MystikWorker") "logs"
    $logFile = Join-Path $logDir "dashboard-worker-latest.log"
    if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $line" | Out-File -FilePath $logFile -Encoding utf8 -Append
    $tsLogFile = Join-Path $logDir "dashboard-worker-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $line" | Out-File -FilePath $tsLogFile -Encoding utf8 -Append
}

function Append-WorkerOutput($text) {
    if ($workerOutputBox -and -not $workerOutputBox.IsDisposed) {
        try { $workerOutputBox.Invoke([Action]{ $workerOutputBox.AppendText("$text`r`n") }) } catch { }
    }
    Write-MWLog $text
}

function Update-WorkerStatus($status, $color) {
    if ($workerStatusLabel -and -not $workerStatusLabel.IsDisposed) {
        try { $workerStatusLabel.Invoke([Action]{ $workerStatusLabel.Text = "Status: $status"; $workerStatusLabel.ForeColor = [System.Drawing.Color]::FromArgb($color[0],$color[1],$color[2]) }) } catch { }
    }
}

function Start-MystikWorkerHidden {
    $exePath = Join-Path $StudioRoot "Creators\MystikWorker\MystikWorker.exe"
    $workDir = Join-Path $StudioRoot "Creators\MystikWorker"
    if (-not (Test-Path $exePath)) { Append-WorkerOutput "ERROR: $exePath not found"; return }
    if ($script:mwProcess -and -not $script:mwProcess.HasExited) { Append-WorkerOutput "Worker is already running (PID: $($script:mwProcess.Id))"; Update-WorkerStatus "Running" @(0,180,80); return }

    $tcp = New-Object System.Net.Sockets.TcpClient
    try { $tcp.Connect("127.0.0.1", 5005); $tcp.Dispose(); Append-WorkerOutput "Port 5005 is already in use. Checking health ..."
        try { $r = Invoke-WebRequest -Uri "http://127.0.0.1:5005/health" -UseBasicParsing -TimeoutSec 5; Append-WorkerOutput "Health: $($r.Content)" } catch { Append-WorkerOutput "Health check failed: $($_.Exception.Message)" }
        Update-WorkerStatus "Already Running" @(200,180,60); return
    } catch { $tcp.Dispose() }

    Append-WorkerOutput "Starting MystikWorker (hidden) ..."
    Update-WorkerStatus "Starting" @(180,180,80)

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $exePath; $psi.WorkingDirectory = $workDir
    $psi.UseShellExecute = $false; $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true; $psi.CreateNoWindow = $true

    $proc = New-Object System.Diagnostics.Process; $proc.StartInfo = $psi

    $outEvent = Register-ObjectEvent -InputObject $proc -EventName OutputDataReceived -MessageData $workerOutputBox -Action {
        $d = $EventArgs.Data; $box = $Event.MessageData
        if ($d -and $box -and -not $box.IsDisposed) { try { $box.Invoke([Action]{ $box.AppendText("$d`r`n") }) } catch { } }
    }

    $errEvent = Register-ObjectEvent -InputObject $proc -EventName ErrorDataReceived -MessageData $workerOutputBox -Action {
        $d = $EventArgs.Data; $box = $Event.MessageData
        if ($d -and $box -and -not $box.IsDisposed) { try { $box.Invoke([Action]{ $box.AppendText("ERR: $d`r`n") }) } catch { } }
    }

    $exEvent = Register-ObjectEvent -InputObject $proc -EventName Exited -MessageData $workerOutputBox -Action {
        $ec = $EventSource.ExitCode; $box = $Event.MessageData
        if ($box -and -not $box.IsDisposed) { try { $box.Invoke([Action]{ $box.AppendText("MystikWorker exited with code: $ec`r`n") }) } catch { } }
        Update-WorkerStatus "Stopped" @(140,140,140)
    }

    [void]$proc.Start(); $proc.BeginOutputReadLine(); $proc.BeginErrorReadLine()
    $script:mwProcess = $proc; $script:mwOutEvent = $outEvent; $script:mwErrEvent = $errEvent; $script:mwExEvent = $exEvent

    Append-WorkerOutput "MystikWorker started (PID: $($proc.Id))"
    Update-WorkerStatus "Running" @(0,180,80)
}

function Focus-MystikWorkerWindow {
    $exePath = Join-Path $StudioRoot "Creators\MystikWorker\MystikWorker.exe"
    $proc = Get-Process -Name "MystikWorker" -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $proc) { Append-WorkerOutput "No MystikWorker process found."; return }
    $proc.Refresh(); $hwnd = $proc.MainWindowHandle
    if ($hwnd -eq [IntPtr]::Zero) { $hwnd = [MystikWindowHelper]::FindWindowByAnyTitle(@("MystikWorker", "MystikWorker.exe", $exePath)) }
    if ($hwnd -eq [IntPtr]::Zero) { Append-WorkerOutput "No visible window found for MystikWorker."; return }
    try { $title = [MystikWindowHelper]::GetWindowTitle($hwnd) } catch { $title = "?" }
    Append-WorkerOutput "Focusing window: $title"
    [void][MystikWindowHelper]::ShowWindowAsync($hwnd, 9); [void][MystikWindowHelper]::SetForegroundWindow($hwnd)
    try { $screen = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
        $rect = New-Object RECT
        if ([MystikWindowHelper]::GetWindowRect($hwnd, [ref]$rect)) {
            $rw = $rect.Right - $rect.Left; $rh = $rect.Bottom - $rect.Top
            $cx = [Math]::Max($screen.Left, [Math]::Floor($screen.Left + ($screen.Width - $rw) / 2))
            $cy = [Math]::Max($screen.Top, [Math]::Floor($screen.Top + ($screen.Height - $rh) / 2))
            [void][MystikWindowHelper]::MoveWindow($hwnd, $cx, $cy, $rw, $rh, $true)
        }
    } catch { }
}

function Stop-MystikWorkerSafe {
    param([switch]$Quiet)
    $exePath = Join-Path $StudioRoot "Creators\MystikWorker\MystikWorker.exe"
    $targetProc = $null
    if ($script:mwProcess -and -not $script:mwProcess.HasExited) { $targetProc = $script:mwProcess }
    else { $targetProc = Get-Process -Name "MystikWorker" -ErrorAction SilentlyContinue | Select-Object -First 1 }
    if (-not $targetProc) { if (-not $Quiet) { Append-WorkerOutput "No MystikWorker process found to close." }; return }
    try { $path = $targetProc.MainModule.FileName } catch { $path = "" }
    if ($path -ne $exePath) {
        try { $pp = Get-NetTCPConnection -LocalPort 5005 -ErrorAction SilentlyContinue
            if ($pp) { $ppProc = Get-Process -Id $pp.OwningProcess -ErrorAction SilentlyContinue
                if ($ppProc) { try { $ppPath = $ppProc.MainModule.FileName } catch { $ppPath = "" }
                    if ($ppPath -ne $exePath) { return }
                }
            }
        } catch { }
        return
    }
    $workerPid = $targetProc.Id
    if ($Quiet) { Write-MWLog "Closing MystikWorker (PID: $workerPid) ..." } else { Append-WorkerOutput "Closing MystikWorker (PID: $workerPid) ..." }
    try {
        $targetProc.CloseMainWindow(); Start-Sleep -Milliseconds 500
        if (-not $targetProc.HasExited) { $targetProc.Kill() }
        if ($Quiet) { Write-MWLog "MystikWorker (PID: $workerPid) closed." } else { Append-WorkerOutput "MystikWorker (PID: $workerPid) closed." }
        $script:mwProcess = $null
        try { Update-WorkerStatus "Stopped" @(140,140,140) } catch { }
    } catch {
        if ($Quiet) { Write-MWLog "Failed to close: $($_.Exception.Message)" } else { Append-WorkerOutput "Failed to close: $($_.Exception.Message)" }
    }
}

function Close-MystikWorker {
    try { Stop-MystikWorkerSafe } catch { Append-WorkerOutput "Close Worker error: $($_.Exception.Message)" }
}

function Stop-AllDashboardWorkers {
    try { Stop-MystikWorkerSafe -Quiet } catch { Write-MWLog "Stop-AllDashboardWorkers error: $($_.Exception.Message)" }
}

function Clear-WorkerOutput { try { $workerOutputBox.Invoke([Action]{ $workerOutputBox.Clear() }) } catch { } }

function Refresh-WorkerStatus {
    try { $r = Invoke-WebRequest -Uri "http://127.0.0.1:5005/health" -UseBasicParsing -TimeoutSec 5; Append-WorkerOutput "Health: $($r.Content)"; Update-WorkerStatus "Running" @(0,180,80) } catch {
        if ($script:mwProcess -and -not $script:mwProcess.HasExited) { Append-WorkerOutput "Health check failed but process is running."; Update-WorkerStatus "Running" @(0,180,80) }
        else { Append-WorkerOutput "Health check: worker not reachable."; Update-WorkerStatus "Stopped" @(140,140,140) }
    }
}

$workerDefs = @(
    @{Text="MystikWorker"; Color="#326040"; Desc="C# Generation Worker - local ComfyUI bridge"}
)

$workersBox = New-Object System.Windows.Forms.GroupBox
$workersBox.Text = "  WORKERS"
$workersBox.Left  = $padLeft
$workersBox.Top   = $rowBox.Top + $rowBox.Height + 6
$workersBox.Width = $rowBox.Width
$workersBox.Height = 265
$workersBox.Anchor = "Top, Left"
$workersBox.ForeColor = [System.Drawing.Color]::FromArgb(180,200,180)
$workersBox.Font      = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$workersBox.BackColor = [System.Drawing.Color]::FromArgb(28,28,38)
$rp.Controls.Add($workersBox)

# Left panel: MystikWorker tile centered
$wrkLeft = New-Object System.Windows.Forms.Panel
$wrkLeft.Width = 215; $wrkLeft.Height = $workersBox.Height - 5
$wrkLeft.Left = 4; $wrkLeft.Top = 18
$wrkLeft.BackColor = [System.Drawing.Color]::FromArgb(28,28,38)
$workersBox.Controls.Add($wrkLeft)

$wrkFlow = New-Object System.Windows.Forms.FlowLayoutPanel
$wrkFlow.Dock = "Fill"
$wrkFlow.WrapContents = $true; $wrkFlow.AutoScroll = $false
$wrkLeft.Controls.Add($wrkFlow)

foreach ($wd in $workerDefs) {
    $wbtn = New-Object System.Windows.Forms.Button
    $wbtn.Text = $wd.Text; $wbtn.Width = $wtileW; $wbtn.Height = $wtileH
    $wbtn.FlatStyle = "Flat"; $wbtn.FlatAppearance.BorderSize = 0
    $wbtn.BackColor = ColorFromHex "#326040"
    $wbtn.ForeColor = [System.Drawing.Color]::Black
    $wbtn.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
    $wbtn.TextAlign = "BottomCenter"; $wbtn.TextImageRelation = "ImageAboveText"; $wbtn.ImageAlign = "MiddleCenter"
    $wimg = Get-ToolImage $wd.Text $wimgSz
    if ($wimg) { $wbtn.Image = $wimg; $wbtn.Padding = New-Object System.Windows.Forms.Padding(4,0,0,0) }
    $wbtn.Add_Click({ try { Start-MystikWorkerHidden } catch { Append-WorkerOutput "Error: $($_.Exception.Message)" } }.GetNewClosure())
    (New-Object System.Windows.Forms.ToolTip).SetToolTip($wbtn, $wd.Desc)
    $wrkFlow.Controls.Add($wbtn)
}

# Right panel: status, output box, buttons (fixed half-width for better proportions)
$wrkRight = New-Object System.Windows.Forms.Panel
$wrkRight.Left = $wrkLeft.Left + $wrkLeft.Width + 4
$wrkRight.Top = 18; $wrkRight.Width = 520
$wrkRight.Height = $workersBox.Height - 22
$wrkRight.BackColor = [System.Drawing.Color]::FromArgb(22,22,30)
$workersBox.Controls.Add($wrkRight)

$workerStatusLabel = New-Object System.Windows.Forms.Label
$workerStatusLabel.Text = "Status: Stopped"
$workerStatusLabel.ForeColor = [System.Drawing.Color]::FromArgb(140,140,140)
$workerStatusLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$workerStatusLabel.Left = 6; $workerStatusLabel.Top = 4; $workerStatusLabel.AutoSize = $true
$wrkRight.Controls.Add($workerStatusLabel)

$workerOutputBox = New-Object System.Windows.Forms.TextBox
$workerOutputBox.Multiline = $true; $workerOutputBox.ReadOnly = $true; $workerOutputBox.ScrollBars = "Vertical"
$workerOutputBox.Left = 6; $workerOutputBox.Top = 22
$workerOutputBox.Width = $wrkRight.Width - 12
$workerOutputBox.Height = $wrkRight.Height - 58
$workerOutputBox.Anchor = "Top, Left, Right, Bottom"
$workerOutputBox.BackColor = [System.Drawing.Color]::FromArgb(16,16,22)
$workerOutputBox.ForeColor = [System.Drawing.Color]::FromArgb(180,200,180)
$workerOutputBox.Font = New-Object System.Drawing.Font("Consolas", 8.5)
$wrkRight.Controls.Add($workerOutputBox)

# Buttons row (no Focus button)
$btnY = $workerOutputBox.Top + $workerOutputBox.Height + 4
$bw = 95; $bh = 24
$btnStart = New-Object System.Windows.Forms.Button
$btnStart.Text = "Start"; $btnStart.Left = 6; $btnStart.Top = $btnY; $btnStart.Width = $bw; $btnStart.Height = $bh
$btnStart.FlatStyle = "Flat"; $btnStart.FlatAppearance.BorderSize = 0
$btnStart.BackColor = [System.Drawing.Color]::FromArgb(0,100,50); $btnStart.ForeColor = [System.Drawing.Color]::White
$btnStart.Font = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Bold)
$btnStart.Add_Click({ try { Start-MystikWorkerHidden } catch { Append-WorkerOutput "Error: $($_.Exception.Message)" } })
$wrkRight.Controls.Add($btnStart)

$btnClose = New-Object System.Windows.Forms.Button
$btnClose.Text = "Close"; $btnClose.Left = $btnStart.Left + $btnStart.Width + 3; $btnClose.Top = $btnY
$btnClose.Width = $bw; $btnClose.Height = $bh
$btnClose.FlatStyle = "Flat"; $btnClose.FlatAppearance.BorderSize = 0
$btnClose.BackColor = [System.Drawing.Color]::FromArgb(100,30,30); $btnClose.ForeColor = [System.Drawing.Color]::White
$btnClose.Font = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Bold)
$btnClose.Add_Click({ Close-MystikWorker })
$wrkRight.Controls.Add($btnClose)

$btnClear = New-Object System.Windows.Forms.Button
$btnClear.Text = "Clear"; $btnClear.Left = $btnClose.Left + $btnClose.Width + 3; $btnClear.Top = $btnY
$btnClear.Width = $bw; $btnClear.Height = $bh
$btnClear.FlatStyle = "Flat"; $btnClear.FlatAppearance.BorderSize = 0
$btnClear.BackColor = [System.Drawing.Color]::FromArgb(60,60,60); $btnClear.ForeColor = [System.Drawing.Color]::White
$btnClear.Font = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Bold)
$btnClear.Add_Click({ Clear-WorkerOutput })
$wrkRight.Controls.Add($btnClear)

$btnRefresh = New-Object System.Windows.Forms.Button
$btnRefresh.Text = "Refresh"; $btnRefresh.Left = $btnClear.Left + $btnClear.Width + 3; $btnRefresh.Top = $btnY
$btnRefresh.Width = $bw; $btnRefresh.Height = $bh
$btnRefresh.FlatStyle = "Flat"; $btnRefresh.FlatAppearance.BorderSize = 0
$btnRefresh.BackColor = [System.Drawing.Color]::FromArgb(40,40,60); $btnRefresh.ForeColor = [System.Drawing.Color]::White
$btnRefresh.Font = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Bold)
$btnRefresh.Add_Click({ Refresh-WorkerStatus })
$wrkRight.Controls.Add($btnRefresh)

# -------------------------------------------------------------------
# Panel-box helper — stacks GroupBox + buttons, grows the column panel
# -------------------------------------------------------------------
function Add-PanelBox {
    param(
        [System.Windows.Forms.Panel]$Parent,
        [string]$Title,
        [object[]]$Buttons,
        [int]$CardWidth = 155
    )

    $box = New-Object System.Windows.Forms.GroupBox
    $box.Text      = "  $Title"
    $box.Left      = 1
    $box.Top       = 1
    $box.Width     = $CardWidth
    $box.ForeColor = [System.Drawing.Color]::FromArgb(170,180,200)
    $box.Font      = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Bold)
    $box.BackColor = [System.Drawing.Color]::FromArgb(28,28,38)

    $yy = 20
    $bw = $box.Width - 16
    foreach ($b in $Buttons) {
        $isMain = $b.ContainsKey('Icon') -and $b.Icon
        $btnHeight = if ($isMain) { 48 } else { 28 }

        $btn = New-Object System.Windows.Forms.Button
        $btn.Text      = $b.Text
        $btn.Left      = 8; $btn.Top = $yy
        $btn.Width     = $bw; $btn.Height = $btnHeight
        $btn.FlatStyle = "Flat"
        $btn.FlatAppearance.BorderSize = 0
        $btn.BackColor = ColorFromHex $b.Color
        $btn.ForeColor = [System.Drawing.Color]::White
        $btn.Font      = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)

        if ($isMain) {
            $img = Get-ToolImage $b.Icon 32
            if ($img) { $btn.Image = $img; $btn.TextImageRelation = "ImageAboveText"; $btn.ImageAlign = "MiddleCenter"; $btn.TextAlign = "MiddleCenter" }
        } else {
            $btn.TextAlign = "MiddleLeft"
            $btn.Padding   = New-Object System.Windows.Forms.Padding(6,0,0,0)
        }

        if ($b.Target) {
            $t = $b.Target
            $a = if ($b.ContainsKey('Arguments')) { $b.Arguments } else { $null }
            if     ($b.Mode -eq 'url') { $btn.Add_Click({ Start-Process $t }.GetNewClosure()) }
            elseif ($a)                { $btn.Add_Click({ Start-Process -FilePath $t -ArgumentList $a }.GetNewClosure()) }
            else                       { $btn.Add_Click({ Start-Process -FilePath $t }.GetNewClosure()) }
        } else { $btn.Enabled = $false }

        if ($b.Desc) { (New-Object System.Windows.Forms.ToolTip).SetToolTip($btn, $b.Desc) }
        $box.Controls.Add($btn)
        $yy += $btnHeight + 4
    }

    $box.Height    = $yy + 6
    $Parent.Controls.Add($box)
}

# -------------------------------------------------------------------
# ROW 2 — TOOLS & RESOURCES GroupBox (replaces old 5-column layout)
# -------------------------------------------------------------------
$toolsBox = New-Object System.Windows.Forms.GroupBox
$toolsBox.Text = "  TOOLS & RESOURCES"
$toolsBox.Left  = $padLeft
$toolsBox.Top   = $workersBox.Top + $workersBox.Height + 6
$toolsBox.Width = $rowBox.Width
$toolsBox.Anchor = "Top, Left"
$toolsBox.ForeColor = [System.Drawing.Color]::FromArgb(180,180,200)
$toolsBox.Font      = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$toolsBox.BackColor = [System.Drawing.Color]::FromArgb(28,28,38)
$rp.Controls.Add($toolsBox)

$webBtnList = @()
foreach ($t in $webTools) {
    $target = if ($t.Folder) { $t.Folder } else { $t.Launcher }
    $webBtnList += @{Text=$t.Name; Color=$t.Color; Desc=$t.Description; Target=$target}
}

$comfyRootPath  = "C:\Users\Michael\Documents\ComfyUI"
$studioTool = Join-Path $StudioRoot "Creators\Studio"
$forgeTool  = Join-Path $StudioRoot "Creators\Forge"
$fusionTool = Join-Path $StudioRoot "Creators\Fusion"
$labTool    = Join-Path $StudioRoot "Creators\Lab"
$workerTool = Join-Path $StudioRoot "Creators\MystikWorker"

# Flow layout panel — categories flow left-to-right, wrap to next row
$toolsInner = New-Object System.Windows.Forms.FlowLayoutPanel
$toolsInner.Dock = "Fill"
$toolsInner.Padding = New-Object System.Windows.Forms.Padding(6)
$toolsInner.AutoScroll = $false
$toolsInner.WrapContents = $true
$toolsBox.Controls.Add($toolsInner)

Add-PanelBox -Parent $toolsInner -Title "STUDIO" -Buttons @(
    @{Text="Studio Config";     Color="#DC143C"; Desc="Browse Studio config folder";                        Target=$studioTool}
    @{Text="Debug Studio";      Color="#DC143C"; Desc="Debug character generator workflow";                 Target=(Join-Path $studioTool "Start-Studio.ps1")}
    @{Text="Studio Folder";     Color="#DC143C"; Desc="Browse Studio folder";                              Target=$studioTool}
)
Add-PanelBox -Parent $toolsInner -Title "FORGE" -Buttons @(
    @{Text="Forge Config";     Color="#5A2840"; Desc="Browse Forge config folder";                         Target=$forgeTool}
    @{Text="Debug Forge";      Color="#5A2840"; Desc="Debug character design workflow";                    Target=(Join-Path $forgeTool "Debug_Forge.vbs")}
    @{Text="Forge Folder";     Color="#5A2840"; Desc="Browse Forge folder";                               Target=$forgeTool}
)
Add-PanelBox -Parent $toolsInner -Title "FUSION" -Buttons @(
    @{Text="Fusion Config";    Color="#3C2860"; Desc="Browse Fusion config folder";                        Target=$fusionTool}
    @{Text="Debug Fusion";     Color="#3C2860"; Desc="Debug LoRA Fusion workflow";                        Target=(Join-Path $fusionTool "Debug_Fusion.vbs")}
    @{Text="Fusion Folder";    Color="#3C2860"; Desc="Browse Fusion folder";                               Target=$fusionTool}
)
Add-PanelBox -Parent $toolsInner -Title "LAB" -Buttons @(
    @{Text="Lab Config";       Color="#284A70"; Desc="Browse Lab config folder";                          Target=$labTool}
    @{Text="Debug Lab";        Color="#284A70"; Desc="Debug LoRA Lab workflow";                           Target=(Join-Path $labTool "Debug_Lab.vbs")}
    @{Text="Lab Folder";       Color="#284A70"; Desc="Browse Lab folder";                                 Target=$labTool}
)
Add-PanelBox -Parent $toolsInner -Title "DEVELOPMENT" -Buttons @(
    @{Text="Open in VS Code";  Color="#2C2C32"; Desc="Open project in VS Code";                    Target="code";         Arguments=$StudioRoot}
    @{Text="Open Terminal";    Color="#2C2C32"; Desc="PowerShell at project root";                 Target="powershell.exe"; Arguments="-NoExit cd `"$StudioRoot`""}
    @{Text="GitHub Issues";    Color="#24292E"; Desc="Open repo issues";                           Target="https://github.com/Mystikvoyd/MystikStudio/issues"; Mode="url"}
)
Add-PanelBox -Parent $toolsInner -Title "WEB APPS" -Buttons $webBtnList
Add-PanelBox -Parent $toolsInner -Title "REPORTS & SESSION" -Buttons @(
    @{Text="Reports Folder";  Color="#463728"; Desc="Browse session reports";                       Target="$comfyRootPath\Reports"}
    @{Text="Session Module";  Color="#463728"; Desc="Shared session report module";                 Target=(Join-Path $StudioRoot "shared")}
    @{Text="Lab Config";      Color="#463728"; Desc="LoRA tester configuration";                    Target=(Join-Path $labTool "Lab.config.json")}
)
Add-PanelBox -Parent $toolsInner -Title "COMFYUI TOOLS" -Buttons @(
    @{Text="Open ComfyUI";    Color="#325032"; Desc="Launch ComfyUI web UI";                        Target="http://127.0.0.1:8000"; Mode="url"}
    @{Text="ComfyUI Manager"; Color="#325032"; Desc="Open ComfyUI Manager tab";                     Target="http://127.0.0.1:8000/manager"; Mode="url"}
    @{Text="ComfyUI Folder";  Color="#463728"; Desc="Browse ComfyUI root";                          Target=$comfyRootPath}
)
Add-PanelBox -Parent $toolsInner -Title "MODELS" -Buttons @(
    @{Text="LoRA Models";   Color="#373746"; Desc="Browse LoRA files";       Target="$comfyRootPath\models\loras"}
    @{Text="Checkpoints";   Color="#373746"; Desc="Checkpoint files";        Target="$comfyRootPath\models\checkpoints"}
    @{Text="ControlNet";    Color="#373746"; Desc="ControlNet models";       Target="$comfyRootPath\models\controlnet"}
    @{Text="VAE";           Color="#373746"; Desc="VAE models";              Target="$comfyRootPath\models\vae"}
)
Add-PanelBox -Parent $toolsInner -Title "WORKERS" -Buttons @(
    @{Text="Worker Folder";      Color="#326040"; Desc="Browse MystikWorker folder";                      Target=$workerTool}
    @{Text="Debug Worker";       Color="#326040"; Desc="Launch MystikWorker in debug command window";     Target="cmd.exe"; Arguments="/k `"$(Join-Path $workerTool 'Debug-MystikWorker.cmd')`""}
    @{Text="Worker Status";      Color="#326040"; Desc="Check port 5005 health and process info";         Target="powershell.exe"; Arguments="-NoProfile -File `"$workerTool\Check-WorkerStatus.ps1`""}
    @{Text="Worker Logs";        Color="#326040"; Desc="Browse MystikWorker logs";                        Target=(Join-Path $workerTool "logs")}
    @{Text="Delete Old Records"; Color="#3A2848"; Desc="Clean old worker logs, keep newest 5";           Target="powershell.exe"; Arguments="-NoProfile -File `"$workerTool\Cleanup-WorkerLogs.ps1`" -Keep 5 -Force"}
)

# -------------------------------------------------------------------
# Dynamic layout: calculate Tools height from card positions, sync on resize
# -------------------------------------------------------------------
function Sync-Layout {
    $rp.Width = $rightPanel.ClientSize.Width
    $sectionW = $rp.Width - $padLeft - $padRight
    $hdr.Width = $rp.Width
    $rowBox.Width = $sectionW
    $workersBox.Width = $sectionW
    $toolsBox.Width = $sectionW
    $toolsInner.PerformLayout()
    $maxCardBottom = 0
    foreach ($ctrl in $toolsInner.Controls) {
        $b = $ctrl.Top + $ctrl.Height
        if ($b -gt $maxCardBottom) { $maxCardBottom = $b }
    }
    $toolsBox.Height = [Math]::Max(180, $maxCardBottom + 20)
    $maxBottom = 0
    foreach ($c in @($rowBox, $workersBox, $toolsBox)) {
        $b = $c.Top + $c.Height
        if ($b -gt $maxBottom) { $maxBottom = $b }
    }
    $rp.Height = $maxBottom + 16
}

# Calculate initial layout after all cards are created
Sync-Layout

# Re-sync on resize (handles form resize and scrollbar appearance)
$rightPanel.Add_Resize({ Sync-Layout })

# -------------------------------------------------------------------
# Show
# -------------------------------------------------------------------
$form.Add_FormClosing({
    Stop-AllDashboardWorkers
})
$form.Add_Shown({
    $form.Activate()
    # Write layout log after form is fully laid out
    try {
        $logDir = Join-Path (Join-Path $StudioRoot "Creators") "logs"
        if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
        $logPath = Join-Path $logDir "dashboard-layout.log"
        $sectionW = $rp.Width - $padLeft - $padRight
        $toolsInner.PerformLayout()
        $maxCardBottom = 0; $clippedSections = @()
        foreach ($ctrl in $toolsInner.Controls) { $b = $ctrl.Top + $ctrl.Height; if ($b -gt $maxCardBottom) { $maxCardBottom = $b } }
        $toolsPadding = $toolsBox.Height - $maxCardBottom
        if ($toolsPadding -gt 80) { $clippedSections += "WARNING: Tools & Resources empty height: $toolsPadding px beyond cards" }
        foreach ($c in @($rowBox, $workersBox, $toolsBox)) {
            if ($c.Left + $c.Width -gt $rp.Width) { $clippedSections += "WARNING: '$($c.Text.Trim())' right edge ($($c.Left+$c.Width)) exceeds rp width ($($rp.Width))" }
        }
        $cardsPerRow = if ($toolsInner.Controls.Count -gt 0) { [math]::Floor($toolsInner.ClientSize.Width / ($toolsInner.Controls[0].Width + 6)) } else { 0 }
        $totalRows = if ($cardsPerRow -gt 0) { [math]::Ceiling($toolsInner.Controls.Count / $cardsPerRow) } else { 0 }
        $mainNeedsScroll = $rp.Height -gt $rightPanel.ClientSize.Height
        $workerCmdPath = Join-Path (Join-Path $StudioRoot "Creators\MystikWorker") "Debug-MystikWorker.cmd"
        $logLines = @(
            "=== MystikStudio Dashboard Layout Report ===",
            "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
            "Dashboard window size: $($form.ClientSize.Width) x $($form.ClientSize.Height)",
            "Minimum size: $($form.MinimumSize.Width) x $($form.MinimumSize.Height)",
            "Main content padding: left=$padLeft right=$padRight (scrollbar reserve: 20 px)",
            "Main content width (sectionW): $sectionW",
            "Tools card width: 155 px",
            "Cards per row: ~$cardsPerRow   Total rows: ~$totalRows",
            "Main page requires scrolling: $mainNeedsScroll",
            "Tools & Resources inner scrollbar: $($toolsInner.AutoScroll)",
            "",
            "Debug Worker command path: $workerCmdPath",
            "Worker folder path: $(Join-Path $StudioRoot 'Creators\MystikWorker')",
            "Worker logs path: $(Join-Path $StudioRoot 'Creators\MystikWorker\logs')",
            "",
            "--- Sections ---",
            "Character Suite bounds: left=$($rowBox.Left) top=$($rowBox.Top) width=$($rowBox.Width) height=$($rowBox.Height)",
            "Character Suite tile container (csFlow) bounds: left=$($csFlow.Left) top=$($csFlow.Top) width=$($csFlow.Width) height=$($csFlow.Height)",
            "Number of Character Suite tiles created: $($csFlow.Controls.Count)",
            ""
        )
        foreach ($tile in $csFlow.Controls) {
            $target = ""
            foreach ($ld in $launcherDefs) {
                if ($ld.Text -eq $tile.Text) { $target = $ld.Target; break }
            }
            $logLines += "  Tile: '$($tile.Text)'  bounds: l=$($tile.Left) t=$($tile.Top) w=$($tile.Width) h=$($tile.Height)  launch: $target"
        }
        $logLines += ""
        $logLines += "Fusion tile launch target: $($launcherDefs[2].Target)"
        $logLines += "Workers bounds: left=$($workersBox.Left) top=$($workersBox.Top) width=$($workersBox.Width) height=$($workersBox.Height)"
        $logLines += "Tools & Resources bounds: left=$($toolsBox.Left) top=$($toolsBox.Top) width=$($toolsBox.Width) height=$($toolsBox.Height)"
        $logLines += "Tools & Resources calculated height: $($toolsBox.Height) (max card bottom: $maxCardBottom + 20 pad)"
        $logLines += ""
        $logLines += "--- Tools & Resources Cards ---"
        foreach ($ctrl in $toolsInner.Controls) {
            $logLines += "  Card: '$($ctrl.Text.Trim())'  bounds: l=$($ctrl.Left) t=$($ctrl.Top) w=$($ctrl.Width) h=$($ctrl.Height)"
        }
        $logLines += ""
        if ($clippedSections.Count -gt 0) { $logLines += $clippedSections } else { $logLines += "No sections exceed visible content width." }
        $logLines += "========================================="
        $logLines | Out-File -FilePath $logPath -Encoding utf8
    } catch { }
})
[void]$form.ShowDialog()

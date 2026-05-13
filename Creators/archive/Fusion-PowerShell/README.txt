PowerShell Fusion - Archived Launch Path
=========================================
Archived: 2026-05-12

What was archived?
------------------
The old PowerShell Fusion launcher and metadata. The PowerShell Fusion app
files still exist in their original location and are NOT deleted. Only the
Dashboard Character Suite button was updated to launch the C# Fusion exe
instead of the PowerShell version.

Original PowerShell Fusion location:
  H:\MystikStudio\Creators\Fusion\

Original launch script:
  H:\MystikStudio\Creators\Fusion\Open Fusion.vbs

Original Dashboard tool.json:
  H:\MystikStudio\Creators\Fusion\tool.json

Original PowerShell entry point:
  H:\MystikStudio\Creators\Fusion\Start-Fusion.ps1

Current Dashboard Fusion button behavior:
------------------------------------------
The Fusion card in the Dashboard's Character Suite now launches:
  H:\MystikStudio\Creators\C-Fusion\C-Fusion.exe

How to restore the old PowerShell Fusion button:
--------------------------------------------------
1. Edit the Dashboard script:
     H:\MystikStudio\Start-MystikStudioDashboard.ps1

2. Find the $launcherDefs array (around line 207) and change the Fusion entry:
     Old (current): @{Text="Fusion"; Color="#5A328C"; Desc="..."; Target=(Join-Path $StudioRoot "Creators\C-Fusion\C-Fusion.exe")}
     Restore:       @{Text="Fusion"; Color="#5A328C"; Desc="LoRA Fusion - dual LoRA testing"; Target=(Join-Path $StudioRoot "Creators\Fusion\Open Fusion.vbs")}

3. Save and restart the Dashboard.

Notes:
- The C-Fusion exe remains at: H:\MystikStudio\Creators\C-Fusion\C-Fusion.exe
- The old PowerShell Fusion is not deleted and can still be launched directly.
- Both versions can coexist. Only the Dashboard button changed.
- Dashboard baseline version: V01.02.01xxA
- Recovery tag: recovery/dashboard-V01.02.01xxA

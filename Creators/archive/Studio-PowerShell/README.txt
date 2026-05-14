Studio-PowerShell — Preserved as Studio-PS
=========================================
Archived: 2026-05-13
Baseline at migration: V01.02.01xxB

The old PowerShell Studio app is preserved as Studio-PS.

Current Dashboard Studio target: Creators\Studio\Open Studio.vbs (PowerShell — working)
Staged C# Studio target: Creators\C-Studio\Studio.exe (C# — signed, blocked by App Control)

C-Studio.exe is signed (Valid) with the same dev cert as Fusion/Lab/Forge.
But Windows Smart App Control blocks it because the self-signed cert lacks cloud reputation.

To activate C-Studio later:
1. Install a hash-based WDAC supplemental policy for Studio.exe
   (same pattern as Install-CFusionLocalTrustPolicy.ps1)
2. Confirm Studio.exe opens directly on user machine
3. Change Dashboard target to: Creators\C-Studio\Studio.exe
4. Update this README accordingly

Old PowerShell Studio location (preserved):
  H:\MystikStudio\Creators\Studio

Rollback instructions (if switching later):
  1. Edit the Dashboard script
  2. Find the $launcherDefs array and change Studio Target back to:
       Target=(Join-Path $StudioRoot "Creators\Studio\Open Studio.vbs")
  3. Save and restart the Dashboard.

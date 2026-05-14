Forge-PowerShell — Preserved as Forge-PS
=========================================
Archived: 2026-05-13
Baseline at migration: V01.02.01xxB

The old PowerShell Forge app is preserved as Forge-PS.

Current Dashboard Forge target: Creators\Forge\Open Forge.vbs (PowerShell — working)
Staged C# Forge target: Creators\C-Forge\Forge.exe (C# — signed, opens directly, awaiting user confirmation)

To activate C-Forge later:
1. Confirm Forge.exe opens directly on user machine
2. Change Dashboard target to: Creators\C-Forge\Forge.exe
3. Update this README accordingly

Old PowerShell Forge location (preserved):
  H:\MystikStudio\Creators\Forge

Rollback instructions (if switching later):
  1. Edit the Dashboard script
  2. Find the $launcherDefs array and change Forge Target back to:
       Target=(Join-Path $StudioRoot "Creators\Forge\Open Forge.vbs")
  3. Save and restart the Dashboard.

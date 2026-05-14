Forge-PowerShell — Preserved as Forge-PS
=========================================
Archived: 2026-05-13
Baseline at migration: V01.02.01xxB

Current Dashboard Forge target: Creators\C-Forge\Forge.exe (C# exe — active)
Old PowerShell Forge preserved as Forge-PS at: H:\MystikStudio\Creators\Forge

To restore the old PowerShell Forge button:
  1. Edit the Dashboard script
  2. Find the $launcherDefs array and change Forge Target back to:
       Target=(Join-Path $StudioRoot "Creators\Forge\Open Forge.vbs")
  3. Save and restart the Dashboard.

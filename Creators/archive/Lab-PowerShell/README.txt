Lab-PowerShell — Preserved as Lab-PS
=========================================
Archived: 2026-05-13
Baseline at migration: V01.02.01xxB

Current Dashboard Lab target: Creators\C-Lab\Lab.exe (C# exe — active)
Old PowerShell Lab preserved as Lab-PS at: H:\MystikStudio\Creators\Lab

To restore the old PowerShell Lab button:
  1. Edit the Dashboard script
  2. Find the $launcherDefs array and change Lab Target back to:
       Target=(Join-Path $StudioRoot "Creators\Lab\Open Lab.vbs")
  3. Save and restart the Dashboard.

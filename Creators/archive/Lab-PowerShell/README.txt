Lab-PowerShell — Preserved as Lab-PS
=========================================
Archived: 2026-05-13
Baseline at migration: V01.02.01xxB

The old PowerShell Lab app is now preserved as Lab-PS.

The Dashboard now launches the C# exe version for Lab.

Old PowerShell Lab location (preserved):
  H:\MystikStudio\Creators\Lab

Old Dashboard launch:
  H:\MystikStudio\Creators\Lab\Open Lab.vbs

New Dashboard launch:
  H:\MystikStudio\Creators\C-Lab\Lab.exe

How to restore the old PowerShell Lab button:
  1. Edit the Dashboard script:
       H:\MystikStudio\Start-MystikStudioDashboard.ps1
  2. Find the $launcherDefs array and change the Lab entry back to:
       Target=(Join-Path $StudioRoot "Creators\Lab\Open Lab.vbs")
  3. Save and restart the Dashboard.

Notes:
  The C# Lab exe is at: H:\MystikStudio\Creators\C-Lab\Lab.exe
  The old PowerShell Lab is not deleted and can still be launched directly.
  Both versions can coexist. Only the Dashboard button changed.

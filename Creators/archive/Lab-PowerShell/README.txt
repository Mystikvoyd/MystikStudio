Lab-PowerShell — Preserved as Lab-PS
=========================================
Archived: 2026-05-13
Baseline at migration: V01.02.01xxB

IMPORTANT: Lab PowerShell remains the ACTIVE Dashboard Lab target.
C-Lab is staged but blocked by Windows Smart App Control.

To activate C-Lab later:
1. Solve signing/trust issue for C-Lab\Lab.exe
2. Change Dashboard target to: Creators\C-Lab\Lab.exe
3. Update this README accordingly.

Old PowerShell Lab location (preserved):
  H:\MystikStudio\Creators\Lab

Current Dashboard launch (working):
  H:\MystikStudio\Creators\Lab\Open Lab.vbs

Staged C# Dashboard target (blocked until trust solved):
  H:\MystikStudio\Creators\C-Lab\Lab.exe

How to check C-Lab trust status:
  .\tools\signing\Test-CFusionTrust.ps1 (Fusion trust check)
  Similar trust setup will be needed for C-Lab.

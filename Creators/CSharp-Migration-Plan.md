# C# Migration Plan — MystikStudio Creators

## 1. Current Approved Baseline

- **Dashboard Version:** V01.02.01xxB
- **Explorer sidebar:** Removed
- **Split layout:** Removed
- **Character Suite:** Studio, Forge, Fusion (exe), Lab — compact centered tiles
- **Workers Section:** Embedded MystikWorker panel with Start/Close/Clear/Refresh
- **Tools & Resources:** Compact card layout with WORKERS card
- **Fusion:** Promoted to C-Fusion.exe, named "Fusion", old PowerShell preserved as Fusion-PS
- **MystikWorker:** Closes when Dashboard closes (FormClosing handler)
- **Recovery tag:** `recovery/dashboard-worker-V01.02.01xxB`

## 2. Fusion Migration Pattern

### Compilation
- Build script: `Creators\C-Fusion\Build-CFusion.ps1`
- Compiler: `csc.exe` (.NET Framework 4.8, `/target:winexe`)
- Source: `Creators\C-Fusion\CFusion.cs`
- Output: `Creators\C-Fusion\C-Fusion.exe`
- Icon: `/win32icon:"H:\MystikStudio\Icons\Fusion.ico"` (added in Entry 43)
- Version: Embed from `Creators\C-Fusion\version.txt`

### Dashboard Integration
- **Character Suite card:** Text = "Fusion", Color = `#5A328C`, Target = `C-Fusion.exe`
- **Dashboard launch:** Direct `Start-Process -FilePath $t -WorkingDirectory $workDir`
- **Dashboard error handling:** Blocked/AppControl check with trust script guidance
- **Icon source:** `H:\MystikStudio\Icons\Fusion.ico`
- **tool.json** exists at `Creators\C-Fusion\tool.json` for `Find-Tools` discovery

### Old PowerShell Preservation
- Original PowerShell files kept at `Creators\Fusion\`
- Archive readme at `Creators\archive\Fusion-PowerShell\README.txt`
- Old PowerShell now referred to as **Fusion-PS**
- Rollback instructions documented in archive README

### Signing
- Dev signing via `tools\signing\Sign-MystikStudioExe.ps1`
- WDAC supplemental policy via `tools\signing\Install-CFusionLocalTrustPolicy.ps1`
- Smart App Control may block self-signed exe without local WDAC policy

### Versioning
- Build script reads version from `Creators\C-Fusion\version.txt`
- Dashboard version tracked separately (`V01.02.01xxB`)
- VERSION_LOG.txt documents all changes

## 3. Studio Inventory

- **Path:** `H:\MystikStudio\Creators\Studio`
- **Launch script:** `Open Studio.vbs` (launches `Start-Studio.ps1`)
- **Main script:** `Start-Studio.ps1`
- **Config:** `Studio.config.json`, `Studio-saves.json`
- **tool.json:** name="Studio", color="#503C82", launcher="Open Studio.vbs"
- **Icon:** `H:\MystikStudio\Icons\Studio.ico`
- **Dashboard target:** `Creators\Studio\Open Studio.vbs`
- **Dashboard card text:** "Studio", Color: `#DC143C` (card uses different color from tool.json)
- **VERSION.txt:** Component: PowerShell Studio, Version: 0.1.0-alpha.1
- **App type:** Windows Forms (PowerShell)
- **Risks:** Studio is the most complex app. It's the central character generation tool. Highest migration risk.

## 4. Forge Inventory

- **Path:** `H:\MystikStudio\Creators\Forge`
- **Launch script:** `Open Forge.vbs` (launches `Start-Forge.ps1`)
- **Main script:** `Start-Forge.ps1`
- **Debug script:** `Debug_Forge.vbs`, `Debug-ForgeWorkflow.ps1`
- **Config:** `Forge.config.json`, `Forge.prefs.json`
- **Test script:** `Test-ForgeValidation.ps1`
- **tool.json:** name="Forge", color="#8C325A", launcher="Open Forge.vbs"
- **Icon:** `H:\MystikStudio\Icons\Forge.ico`
- **Dashboard target:** `Creators\Forge\Open Forge.vbs`
- **Dashboard card text:** "Forge", Color: `#8C325A`
- **VERSION.txt:** Component: PowerShell Forge, Version: 0.1.0-alpha.1
- **App type:** Windows Forms (PowerShell)

## 5. Lab Inventory

- **Path:** `H:\MystikStudio\Creators\Lab`
- **Launch script:** `Open Lab.vbs` (launches `Start-Lab.ps1`)
- **Main script:** `Start-Lab.ps1`
- **Debug script:** `Debug_Lab.vbs`, `Debug-LabWorkflow.ps1`
- **Config:** `Lab.config.json`, `Lab.prefs.json`
- **Data:** `data/` folder, `Lab.runlog.json`
- **Test scripts:** `Test-LabSessionReport.ps1`, `Test-LabValidation.ps1`
- **tool.json:** name="Lab", color="#325A8C", launcher="Open Lab.vbs"
- **Icon:** `H:\MystikStudio\Icons\Lab.ico`
- **Dashboard target:** `Creators\Lab\Open Lab.vbs`
- **Dashboard card text:** "Lab", Color: `#325A8C`
- **VERSION.txt:** Component: PowerShell Lab, Version: 0.1.0-alpha.1
- **App type:** Windows Forms (PowerShell)
- **Lowest complexity.** Good first migration candidate.

## 6. Proposed C# Folder Structure

```
Creators\
  C-Studio\             # Future C# Studio app
    src\                # C# source files
    build\              # Build output
    logs\               # Runtime logs
    version.txt         # App version
    README.md           # Scaffold notes
  C-Forge\              # Future C# Forge app
    src\
    build\
    logs\
    version.txt
    README.md
  C-Lab\                # Future C# Lab app
    src\
    build\
    logs\
    version.txt
    README.md
```

### Planned exe names
- Lab: `Creators\C-Lab\Lab.exe`
- Forge: `Creators\C-Forge\Forge.exe`
- Studio: `Creators\C-Studio\Studio.exe`

### Planned icon paths
- Studio: `H:\MystikStudio\Icons\Studio.ico`
- Forge: `H:\MystikStudio\Icons\Forge.ico`
- Lab: `H:\MystikStudio\Icons\Lab.ico`

## 7. Proposed Dashboard Launch Changes

### Current launch targets (UNCHANGED in this pass)
| App | Current Target | Target Type |
|-----|---------------|-------------|
| Studio | `Creators\Studio\Open Studio.vbs` | VBS launcher |
| Forge | `Creators\Forge\Open Forge.vbs` | VBS launcher |
| Lab | `Creators\Lab\Open Lab.vbs` | VBS launcher |

### Future launch targets (after migration)
| App | Future Target | Target Type |
|-----|---------------|-------------|
| Studio | `Creators\C-Studio\Studio.exe` | Direct exe |
| Forge | `Creators\C-Forge\Forge.exe` | Direct exe |
| Lab | `Creators\C-Lab\Lab.exe` | Direct exe |

### Card names and colors (unchanged)
- Studio: Text="Studio", Color="#DC143C"
- Forge: Text="Forge", Color="#8C325A"
- Lab: Text="Lab", Color="#325A8C"

## 8. Proposed Rollback Plan

### Archive structure
```
Creators\archive\
  Studio-PowerShell\README.txt    # Future archive
  Forge-PowerShell\README.txt     # Future archive
  Lab-PowerShell\README.txt       # Future archive
  Fusion-PowerShell\README.txt    # Existing archive (already migrated)
```

### Per app rollback
1. Keep original PowerShell files at their original location (do not delete)
2. Create archive README documenting original launch path
3. Dashboard targets point to exe; original VBS/PS1 are bypassed but not removed
4. To restore: edit `$launcherDefs` in Dashboard script, change Target back to original VBS path

## 9. Proposed Versioning Plan

- Each C# exe gets its own `version.txt` (e.g., `Creators\C-Lab\version.txt`)
- Each C# exe gets a build script (e.g., `Build-CLab.ps1`) following Fusion pattern
- Dashboard version stays at `V01.02.01xxB` until all migrations complete
- VERSION_LOG.txt tracks each migration step
- Old PowerShell apps keep their existing `VERSION.txt` as-is (preserved for rollback)

## 10. Risks and Blockers

### Smart App Control / WDAC
- C# exes will be blocked by Smart App Control just like C-Fusion was
- Each new exe needs either a WDAC supplemental policy or real CA signing
- WDAC policy must be updated for each exe (hash or signer based)

### Build Environment
- Requires .NET Framework 4.8 SDK (`csc.exe` at `C:\Windows\Microsoft.NET\Framework64\v4.0.30319\`)
- Each app needs to define UI in C# WinForms (equivalent to current PowerShell WinForms)

### Complexity
- **Studio (highest):** Complex character generation workflow, multiple config files, tightest integration with ComfyUI
- **Forge (medium):** Character composition, chain LoRAs, production-ready output
- **Lab (lowest):** Single LoRA testing, simplest workflow, best first candidate

### ComfyUI Dependency
- All three apps depend on ComfyUI being reachable
- The worker dependency (MystikWorker) may need to be running for some operations

## 11. Recommended Migration Order

1. **Lab first** — simplest app, lowest risk, good pattern validation
2. **Forge second** — medium complexity, benefits from Lab migration learnings
3. **Studio last** — most complex, benefits from both prior migrations

### Rationale
Lab has: fewest scripts, fewest config files, simplest workflow, lowest user impact.
Starting with the smallest app validates the migration pattern before tackling Studio.
Each migration should follow the same pattern documented in Section 2.

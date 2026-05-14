# MystikStudio Living Handoff

Last updated: 2026-05-13
Repo: `Mystikvoyd/MystikStudio`
Default branch: `master`

This is the living handoff for coordinating new ChatGPT, OpenCode, and local development sessions. Read this first before making changes.

## Current locked baseline

Dashboard baseline: `V01.02.01xxB`

Recovery tag:

`recovery/dashboard-worker-V01.02.01xxB`

Known locked state:

- Dashboard opens from the approved compact layout.
- Explorer sidebar is removed.
- No split layout.
- Character Suite shows Studio, Forge, Fusion, and Lab.
- Fusion visible card launches the current exe version.
- Old PowerShell Fusion is preserved as Fusion-PS or rollback path.
- MystikWorker has an embedded Dashboard panel.
- MystikWorker starts from the Dashboard without a normal external console.
- MystikWorker can be closed from the Dashboard.
- MystikWorker closes automatically when the Dashboard closes.
- Tools & Resources layout is compact.

## Current app target status

Current working rule:
Do not point the Dashboard at a C# exe that is blocked by Windows Application Control.

### Fusion

Status: Active C# exe target.

Fusion is the approved migration model.

Old PowerShell Fusion is preserved through the Fusion-PS rollback documentation.

### Lab

Current Dashboard target: PowerShell fallback

`Creators\Lab\Open Lab.vbs`

C# staged target:

`Creators\C-Lab\Lab.exe`

Status:
C-Lab exists and was rebuilt with native GPU status work but is currently blocked by WDAC after rebuild because the binary hash changed.

### Forge

Current Dashboard target: PowerShell fallback

`Creators\Forge\Open Forge.vbs`

C# staged target:

`Creators\C-Forge\Forge.exe`

Status:
C-Forge exists and was rebuilt with native GPU status work but is currently blocked by WDAC after rebuild because the binary hash changed.

### Studio

Current Dashboard target: PowerShell

`Creators\Studio\Open Studio.vbs`

Planned C# target:

`Creators\C-Studio\Studio.exe`

Status:
Studio has not yet been fully migrated and activated. Studio is higher risk and should come after the Lab and Forge trust path is clean.

## Windows Application Control and WDAC status

Lab and Forge C# exes are blocked by the system base WDAC policy at Enterprise signing level.

Policy ID:

`{0283ac0f-fff1-49ae-ada1-8a933130cad6}`

Observed block events:

- Event 3077
- Event 3033

Known hashes after GPU-status rebuild:

- Lab.exe: `B1CE724529BCA0B1C98539B355A45B1696033BF173B47D992DF64AED3DFCEE7B`
- Forge.exe: `27784822EE7F6AC3E7031199F886C9EAF21840A657AEE1C91CFF5F3D60E85AA4`

Mark of the Web was not present on either file.

Both were signed with:

`CN=MystikStudio Local Dev Code Signing`

The current WDAC trust process is hash based. Rebuilding an exe changes its hash and requires a new supplemental trust policy or a stronger signer-based deployment path.

Do not keep rerunning the same trust scripts blindly. Verify policy coverage and install status.

## Trust workflow needed next

Create or use a unified trust workflow:

`tools\signing\Install-MystikStudioLocalTrustPolicy.ps1`

Desired options:

- `-Install`
- `-Test`
- `-Status`

It should cover the current C# creator exes:

- Fusion exe path currently used by Dashboard
- `Creators\C-Lab\Lab.exe`
- `Creators\C-Forge\Forge.exe`
- eventually `Creators\C-Studio\Studio.exe`

Admin install is required to copy supplemental policy files to:

`C:\Windows\System32\CodeIntegrity\`

A reboot is required after installing or refreshing WDAC policy.

After reboot, run a post reboot activation script only if direct launch succeeds:

`tools\Activate-CSharpCreatorTargets.ps1`

That script should only switch Lab and Forge Dashboard targets back to C# if both exes launch successfully.

If either C# exe is still blocked, keep Dashboard targets on PowerShell fallback.

## Current Dashboard target rule

Dashboard must remain usable.

If C# Lab or C# Forge is blocked, keep these fallbacks active:

- Lab: `Creators\Lab\Open Lab.vbs`
- Forge: `Creators\Forge\Open Forge.vbs`

Only activate:

- Lab: `Creators\C-Lab\Lab.exe`
- Forge: `Creators\C-Forge\Forge.exe`

when direct launch is confirmed after trust install and reboot.

## Native GPU status work

Recent C# Lab and Forge work added a shared GPU helper:

`Creators\shared\GpuStatusProvider.cs`

Intent:

- Use Windows native GPU status first.
- Use `Win32_VideoController` for GPU name and VRAM total.
- Use `GPU Adapter Memory` performance counters for dedicated and shared usage when available.
- Use ComfyUI `/system_stats` only for online or offline status context.
- Do not rely on `nvidia-smi`.
- Do not open helper command windows.

Known limitation:
Windows performance counters may show `?` for VRAM usage depending on driver and counter availability.

## Recent issue: Dashboard VBS launcher

The VBS launcher had a failure:

`Invalid use of Null: 'CStr'`

File:

`H:\MystikStudio\Open MystikStudio Dashboard.vbs`

The fix should be to safely handle Null before using `CStr`, especially around WMI process data or command line duplicate detection.

Dashboard may work when launched directly by PowerShell even if the VBS launcher is broken.

Direct launch command:

`powershell.exe -NoProfile -ExecutionPolicy Bypass -File H:\MystikStudio\Start-MystikStudioDashboard.ps1`

## Versioning notes

Current Dashboard baseline remains:

`V01.02.01xxB`

Do not bump the Dashboard baseline unless the user explicitly asks to lock a new recovery state.

Append all meaningful work to:

`Creators\VERSION_LOG.txt`

Follow:

`Creators\VERSIONING.txt`

## Development rules

- Do not change Dashboard layout unless the user explicitly requests it.
- Do not break the `V01.02.01xxB` baseline.
- Keep PowerShell versions preserved as rollback.
- Do not delete old PowerShell app folders.
- Do not point Dashboard at blocked C# exes.
- Do not commit private keys, PFX files, tokens, secrets, runtime junk, or large generated output.
- Keep GitHub `master` as the coordination source.
- Prefer small targeted commits.
- Report files changed, checks run, commit hash, and push result.

## Recommended next work

1. Fix or confirm the VBS Dashboard launcher if it is still broken.
2. Create unified MystikStudio trust scripts for creator exes.
3. Run trust install as Administrator.
4. Reboot.
5. Confirm C-Lab and C-Forge launch directly.
6. Only then activate C-Lab and C-Forge Dashboard targets.
7. After Lab and Forge are stable, continue Studio migration.

## Startup checklist for a new session

1. Pull latest `master`.
2. Read this handoff.
3. Read `Creators\VERSION_LOG.txt`.
4. Read `Creators\CSharp-Migration-Plan.md`.
5. Confirm Dashboard version is still `V01.02.01xxB`.
6. Confirm current Dashboard targets before editing.
7. Make only the requested targeted change.
8. Commit and push.
9. Update this handoff when the project state changes.

# Fusion Last Known Working Backup

## Why This Backup Exists
Fusion direct exe launch is grandfathered — the current `C-Fusion.exe` hash is covered by the
`MystikStudioCreators.p7b` policy in `C:\Windows\System32\CodeIntegrity\`. Rebuilding from source
will produce a different hash and Fusion will be blocked by Windows App Control (same as Lab and
Forge). This backup preserves the exact working binary.

## Exact Fusion Hash
SHA256: `12181699FC565357DFA8D90A055ACD96C371D04B80094F451E06FCFD896B0CDF`
Size: 58,368 bytes
Built: 05/12/2026 20:20:14
Signature: `CN=MystikStudio Local Dev Code Signing` — Status: Valid

## Warnings
- **Rebuilding from source may not reproduce the same hash.** The compiled binary depends on the C#
  compiler version, source content, and embedding resources. Expect different hash after any rebuild.
- **Do not delete `MystikStudioCreators.p7b`** from `C:\Windows\System32\CodeIntegrity\`.
  Removing it may cause Fusion to stop launching even with this backup binary.
- **Do not attempt WDAC changes.** The supplemental policy path does not work on this system.

## Contents
| File | Description |
|------|-------------|
| `C-Fusion.exe` | Exact working binary (58,368 bytes) |
| `fusion-sha256.txt` | Recorded SHA256 hash |
| `Start-MystikStudioDashboard.ps1` | Dashboard at time of backup |
| `CSharp-Migration-Plan.md` | Migration plan at time of backup |
| `FUSION_TRUST_INVESTIGATION.md` | Trust investigation at time of backup |

## How to Restore
Run from repo root:
```
.\tools\Restore-FusionLastKnownWorking.ps1
```
Type `RESTORE FUSION LKG` when prompted.

## Recovery Tag
`fusion-lkg-direct-launch-before-gpu-vram`

# C-Forge — Active C# Version

**Status:** Active Dashboard target. Forge.exe signed, opens directly, ComfyUI integration complete.

## Active Dashboard Target
- **Current:** `Creators\C-Forge\Forge.exe` (C# — active, signed, requires WDAC refresh after rebuild)
- **Old PowerShell preserved as Forge-PS:** `Creators\Forge\`

## Trust Status
- **Signature:** Signed with `CN=MystikStudio Local Dev Code Signing` — Status: Valid
- **Direct launch test:** Requires WDAC trust refresh after GPU rebuild (Entry 55).
- **WDAC policy:** Hash-based supplemental policy at `%TEMP%\MystikStudioCForge_v2.p7b`.
  **Admin must run in elevated PowerShell, then reboot:**
  ```
  Copy-Item "$env:TEMP\MystikStudioCForge_v2.p7b" "C:\Windows\System32\CodeIntegrity\" -Force
  ```
- **Current hash:** `27784822EE7F6AC3E7031199F886C9EAF21840A657AEE1C91CFF5F3D60E85AA4`
- **Note:** Any rebuild changes this hash. Consider signer-based WDAC to avoid per-rebuild updates.

## Features
- Triple LoRA character composition (3 LoRA slots with individual strength controls)
- Prompt/negative prompt fields
- Generation parameters: seed (fixed or random), steps, CFG, width, height
- Sampler and scheduler selection
- Workflow preset selection
- ControlNet tab (model, image, preprocessor, strength, start/end)
- Outfit section (category, item, color, material, placement)
- Open Output button (opens ComfyUI output folder)
- Session tracking with START/STOP SESSION toggle
- Activity log (visible in Session tab)
- Output history grid with image preview
- GPU/VRAM status tab (queries ComfyUI /system_stats)
- ComfyUI workflow generation via /prompt API
- Config loaded from Forge.config.json
- Preferences saved on form close

## ComfyUI Integration
- Connects to `http://127.0.0.1:8188` (default) or URL from config
- Generate button sends workflow to ComfyUI via POST /prompt
- Workflow file loaded from workflow preset path
- Background generation — UI does not freeze
- Errors displayed in activity log
- GPU status via GET /system_stats

## Trust Status
- **Signature:** Signed with `CN=MystikStudio Local Dev Code Signing` — Status: Valid
- **Direct launch test:** Confirmed (PID 26116)

## Rollback to Forge-PS
1. Edit `Start-MystikStudioDashboard.ps1`
2. Change Forge Target to `Creators\Forge\Open Forge.vbs`
3. Restart Dashboard

## Rebuild
```
.\Build-CForge.ps1
.\tools\signing\Sign-MystikStudioExe.ps1 -ExePath "Creators\C-Forge\Forge.exe"
```

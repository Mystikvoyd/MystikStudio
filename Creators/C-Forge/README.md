# C-Forge — Staged C# Version (WDAC Blocked)

**Status:** C# migration staged but BLOCKED by Microsoft WDAC Enterprise signing level.
**Dashboard target is permanently on PowerShell fallback** — the WDAC supplemental policy was attempted and removed.
**C# activation is NOT supported on this system** unless a future Microsoft-trusted code signing certificate is used.

## Active Dashboard Target
- **Current:** `Creators\Forge\Open Forge.vbs` (PowerShell — permanent fallback)
- **C# exe staged at:** `Creators\C-Forge\Forge.exe` (blocked — WDAC activation failed, do not retry)

## Trust Status
- **Signature:** Signed with `CN=MystikStudio Local Dev Code Signing` — Status: Valid
- **Block source:** System base WDAC policy (Policy ID `{0283ac0f-fff1-49ae-ada1-8a933130cad6}`) blocks self-signed exes at Enterprise signing level. Supplemental WDAC policy was attempted and removed (the system did not accept it).
- **C# activation: NOT SUPPORTED** — The WDAC supplemental policy path does not work on this system. A Microsoft-trusted code signing certificate (EV or standard CA) would be needed to meet the Enterprise signing level.
- **Current hash:** `27784822EE7F6AC3E7031199F886C9EAF21840A657AEE1C91CFF5F3D60E85AA4`

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

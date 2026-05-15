# MystikStudio Status and Handoff

Last updated: 2026-05-14
Repo: `Mystikvoyd/MystikStudio`
Primary local repo: `H:\MystikStudio`
Current focus: Creators Character Suite, especially `Creators\C-Lab` and future modular ComfyUI image workflow support.

## Purpose

This is the living handoff section for MystikStudio work. It exists so future ChatGPT sessions and Leonardo sessions do not have to rediscover paths, rules, current state, workflow plans, and safety boundaries.

Use this file first when continuing MystikStudio work.

## Operating Mode

1. Local PC first.
2. Test locally before committing.
3. GitHub becomes the source of truth only after the user approves the tested local state.
4. Leonardo should read prompts from the local prompt file instead of receiving long chat prompts.
5. Leonardo should write full reports to the local report file and reply only `Done!` when finished.
6. Every ticket or child ticket worked must produce a zip package in `C:\Users\Michael\Documents\Leonardo Prompts\Reports` named with the exact ticket number. See `status/Tickets/TICKET_STANDARD.md` for full packaging rules.
7. Ticket numbers use per-type independent sequences: `MSTK-[TYPE]-[TYPE-SEQUENCE]-[CHILD-SEQUENCE]`. Each ticket type has its own counter. See `status/Tickets/TICKET_STANDARD.md` for the full numbering rule.

## Current High-Level State

### Dashboard

The Dashboard exists and has a Character Suite area with Studio, Forge, Fusion, and Lab. Do not change Dashboard targets unless explicitly instructed.

Dashboard target rules at this checkpoint:

- Fusion is the only active C# Dashboard target and must not be rebuilt casually.
- Lab Dashboard target should remain the PowerShell fallback until direct C# launch and WDAC/trust are approved.
- Forge Dashboard target should remain the PowerShell fallback until direct C# launch and WDAC/trust are approved.
- Do not point Dashboard at C# Lab or C# Forge yet.

### Fusion

Fusion is the visual/layout reference and must be treated as fragile.

Rules:

- Do not touch Fusion.
- Do not rebuild Fusion.
- Do not change Fusion signing or hash state.
- Use Fusion only as a visual/layout reference.

### Lab

Lab is the current active app under repair and expansion.

Working or mostly working:

- Lab opens locally.
- Window title: `Mystikvoyd Studios - Lab`.
- Application icon is present.
- Info tab exists.
- Resources tab exists.
- Prompt and negative prompt fields exist.
- Checkpoint discovery now uses the real Documents ComfyUI model root.
- Type / Style can show the `SDXL` folder under checkpoints.
- Checkpoint dropdown can show real SDXL checkpoint files.
- LoRA dropdown can read real LoRA files.
- Seed field was repaired after identifying the oversized Seed label overlap issue.
- Random seed checkbox exists.
- History row click loads the corresponding history item.
- History Seed click copies the seed to clipboard.
- Output history includes useful generation columns such as LoRA, LoRA strength, steps, CFG, and seed.
- Outfit UI works and generation works.
- Config buttons exist: Save Config, Load Config, Save & Close.
- Default config path is intended to be `Creators\C-Lab\Lab.default.json`.

Known current Lab work items:

1. Ensure checkpoint and LoRA selections are actually wired into the ComfyUI workflow payload, not only visible in the UI.
2. Verify and wire ControlNet into the workflow only if matching nodes exist.
3. Verify what Realism Boost should do and wire it only when the target workflow behavior is defined.
4. Keep visual verification mandatory because previous source-only checks reported PASS while the running UI still had issues.
5. Build a modular image workflow foundation for Lab.

### Forge

Forge should not be changed until Lab is stable unless explicitly instructed.

Planned Forge role:

- More advanced image app.
- Multiple LoRAs.
- ControlNet.
- IPAdapter.
- Realism Boost/refine/upscale pass.
- More advanced resources tooling.

### Studio

Studio remains later work. Do not fold Studio into Lab or Forge work without explicit instruction.

## Current Leonardo Workflow

Prompt file:

`C:\Users\Michael\Documents\Leonardo Prompts\Prompt.txt`

Report file:

`C:\Users\Michael\Documents\Leonardo Prompts\Leo Reports.txt`

Folder reference file:

`C:\Users\Michael\Documents\Leonardo Prompts\Lab_Dropdown_Folders.txt`

Seed overlay diagnostic file used previously:

`C:\Users\Michael\Documents\Leonardo Prompts\Lab_Seed_Overlay_Diagnostic.txt`

Standard Leonardo instruction from chat:

```text
Read and execute the prompt here:

C:\Users\Michael\Documents\Leonardo Prompts\Prompt.txt
```

All Leo prompts should include:

- Write the final report to `C:\Users\Michael\Documents\Leonardo Prompts\Leo Reports.txt`.
- Overwrite it with the newest report.
- Do not paste a long report in chat.
- When finished, only reply `Done!`.

## Local Path Rules

### Repo and apps

Primary repo:

`H:\MystikStudio`

Lab source:

`H:\MystikStudio\Creators\C-Lab\Lab.cs`

Lab build script:

`H:\MystikStudio\Creators\C-Lab\Build-CLab.ps1`

Lab executable:

`H:\MystikStudio\Creators\C-Lab\Lab.exe`

Lab default config:

`H:\MystikStudio\Creators\C-Lab\Lab.default.json`

Lab user config folder:

`H:\MystikStudio\Creators\C-Lab\configs`

Lab ComfyUI workflow repo path:

`Creators/comfyui/workflows/sdxl-basic-book-image.api.json`

Lab ComfyUI workflow local path:

`H:\MystikStudio\Creators\comfyui\workflows\sdxl-basic-book-image.api.json`

Important workflow path note:

Lab currently builds the workflow path from the Lab executable folder by going up one level to `H:\MystikStudio\Creators`, then appending `comfyui\workflows\sdxl-basic-book-image.api.json`. The correct current repo path is therefore `Creators/comfyui/workflows/sdxl-basic-book-image.api.json`, not repo-root `comfyui/workflows/sdxl-basic-book-image.api.json`.

Forge source:

`H:\MystikStudio\Creators\C-Forge\Forge.cs`

Forge build script:

`H:\MystikStudio\Creators\C-Forge\Build-CForge.ps1`

Forge executable:

`H:\MystikStudio\Creators\C-Forge\Forge.exe`

Fusion source/reference:

`H:\MystikStudio\Creators\C-Fusion\CFusion.cs`

Main worker area:

`H:\MystikStudio\Creators\MystikWorker`

### ComfyUI user model root

Primary ComfyUI model root:

`C:\Users\Michael\Documents\ComfyUI\models`

Use this before the AppData packaged fallback.

Checkpoint root:

`C:\Users\Michael\Documents\ComfyUI\models\checkpoints`

Known checkpoint type/style folder:

`C:\Users\Michael\Documents\ComfyUI\models\checkpoints\SDXL`

Known SDXL checkpoint files:

- `SDXL\sd_xl_base_1.0.safetensors`
- `SDXL\Juggernaut-XL_v9_RunDiffusionPhoto_v2.safetensors`
- `SDXL\dreamshaperXL_lightningDPMSDE.safetensors`

LoRA root:

`C:\Users\Michael\Documents\ComfyUI\models\loras`

ControlNet root:

`C:\Users\Michael\Documents\ComfyUI\models\controlnet`

Known ControlNet file:

`control-lora-openposeXL2-rank256.safetensors`

CLIP Vision root:

`C:\Users\Michael\Documents\ComfyUI\models\clip_vision`

Known CLIP Vision file:

`CLIP-ViT-H-14-laion2B-s32B-b79K.safetensors`

IPAdapter root:

`C:\Users\Michael\Documents\ComfyUI\models\ipadapter`

Known IPAdapter files:

- `ip-adapter-plus_sdxl_vit-h.safetensors`
- `ip-adapter-plus-face_sdxl_vit-h.safetensors`

VAE root:

`C:\Users\Michael\Documents\ComfyUI\models\vae`

Upscale model root:

`C:\Users\Michael\Documents\ComfyUI\models\upscale_models`

AnimateDiff model root:

`C:\Users\Michael\Documents\ComfyUI\models\animatediff_models`

AnimateDiff motion LoRA root:

`C:\Users\Michael\Documents\ComfyUI\models\animatediff_motion_lora`

CogVideo root:

`C:\Users\Michael\Documents\ComfyUI\models\CogVideo`

Fallback packaged ComfyUI root:

`C:\Users\Michael\AppData\Local\Programs\ComfyUI\resources\ComfyUI\models`

Only use the AppData packaged folder as fallback if the Documents path does not have real model files. Ignore placeholder files such as `put_checkpoints_here`, `put_loras_here`, and `put_diffusion_model_files_here`.

## Build and Launch Commands

Build Lab:

```powershell
powershell -ExecutionPolicy Bypass -File .\Creators\C-Lab\Build-CLab.ps1 -SignMode Dev
```

Launch Lab:

```powershell
.\Creators\C-Lab\Lab.exe
```

Build Forge:

```powershell
powershell -ExecutionPolicy Bypass -File .\Creators\C-Forge\Build-CForge.ps1 -SignMode Dev
```

Launch Forge:

```powershell
.\Creators\C-Forge\Forge.exe
```

## Ruleset

### Hard no-touch rules

- Do not touch Fusion unless explicitly instructed.
- Do not rebuild Fusion unless explicitly instructed.
- Do not change Dashboard targets unless explicitly instructed.
- Do not point Dashboard at C# Lab or C# Forge yet.
- Do not push or commit unless the user explicitly asks.
- Do not delete files without backup.
- Do not move or copy model files without explicit approval.
- Do not scan the full ComfyUI install tree during normal app startup.
- Do not fake workflow support if a ComfyUI workflow does not contain the required nodes.

### Local-first rules

- Make changes locally first.
- Build locally.
- Launch locally.
- Visually verify the actual running app.
- Write full report to `Leo Reports.txt`.
- Reply only `Done!` from Leonardo.
- Commit only after user approves.

### Visual verification rule

Do not mark a UI issue PASS from source inspection alone. Many previous source-level reports were wrong because the running UI still showed visual failures.

When a visual issue is being fixed:

1. Build Lab.
2. Launch Lab.
3. Inspect the running window.
4. If needed, add a diagnostic file under the Leonardo prompts folder.
5. Report the actual runtime result.

### Workflow wiring rule

A UI control is not considered complete until it is wired into the generation workflow or explicitly documented as UI-only with a TODO.

Examples:

- Checkpoint dropdown must update the checkpoint loader node.
- LoRA dropdown and strength must update LoRA loader nodes.
- ControlNet UI must map to ControlNet workflow nodes or be reported as not supported by the current workflow.
- Realism Boost must have defined behavior before being wired.

## Lab Image Workflow Plan

Lab will become the stable modular image-generation app. It should support modular image workflow sections that can be turned on only when the workflow and files exist.

### Phase 1: Core SDXL workflow

Required nodes:

- Checkpoint Loader
- CLIP Text Encode positive
- CLIP Text Encode negative
- Empty Latent Image
- KSampler
- VAE Decode
- Save Image
- Preview Image

Required UI wiring:

- Selected checkpoint
- Prompt
- Negative prompt
- Seed
- Random seed
- Width
- Height
- Steps
- CFG
- Sampler
- Scheduler

Status: in progress. Basic generation works, but checkpoint selection wiring must be verified and fixed if missing.

### Phase 2: LoRA workflow

Lab uses one LoRA.

Required node:

- LoRA Loader

Required UI wiring:

- LoRA file
- LoRA enabled state
- LoRA strength

Status: UI exists. Current Lab source dynamically adds a `LoraLoader` node during generation when LoRA is enabled and rewires KSampler plus positive and negative CLIP encoders to that node. This must still be tested locally against the running ComfyUI payload before marking verified.

### Phase 3: ControlNet workflow

Required nodes if enabled:

- Load Image
- ControlNet Loader
- Apply ControlNet or Apply ControlNet Advanced
- Optional preprocessor node when clearly supported

Required UI wiring:

- Enable
- ControlNet model
- Control image path
- Filter/preprocessor
- Strength
- Start
- End

Status: UI exists. Current workflow does not contain ControlNet nodes. ControlNet is UI-only until the workflow is expanded with real ControlNet nodes and Lab maps to those nodes.

### Phase 4: VAE override

Optional.

Required node:

- VAE Loader

Behavior:

- If no VAE is selected, use checkpoint VAE.
- If VAE selected, override decode VAE.

Status: planned.

### Phase 5: IPAdapter image reference

Likely for Forge first, but Lab may later support it as a workflow preset.

Required nodes:

- Load Image
- CLIP Vision Loader
- IPAdapter Model Loader
- Apply IPAdapter

Required UI wiring:

- Enable IPAdapter
- IPAdapter model
- Reference image
- Strength/weight

Status: planned, not for current Lab core unless explicitly requested.

### Phase 6: Realism Boost

Do not treat Realism Boost as a magic checkbox. It must have a defined workflow effect.

Possible implementations:

1. Simple preset mode: adjust steps/CFG/sampler/prompt suffix.
2. Better mode: second pass refine/upscale/detail workflow.
3. Disabled/TODO until a target workflow is defined.

Status: currently UI-only. Needs definition before wiring.

### Phase 7: Upscale/refine pass

Possible future nodes:

- Upscale Model Loader
- Image Upscale With Model
- Optional second KSampler/refiner pass
- Save final image

Status: planned.

## Model Folder Purposes

- `checkpoints`: full base models, currently SDXL.
- `loras`: LoRA adapters for characters, styles, body/outfit behavior, maps, and concepts.
- `controlnet`: structural guidance models such as pose, canny, depth, and composition guidance.
- `clip_vision`: image encoder models used by IPAdapter and other reference image systems.
- `ipadapter`: reference image adapters for subject, style, face, or composition guidance.
- `vae`: optional decode/color/detail models.
- `upscale_models`: post-generation upscaling and detail pass models.
- `animatediff_models`: video motion modules, not current Lab image focus.
- `animatediff_motion_lora`: video motion LoRAs, not current Lab image focus.
- `CogVideo`: video generation models, not current Lab image focus.
- `blip`, `Joy_caption`: captioning/tagging support for datasets and training, not image generation directly.
- `insightface`, `photomaker`, `liveportrait`: identity, face, portrait, and animation tooling. Use only in dedicated workflows.

## Git Commit Guidance

Only commit after the user confirms the local build is a good checkpoint.

Suggested checkpoint label:

`last-good/lab-core-ui-and-model-discovery-2026-05-14`

Suggested commit message:

`Checkpoint Lab core UI and model discovery`

Suggested tag after commit:

`last-good-mystikstudio-lab-core-2026-05-14`

Before committing, Leonardo should:

1. Run `git status`.
2. Confirm changed files are expected.
3. Build Lab.
4. Launch Lab.
5. Confirm no Fusion changes.
6. Confirm no Dashboard target changes.
7. Confirm report is written to `Leo Reports.txt`.
8. Commit local code plus handoff/status docs if the user approves.

## Current Next Action

Leonardo is currently investigating and verifying the Lab ComfyUI workflow.

Current immediate target:

1. Inspect `Creators/comfyui/workflows/sdxl-basic-book-image.api.json`.
2. Confirm Lab resolves the local workflow path as `H:\MystikStudio\Creators\comfyui\workflows\sdxl-basic-book-image.api.json`.
3. Map workflow nodes.
4. Verify selected checkpoint changes node `3` input `ckpt_name` in the outgoing ComfyUI payload.
5. Verify selected LoRA dynamically adds a `LoraLoader` node and rewires node `7` model plus nodes `4` and `5` clip inputs.
6. Report ControlNet as UI-only because the current workflow does not contain ControlNet nodes.
7. Report Realism Boost as UI-only because no defined workflow behavior exists yet.
8. Do not fake wiring.
9. Preserve currently working UI and generation behavior.

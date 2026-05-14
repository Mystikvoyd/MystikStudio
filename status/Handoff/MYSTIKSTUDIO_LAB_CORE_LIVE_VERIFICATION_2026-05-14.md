# MystikStudio Lab Core Live Verification

Date: 2026-05-14
Repo: `Mystikvoyd/MystikStudio`
Branch: `master`
Primary handoff: `status/Handoff/MYSTIKSTUDIO_HANDOFF.md`
Local repo: `H:\MystikStudio`

## Result

Lab core SDXL generation and LoRA wiring are live verified by the user.

User reported: all tests passed.

## Verified Local State

- Correct repo confirmed: `H:\MystikStudio`
- Correct remote confirmed: `https://github.com/Mystikvoyd/MystikStudio.git`
- Latest handoff/path commit confirmed locally: `23de5e3 Fix Lab workflow path in handoff`
- ComfyUI reachable at `http://127.0.0.1:8000/system_stats`
- ComfyUI returned HTTP 200
- Lab launched from `H:\MystikStudio\Creators\C-Lab\Lab.exe`
- Live generation tests passed

## Verified Workflow Path

Correct repo path:

`Creators/comfyui/workflows/sdxl-basic-book-image.api.json`

Correct local path:

`H:\MystikStudio\Creators\comfyui\workflows\sdxl-basic-book-image.api.json`

Incorrect path avoided:

`H:\MystikStudio\comfyui\workflows\sdxl-basic-book-image.api.json`

## Verified Lab Core Wiring

The following are considered live verified after user testing:

1. Prompt maps into the workflow payload.
2. Negative prompt maps into the workflow payload.
3. Width and height map into the workflow payload.
4. Seed and random seed behavior work for generation.
5. Steps and CFG map into the workflow payload.
6. Sampler and scheduler map into the workflow payload.
7. Selected checkpoint generates successfully.
8. Changing checkpoint and generating again succeeds.
9. LoRA can be enabled.
10. Selected LoRA generates successfully.
11. LoRA strength is accepted during generation.
12. Output image appears in Lab preview.
13. Output history records the generated result.
14. History row click loads the image.
15. History seed click copies the seed.

## ControlNet Status

ControlNet remains UI-only at this checkpoint.

Reason:

The current `sdxl-basic-book-image.api.json` workflow does not contain ControlNet nodes. Do not claim ControlNet is wired until the workflow has matching ControlNet Loader and Apply ControlNet nodes and Lab maps its UI fields to those nodes.

## Realism Boost Status

Realism Boost remains UI-only at this checkpoint.

Reason:

No defined workflow behavior exists yet. Do not wire or claim Realism Boost until the project chooses a specific behavior such as preset tuning, second-pass refine, or upscale/detail pass.

## Rules Preserved

- Fusion was not touched.
- Fusion was not rebuilt.
- Dashboard targets were not changed.
- Dashboard was not pointed at C# Lab or C# Forge.
- Model files were not moved.
- Files were not deleted.
- Workflow support was not faked.

## Next Safe Work

Recommended next step is to create a last-good checkpoint for Lab core SDXL plus single LoRA generation.

After that, the next development target should be one of these:

1. Add a workflow payload diagnostic export so Lab can save the exact outgoing ComfyUI JSON for future verification.
2. Create a ControlNet-enabled workflow variant and wire Lab ControlNet controls only to that variant.
3. Define Realism Boost behavior before any implementation.
4. Add optional VAE override support only if the workflow is expanded with a VAE Loader node.

## Suggested Checkpoint Label

`last-good-mystikstudio-lab-core-sdxl-lora-live-2026-05-14`

## Suggested Commit Message

`Record Lab core SDXL LoRA live verification`

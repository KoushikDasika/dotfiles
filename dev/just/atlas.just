# Atlas runtime via sparkrun — DGX Spark (GB10, 121GB unified, ~107GB usable @ 0.88 util).
# All serve an OpenAI-compatible API on localhost:8888.
# Override any recipe default with:  sparkrun run <recipe> -o key=value

# Native FP8, bf16 lm-head + bf16 KV (gate-measured best quality),
# 256K ctx validated on a single GB10 (~105GB steady-state).
# Qwen3.6-35B-A3B FP8 + MTP — THE FLAGSHIP: smartest fast model, 256K ctx
a3b ctx="262144":
    sparkrun run @atlas/qwen3.6-35b-a3b-fp8-mtp --hosts localhost --max-model-len {{ctx}}

# 116.5 t/s @ MTP K=1 (no-spec 89.7; K=2 is a measured 8% LOSS — never raise
# num_drafts). Calibrated fp8 KV.
# Qwen3.6-35B-A3B NVFP4 — FASTEST: ~116 t/s, 256K ctx
a3b-nvfp4 ctx="262144":
    sparkrun run @atlas/qwen3.6-35b-a3b-nvfp4 --hosts localhost --max-model-len {{ctx}}

# Recipe caps ctx at 60K for arena sweeps; VRAM estimate allows 333K on this box.
# num_drafts=1 + :dev container are recipe defaults and load-bearing — don't override.
# Qwen3.6-27B dense FP8 + MTP — smartest dense, ~15.6 t/s, 256K ctx
dense ctx="262144":
    sparkrun run @atlas/qwen3.6-27b-fp8-mtp --hosts localhost --max-model-len {{ctx}}

# Recipe defaults are 32K ctx / 0.7 util; raise both.
# Qwen3.6-27B NVFP4 — lighter dense, 256K ctx
dense-nvfp4 ctx="262144" mem="0.85":
    sparkrun run @atlas/qwen3.6-27b-nvfp4 --hosts localhost --max-model-len {{ctx}} --gpu-mem {{mem}}

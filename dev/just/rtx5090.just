# Legacy recipes for the 24GB RTX 5090 laptop — Q4 quants, expert offload,
# KV-in-RAM tricks. Only linked on non-GB10 machines (see dotfiles `symlinks`).

llama := home_directory() / "git/llama.cpp/build/bin/llama-server"
llama_bench := home_directory() / "git/llama.cpp/build/bin/llama-bench"

# default context window (tokens)
ctx := "65536"

# gemma-4-12B QAT + MTP speculative decode (~120 t/s on RTX 5090)
gemma ctx="200000":
    {{llama}} \
        -hf unsloth/gemma-4-12B-it-qat-GGUF \
        -hfd Janvitos/gemma-4-12B-it-qat-assistant-MTP-Q8_0-GGUF:Q8_0 \
        -ngl 99 -ngld 99 \
        -c {{ctx}} --no-mmproj -fa on -np 4 \
        --cache-type-k q8_0 --cache-type-v q8_0 \
        --spec-type draft-mtp --spec-draft-n-max 4 -fit off

# gemma-4-12B QAT, no speculative draft (~93 t/s)
gemma-plain ctx="200000":
    {{llama}} \
        -hf unsloth/gemma-4-12B-it-qat-GGUF \
        -ngl 99 -c {{ctx}} --no-mmproj -fa on -np 6 --cache-type-k q8_0 --cache-type-v q8_0

# download gemma-4-12B agentic fine-tune Q8 + BF16 MTP → ~/git/models/gemma-4-12B-agentic-ft/
# (needed because -hf quant selectors are ambiguous: MTP/ subdir has same quant names as main files)
gemma-ft-download:
    hf download yuxinlu1/gemma-4-12B-agentic-fable5-composer2.5-v2-3.5x-tau2-GGUF \
        gemma4-v2-Q8_0.gguf \
        --local-dir {{ home_directory() / "git/models/gemma-4-12B-agentic-ft" }}
    hf download yuxinlu1/gemma-4-12B-agentic-fable5-composer2.5-v2-3.5x-tau2-GGUF \
        MTP/gemma-4-12B-it-MTP-BF16.gguf \
        --local-dir {{ home_directory() / "git/models/gemma-4-12B-agentic-ft" }}

# gemma-4-12B agentic fine-tune (fable5/composer) Q8 + BF16 MTP speculative decode, 256K ctx
# run gemma-ft-download first. If OOM: reduce ctx or switch KV to q4_0 / --no-kv-offload
gemma-ft ctx="262144":
    {{llama}} \
        -m {{ home_directory() / "git/models/gemma-4-12B-agentic-ft/gemma4-v2-Q8_0.gguf" }} \
        --model-draft {{ home_directory() / "git/models/gemma-4-12B-agentic-ft/MTP/gemma-4-12B-it-MTP-BF16.gguf" }} \
        -ngl 99 -ngld 99 \
        -c {{ctx}} --no-mmproj -fa on -np 1 \
        --cache-type-k q8_0 --cache-type-v q8_0 \
        --spec-type draft-mtp --spec-draft-n-max 4 -fit off

# benchmark the cached gemma-4-12B Q4_K_XL
bench-gemma:
    {{llama_bench}} -m {{ home_directory() / ".cache/huggingface/hub/models--unsloth--gemma-4-12B-it-qat-GGUF/snapshots/ceadd70e5c46c5a839a7fd622307dabe8fdea551/gemma-4-12B-it-qat-UD-Q4_K_XL.gguf" }} -ngl 99 -fa 1

# vision arg: "off" (default) = text-only (--no-mmproj); "on" = load multimodal projector
# usage:  just -g rtx5090 qwen                  (256K ctx, text, ~85-100 t/s)
#         just -g rtx5090 qwen 131072 on        (128K ctx, vision on)

# Qwen3.6-35B-A3B MoE (3B active) Q4 + MTP — fastest big model, ~19GB, BEST for 24GB
qwen-a3b ctx=ctx vision="off":
    {{llama}} \
        -hf unsloth/Qwen3.6-35B-A3B-MTP-GGUF:UD-Q4_K_XL \
        -ngl 99 \
        -np 4 \
        -c {{ctx}} -fa on -np 1 \
        --cache-type-k q8_0 --cache-type-v q8_0 \
        --spec-type draft-mtp --spec-draft-n-max 2 \
        {{ if vision == "on" { "" } else { "--no-mmproj" } }}

# Same as qwen-a3b but KV cache lives in system RAM (--no-kv-offload) at q4_0 for speed,
# defaults to 256K ctx (262144) so big sessions rarely compact. Weights stay on GPU.
# q4 KV trades some long-context precision for ~2x KV bandwidth (~80-95 t/s vs 45 at q8).
qwen-a3b-kv ctx="262144" vision="off":
    {{llama}} \
        -hf unsloth/Qwen3.6-35B-A3B-MTP-GGUF:UD-Q4_K_XL \
        -ngl 99 \
        -c {{ctx}} -fa on -np 1 \
        --cache-type-k q4_0 --cache-type-v q4_0 \
        --no-kv-offload \
        --spec-type draft-mtp --spec-draft-n-max 4 \
        {{ if vision == "on" { "" } else { "--no-mmproj" } }}

# Qwen3.6-35B-A3B at HIGHER quant via expert offload to CPU/RAM (uses your 62GB).
# quant: UD-Q6_K_XL, UD-Q8_K_XL ...   ncmoe: # layers whose experts go to CPU.
# RAISE ncmoe if it OOMs, LOWER it for more speed (more experts stay on GPU).
qwen-a3b-big quant="UD-Q6_K_XL" ncmoe="24" ctx=ctx vision="off":
    {{llama}} \
        -hf unsloth/Qwen3.6-35B-A3B-MTP-GGUF:{{quant}} \
        -ngl 99 -ncmoe {{ncmoe}} \
        -c {{ctx}} -fa on -np 1 \
        --cache-type-k q8_0 --cache-type-v q8_0 \
        --spec-type draft-mtp --spec-draft-n-max 2 \
        {{ if vision == "on" { "" } else { "--no-mmproj" } }}

# Qwen3.6-35B-A3B MoE (3B active) — fast + huge context. Primary daily driver on 24GB.
# 256K ctx via KV in system RAM at q4; weights stay on GPU (~19GB of 24GB).
qwen ctx=ctx vision="off":
    {{llama}} \
        -hf unsloth/Qwen3.6-35B-A3B-MTP-GGUF:UD-Q4_K_XL \
        -ngl 99 \
        -c {{ctx}} -fa on -np 1 \
        --cache-type-k q8_0 --cache-type-v q8_0 \
        --spec-type draft-mtp --spec-draft-n-max 2 \
        {{ if vision == "on" { "" } else { "--no-mmproj" } }}

# Qwen3.6-35B-A3B MoE, single slot, all layers on GPU, q8_0 KV for max quality
# 80k ctx fits in 24GB VRAM (RTX 5090 Laptop); try 90112 if it boots clean
qwen-wide ctx="81920" vision="off":
    {{llama}} \
        -hf unsloth/Qwen3.6-35B-A3B-MTP-GGUF:UD-Q4_K_XL \
        -ngl 99 -c {{ctx}} -fa on -np 1 \
        --cache-type-k q8_0 --cache-type-v q8_0 \
        --spec-type draft-mtp --spec-draft-n-max 2 \
        {{ if vision == "on" { "" } else { "--no-mmproj" } }}

# Qwen3.6-27B dense Q4_K_XL + MTP spec decode (explicit draft head from bartowski)
qwen-dense ctx=ctx vision="off":
    {{llama}} \
        -hf unsloth/Qwen3.6-27B-MTP-GGUF:UD-Q4_K_XL \
        -hfd bartowski/Qwen_Qwen3.6-27B-GGUF:mtp-Qwen_Qwen3.6-27B-Q8_0 \
        -ngl 99 -ngld 99 \
        -c {{ctx}} -fa on -np 6 \
        --cache-type-k q8_0 --cache-type-v q8_0 \
        --spec-type draft-mtp --spec-draft-n-max 2 \
        {{ if vision == "on" { "" } else { "--no-mmproj" } }}

# Qwen3.6-27B dense, no speculative draft (~37 t/s base)
qwen-dense-plain ctx=ctx vision="off":
    {{llama}} \
        -hf unsloth/Qwen3.6-27B-MTP-GGUF:UD-Q4_K_XL \
        -ngl 99 -c {{ctx}} -fa on -np 1 \
        {{ if vision == "on" { "" } else { "--no-mmproj" } }}

# Qwen3.6-27B dense, single slot, all layers on GPU, q8_0 KV (~37 t/s)
# 152k ctx fits in 24GB VRAM (RTX 5090 Laptop) with ~1.3GB margin
qwen-dense-wide ctx="155648" vision="off":
    {{llama}} \
        -hf unsloth/Qwen3.6-27B-MTP-GGUF:UD-Q4_K_XL \
        -ngl 99 -c {{ctx}} -fa on -np 1 \
        --cache-type-k q8_0 --cache-type-v q8_0 \
        {{ if vision == "on" { "" } else { "--no-mmproj" } }}

# Qwen3.6-27B dense + MTP, 130K ctx, KV on GPU, q8_0 KV (~55-65 t/s)
# ~22.9 GB VRAM (model 17.9 + MTP ~1 + KV ~4). Single slot only (-np 1).
# If OOM: drop ctx to 120000 or switch to --cache-type-k q4_0 --cache-type-v q4_0
qwen-dense-fast ctx="131072" vision="off":
    {{llama}} \
        -hf unsloth/Qwen3.6-27B-MTP-GGUF:UD-Q4_K_XL \
        -hfd bartowski/Qwen_Qwen3.6-27B-GGUF:mtp-Qwen_Qwen3.6-27B-Q8_0 \
        -ngl 99 -ngld 99 \
        -c {{ctx}} -fa on -np 1 \
        --cache-type-k q8_0 --cache-type-v q8_0 \
        --spec-type draft-mtp --spec-draft-n-max 2 \
        {{ if vision == "on" { "" } else { "--no-mmproj" } }}

# Qwen3.6-27B dense + MTP, 150K ctx, q4_0 KV on GPU (~55-65 t/s)
# ~21.5 GB VRAM (model 17.9 + KV 2.3 + overhead). Only 16/65 layers carry KV (hybrid SSM arch).
# q4_0 KV chosen over q8_0: actual allocation was 23.84/23.89 GB — too tight for prefill buffers.
qwen-dense-150k ctx="153600" vision="off":
    {{llama}} \
        -hf unsloth/Qwen3.6-27B-MTP-GGUF:UD-Q4_K_XL \
        -hfd bartowski/Qwen_Qwen3.6-27B-GGUF:mtp-Qwen_Qwen3.6-27B-Q8_0 \
        -ngl 99 -ngld 99 \
        -c {{ctx}} -fa on -np 1 \
        --cache-type-k q4_0 --cache-type-v q4_0 \
        --spec-type draft-mtp --spec-draft-n-max 2 \
        {{ if vision == "on" { "" } else { "--no-mmproj" } }}

# Qwen3.8-27B dense Q4_K_XL — text-only. No MTP GGUF available yet (2026-08-14).
# Add -hfd spec head + --spec-type draft-mtp once unsloth/Qwen3.8-27B-MTP-GGUF drops.
qwen38 ctx=ctx vision="off":
    {{llama}} \
        -hf unsloth/Qwen3.8-27B-GGUF:UD-Q4_K_XL \
        -ngl 99 \
        -c {{ctx}} -fa on -np 1 \
        --cache-type-k q8_0 --cache-type-v q8_0 \
        {{ if vision == "on" { "" } else { "--no-mmproj" } }}

vllm_python := home_directory() / ".config/just/.venv/bin/python"

# Download unsloth/Qwen3.8-27B-NVFP4 → ~/git/models/Qwen3.8-27B-NVFP4-unsloth
download-qwen38-nvfp4:
    {{vllm_python}} -c "from huggingface_hub import snapshot_download; snapshot_download('unsloth/Qwen3.8-27B-NVFP4', local_dir='{{home_directory() / "git/models/Qwen3.8-27B-NVFP4-unsloth"}}')"

# Qwen3.8-27B NVFP4 via vLLM — text-only (--language-model-only skips vision encoder).
# Run download-qwen38-nvfp4 first. Auto-installs vLLM via mise if missing.
# Max ctx on 24GB VRAM is ~23520 (vLLM-reported KV cache limit). Default 20480 leaves margin.
# To push higher: just -g qwen38-nvfp4 ctx=23040
# MTP drafter OOMs on 24GB (needs ~140 MiB on top of 22.85 GiB model). Spark only.
qwen38-nvfp4 port="8000" ctx="20480":
    #!/usr/bin/env bash
    set -euo pipefail
    PYTHON="{{vllm_python}}"
    MODEL="{{home_directory() / "git/models/Qwen3.8-27B-NVFP4-unsloth"}}"
    VENV_SITE="$(dirname "$PYTHON")/../lib/python3.12/site-packages"
    export CUDA_HOME="$(realpath "$VENV_SITE/nvidia/cu13")"
    export LD_LIBRARY_PATH="$VENV_SITE/nvidia/cu13/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    export NVCC_PREPEND_FLAGS="-DCCCL_DISABLE_CTK_COMPATIBILITY_CHECK"
    export PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True
    export HF_HUB_OFFLINE=1
    _setup() { cd "$HOME/.config/just" && mise run setup; }
    _serve() {
        "$PYTHON" -m vllm.entrypoints.openai.api_server \
            --model "$MODEL" \
            --port {{port}} \
            --max-model-len {{ctx}} \
            --enforce-eager \
            --gpu-memory-utilization 0.95 \
            --language-model-only \
            --enable-auto-tool-choice \
            --tool-call-parser qwen3_xml
    }
    [ -f "$PYTHON" ] || _setup
    _serve || { _setup && _serve; }

# benchmark the cached Qwen3.6-27B Q4_K_XL
bench-qwen:
    {{llama_bench}} -m {{ home_directory() / ".cache/huggingface/hub/models--unsloth--Qwen3.6-27B-MTP-GGUF/snapshots/5cb35eb3dcbf52dbce5f87dbc64df6aaffadcace/Qwen3.6-27B-UD-Q4_K_XL.gguf" }} -ngl 99 -fa 1

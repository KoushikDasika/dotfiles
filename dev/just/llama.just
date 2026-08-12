# llama.cpp recipes tuned for DGX Spark (GB10, 121GB unified @ ~273GB/s).
# No offload tricks needed — everything lives on the GPU side of unified memory.
# MoE (3B active) decodes ~80-115 t/s even at Q8/BF16; dense 27B is bandwidth-walled
# at ~10-15 t/s regardless of quant — MoE is the daily driver, dense is "smart but slow".

llama := home_directory() / "git/llama.cpp/build/bin/llama-server"
llama_bench := home_directory() / "git/llama.cpp/build/bin/llama-bench"

# Qwen3.6-35B-A3B UD-Q8_K_XL (39GB) + MTP — highest-quant fast MoE. ~60GB @ 256K ctx.
a3b-q8 ctx="262144" vision="off":
    {{llama}} \
        -hf unsloth/Qwen3.6-35B-A3B-MTP-GGUF:UD-Q8_K_XL \
        -ngl 99 \
        -c {{ctx}} -fa on -np 1 \
        --cache-type-k q8_0 --cache-type-v q8_0 \
        --spec-type draft-mtp --spec-draft-n-max 2 \
        {{ if vision == "on" { "" } else { "--no-mmproj" } }}

# Qwen3.6-35B-A3B BF16 (71GB, 2 shards) + MTP — maximum-quality MoE. ~94GB @ 256K ctx.
a3b-bf16 ctx="262144" vision="off":
    {{llama}} \
        -hf unsloth/Qwen3.6-35B-A3B-MTP-GGUF:BF16 \
        -ngl 99 \
        -c {{ctx}} -fa on -np 1 \
        --cache-type-k q8_0 --cache-type-v q8_0 \
        --spec-type draft-mtp --spec-draft-n-max 2 \
        {{ if vision == "on" { "" } else { "--no-mmproj" } }}

# Qwen3.6-27B dense UD-Q8_K_XL (35.8GB) + MTP draft — smartest usable dense, ~10-15 t/s.
dense-q8 ctx="200000" vision="off":
    {{llama}} \
        -hf unsloth/Qwen3.6-27B-MTP-GGUF:UD-Q8_K_XL \
        -hfd bartowski/Qwen_Qwen3.6-27B-GGUF:mtp-Qwen_Qwen3.6-27B-Q8_0 \
        -ngl 99 -ngld 99 \
        -c {{ctx}} -fa on -np 1 \
        --cache-type-k q8_0 --cache-type-v q8_0 \
        --spec-type draft-mtp --spec-draft-n-max 2 \
        {{ if vision == "on" { "" } else { "--no-mmproj" } }}

# For quality spot-checks, not daily work.
# Qwen3.6-27B dense BF16 (54.7GB) + MTP draft — maximum-precision dense, ~5-8 t/s
dense-bf16 ctx="131072" vision="off":
    {{llama}} \
        -hf unsloth/Qwen3.6-27B-MTP-GGUF:BF16 \
        -hfd bartowski/Qwen_Qwen3.6-27B-GGUF:mtp-Qwen_Qwen3.6-27B-Q8_0 \
        -ngl 99 -ngld 99 \
        -c {{ctx}} -fa on -np 1 \
        --cache-type-k q8_0 --cache-type-v q8_0 \
        --spec-type draft-mtp --spec-draft-n-max 2 \
        {{ if vision == "on" { "" } else { "--no-mmproj" } }}

# benchmark the cached 35B-A3B Q8_K_XL (run a3b-q8 once first to download)
bench-a3b:
    #!/usr/bin/env bash
    set -euo pipefail
    f="$(ls "$HOME"/.cache/llama.cpp/*Qwen3.6-35B-A3B*Q8_K_XL*.gguf \
          "$HOME"/.cache/huggingface/hub/models--unsloth--Qwen3.6-35B-A3B-MTP-GGUF/snapshots/*/*Q8_K_XL*.gguf \
          2>/dev/null | head -1)"
    [ -n "$f" ] || { echo "no cached gguf — run: just -g llama a3b-q8 first"; exit 1; }
    {{llama_bench}} -m "$f" -ngl 99 -fa 1

# benchmark the cached 27B Q8_K_XL (run dense-q8 once first to download)
bench-dense:
    #!/usr/bin/env bash
    set -euo pipefail
    f="$(ls "$HOME"/.cache/llama.cpp/*Qwen3.6-27B*Q8_K_XL*.gguf \
          "$HOME"/.cache/huggingface/hub/models--unsloth--Qwen3.6-27B-MTP-GGUF/snapshots/*/*Q8_K_XL*.gguf \
          2>/dev/null | head -1)"
    [ -n "$f" ] || { echo "no cached gguf — run: just -g llama dense-q8 first"; exit 1; }
    {{llama_bench}} -m "$f" -ngl 99 -fa 1

# Qwen3.8-27B landing pad — model drops 2026-08-12.
# Day-one flow:
#   1. just -g qwen38 find          (discover HF checkpoints: GGUF / FP8 / NVFP4)
#   2. just -g qwen38 find-recipes  (check sparkrun registries for new @atlas recipes)
#   3. Fix the vars below to the real repo/quant names, then: just -g qwen38 serve

llama := home_directory() / "git/llama.cpp/build/bin/llama-server"

gguf_repo := "unsloth/Qwen3.8-27B-GGUF"
quant := "UD-Q4_K_XL"

# search HF for released Qwen3.8-27B checkpoints
find:
    hf models list --search "Qwen3.8-27B" --limit 20
    hf models list --search "Qwen3.8-27B-GGUF" --limit 10

# update sparkrun registries and search for qwen3.8 recipes
find-recipes:
    sparkrun update
    sparkrun search qwen3.8

# Qwen3.8-27B dense UD-Q4_K_XL. MTP heads baked into model weights — no separate draft model needed.
serve ctx="200000" vision="off":
    {{llama}} \
        -hf {{gguf_repo}}:{{quant}} \
        -ngl 99 \
        -c {{ctx}} -fa on -np 2 \
        --cache-type-k q8_0 --cache-type-v q8_0 \
        --context-shift \
        --spec-type draft-mtp --spec-draft-n-max 5 \
        {{ if vision == "on" { "" } else { "--no-mmproj" } }}

# Qwen3.8-27B dense BF16 (54.7GB, 2 shards) — max quality. MTP baked in.
# Leaves ~67GB for KV on the 121GB Spark — 400K+ ctx fits comfortably.
dense-bf16 ctx="130000" vision="off":
    {{llama}} \
        -hf unsloth/Qwen3.8-27B-GGUF:BF16 \
        -ngl 99 \
        --context-shift \
        -c {{ctx}} -fa on -np 1 \
        --cache-type-k q8_0 --cache-type-v q8_0 \
        --spec-type draft-mtp --spec-draft-n-max 5 \
        {{ if vision == "on" { "" } else { "--no-mmproj" } }}

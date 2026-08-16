# vLLM recipes tuned for DGX Spark (GB10, 121GB unified).
# gpu-memory-utilization 0.85: unified memory is shared with the OS — above ~0.90
# vLLM OOMs despite "free" RAM. Env shims below encode hard-won CUDA-13 fixes.

vllm_python := home_directory() / ".config/just/.venv/bin/python"

# Download unsloth/Qwen3.6-27B-NVFP4 → ~/git/models/Qwen3.6-27B-NVFP4-unsloth (~23GB)
download-unsloth:
    {{vllm_python}} -c "from huggingface_hub import snapshot_download; snapshot_download('unsloth/Qwen3.6-27B-NVFP4', local_dir='{{home_directory() / "git/models/Qwen3.6-27B-NVFP4-unsloth"}}')"

# Download nvidia/Qwen3.6-27B-NVFP4 → ~/git/models/Qwen3.6-27B-NVFP4-nvidia (~23GB)
download-nvidia:
    {{vllm_python}} -c "from huggingface_hub import snapshot_download; snapshot_download('nvidia/Qwen3.6-27B-NVFP4', local_dir='{{home_directory() / "git/models/Qwen3.6-27B-NVFP4-nvidia"}}')"

# Env notes: NVCC_PREPEND_FLAGS bypasses flashinfer CCCL/cu13 version mismatch.
#            lib64->lib symlink + stubs/libcuda.so created by mise setup.
# Text-only (--language-model-only skips the 2.3GB visual encoder).
# Run download-unsloth first. Auto-installs vLLM via mise if missing.
# Qwen3.6-27B NVFP4 via vLLM (unsloth) — 128K ctx, port 8000
dense-nvfp4-unsloth port="8000" ctx="131072":
    #!/usr/bin/env bash
    set -euo pipefail
    PYTHON="{{vllm_python}}"
    MODEL="{{home_directory() / "git/models/Qwen3.6-27B-NVFP4-unsloth"}}"
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
            --gpu-memory-utilization 0.85 \
            --language-model-only \
            --enable-auto-tool-choice \
            --tool-call-parser qwen3_xml
    }
    [ -f "$PYTHON" ] || _setup
    _serve || { _setup && _serve; }

# Native SafeTensors, modelopt quantization. No MTP.
# Run download-nvidia first. Auto-installs vLLM via mise if missing.
# Qwen3.6-27B NVFP4 via vLLM (nvidia) — 262K ctx, port 8000
dense-nvfp4-nvidia port="8000" ctx="262144":
    #!/usr/bin/env bash
    set -euo pipefail
    PYTHON="{{vllm_python}}"
    MODEL="{{home_directory() / "git/models/Qwen3.6-27B-NVFP4-nvidia"}}"
    VENV_CUDA="$(dirname "$PYTHON")/../lib/python3.12/site-packages/nvidia/cu13"
    export CUDA_HOME="$(realpath "$VENV_CUDA")"
    export HF_HUB_OFFLINE=1
    _setup() { cd "$HOME/.config/just" && mise run setup; }
    _serve() {
        "$PYTHON" -m vllm.entrypoints.openai.api_server \
            --model "$MODEL" \
            --port {{port}} \
            --quantization modelopt \
            --max-model-len {{ctx}} \
            --gpu-memory-utilization 0.85 \
            --reasoning-parser qwen3
    }
    [ -f "$PYTHON" ] || _setup
    _serve || { _setup && _serve; }

qwen3-8 port="8000" ctx="262144":
    #!/usr/bin/env bash
    set -euo pipefail
    PYTHON="{{vllm_python}}"
    MODEL="{{home_directory() / "git/models/Qwen3.6-27B-NVFP4-nvidia"}}"
    VENV_CUDA="$(dirname "$PYTHON")/../lib/python3.12/site-packages/nvidia/cu13"
    export CUDA_HOME="$(realpath "$VENV_CUDA")"
    export HF_HUB_OFFLINE=1
    _setup() { cd "$HOME/.config/just" && mise run setup; }
    _serve() {
        "$PYTHON" -m vllm.entrypoints.openai.api_server \
            --model "$MODEL" \
            --port {{port}} \
            --quantization modelopt \
            --max-model-len {{ctx}} \
            --gpu-memory-utilization 0.85 \
            --reasoning-parser qwen3
    }
    [ -f "$PYTHON" ] || _setup
    _serve || { _setup && _serve; }

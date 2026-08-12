# sparkrun recipes from local YAML files — ~/git/dotfiles/ai/sparkrun-recipes/.
# Override any default with:  just -g sparkrun <recipe> [host] -o key=value
# List files:  ls ~/git/dotfiles/ai/sparkrun-recipes/

sparkrun_recipes := home_directory() / "git/dotfiles/ai/sparkrun-recipes"

# Qwen3.6-35B-A3B FP8 + DFlash speculative decoding — requires z-lab/Qwen3.6-35B-A3B-DFlash cached on host
a3b hosts="spark-29ca" ctx="262144":
    sparkrun run {{sparkrun_recipes}}/qwen-3.6-35B-A3B-FP8.yml --hosts {{hosts}} --max-model-len {{ctx}}

dense27b hosts="spark-29ca" ctx="262144":
    sparkrun run {{sparkrun_recipes}}/qwen-3.6-27B-FP8.yml --hosts {{hosts}} --max-model-len {{ctx}}

# Qwen3.6-35B-A3B FP8, no speculative decoding — use when DFlash draft model not cached on host
a3b-nospec hosts="spark-29ca" ctx="262144":
    sparkrun run {{sparkrun_recipes}}/qwen-3.6-35B-A3B-FP8-nospec.yml --hosts {{hosts}} --max-model-len {{ctx}}

# Download DFlash draft model to host HF cache (required for a3b speculative decoding)
download-dflash hosts="spark-29ca":
    ssh {{hosts}} 'hf download z-lab/Qwen3.6-35B-A3B-DFlash --revision 31977fbe13a86e8b961774f773058175676d89b8 --cache-dir $HOME/.cache/huggingface/hub'

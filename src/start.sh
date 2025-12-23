#!/bin/bash
set -e

echo "==================================="
echo "ComfyUI WanVideo Serverless Startup"
echo "==================================="

# Set CUDA environment
export CUDA_VISIBLE_DEVICES=${CUDA_VISIBLE_DEVICES:-0}
export PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:512

# Print GPU info
echo "GPU Information:"
nvidia-smi --query-gpu=name,memory.total,memory.free --format=csv,noheader

# Check if models exist
echo ""
echo "Checking models..."
MODEL_DIR="/app/ComfyUI/models"

REQUIRED_MODELS=(
    "diffusion_models/Wan2_1-InfiniteTalk-Single_fp8_e4m3fn_scaled_KJ.safetensors"
    "diffusion_models/Wan2_1-I2V-14B-480p_fp8_e5m2_scaled_KJ.safetensors"
    "vae/wan_2.1_vae.safetensors"
    "text_encoders/umt5_xxl_fp16.safetensors"
    "clip_vision/clip_vision_h.safetensors"
    "transformers/TencentGameMate/wav2vec2-chinese-base_fp16.safetensors"
    "diffusion_models/MelBandRoformer_fp32.safetensors"
    "loras/lightx2v_I2V_14B_480p_cfg_step_distill_rank64_bf16.safetensors"
)

MISSING_MODELS=()
for model in "${REQUIRED_MODELS[@]}"; do
    if [ ! -f "$MODEL_DIR/$model" ]; then
        MISSING_MODELS+=("$model")
        echo "❌ Missing: $model"
    else
        echo "✅ Found: $model"
    fi
done

if [ ${#MISSING_MODELS[@]} -gt 0 ]; then
    echo ""
    echo "⚠️  WARNING: ${#MISSING_MODELS[@]} model(s) missing!"
    echo "The endpoint may not work correctly."
    echo "Please download models or use a network volume."
fi

echo ""
echo "Starting handler..."
exec python /app/handler.py

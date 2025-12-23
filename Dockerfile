# RunPod Serverless - ComfyUI WanVideo InfiniteTalk
# Base: NVIDIA CUDA 12.8 with Ubuntu
FROM nvidia/cuda:12.8.0-cudnn-runtime-ubuntu22.04

# Prevent interactive prompts
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV CUDA_HOME=/usr/local/cuda
ENV TORCH_CUDA_ARCH_LIST="8.0 8.6 8.9 9.0"

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    python3.11 \
    python3.11-dev \
    python3-pip \
    git \
    wget \
    curl \
    ffmpeg \
    libsm6 \
    libxext6 \
    libxrender-dev \
    libgomp1 \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# Create symbolic links
RUN ln -sf /usr/bin/python3.11 /usr/bin/python \
    && ln -sf /usr/bin/pip3 /usr/bin/pip

# Upgrade pip
RUN pip install --no-cache-dir --upgrade pip setuptools wheel

# 🔥 Install PyTorch NIGHTLY (CUDA 12.8)
RUN pip install --no-cache-dir \
    --pre torch torchvision torchaudio \
    --index-url https://download.pytorch.org/whl/nightly/cu128

# Install common dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Clone ComfyUI
RUN git clone https://github.com/comfyanonymous/ComfyUI.git /app/ComfyUI

# Install ComfyUI dependencies
RUN pip install --no-cache-dir -r /app/ComfyUI/requirements.txt

# Install comfy-cli for model downloads
RUN pip install --no-cache-dir comfy-cli

# Setup custom nodes
COPY builder/setup.sh /app/builder/setup.sh
RUN chmod +x /app/builder/setup.sh && /app/builder/setup.sh

# Download all required models using comfy-cli
WORKDIR /app/ComfyUI

RUN comfy model download \
    --url https://huggingface.co/Kijai/WanVideo_comfy_fp8_scaled/resolve/main/InfiniteTalk/Wan2_1-InfiniteTalk-Single_fp8_e4m3fn_scaled_KJ.safetensors \
    --relative-path models/diffusion_models \
    --filename Wan2_1-InfiniteTalk-Single_fp8_e4m3fn_scaled_KJ.safetensors

RUN comfy model download \
    --url https://huggingface.co/Kijai/WanVideo_comfy_fp8_scaled/resolve/main/I2V/Wan2_1-I2V-14B-480p_fp8_e5m2_scaled_KJ.safetensors \
    --relative-path models/diffusion_models \
    --filename Wan2_1-I2V-14B-480p_fp8_e5m2_scaled_KJ.safetensors

RUN comfy model download \
    --url https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors \
    --relative-path models/vae \
    --filename wan_2.1_vae.safetensors

RUN comfy model download \
    --url https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Lightx2v/lightx2v_I2V_14B_480p_cfg_step_distill_rank64_bf16.safetensors \
    --relative-path models/loras \
    --filename lightx2v_I2V_14B_480p_cfg_step_distill_rank64_bf16.safetensors

RUN comfy model download \
    --url https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/clip_vision/clip_vision_h.safetensors \
    --relative-path models/clip_vision \
    --filename clip_vision_h.safetensors

RUN comfy model download \
    --url https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp16.safetensors \
    --relative-path models/text_encoders \
    --filename umt5_xxl_fp16.safetensors

RUN comfy model download \
    --url https://huggingface.co/Kijai/wav2vec2_safetensors/resolve/main/wav2vec2-chinese-base_fp16.safetensors \
    --relative-path models/transformers/TencentGameMate \
    --filename wav2vec2-chinese-base_fp16.safetensors

RUN comfy model download \
    --url https://huggingface.co/Kijai/MelBandRoFormer_comfy/resolve/main/MelBandRoformer_fp32.safetensors \
    --relative-path models/diffusion_models \
    --filename MelBandRoformer_fp32.safetensors

WORKDIR /app

# Copy workflow
COPY workflows/infinite-talk.json /app/ComfyUI/workflows/

# Copy handler and startup script
COPY src/handler.py /app/handler.py
COPY src/start.sh /app/start.sh
RUN chmod +x /app/start.sh

# Create model directories
RUN mkdir -p /app/ComfyUI/input \
    /app/ComfyUI/output \
    /app/ComfyUI/models

# Environment variables
ENV COMFYUI_PATH=/app/ComfyUI
ENV PYTHONPATH="${PYTHONPATH}:/app/ComfyUI"

# Expose port (optional)
EXPOSE 8188

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8188/ || exit 1

# Start handler
CMD ["python", "/app/handler.py"]

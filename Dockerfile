# RunPod Serverless - ComfyUI WanVideo InfiniteTalk
# Base: NVIDIA CUDA with Ubuntu
FROM nvidia/cuda:12.1.0-cudnn8-devel-ubuntu22.04

# Prevent interactive prompts
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV CUDA_HOME=/usr/local/cuda

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    python3.10 \
    python3.10-dev \
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

# Create symbolic link for python
RUN ln -sf /usr/bin/python3.10 /usr/bin/python

# Upgrade pip
RUN pip install --no-cache-dir --upgrade pip setuptools wheel

# Install PyTorch 2.6.0 (CUDA 12.1) - Required for transformers security fix
RUN pip install --no-cache-dir \
    torch==2.6.0 \
    torchvision==0.21.0 \
    torchaudio==2.6.0 \
    --index-url https://download.pytorch.org/whl/cu121

# Install common dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Increase container disk space limit
ENV PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:512

# Clone ComfyUI
RUN git clone https://github.com/comfyanonymous/ComfyUI.git /app/ComfyUI

# Install ComfyUI dependencies
WORKDIR /app/ComfyUI
RUN pip install --no-cache-dir -r requirements.txt

# Setup custom nodes
COPY builder/setup.sh /app/builder/setup.sh
RUN chmod +x /app/builder/setup.sh && /app/builder/setup.sh

# Download models using wget (more reliable in Docker)
# Downloads ~40GB total, done in stages to avoid disk space issues
RUN echo "Creating model directories..." && \
    mkdir -p models/diffusion_models models/vae models/loras models/clip_vision models/text_encoders models/transformers/TencentGameMate

# Download smaller models first
RUN echo "Downloading VAE (3GB)..." && \
    wget -q --show-progress -O models/vae/wan_2.1_vae.safetensors \
      https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors

RUN echo "Downloading CLIP Vision (2GB)..." && \
    wget -q --show-progress -O models/clip_vision/clip_vision_h.safetensors \
      https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/clip_vision/clip_vision_h.safetensors

RUN echo "Downloading MelBandRoFormer (2GB)..." && \
    wget -q --show-progress -O models/diffusion_models/MelBandRoformer_fp32.safetensors \
      https://huggingface.co/Kijai/MelBandRoFormer_comfy/resolve/main/MelBandRoformer_fp32.safetensors

RUN echo "Downloading Wav2Vec2 (1GB)..." && \
    wget -q --show-progress -O models/transformers/TencentGameMate/wav2vec2-chinese-base_fp16.safetensors \
      https://huggingface.co/Kijai/wav2vec2_safetensors/resolve/main/wav2vec2-chinese-base_fp16.safetensors

RUN echo "Downloading LoRA (500MB)..." && \
    wget -q --show-progress -O models/loras/lightx2v_I2V_14B_480p_cfg_step_distill_rank64_bf16.safetensors \
      https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Lightx2v/lightx2v_I2V_14B_480p_cfg_step_distill_rank64_bf16.safetensors

# Download text encoder
RUN echo "Downloading text encoder (5GB)..." && \
    wget -q --show-progress -O models/text_encoders/umt5_xxl_fp16.safetensors \
      https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp16.safetensors

# Download large models last
RUN echo "Downloading InfiniteTalk model (10GB)..." && \
    wget -q --show-progress -O models/diffusion_models/Wan2_1-InfiniteTalk-Single_fp8_e4m3fn_scaled_KJ.safetensors \
      https://huggingface.co/Kijai/WanVideo_comfy_fp8_scaled/resolve/main/InfiniteTalk/Wan2_1-InfiniteTalk-Single_fp8_e4m3fn_scaled_KJ.safetensors

RUN echo "Downloading I2V model (15GB)..." && \
    wget -q --show-progress -O models/diffusion_models/Wan2_1-I2V-14B-480p_fp8_e5m2_scaled_KJ.safetensors \
      https://huggingface.co/Kijai/WanVideo_comfy_fp8_scaled/resolve/main/I2V/Wan2_1-I2V-14B-480p_fp8_e5m2_scaled_KJ.safetensors

# Verify all models
RUN echo "Verifying models..." && \
    ls -lh models/diffusion_models/ && \
    ls -lh models/vae/ && \
    ls -lh models/loras/ && \
    ls -lh models/clip_vision/ && \
    ls -lh models/text_encoders/ && \
    ls -lh models/transformers/TencentGameMate/ && \
    echo "✅ All models downloaded successfully!"

WORKDIR /app

# Copy workflow
COPY workflows/infinite-talk.json /app/ComfyUI/workflows/

# Copy handler and startup script
COPY src/handler.py /app/handler.py
COPY src/start.sh /app/start.sh
RUN chmod +x /app/start.sh

# Create model directories (comfy-cli will create subdirs automatically)
RUN mkdir -p /app/ComfyUI/input \
    /app/ComfyUI/output \
    /app/ComfyUI/models

# Set environment variables
ENV COMFYUI_PATH=/app/ComfyUI
ENV PYTHONPATH="${PYTHONPATH}:/app/ComfyUI"

# Expose port (optional, for testing)
EXPOSE 8188

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8188/ || exit 1

# Start handler
CMD ["python", "/app/handler.py"]

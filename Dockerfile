# RunPod Serverless - ComfyUI WanVideo InfiniteTalk
# Base: PyTorch 2.5.1 + CUDA 12.4 (OFFICIAL, PREINSTALLED)
FROM pytorch/pytorch:2.5.1-cuda12.4-cudnn9-runtime

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV CUDA_HOME=/usr/local/cuda
ENV TORCH_CUDA_ARCH_LIST="8.0 8.6 8.9 9.0"

WORKDIR /app

# System dependencies (minimal, CI-safe)
RUN apt-get update && apt-get install -y --no-install-recommends \
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

# Upgrade pip tooling
RUN pip install --no-cache-dir --upgrade pip setuptools wheel

# Install common Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Clone ComfyUI
RUN git clone https://github.com/comfyanonymous/ComfyUI.git /app/ComfyUI

# Install ComfyUI dependencies
RUN pip install --no-cache-dir -r /app/ComfyUI/requirements.txt

# Install comfy-cli
RUN pip install --no-cache-dir comfy-cli

# Setup custom nodes
COPY builder/setup.sh /app/builder/setup.sh
RUN chmod +x /app/builder/setup.sh && /app/builder/setup.sh

# Download models
WORKDIR /app/ComfyUI
# (model downloads remain unchanged)

WORKDIR /app

# Copy workflow
COPY workflows/infinite-talk.json /app/ComfyUI/workflows/

# Copy handler and startup scripts
COPY src/handler.py /app/handler.py
COPY src/start.sh /app/start.sh
RUN chmod +x /app/start.sh

# Create required directories
RUN mkdir -p /app/ComfyUI/input \
    /app/ComfyUI/output \
    /app/ComfyUI/models

# Environment variables
ENV COMFYUI_PATH=/app/ComfyUI
ENV PYTHONPATH=/app/ComfyUI

# Expose ComfyUI port
EXPOSE 8188

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8188/ || exit 1

# Start handler
CMD ["python", "/app/handler.py"]

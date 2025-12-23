# RunPod Serverless - ComfyUI WanVideo InfiniteTalk
# Base: PyTorch Nightly CUDA 12.8 (PREINSTALLED)
FROM pytorch/pytorch:nightly-cuda12.8-cudnn9-runtime

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV CUDA_HOME=/usr/local/cuda
ENV TORCH_CUDA_ARCH_LIST="8.0 8.6 8.9 9.0"

WORKDIR /app

# System deps (keep minimal!)
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

# Upgrade pip (safe)
RUN pip install --no-cache-dir --upgrade pip setuptools wheel

# Install common dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Clone ComfyUI
RUN git clone https://github.com/comfyanonymous/ComfyUI.git /app/ComfyUI

# Install ComfyUI dependencies
RUN pip install --no-cache-dir -r /app/ComfyUI/requirements.txt

# comfy-cli
RUN pip install --no-cache-dir comfy-cli

# Custom nodes
COPY builder/setup.sh /app/builder/setup.sh
RUN chmod +x /app/builder/setup.sh && /app/builder/setup.sh

# Models
WORKDIR /app/ComfyUI
# (model downloads unchanged – omitted here for brevity)

WORKDIR /app

COPY workflows/infinite-talk.json /app/ComfyUI/workflows/
COPY src/handler.py /app/handler.py
COPY src/start.sh /app/start.sh
RUN chmod +x /app/start.sh

RUN mkdir -p /app/ComfyUI/input \
    /app/ComfyUI/output \
    /app/ComfyUI/models

ENV COMFYUI_PATH=/app/ComfyUI
ENV PYTHONPATH=/app/ComfyUI

EXPOSE 8188

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8188/ || exit 1

CMD ["python", "/app/handler.py"]

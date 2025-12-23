# ComfyUI WanVideo InfiniteTalk - RunPod Serverless

Deploy audio-driven video generation using WanVideo 2.1 InfiniteTalk on RunPod Serverless.

## Features

- 🎤 Audio-driven facial animation
- 🖼️ Image-to-video generation
- 🎵 Automatic vocal separation
- ⚡ FP8 quantization for efficiency
- 🔄 Automatic model management

## Prerequisites

1. **RunPod Account** with credits
2. **GitHub Account** for repository hosting
3. **Hugging Face Account** (optional, for model downloads)

## Quick Start

### 1. Clone/Fork this Repository

```bash
git clone https://github.com/YOUR_USERNAME/runpod-comfyui-wanvideo.git
cd runpod-comfyui-wanvideo
```

### 2. Add Your Workflow

Copy your workflow JSON:
```bash
cp /path/to/your/infinite-talk.json workflows/
```

### 3. Configure Models

Edit `builder/setup.sh` to uncomment model download URLs, or use network volumes.

### 4. Push to GitHub

```bash
git add .
git commit -m "Initial setup"
git push origin main
```

### 5. Deploy to RunPod

1. Go to [RunPod Serverless](https://www.runpod.io/console/serverless)
2. Click **"+ New Endpoint"**
3. Select **"Import GitHub Repository"**
4. Enter your repository URL
5. Configure:
   - **Name**: WanVideo-InfiniteTalk
   - **GPU Type**: RTX 4090 / A40 / A100 (24GB+ VRAM)
   - **Container Disk**: 50GB
   - **Active Workers**: 1-3
   - **Max Workers**: 5

### 6. Wait for Build

Building takes ~30-60 minutes (first time). Watch logs in RunPod dashboard.

## Usage

### API Request Example

```python
import runpod
import base64

runpod.api_key = "YOUR_RUNPOD_API_KEY"
endpoint = runpod.Endpoint("YOUR_ENDPOINT_ID")

# Read files
with open("audio.mp3", "rb") as f:
    audio_b64 = base64.b64encode(f.read()).decode()

with open("portrait.png", "rb") as f:
    image_b64 = base64.b64encode(f.read()).decode()

# Run job
job = endpoint.run({
    "input": {
        "audio_base64": audio_b64,
        "image_base64": image_b64,
        "width": 960,
        "height": 960,
        "max_frames": 10000,
        "prompt": "professional lighting, 8K, hyperrealistic",
        "seed": 42,
        "steps": 4,
        "cfg": 2
    }
})

# Wait for completion
result = job.wait()

# Save output
if "outputs" in result:
    video_b64 = result["outputs"][0]["video_base64"]
    with open("output.mp4", "wb") as f:
        f.write(base64.b64decode(video_b64))
```

### Input Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `audio_base64` | string | Yes | - | Base64 encoded audio file (MP3/WAV) |
| `image_base64` | string | Yes | - | Base64 encoded portrait image |
| `width` | int | No | 960 | Output width (multiple of 16) |
| `height` | int | No | 960 | Output height (multiple of 16) |
| `max_frames` | int | No | 10000 | Maximum frames to generate |
| `prompt` | string | No | Default | Positive text prompt |
| `negative_prompt` | string | No | "" | Negative text prompt |
| `seed` | int | No | 2 | Random seed |
| `steps` | int | No | 4 | Sampling steps |
| `cfg` | int | No | 2 | CFG scale |

## Model Management

### Option 1: Bake Models into Image (Recommended)

Uncomment download commands in `builder/setup.sh`:

**Pros:** Faster cold starts, no network dependency  
**Cons:** Large image size (~50GB), slower builds

### Option 2: Network Volume

1. Create RunPod Network Volume
2. Download models to volume:
   ```bash
   /runpod-volume/models/checkpoints/
   /runpod-volume/models/vae/
   /runpod-volume/models/loras/
   # etc...
   ```
3. Mount volume to endpoint
4. Update paths in handler

**Pros:** Smaller images, share models across endpoints  
**Cons:** Requires network volume, slightly slower first load

### Required Models (~40GB total)

Download from Hugging Face:

```bash
# Main model
https://huggingface.co/Kijai/WanVideo_comfy_fp8_scaled/resolve/main/Wan2_1-I2V-14B-480p_fp8_e5m2_scaled_KJ.safetensors

# InfiniteTalk
https://huggingface.co/Kijai/WanVideo_comfy_fp8_scaled/resolve/main/InfiniteTalk/Wan2_1-InfiniteTalk-Single_fp8_e4m3fn_scaled_KJ.safetensors

# VAE
https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/wan_2.1_vae.safetensors

# Text Encoder
https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/umt5_xxl_fp16.safetensors

# CLIP Vision
https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/clip_vision_h.safetensors

# Wav2Vec2
https://huggingface.co/Kijai/wav2vec2_safetensors/resolve/main/wav2vec2-chinese-base_fp16.safetensors

# Vocal Separator
https://huggingface.co/Kijai/MelBandRoFormer_comfy/resolve/main/MelBandRoformer_fp32.safetensors

# LoRA (optional)
https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/loras/lightx2v_I2V_14B_480p_cfg_step_distill_rank64_bf16.safetensors
```

## Troubleshooting

### Build Fails

- Check GitHub repo is public
- Verify Dockerfile syntax
- Check RunPod build logs

### Out of Memory

- Use smaller resolution (832x480)
- Reduce max_frames
- Use fp8 models (already configured)
- Increase GPU VRAM (A100 48GB recommended)

### Slow Generation

- First run is slower (model loading)
- Use active workers > 0 to keep warm
- Consider baking models into image

### Model Not Found

- Check model filenames match exactly
- Verify models are in correct directories
- Check network volume mount paths

## Cost Optimization

1. **Use Spot Instances** - 50% cheaper
2. **Scale to Zero** - Only pay when running
3. **Network Volumes** - Share models across endpoints
4. **FP8 Models** - Already configured, saves VRAM
5. **Batch Jobs** - Process multiple videos together

## Advanced Configuration

### Custom Workflow

Replace `workflows/infinite-talk.json` with your own ComfyUI workflow. Update handler.py to match node IDs.

### Environment Variables

Add to RunPod endpoint settings:

```bash
COMFYUI_PORT=8188
CUDA_VISIBLE_DEVICES=0
```

### Multi-GPU

Modify Dockerfile to support multiple GPUs:

```dockerfile
ENV CUDA_VISIBLE_DEVICES=0,1
```

Update handler to distribute load.

## Support

- **RunPod Discord**: https://discord.gg/runpod
- **ComfyUI Forum**: https://www.comfy.org/
- **Issues**: GitHub Issues on this repo

## License

MIT License - See LICENSE file

## Credits

- [WanVideo](https://github.com/kijai/ComfyUI-WanVideoWrapper) by Kijai
- [ComfyUI](https://github.com/comfyanonymous/ComfyUI)
- [RunPod](https://runpod.io/)

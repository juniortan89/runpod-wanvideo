# Quick Start Guide - WanVideo InfiniteTalk on RunPod

## ⚡ Fast Track (10 Minutes)

### Prerequisites
- GitHub account
- RunPod account with credits
- Your workflow JSON file

### Step 1: Create Repository (2 min)

```bash
# Create and clone repo
mkdir runpod-wanvideo && cd runpod-wanvideo
git init

# Create structure
mkdir -p builder src workflows .github/workflows
```

### Step 2: Add Files (3 min)

Copy these files from the artifacts I provided:
- ✅ `Dockerfile` (updated with comfy-cli model downloads)
- ✅ `requirements.txt`
- ✅ `builder/setup.sh` (simplified, no manual downloads)
- ✅ `src/handler.py` (updated with your workflow node IDs)
- ✅ `src/start.sh` (updated model paths)
- ✅ `.dockerignore`
- ✅ `.gitignore`
- ✅ `README.md`

### Step 3: Add Your Workflow (1 min)

```bash
# Copy your workflow
cp /path/to/infinite-talk.json workflows/

# Make scripts executable
chmod +x builder/setup.sh src/start.sh
```

### Step 4: Push to GitHub (2 min)

```bash
git add .
git commit -m "WanVideo InfiniteTalk serverless setup"

# Create repo on GitHub, then:
git remote add origin https://github.com/YOUR_USERNAME/runpod-wanvideo.git
git push -u origin main
```

### Step 5: Deploy to RunPod (2 min)

1. Go to https://www.runpod.io/console/serverless
2. Click **"New Endpoint"**
3. Choose **"Import GitHub Repository"**
4. Paste your repo URL: `https://github.com/YOUR_USERNAME/runpod-wanvideo`
5. Configure:
   - **Name**: `wanvideo-infinitetalk`
   - **GPU**: RTX 4090 or A40 (24GB+ VRAM)
   - **Container Disk**: 50GB
   - **Min Workers**: 0
   - **Max Workers**: 3
   - **Idle Timeout**: 5s
   - **Execution Timeout**: 600s

6. Click **Deploy**

### Step 6: Wait for Build (~45 min)

The first build takes time because it:
- Downloads ~40GB of models
- Installs all dependencies
- Compiles CUDA kernels

☕ Grab coffee, watch the build logs!

---

## 📊 What Gets Downloaded

Your Dockerfile now automatically downloads:

| Model | Size | Purpose |
|-------|------|---------|
| Wan2_1-InfiniteTalk-Single | ~10GB | Audio-driven animation |
| Wan2_1-I2V-14B-480p | ~15GB | Image-to-video base model |
| wan_2.1_vae | ~3GB | VAE encoder/decoder |
| umt5_xxl_fp16 | ~5GB | Text encoder |
| clip_vision_h | ~2GB | Image encoder |
| wav2vec2-chinese-base | ~1GB | Audio feature extraction |
| MelBandRoformer | ~2GB | Vocal separation |
| lightx2v LoRA | ~500MB | Quality enhancement |

**Total**: ~40GB in models

---

## 🧪 Testing Your Endpoint

Once deployed, test with this script:

```python
import runpod
import base64
import os

# Set your API key
runpod.api_key = os.getenv("RUNPOD_API_KEY")

# Initialize endpoint
endpoint = runpod.Endpoint("YOUR_ENDPOINT_ID")

# Prepare test files
with open("test_audio.mp3", "rb") as f:
    audio_b64 = base64.b64encode(f.read()).decode()

with open("test_portrait.png", "rb") as f:
    image_b64 = base64.b64encode(f.read()).decode()

# Submit job
print("Submitting job...")
job = endpoint.run({
    "input": {
        "audio_base64": audio_b64,
        "image_base64": image_b64,
        "width": 832,
        "height": 480,
        "max_frames": 100,  # ~4 seconds at 25fps
        "steps": 4,
        "cfg": 2.0,
        "seed": 42
    }
})

# Wait for completion
print("Waiting for result...")
result = job.wait()

# Save output
if "outputs" in result:
    video_b64 = result["outputs"][0]["video_base64"]
    with open("output.mp4", "wb") as f:
        f.write(base64.b64decode(video_b64))
    print("✅ Video saved to output.mp4")
else:
    print("❌ Error:", result.get("error", "Unknown error"))
```

Or use the test script:

```bash
python test_endpoint.py \
  --endpoint-id YOUR_ENDPOINT_ID \
  --audio test_audio.mp3 \
  --image test_portrait.png \
  --output result.mp4
```

---

## 💰 Cost Estimates

Based on RTX 4090 pricing (~$0.30/min):

| Task | Duration | Cost |
|------|----------|------|
| Cold start (first time) | 2-3 min | $0.60-0.90 |
| Generate 100 frames (4s video) | 2-3 min | $0.60-0.90 |
| Generate 250 frames (10s video) | 4-5 min | $1.20-1.50 |
| Generate 625 frames (25s video) | 8-10 min | $2.40-3.00 |

**Cost Optimization:**
- Keep 1 active worker if processing frequently ($0.30/min idle)
- Scale to 0 if infrequent use (no idle costs)
- Use spot instances for 50% discount

---

## 🔧 Configuration Options

### Resolution Presets

```python
# Standard HD (faster)
"width": 832, "height": 480

# HD (balanced)
"width": 960, "height": 540

# Full HD (slower, more VRAM)
"width": 1280, "height": 720
```

### Quality Settings

```python
# Fast (good quality)
"steps": 4, "cfg": 2.0

# Balanced
"steps": 6, "cfg": 2.5

# High quality (slower)
"steps": 8, "cfg": 3.0
```

### Frame Limits

```python
# Short clip (~4s at 25fps)
"max_frames": 100

# Medium clip (~10s)
"max_frames": 250

# Long clip (~40s)
"max_frames": 1000

# Let audio determine length
"max_frames": 10000  # Will use actual audio length
```

---

## 🐛 Troubleshooting

### Build Fails

**Error: "Failed to download model"**
- Check Hugging Face is accessible
- Verify URLs in Dockerfile are correct
- Try rebuilding

**Error: "Out of disk space"**
- Increase Container Disk to 50GB
- Models are ~40GB total

### Runtime Errors

**Error: "Model not found"**
- Check model paths match your workflow
- Verify models downloaded during build
- Check startup logs

**Error: "CUDA out of memory"**
- Reduce resolution (832x480)
- Use fewer max_frames
- Switch to larger GPU (A100)

**Error: "Job timeout"**
- Increase execution timeout to 600s
- Reduce max_frames for testing
- Check ComfyUI logs

### Slow Performance

**Cold starts take 3+ minutes**
- Normal for first load
- Keep 1 active worker to stay warm
- Consider FlashBoot (RunPod feature)

**Generation takes 10+ minutes**
- Check GPU utilization in logs
- Verify fp8 models are being used
- Try reducing resolution/steps

---

## 📈 Monitoring & Logs

### View Logs

```bash
# In RunPod dashboard:
Serverless → Your Endpoint → Logs
```

### Key Log Indicators

```
✅ "ComfyUI server is ready!" - Server started
✅ "Found: models/..." - Models loaded correctly
❌ "Missing: models/..." - Model download failed
✅ "Queued prompt: ..." - Job accepted
✅ "Status: COMPLETED" - Job finished
```

### Performance Metrics

Monitor in RunPod dashboard:
- Average execution time
- GPU utilization
- Memory usage
- Cost per job
- Error rate

---

## 🚀 Production Checklist

- [ ] Build completes successfully
- [ ] Test with short audio (5-10s)
- [ ] Test with long audio (30s+)
- [ ] Verify output quality
- [ ] Check execution times acceptable
- [ ] Set up monitoring/alerts
- [ ] Configure autoscaling settings
- [ ] Document API for team
- [ ] Set budget alerts
- [ ] Plan backup/redundancy

---

## 🆘 Need Help?

- **RunPod Discord**: https://discord.gg/runpod
- **ComfyUI Forum**: https://www.comfy.org/
- **WanVideo Issues**: https://github.com/kijai/ComfyUI-WanVideoWrapper/issues
- **This Repo**: GitHub Issues

---

## 📚 Next Steps

Once deployed and tested:

1. **Integrate with your app**
   - Use RunPod Python SDK or REST API
   - Handle webhooks for job completion
   - Implement retry logic

2. **Optimize costs**
   - Monitor usage patterns
   - Adjust worker counts
   - Consider batch processing

3. **Improve quality**
   - Experiment with prompts
   - Try different resolutions
   - Test various CFG scales

4. **Scale up**
   - Add more workers
   - Implement queuing
   - Set up load balancing

---

**Total Setup Time**: ~1 hour (10 min setup + 45 min build)

**Ready to deploy?** Follow the steps above and you'll have a production-ready video generation API in under an hour!

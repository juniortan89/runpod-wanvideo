# RunPod Serverless Deployment Checklist

## Pre-Deployment Setup

### 1. Repository Setup
- [ ] Create new GitHub repository
- [ ] Clone repository locally
- [ ] Copy all files from this template:
  ```
  ├── Dockerfile
  ├── requirements.txt
  ├── builder/setup.sh
  ├── src/handler.py
  ├── src/start.sh
  ├── workflows/infinite-talk.json
  ├── .dockerignore
  ├── .github/workflows/docker-build.yml (optional)
  └── README.md
  ```
- [ ] Make shell scripts executable:
  ```bash
  chmod +x builder/setup.sh src/start.sh
  ```

### 2. Workflow Configuration
- [ ] Copy your workflow JSON to `workflows/infinite-talk.json`
- [ ] Verify workflow uses these models:
  - Wan2_1-I2V-14B-480p_fp8_e5m2_scaled_KJ.safetensors
  - Wan2_1-InfiniteTalk-Single_fp8_e4m3fn_scaled_KJ.safetensors
  - wan_2.1_vae.safetensors
  - umt5_xxl_fp16.safetensors
  - clip_vision_h.safetensors
  - wav2vec2-chinese-base_fp16.safetensors
  - MelBandRoformer_fp32.safetensors

### 3. Model Preparation

#### Option A: Bake Models into Image
- [ ] Edit `builder/setup.sh`
- [ ] Uncomment model download sections
- [ ] Verify Hugging Face URLs are correct
- [ ] Test downloads manually (optional)

#### Option B: Use Network Volume
- [ ] Create RunPod Network Volume (50GB+)
- [ ] Download models to volume:
  ```bash
  # From a RunPod Pod with volume mounted:
  cd /workspace/models
  
  # Create directories
  mkdir -p checkpoints vae loras clip_vision wav2vec2 diffusion_models
  
  # Download main model
  wget https://huggingface.co/Kijai/WanVideo_comfy_fp8_scaled/resolve/main/Wan2_1-I2V-14B-480p_fp8_e5m2_scaled_KJ.safetensors \
    -O checkpoints/Wan2_1-I2V-14B-480p_fp8_e5m2_scaled_KJ.safetensors
  
  # Download InfiniteTalk
  wget https://huggingface.co/Kijai/WanVideo_comfy_fp8_scaled/resolve/main/InfiniteTalk/Wan2_1-InfiniteTalk-Single_fp8_e4m3fn_scaled_KJ.safetensors \
    -O checkpoints/Wan2_1-InfiniteTalk-Single_fp8_e4m3fn_scaled_KJ.safetensors
  
  # Continue for all models...
  ```
- [ ] Update handler.py to mount volume paths
- [ ] Note volume ID for deployment

### 4. Push to GitHub
```bash
git add .
git commit -m "Initial serverless setup"
git push origin main
```

## RunPod Deployment

### 1. Create Endpoint
- [ ] Go to https://www.runpod.io/console/serverless
- [ ] Click "New Endpoint"
- [ ] Select "Import GitHub Repository"

### 2. Configuration

#### Basic Settings
- [ ] **Name**: `wanvideo-infinitetalk` (or your choice)
- [ ] **GitHub URL**: Your repository URL
- [ ] **Branch**: `main`
- [ ] **Dockerfile Path**: `Dockerfile` (default)

#### Container Settings
- [ ] **Container Disk**: 50GB (if baking models) or 15GB (if using volume)
- [ ] **Environment Variables**: (optional)
  ```
  COMFYUI_PORT=8188
  PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:512
  ```

#### GPU Selection
- [ ] **GPU Types**: Select one or more:
  - ✅ RTX 4090 (24GB) - Good balance
  - ✅ RTX A6000 (48GB) - Expensive but fast
  - ✅ A40 (48GB) - Good for production
  - ✅ A100 (40GB/80GB) - Best performance
  - ❌ RTX 3090 (24GB) - May work but tight on VRAM
  - ❌ RTX 4080 (16GB) - Not enough VRAM

#### Scaling Settings
- [ ] **Min Workers**: 0 (scale to zero)
- [ ] **Max Workers**: 3-5 (depending on budget)
- [ ] **Idle Timeout**: 5 seconds
- [ ] **Execution Timeout**: 600 seconds (10 min)
- [ ] **Active Workers**: 1 (optional, keeps warm)

#### Network Volume (if using)
- [ ] Attach your network volume
- [ ] Mount path: `/workspace/models`
- [ ] Update handler.py model paths

### 3. Advanced Settings (Optional)
- [ ] Enable FlashBoot (faster cold starts)
- [ ] Set up custom domains
- [ ] Configure webhooks for completion notifications

### 4. Deploy
- [ ] Click "Deploy"
- [ ] Wait for initial build (30-60 minutes first time)
- [ ] Monitor build logs for errors

## Post-Deployment Testing

### 1. Wait for Build
- [ ] Build status shows "Ready"
- [ ] Check logs for errors
- [ ] Note Endpoint ID

### 2. Test API
```python
import runpod
import base64

# Initialize
runpod.api_key = "YOUR_API_KEY"
endpoint = runpod.Endpoint("YOUR_ENDPOINT_ID")

# Prepare test data
with open("test_audio.mp3", "rb") as f:
    audio_b64 = base64.b64encode(f.read()).decode()

with open("test_portrait.png", "rb") as f:
    image_b64 = base64.b64encode(f.read()).decode()

# Test request
job = endpoint.run({
    "input": {
        "audio_base64": audio_b64,
        "image_base64": image_b64,
        "width": 832,
        "height": 480,
        "max_frames": 100,  # Short test
        "steps": 4
    }
})

# Check status
status = job.status()
print(f"Status: {status}")

# Wait for result
result = job.wait()
print(result)
```

### 3. Verify Output
- [ ] Job completes successfully
- [ ] Output video generated
- [ ] Video quality is acceptable
- [ ] Audio sync is correct
- [ ] Execution time is reasonable (2-5 min for 100 frames)

### 4. Test Edge Cases
- [ ] Very short audio (<5 seconds)
- [ ] Long audio (>60 seconds)
- [ ] Different image sizes
- [ ] Portrait vs landscape images
- [ ] Different audio formats (MP3, WAV)

## Cost Optimization

### Monitor Usage
- [ ] Set up billing alerts
- [ ] Monitor active worker costs
- [ ] Track execution times
- [ ] Review GPU utilization

### Optimize Settings
- [ ] Reduce max_workers if underutilized
- [ ] Use spot instances for 50% savings
- [ ] Scale active_workers to 0 if low traffic
- [ ] Consider smaller GPU types for testing

### Batch Processing
- [ ] Process multiple jobs together
- [ ] Use queue system for non-urgent jobs
- [ ] Schedule batch runs during off-peak hours

## Troubleshooting

### Build Failures
- [ ] Check Dockerfile syntax
- [ ] Verify GitHub repo is accessible
- [ ] Check custom node installation errors
- [ ] Review build logs line by line

### Runtime Errors
- [ ] Check model files exist
- [ ] Verify GPU memory sufficient
- [ ] Test locally with Docker first
- [ ] Check ComfyUI logs in pod

### Slow Performance
- [ ] Monitor GPU utilization
- [ ] Check if models loaded in memory
- [ ] Verify network volume performance
- [ ] Consider fp8 models (already using)

### Out of Memory
- [ ] Reduce resolution (832x480 instead of 960x960)
- [ ] Decrease max_frames
- [ ] Use larger GPU (A100)
- [ ] Check for memory leaks

## Maintenance

### Regular Updates
- [ ] Update ComfyUI regularly
- [ ] Update custom nodes
- [ ] Update PyTorch/dependencies
- [ ] Rebuild image periodically

### Model Updates
- [ ] Check for new model releases
- [ ] Test new models before deploying
- [ ] Maintain model version control
- [ ] Document model changes

### Monitoring
- [ ] Set up logging/monitoring
- [ ] Track error rates
- [ ] Monitor costs daily
- [ ] Review performance metrics

## Security

- [ ] Use environment variables for secrets
- [ ] Don't commit API keys to repo
- [ ] Limit endpoint access with API keys
- [ ] Regularly rotate credentials
- [ ] Monitor unauthorized access

## Documentation

- [ ] Document API usage for team
- [ ] Create example requests
- [ ] Document error codes
- [ ] Maintain changelog

## Success Criteria

- [x] Build completes without errors
- [x] Test job runs successfully
- [x] Output quality meets requirements
- [x] Execution time under 5 minutes (for 100 frames)
- [x] Cost per generation under budget
- [x] API accessible and documented

---

**Deployment Date**: _____________

**Deployed By**: _____________

**Endpoint ID**: _____________

**Notes**: 
_____________________________________________________________
_____________________________________________________________
_____________________________________________________________

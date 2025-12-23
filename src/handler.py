"""
RunPod Serverless Handler for ComfyUI WanVideo InfiniteTalk
"""
import os
import json
import uuid
import base64
import subprocess
import time
import requests
from pathlib import Path
from typing import Dict, Any
import runpod

# Environment variables
COMFYUI_PATH = os.getenv("COMFYUI_PATH", "/app/ComfyUI")
COMFYUI_PORT = os.getenv("COMFYUI_PORT", "8188")
COMFYUI_URL = f"http://127.0.0.1:{COMFYUI_PORT}"

# Start ComfyUI server in background
comfyui_process = None

def start_comfyui():
    """Start ComfyUI server"""
    global comfyui_process
    print("Starting ComfyUI server...")
    
    cmd = [
        "python", 
        os.path.join(COMFYUI_PATH, "main.py"),
        "--listen", "127.0.0.1",
        "--port", COMFYUI_PORT,
        "--disable-auto-launch",
        "--cuda-device", "0"
    ]
    
    comfyui_process = subprocess.Popen(cmd, cwd=COMFYUI_PATH)
    
    # Wait for server to be ready
    max_retries = 30
    for i in range(max_retries):
        try:
            response = requests.get(f"{COMFYUI_URL}/system_stats")
            if response.status_code == 200:
                print("ComfyUI server is ready!")
                return True
        except:
            time.sleep(2)
            print(f"Waiting for ComfyUI... ({i+1}/{max_retries})")
    
    raise Exception("Failed to start ComfyUI server")

def save_file_from_base64(base64_str: str, filename: str, input_dir: str) -> str:
    """Save base64 encoded file to input directory"""
    file_path = os.path.join(input_dir, filename)
    
    # Remove data URL prefix if present
    if "," in base64_str:
        base64_str = base64_str.split(",")[1]
    
    # Decode and save
    file_data = base64.b64decode(base64_str)
    with open(file_path, "wb") as f:
        f.write(file_data)
    
    return filename

def load_workflow(workflow_path: str = None) -> Dict:
    """Load workflow JSON (already in API format)"""
    if workflow_path is None:
        workflow_path = os.path.join(COMFYUI_PATH, "workflows", "infinite-talk.json")
    
    with open(workflow_path, "r") as f:
        workflow_data = json.load(f)
    
    # Workflow is already in API format (has node IDs as keys)
    # Just return it as-is
    return workflow_data

def update_workflow_params(workflow: Dict, params: Dict) -> Dict:
    """Update workflow with user parameters"""
    
    # Workflow is in API format: {"node_id": {"inputs": {...}, "class_type": "..."}}
    for node_id, node_data in workflow.items():
        class_type = node_data.get("class_type")
        inputs = node_data.get("inputs", {})
        
        # Update LoadAudio node (125)
        if node_id == "125" or class_type == "LoadAudio":
            if "audio_file" in params:
                inputs["audio"] = params["audio_file"]
        
        # Update LoadImage node (284)
        elif node_id == "284" or class_type == "LoadImage":
            if "input_image" in params:
                inputs["image"] = params["input_image"]
        
        # Update Width (245)
        elif node_id == "245":
            if "width" in params:
                inputs["value"] = params["width"]
        
        # Update Height (246)
        elif node_id == "246":
            if "height" in params:
                inputs["value"] = params["height"]
        
        # Update Max frames (270)
        elif node_id == "270":
            if "max_frames" in params:
                inputs["value"] = params["max_frames"]
        
        # Update text prompt (241)
        elif node_id == "241" or class_type == "WanVideoTextEncodeCached":
            if "prompt" in params:
                inputs["positive_prompt"] = params["prompt"]
            if "negative_prompt" in params:
                inputs["negative_prompt"] = params["negative_prompt"]
        
        # Update sampler settings (128)
        elif node_id == "128" or class_type == "WanVideoSampler":
            if "seed" in params:
                inputs["seed"] = params["seed"]
            if "steps" in params:
                inputs["steps"] = params["steps"]
            if "cfg" in params:
                inputs["cfg"] = params["cfg"]
    
    return workflow

def queue_prompt(workflow: Dict) -> str:
    """Queue workflow to ComfyUI"""
    payload = {
        "prompt": workflow,
        "client_id": str(uuid.uuid4())
    }
    
    response = requests.post(f"{COMFYUI_URL}/prompt", json=payload)
    response.raise_for_status()
    
    result = response.json()
    return result["prompt_id"]

def get_output_files(prompt_id: str) -> list:
    """Get generated output files"""
    history_url = f"{COMFYUI_URL}/history/{prompt_id}"
    
    max_wait = 600  # 10 minutes
    start_time = time.time()
    
    while time.time() - start_time < max_wait:
        try:
            response = requests.get(history_url)
            history = response.json()
            
            if prompt_id in history:
                outputs = history[prompt_id].get("outputs", {})
                
                # Find video output
                for node_id, node_output in outputs.items():
                    if "images" in node_output or "gifs" in node_output or "videos" in node_output:
                        files = node_output.get("images", node_output.get("gifs", node_output.get("videos", [])))
                        return files
                
                # If no outputs, check if completed
                status = history[prompt_id].get("status", {})
                if status.get("completed", False):
                    return []
            
        except Exception as e:
            print(f"Error checking history: {e}")
        
        time.sleep(2)
    
    raise Exception("Timeout waiting for generation")

def handler(event: Dict[str, Any]) -> Dict[str, Any]:
    """
    RunPod handler function
    
    Expected input:
    {
        "input": {
            "audio_base64": "base64_encoded_audio",  # Required
            "image_base64": "base64_encoded_image",  # Required
            "audio_filename": "audio.mp3",  # Optional
            "image_filename": "image.png",  # Optional
            "width": 960,  # Optional
            "height": 960,  # Optional
            "max_frames": 10000,  # Optional
            "prompt": "text prompt",  # Optional
            "negative_prompt": "negative prompt",  # Optional
            "seed": 2,  # Optional
            "steps": 4,  # Optional
            "cfg": 2  # Optional
        }
    }
    """
    try:
        job_input = event["input"]
        
        # Validate required inputs
        if "audio_base64" not in job_input:
            return {"error": "audio_base64 is required"}
        if "image_base64" not in job_input:
            return {"error": "image_base64 is required"}
        
        input_dir = os.path.join(COMFYUI_PATH, "input")
        output_dir = os.path.join(COMFYUI_PATH, "output")
        
        # Save audio file
        audio_filename = job_input.get("audio_filename", f"audio_{uuid.uuid4().hex[:8]}.mp3")
        audio_file = save_file_from_base64(job_input["audio_base64"], audio_filename, input_dir)
        
        # Save image file
        image_filename = job_input.get("image_filename", f"image_{uuid.uuid4().hex[:8]}.png")
        image_file = save_file_from_base64(job_input["image_base64"], image_filename, input_dir)
        
        # Load and update workflow
        workflow = load_workflow()
        params = {
            "audio_file": audio_file,
            "input_image": image_file,
            "width": job_input.get("width", 960),
            "height": job_input.get("height", 960),
            "max_frames": job_input.get("max_frames", 10000),
            "prompt": job_input.get("prompt", "professional lighting highlights her features. 8K, hyperrealistic. Static camera Shot."),
            "negative_prompt": job_input.get("negative_prompt", ""),
            "seed": job_input.get("seed", 2),
            "steps": job_input.get("steps", 4),
            "cfg": job_input.get("cfg", 2)
        }
        
        workflow = update_workflow_params(workflow, params)
        
        # Queue prompt
        prompt_id = queue_prompt(workflow)
        print(f"Queued prompt: {prompt_id}")
        
        # Wait for completion and get outputs
        output_files = get_output_files(prompt_id)
        
        if not output_files:
            return {"error": "No output files generated"}
        
        # Read and encode output video
        results = []
        for file_info in output_files:
            file_path = os.path.join(output_dir, file_info.get("subfolder", ""), file_info["filename"])
            
            if os.path.exists(file_path):
                with open(file_path, "rb") as f:
                    video_data = base64.b64encode(f.read()).decode("utf-8")
                
                results.append({
                    "filename": file_info["filename"],
                    "video_base64": video_data,
                    "type": file_info.get("type", "output")
                })
        
        return {
            "status": "success",
            "outputs": results,
            "prompt_id": prompt_id
        }
        
    except Exception as e:
        print(f"Error in handler: {str(e)}")
        return {"error": str(e)}

# Start ComfyUI on container startup
if __name__ == "__main__":
    print("Initializing RunPod handler...")
    start_comfyui()
    print("Starting RunPod serverless...")
    runpod.serverless.start({"handler": handler})

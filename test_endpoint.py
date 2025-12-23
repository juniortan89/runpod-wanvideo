#!/usr/bin/env python3
"""
Test script for RunPod WanVideo InfiniteTalk Serverless Endpoint
"""
import os
import sys
import base64
import time
import argparse
from pathlib import Path

try:
    import runpod
except ImportError:
    print("Error: runpod package not installed")
    print("Install with: pip install runpod")
    sys.exit(1)


def encode_file(file_path: str) -> str:
    """Encode file to base64"""
    with open(file_path, "rb") as f:
        return base64.b64encode(f.read()).decode("utf-8")


def save_base64_file(base64_str: str, output_path: str):
    """Save base64 string to file"""
    with open(output_path, "wb") as f:
        f.write(base64.b64decode(base64_str))


def test_endpoint(
    endpoint_id: str,
    audio_path: str,
    image_path: str,
    output_path: str = "output.mp4",
    width: int = 832,
    height: int = 480,
    max_frames: int = 100,
    steps: int = 4,
    cfg: float = 2.0,
    seed: int = 42
):
    """
    Test the WanVideo endpoint
    
    Args:
        endpoint_id: RunPod endpoint ID
        audio_path: Path to audio file (MP3/WAV)
        image_path: Path to portrait image (PNG/JPG)
        output_path: Where to save output video
        width: Video width (multiple of 16)
        height: Video height (multiple of 16)
        max_frames: Maximum frames to generate
        steps: Sampling steps (higher = better quality, slower)
        cfg: CFG scale
        seed: Random seed for reproducibility
    """
    
    print("=" * 60)
    print("Testing WanVideo InfiniteTalk Endpoint")
    print("=" * 60)
    
    # Validate inputs
    if not os.path.exists(audio_path):
        print(f"Error: Audio file not found: {audio_path}")
        return False
    
    if not os.path.exists(image_path):
        print(f"Error: Image file not found: {image_path}")
        return False
    
    # Encode files
    print("\n1. Encoding input files...")
    print(f"   Audio: {audio_path} ({os.path.getsize(audio_path) / 1024:.1f} KB)")
    print(f"   Image: {image_path} ({os.path.getsize(image_path) / 1024:.1f} KB)")
    
    audio_b64 = encode_file(audio_path)
    image_b64 = encode_file(image_path)
    
    print(f"   Audio base64: {len(audio_b64)} chars")
    print(f"   Image base64: {len(image_b64)} chars")
    
    # Initialize endpoint
    print("\n2. Connecting to endpoint...")
    try:
        endpoint = runpod.Endpoint(endpoint_id)
        print(f"   Connected to: {endpoint_id}")
    except Exception as e:
        print(f"   Error connecting: {e}")
        return False
    
    # Prepare request
    print("\n3. Preparing request...")
    request_data = {
        "input": {
            "audio_base64": audio_b64,
            "image_base64": image_b64,
            "width": width,
            "height": height,
            "max_frames": max_frames,
            "steps": steps,
            "cfg": cfg,
            "seed": seed,
            "prompt": "professional lighting highlights features. 8K, hyperrealistic. Static camera.",
            "negative_prompt": "blurred, low quality, deformed"
        }
    }
    
    print(f"   Width: {width}px")
    print(f"   Height: {height}px")
    print(f"   Max Frames: {max_frames}")
    print(f"   Steps: {steps}")
    print(f"   CFG: {cfg}")
    print(f"   Seed: {seed}")
    
    # Submit job
    print("\n4. Submitting job...")
    start_time = time.time()
    
    try:
        job = endpoint.run(request_data)
        job_id = job.job_id
        print(f"   Job ID: {job_id}")
    except Exception as e:
        print(f"   Error submitting job: {e}")
        return False
    
    # Poll for status
    print("\n5. Waiting for completion...")
    last_status = None
    
    while True:
        try:
            status = job.status()
            
            if status != last_status:
                print(f"   Status: {status}")
                last_status = status
            
            if status in ["COMPLETED", "FAILED"]:
                break
            
            time.sleep(5)
            
        except Exception as e:
            print(f"   Error checking status: {e}")
            time.sleep(5)
    
    elapsed = time.time() - start_time
    
    # Get results
    print("\n6. Retrieving results...")
    
    try:
        result = job.output()
        
        if "error" in result:
            print(f"   ❌ Job failed: {result['error']}")
            return False
        
        if "outputs" not in result or len(result["outputs"]) == 0:
            print("   ❌ No outputs generated")
            return False
        
        # Save output video
        output = result["outputs"][0]
        video_b64 = output["video_base64"]
        
        print(f"   Output size: {len(video_b64)} chars")
        print(f"   Saving to: {output_path}")
        
        save_base64_file(video_b64, output_path)
        
        file_size = os.path.getsize(output_path)
        print(f"   Saved: {file_size / 1024 / 1024:.2f} MB")
        
    except Exception as e:
        print(f"   Error retrieving results: {e}")
        return False
    
    # Summary
    print("\n" + "=" * 60)
    print("✅ Test Successful!")
    print("=" * 60)
    print(f"Total Time: {elapsed:.1f} seconds")
    print(f"Output: {output_path}")
    print(f"File Size: {file_size / 1024 / 1024:.2f} MB")
    
    return True


def main():
    parser = argparse.ArgumentParser(
        description="Test WanVideo InfiniteTalk Serverless Endpoint"
    )
    
    parser.add_argument(
        "--endpoint-id",
        required=True,
        help="RunPod endpoint ID"
    )
    parser.add_argument(
        "--audio",
        required=True,
        help="Path to audio file (MP3/WAV)"
    )
    parser.add_argument(
        "--image",
        required=True,
        help="Path to portrait image"
    )
    parser.add_argument(
        "--output",
        default="output.mp4",
        help="Output video path (default: output.mp4)"
    )
    parser.add_argument(
        "--width",
        type=int,
        default=832,
        help="Video width (default: 832)"
    )
    parser.add_argument(
        "--height",
        type=int,
        default=480,
        help="Video height (default: 480)"
    )
    parser.add_argument(
        "--max-frames",
        type=int,
        default=100,
        help="Max frames to generate (default: 100)"
    )
    parser.add_argument(
        "--steps",
        type=int,
        default=4,
        help="Sampling steps (default: 4)"
    )
    parser.add_argument(
        "--cfg",
        type=float,
        default=2.0,
        help="CFG scale (default: 2.0)"
    )
    parser.add_argument(
        "--seed",
        type=int,
        default=42,
        help="Random seed (default: 42)"
    )
    parser.add_argument(
        "--api-key",
        help="RunPod API key (or set RUNPOD_API_KEY env var)"
    )
    
    args = parser.parse_args()
    
    # Set API key
    api_key = args.api_key or os.getenv("RUNPOD_API_KEY")
    if not api_key:
        print("Error: RunPod API key required")
        print("Provide via --api-key or RUNPOD_API_KEY environment variable")
        sys.exit(1)
    
    runpod.api_key = api_key
    
    # Run test
    success = test_endpoint(
        endpoint_id=args.endpoint_id,
        audio_path=args.audio,
        image_path=args.image,
        output_path=args.output,
        width=args.width,
        height=args.height,
        max_frames=args.max_frames,
        steps=args.steps,
        cfg=args.cfg,
        seed=args.seed
    )
    
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()

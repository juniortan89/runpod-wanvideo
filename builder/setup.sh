#!/bin/bash
set -e

echo "Setting up ComfyUI Custom Nodes..."

cd /app/ComfyUI/custom_nodes

# ComfyUI-WanVideoWrapper (Main node for WanVideo)
echo "Installing ComfyUI-WanVideoWrapper..."
git clone https://github.com/kijai/ComfyUI-WanVideoWrapper.git
cd ComfyUI-WanVideoWrapper
pip install --no-cache-dir -r requirements.txt
cd ..

# ComfyUI-MelBandRoFormer (Vocal separation)
echo "Installing ComfyUI-MelBandRoFormer..."
git clone https://github.com/kijai/ComfyUI-MelBandRoFormer.git
cd ComfyUI-MelBandRoFormer
pip install --no-cache-dir -r requirements.txt
cd ..

# ComfyUI-KJNodes (Utility nodes)
echo "Installing ComfyUI-KJNodes..."
git clone https://github.com/kijai/ComfyUI-KJNodes.git
cd ComfyUI-KJNodes
pip install --no-cache-dir -r requirements.txt
cd ..

# ComfyUI-VideoHelperSuite (Video handling)
echo "Installing ComfyUI-VideoHelperSuite..."
git clone https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git
cd ComfyUI-VideoHelperSuite
pip install --no-cache-dir -r requirements.txt
cd ..

# ComfyUI-Manager (Optional, for easier node management)
echo "Installing ComfyUI-Manager..."
git clone https://github.com/ltdrdata/ComfyUI-Manager.git

echo "Custom nodes installation complete!"

# Note: Models are downloaded in Dockerfile using comfy-cli
# This ensures they're baked into the image for faster cold starts

echo "Setup complete!"

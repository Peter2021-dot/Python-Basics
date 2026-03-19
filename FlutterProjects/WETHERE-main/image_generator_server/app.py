from flask import Flask, request, send_file
from flask_cors import CORS
import torch
import io
from PIL import Image
import torchvision.utils as vutils
from model import Generator
import os
import hashlib

app = Flask(__name__)
CORS(app)

# Load the model
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
model = Generator().to(device)

model_path = os.path.join("..", "assets", "models", "generator.pth")

if not os.path.exists(model_path):
    print(f"Warning: Model not found at {model_path}. Using random noise for demo.")
    # You might want to download or provide the model here.
else:
    try:
        # Try loading state dict
        model.load_state_dict(torch.load(model_path, map_location=device))
        print("Model loaded successfully!")
    except Exception as e:
        print(f"Error loading model state dict: {e}")
        print("Attempting to load entire model...")
        try:
             model = torch.load(model_path, map_location=device)
             print("Entire model loaded successfully!")
        except Exception as e2:
             print(f"Failed to load model: {e2}")

model.eval()

@app.route('/generate-image', methods=['POST'])
def generate_image():
    data = request.json
    title = data.get('title', 'Journey')
    print(f"Generating image for: {title}")

    # Use title hash as seed for reproducibility or just random
    seed = int(hashlib.sha256(title.encode('utf-8')).hexdigest(), 16) % (2**32)
    torch.manual_seed(seed)
    
    # Generate image
    noise = torch.randn(1, 100, device=device)
    with torch.no_grad():
        fake = model(noise).detach().cpu()
    
    # Post-process (convert from [-1, 1] to [0, 1])
    fake = (fake + 1) / 2
    
    # Convert to PIL Image
    ndarr = fake[0].permute(1, 2, 0).numpy()
    ndarr = (ndarr * 255).astype('uint8')
    img = Image.fromarray(ndarr)
    
    # Resize
    img = img.resize((400, 400), Image.LANCZOS)

    # Save locally to project folder (web-accessible static dir)
    storage_dir = os.path.join('static', 'journey_images')
    os.makedirs(storage_dir, exist_ok=True)
    
    filename = f"journey_{hashlib.md5(title.encode()).hexdigest()[:10]}.png"
    save_path = os.path.join(storage_dir, filename)
    img.save(save_path)
    
    # Relative path for the web
    web_path = f"static/journey_images/{filename}"
    print(f"Generated image saved locally: {web_path}")

    # Save to bytes for direct response
    img_byte_arr = io.BytesIO()
    img.save(img_byte_arr, format='PNG')
    img_byte_arr.seek(0)

    return send_file(img_byte_arr, mimetype='image/png')

@app.route('/upload-profile-image', methods=['POST'])
def upload_profile_image():
    try:
        if 'image' not in request.files:
            return {'error': 'No image provided'}, 400
        
        image = request.files['image']
        uid = request.form.get('uid', 'unknown')
        
        # Create profile_images directory inside static
        storage_dir = os.path.join('static', 'profile_images')
        os.makedirs(storage_dir, exist_ok=True)
        
        # Save image with uid as filename
        filename = f"{uid}_profile.jpg"
        save_path = os.path.join(storage_dir, filename)
        image.save(save_path)
        
        # Web accessible path
        web_path = f"static/profile_images/{filename}"
        print(f"Profile image saved locally for user: {uid} at {web_path}")
        
        return {
            'success': True, 
            'message': 'Image saved locally',
            'local_path': web_path
        }
    except Exception as e:
        print(f"Error saving profile image locally: {e}")
        return {'error': str(e)}, 500

from flask import send_from_directory

@app.route('/static/<path:path>')
def send_static(path):
    return send_from_directory('static', path)

if __name__ == '__main__':
    # Ensure base static dirs exist
    os.makedirs(os.path.join('static', 'journey_images'), exist_ok=True)
    os.makedirs(os.path.join('static', 'profile_images'), exist_ok=True)
    app.run(host='0.0.0.0', port=5000)

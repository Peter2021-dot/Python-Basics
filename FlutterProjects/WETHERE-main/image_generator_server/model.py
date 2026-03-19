import torch
import torch.nn as nn

# Constants based on your model description
latent_dim = 100
img_size = 64

class Generator(nn.Module):
    def __init__(self):
        super().__init__()

        # Linear layers approximate nonlinear mapping:
        # z ∈ R^100  →  x ∈ R^(3*64*64)
        self.model = nn.Sequential(
            nn.Linear(latent_dim, 256),
            nn.ReLU(),
            nn.Linear(256, 512),
            nn.ReLU(),
            nn.Linear(512, 3 * img_size * img_size),
            nn.Tanh()  # Outputs between [-1,1]
        )

    def forward(self, z):
        img = self.model(z)
        # Reshape to (batch_size, channels, height, width)
        return img.view(z.size(0), 3, img_size, img_size)

# Discriminator included for completeness/future training, 
# though not strictly needed for the generation server.
class Discriminator(nn.Module):
    def __init__(self):
        super().__init__()

        # Binary classifier:
        # x ∈ R^(3*64*64) → probability
        self.model = nn.Sequential(
            nn.Linear(3 * img_size * img_size, 512),
            nn.LeakyReLU(0.2),
            nn.Linear(512, 256),
            nn.LeakyReLU(0.2),
            nn.Linear(256, 1),
            nn.Sigmoid()  # Output in [0,1]
        )

    def forward(self, img):
        img_flat = img.view(img.size(0), -1)
        return self.model(img_flat)

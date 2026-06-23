import os
from PIL import Image, ImageDraw, ImageFilter

def make_squircle_mask(size, radius):
    mask = Image.new('L', size, 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, size[0], size[1]), radius=radius, fill=255)
    return mask

def generate_mac_icon(input_path, output_path):
    # Standard macOS icon sizes
    canvas_size = (1024, 1024)
    # macOS Big Sur squircle corner radius for 1024 is ~226
    corner_radius = 226
    
    # Load original image
    try:
        orig = Image.open(input_path).convert("RGBA")
    except Exception as e:
        print(f"Error loading image: {e}")
        return
        
    # Create the base transparent canvas
    final_icon = Image.new("RGBA", canvas_size, (0, 0, 0, 0))
    
    # Create a white background for the squircle
    bg = Image.new("RGBA", canvas_size, (255, 255, 255, 255))
    mask = make_squircle_mask(canvas_size, corner_radius)
    
    # Add a subtle drop shadow (standard for macOS)
    shadow = Image.new("RGBA", canvas_size, (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.rounded_rectangle((20, 40, 1004, 1024), radius=corner_radius, fill=(0, 0, 0, 60))
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=20))
    
    # Composite the shadow
    final_icon.paste(shadow, (0, 0), shadow)
    
    # We want the original image to have some padding so it's not cropped
    # Let's scale it down so it fits nicely inside the squircle
    target_content_size = (800, 800)
    orig.thumbnail(target_content_size, Image.Resampling.LANCZOS)
    
    # If the original image has a white background, it will blend perfectly
    # Calculate position to center it
    paste_x = (canvas_size[0] - orig.width) // 2
    paste_y = (canvas_size[1] - orig.height) // 2
    
    # Paste the original image onto the white background
    bg.paste(orig, (paste_x, paste_y), orig)
    
    # Now mask the white background with the squircle mask
    final_icon.paste(bg, (0, 0), mask)
    
    # Save the cleaned up png
    final_icon.save(output_path)
    print(f"Saved optimized icon to {output_path}")

input_img = "/Users/harshmishra/.gemini/antigravity-ide/brain/780a9aaf-8d93-4144-b308-1bcc1ad1e0b3/minimal_mac_icon_v2_1782199139517.png"
output_img = "clean_icon.png"

generate_mac_icon(input_img, output_img)

#!/usr/bin/env python3
"""
FLCMS Church Management App Icon Generator
"""

try:
    from PIL import Image, ImageDraw
    import math
    import os
except ImportError:
    print("Installing PIL...")
    import subprocess
    subprocess.check_call(['python', '-m', 'pip', 'install', 'Pillow'])
    from PIL import Image, ImageDraw
    import math
    import os

def create_church_icon(size=1024):
    """Create church management app icon"""
    
    # Create image
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Colors
    blue = (74, 144, 226)
    dark_blue = (46, 90, 165)
    white = (255, 255, 255)
    
    # Background circle
    center = size // 2
    radius = int(size * 0.45)
    
    # Gradient effect with multiple circles
    for i in range(radius, 0, -3):
        ratio = i / radius
        alpha = int(255 * (0.7 + 0.3 * ratio))
        color = blue if ratio > 0.5 else dark_blue
        draw.ellipse([center-i, center-i, center+i, center+i], 
                    fill=color + (alpha,))
    
    # White cross
    cross_size = int(size * 0.35)
    cross_thickness = int(cross_size * 0.15)
    
    # Vertical bar
    draw.rectangle([
        center - cross_thickness//2,
        center - cross_size//2,
        center + cross_thickness//2,
        center + cross_size//2
    ], fill=white)
    
    # Horizontal bar
    draw.rectangle([
        center - cross_size//2,
        center - cross_thickness//2,
        center + cross_size//2,
        center + cross_thickness//2
    ], fill=white)
    
    # Small management icons around cross
    icon_size = int(size * 0.05)
    distance = int(size * 0.28)
    
    # Document (top-right)
    doc_x = center + int(math.cos(-math.pi/4) * distance)
    doc_y = center + int(math.sin(-math.pi/4) * distance)
    draw.rectangle([
        doc_x - icon_size//2, doc_y - icon_size//2,
        doc_x + icon_size//2, doc_y + icon_size//2
    ], fill=(255, 255, 255, 180))
    
    # People (bottom-left)
    people_x = center + int(math.cos(3*math.pi/4) * distance)
    people_y = center + int(math.sin(3*math.pi/4) * distance)
    for i in range(3):
        px = people_x - icon_size//2 + i * icon_size//3
        draw.ellipse([
            px - icon_size//8, people_y - icon_size//8,
            px + icon_size//8, people_y + icon_size//8
        ], fill=(255, 255, 255, 180))
    
    return img

def main():
    print("Generating church management app icon...")
    
    # Generate main icon
    icon = create_church_icon(1024)
    icon.save('app_icon.png', 'PNG')
    print("✅ Generated app_icon.png")
    
    # Generate other sizes
    for size in [512, 256, 128]:
        smaller = icon.resize((size, size), Image.Resampling.LANCZOS)
        smaller.save(f'icon_{size}.png', 'PNG')
        print(f"✅ Generated icon_{size}.png")
    
    print("\n🎉 Church management app icons created!")
    print("📱 Main icon: app_icon.png")

if __name__ == "__main__":
    main() 
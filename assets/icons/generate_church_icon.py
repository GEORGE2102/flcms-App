#!/usr/bin/env python3
"""
FLCMS Church Management App Icon Generator
Generates a professional church management app icon with cross and management elements
"""

try:
    from PIL import Image, ImageDraw, ImageFilter
    import math
    import os
except ImportError:
    print("Installing required dependencies...")
    import subprocess
    subprocess.check_call(['python', '-m', 'pip', 'install', 'Pillow'])
    from PIL import Image, ImageDraw, ImageFilter
    import math
    import os

def create_church_management_icon(size=1024):
    """Create a church management app icon with cross and management elements"""
    
    # Create image with transparent background
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Scale factor
    scale = size / 1024
    
    # Define colors
    primary_blue = (74, 144, 226)  # #4A90E2
    secondary_blue = (53, 122, 189)  # #357ABD
    dark_blue = (46, 90, 165)  # #2E5AA5
    white = (255, 255, 255)
    
    # Background circle with gradient effect (simulate gradient with multiple circles)
    center = size // 2
    radius = int(size * 0.45)
    
    # Create gradient effect by drawing multiple circles
    for i in range(radius, 0, -2):
        # Interpolate color based on distance from center
        ratio = i / radius
        if ratio > 0.7:
            color = primary_blue
        elif ratio > 0.4:
            # Interpolate between primary and secondary
            t = (ratio - 0.4) / 0.3
            color = tuple(int(primary_blue[j] * t + secondary_blue[j] * (1-t)) for j in range(3))
        else:
            # Interpolate between secondary and dark
            t = ratio / 0.4
            color = tuple(int(secondary_blue[j] * t + dark_blue[j] * (1-t)) for j in range(3))
        
        # Add slight transparency for blend effect
        alpha = int(255 * (0.8 + 0.2 * (i / radius)))
        draw.ellipse([center-i, center-i, center+i, center+i], 
                    fill=color + (alpha,), outline=None)
    
    # Church Cross (main element)
    cross_size = int(size * 0.35)
    cross_thickness = int(cross_size * 0.15)
    
    # Add shadow effect for cross
    shadow_offset = int(3 * scale)
    shadow_color = (0, 0, 0, 100)
    
    # Shadow for vertical bar
    draw.rectangle([
        center - cross_thickness//2 + shadow_offset,
        center - cross_size//2 + shadow_offset,
        center + cross_thickness//2 + shadow_offset,
        center + cross_size//2 + shadow_offset
    ], fill=shadow_color)
    
    # Shadow for horizontal bar
    draw.rectangle([
        center - cross_size//2 + shadow_offset,
        center - cross_thickness//2 + shadow_offset,
        center + cross_size//2 + shadow_offset,
        center + cross_thickness//2 + shadow_offset
    ], fill=shadow_color)
    
    # White cross
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
    
    # Management elements around the cross
    icon_size = int(size * 0.06)
    element_radius = int(size * 0.32)
    
    # Document icon (top-right) - 45 degrees
    doc_x = center + int(math.cos(-math.pi/4) * element_radius)
    doc_y = center + int(math.sin(-math.pi/4) * element_radius)
    
    # Document shape
    draw.rectangle([
        doc_x - icon_size//2,
        doc_y - icon_size//2,
        doc_x + icon_size//2,
        doc_y + icon_size//2 + int(icon_size * 0.2)
    ], fill=(255, 255, 255, 200))
    
    # Document lines
    line_color = (74, 144, 226, 200)
    line_height = int(icon_size * 0.08)
    for i in range(3):
        draw.rectangle([
            doc_x - icon_size//3,
            doc_y - icon_size//4 + i * line_height * 2,
            doc_x + icon_size//3,
            doc_y - icon_size//4 + i * line_height * 2 + line_height
        ], fill=line_color)
    
    # People icon (bottom-left) - 135 degrees
    people_x = center + int(math.cos(3*math.pi/4) * element_radius)
    people_y = center + int(math.sin(3*math.pi/4) * element_radius)
    
    # Three people circles
    circle_radius = int(icon_size * 0.12)
    for i in range(3):
        px = people_x - icon_size//3 + i * icon_size//3
        py = people_y
        draw.ellipse([
            px - circle_radius, py - circle_radius,
            px + circle_radius, py + circle_radius
        ], fill=(255, 255, 255, 200))
    
    # Calendar icon (top-left) - 225 degrees
    cal_x = center + int(math.cos(-3*math.pi/4) * element_radius)
    cal_y = center + int(math.sin(-3*math.pi/4) * element_radius)
    
    # Calendar base
    draw.rectangle([
        cal_x - icon_size//2,
        cal_y - icon_size//2,
        cal_x + icon_size//2,
        cal_y + icon_size//2
    ], fill=(255, 255, 255, 200))
    
    # Calendar grid
    grid_size = icon_size // 6
    for i in range(2):
        for j in range(2):
            draw.rectangle([
                cal_x - icon_size//4 + i * icon_size//3,
                cal_y - icon_size//4 + j * icon_size//3,
                cal_x - icon_size//4 + i * icon_size//3 + grid_size,
                cal_y - icon_size//4 + j * icon_size//3 + grid_size
            ], fill=line_color)
    
    # Chart icon (bottom-right) - 45 degrees
    chart_x = center + int(math.cos(math.pi/4) * element_radius)
    chart_y = center + int(math.sin(math.pi/4) * element_radius)
    
    # Chart bars
    bar_heights = [int(icon_size*0.3), int(icon_size*0.5), int(icon_size*0.2)]
    bar_width = icon_size // 4
    for i, height in enumerate(bar_heights):
        draw.rectangle([
            chart_x - icon_size//2 + i * icon_size//3,
            chart_y - height//2,
            chart_x - icon_size//2 + i * icon_size//3 + bar_width,
            chart_y + height//2
        ], fill=(255, 255, 255, 200))
    
    return img

def main():
    """Generate church management app icons in multiple sizes"""
    
    print("🏛️ Generating FLCMS Church Management App Icons...")
    
    # Sizes to generate
    sizes = {
        'app_icon.png': 1024,
        'icon_512.png': 512,
        'icon_256.png': 256,
        'icon_128.png': 128,
        'icon_64.png': 64,
        'icon_32.png': 32
    }
    
    # Generate icons
    for filename, size in sizes.items():
        print(f"  📱 Generating {filename} ({size}x{size})")
        
        # Create icon
        icon = create_church_management_icon(size)
        
        # Save icon
        icon.save(filename, 'PNG', optimize=True)
        
        print(f"     ✅ Saved {filename}")
    
    print("\n🎉 Church management app icons generated successfully!")
    print("\n📋 Generated files:")
    for filename in sizes.keys():
        if os.path.exists(filename):
            file_size = os.path.getsize(filename)
            print(f"  - {filename} ({file_size:,} bytes)")
    
    print("\n📱 Main app icon: app_icon.png")
    print("🔧 Run 'flutter pub get && flutter pub run flutter_launcher_icons:main' to update your app icons")

if __name__ == "__main__":
    main() 
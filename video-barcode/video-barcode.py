#!/usr/bin/env python3

import os
import sys
import argparse
from datetime import timedelta
import cv2
import numpy as np
from PIL import Image, ImageDraw
from collections import Counter

def extract_frames(video_path, interval_seconds, start_time=0, end_time=None):
    """
    Extract frames from a video at specified time intervals
    
    Args:
        video_path: Path to the video file
        interval_seconds: Interval between frames in seconds
        start_time: Starting time in seconds
        end_time: Ending time in seconds or None for end of video
        
    Returns:
        List of extracted frames as numpy arrays
    """
    print(f"Opening video: {video_path}")
    video = cv2.VideoCapture(video_path)
    
    if not video.isOpened():
        raise ValueError(f"Could not open video file: {video_path}")
    
    # Get video properties
    fps = video.get(cv2.CAP_PROP_FPS)
    total_frames = int(video.get(cv2.CAP_PROP_FRAME_COUNT))
    duration = total_frames / fps
    
    if end_time is None:
        end_time = duration
    
    print(f"Video duration: {timedelta(seconds=duration)}")
    print(f"Extracting frames from {timedelta(seconds=start_time)} to {timedelta(seconds=end_time)}")
    print(f"Frame interval: {interval_seconds} seconds")
    
    frames = []
    
    current_time = start_time
    while current_time <= end_time:
        # Set video to the specific time
        frame_position = int(current_time * fps)
        video.set(cv2.CAP_PROP_POS_FRAMES, frame_position)
        
        # Read the frame
        success, frame = video.read()
        if not success:
            break
        
        # Convert from BGR to RGB
        frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        frames.append(frame_rgb)
        
        current_time += interval_seconds
    
    video.release()
    print(f"Extracted {len(frames)} frames")
    return frames

def get_dominant_color(image, num_colors=1):
    """
    Extract the dominant color from an image
    
    Args:
        image: PIL Image or numpy array
        num_colors: Number of dominant colors to return
        
    Returns:
        List of (r, g, b) tuples representing dominant colors
    """
    # Convert to PIL Image if numpy array
    if isinstance(image, np.ndarray):
        image = Image.fromarray(image)
    
    # Resize image to speed up processing
    image = image.resize((100, 100))
    
    # Convert to RGB mode if not already
    image = image.convert('RGB')
    
    # Get pixels and count occurrences
    pixels = image.getdata()
    color_counts = Counter(pixels)
    
    # Get the most common colors
    dominant_colors = color_counts.most_common(num_colors)
    return [color for color, count in dominant_colors]

def create_color_barcode(colors, bar_width, height, output_path):
    """
    Create a barcode image from a list of colors
    
    Args:
        colors: List of (r, g, b) colors
        bar_width: Width of each bar in pixels
        height: Height of the barcode
        output_path: Path to save the result
    """
    width = len(colors) * bar_width
    barcode = Image.new('RGB', (width, height))
    draw = ImageDraw.Draw(barcode)
    
    x_pos = 0
    for color in colors:
        draw.rectangle([x_pos, 0, x_pos + bar_width, height], fill=color)
        x_pos += bar_width
    
    # Save as JPEG
    barcode.save(output_path, "JPEG", quality=95)
    print(f"Barcode saved to {output_path}")
    return barcode

def create_image_barcode(frames, bar_width, height, output_path):
    """
    Create a barcode using compressed frames as bars
    
    Args:
        frames: List of frames as numpy arrays
        bar_width: Width of each bar in pixels
        height: Height of the barcode
        output_path: Path to save the result
    """
    width = len(frames) * bar_width
    barcode = Image.new('RGB', (width, height))
    
    x_pos = 0
    for frame in frames:
        # Convert numpy array to PIL Image if needed
        if isinstance(frame, np.ndarray):
            frame_img = Image.fromarray(frame)
        else:
            frame_img = frame
        
        # Resize the frame to fit the bar dimensions
        frame_img = frame_img.resize((bar_width, height), Image.LANCZOS)
        
        # Paste into the barcode
        barcode.paste(frame_img, (x_pos, 0))
        x_pos += bar_width
    
    # Save as JPEG
    barcode.save(output_path, "JPEG", quality=95)
    print(f"Barcode saved to {output_path}")
    return barcode

def main():
    help_text = """
EXAMPLES:

IMAGE MODE (Recommended for visual barcodes)
Generate a barcode where each bar is a slice of the actual video frame.
This preserves more detail and gives the classic "slit-scan" look.
Usage:
  %(prog)s video.mov -i 15 -m image -o barcode.jpg

COLOR MODE (Dominant colors)
Generate a barcode where each bar represents the dominant color of the frame.
This creates a more abstract color palette of the video.
Usage:
  %(prog)s video.mp4 -i 1 -m color -o color_barcode.jpg

KEY OPTIONS EXPLAINED:
  -i, --interval: Seconds between each captured frame.
       * For Image Mode on features/long videos: Try 10-20 seconds (e.g. -i 16).
       * For Color Mode or short clips: Try 1-2 seconds (e.g. -i 1).
  
  -m, --mode:
       * image: Slices a vertical strip from each frame (Visual texture).
       * color: Calculates the average/dominant color of the frame (Abstract).
"""
    parser = argparse.ArgumentParser(
        description='Create a color barcode from a video file.',
        epilog=help_text,
        formatter_class=argparse.RawTextHelpFormatter
    )
    parser.add_argument('video_path', type=str, help='Path to the video file')
    parser.add_argument('-o', '--output', type=str, default='barcode.jpg',
                        help='Output filename (default: barcode.jpg)')
    parser.add_argument('-i', '--interval', type=float, default=1.0,
                        help='Interval between frames in seconds (default: 1.0)')
    parser.add_argument('-s', '--start', type=float, default=0.0,
                        help='Start time in seconds (default: 0.0)')
    parser.add_argument('-e', '--end', type=float, default=None,
                        help='End time in seconds (default: end of video)')
    parser.add_argument('-b', '--bar-width', type=int, default=5,
                        help='Width of each bar in pixels (default: 5)')
    parser.add_argument('-ht', '--height', type=int, default=800,
                        help='Height of the barcode in pixels (default: 800)')
    parser.add_argument('-m', '--mode', type=str, choices=['color', 'image'], default='color',
                        help='Barcode mode: dominant color or image (default: color)')
    
    args = parser.parse_args()
    
    try:
        # Extract frames from the video
        frames = extract_frames(
            args.video_path,
            args.interval,
            args.start,
            args.end
        )
        
        if not frames:
            print("No frames extracted. Check video file and parameters.")
            return
        
        if args.mode == 'color':
            # Get dominant color for each frame
            print("Extracting dominant colors...")
            colors = [get_dominant_color(frame)[0] for frame in frames]
            
            # Create color barcode
            create_color_barcode(colors, args.bar_width, args.height, args.output)
        else:
            # Create image barcode
            print("Creating image barcode...")
            create_image_barcode(frames, args.bar_width, args.height, args.output)
            
        print(f"Successfully created barcode with {len(frames)} bars")
            
    except Exception as e:
        print(f"Error: {e}")
        return

if __name__ == "__main__":
    main()

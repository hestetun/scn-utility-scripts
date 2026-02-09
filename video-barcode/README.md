# Video Barcode Generator

This project generates video barcodes (slit-scan style images) or color dominant bars from video files.

## Prerequisites

This project uses [uv](https://github.com/astral-sh/uv) for dependency management and execution.

1. Install `uv`:
   ```bash
   # On macOS/Linux
   curl -LsSf https://astral.sh/uv/install.sh | sh
   
   # On Windows
   powershell -c "irm https://astral.sh/uv/install.ps1 | iex"
   ```

## Installation

Clone the repository to your local machine.

```bash
git clone <repository_url>
cd video-barcode
```

The dependencies will be automatically installed when you first run the tool using `uv`.

## Usage

Run the script using `uv run`. You don't need to manually create virtual environments or install pip packages.

**Important:** You must calculate the dependencies by running the command from within the project directory.
```bash
cd video-barcode
```

### Basic Usage

```bash
uv run video-barcode-generator.py <video_path> [options]
```

### Options

- `video_path`: Path to the input video file (Required).
- `-i`, `--interval`: Interval between frames in seconds (Default: 1.0).
- `-m`, `--mode`: Output mode, either `image` or `color` (Default: `image`).
  - `image`: Creates a barcode where each bar is a slice of the frame.
  - `color`: Creates a barcode where each bar is the dominant color of the frame.
- `-o`, `--output`: Output image filename (Default: `output_barcode.jpg`).
- `--start`: Start time in seconds (Default: 0).
- `--end`: End time in seconds (Default: End of video).
- `--width`: Width of each bar in pixels (Default: 5).
- `--height`: Height of the output image (Default: 1000).

### Examples

**Generate a barcode using frame slices (Image Mode):**

```bash
uv run video-barcode.py /Volumes/zz_movie_inspiration/WeMadeThis/Ruffen_FTR-3_S_NO-NO_NO_71_2K_XX_20250916_SCN_SMPTE_VF/Ruffen_FTR-3_S_NO-NO_NO_71_2K_XX_20250916_SCN_SMPTE_VF.mp4 -i 16 -m image -o ruffen_16s_movie_barcode.jpg
```

**Generate a barcode using dominant colors (Color Mode):**

```bash
uv run video-barcode-generator.py /path/to/video.mp4 -i 1 -m color -o color_barcode.jpg
```video-barcode-generator.py`, `pyproject.toml`, and `uv.lock` are included).
2. Install `uv` on the target machine.
3. Open a terminal and `cd` into the folder.
4# Distribution

To run this on another machine:
1. Copy this folder (ensure `pyproject.toml` and `uv.lock` are included).
2. Install `uv` on the target machine.
3. Run the commands as shown above. `uv` will handle downloading the correct python version and dependencies.

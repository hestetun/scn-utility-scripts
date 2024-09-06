import xml.etree.ElementTree as ET
from PIL import ImageFont, ImageDraw, Image

# ANSI escape codes for color output
RED = '\033[91m'
RESET = '\033[0m'

def extract_text_from_xml_with_lines(xml_file):
    tree = ET.parse(xml_file)
    root = tree.getroot()
    text_content = []
    line_numbers = []

    def recurse_through_elements(element, current_line):
        if element.text:
            for char in element.text:
                text_content.append(char)
                line_numbers.append(current_line)
        for child in element:
            recurse_through_elements(child, current_line + 1)

    recurse_through_elements(root, 1)
    return text_content, line_numbers

def is_character_supported_by_font(char, font):
    # Create a small image to render the character
    image = Image.new("L", (20, 20), 0)
    draw = ImageDraw.Draw(image)
    draw.text((0, 0), char, font=font, fill=255)
    
    # Check if the image is still blank
    bbox = image.getbbox()
    return bbox is not None

def check_characters_in_font(xml_file, font_path, font_size):
    # Load font
    font = ImageFont.truetype(font_path, font_size)

    # Extract text from XML with line numbers
    text, lines = extract_text_from_xml_with_lines(xml_file)

    # Track unsupported characters by line
    line_unsupported_chars = {}
    for char, line in zip(text, lines):
        if not is_character_supported_by_font(char, font):
            if line not in line_unsupported_chars:
                line_unsupported_chars[line] = set()
            line_unsupported_chars[line].add(char)

    return line_unsupported_chars

def get_line_from_xml(xml_file, line_number):
    # Extract the whole XML content to find the specific line
    with open(xml_file, 'r', encoding='utf-8') as file:
        lines = file.readlines()
        if 0 < line_number <= len(lines):
            return lines[line_number - 1].strip()
    return "Line not found"

def print_highlighted_line(line_content, unsupported_chars):
    highlighted_line = ""
    for char in line_content:
        if char in unsupported_chars:
            highlighted_line += f"{RED}{char}{RESET}"
        else:
            highlighted_line += char
    print(highlighted_line)

# Hardcoded file paths and font size
xml_file = '/Users/oah/Downloads/Filemail.com files 8_13_2024 psqhweawkqpdlkb/subtitles/dci/Elskling_FTR-2_F_NO-NO_NO_51_2K_SPR_20240812_SCN_SMPTE_OV/e7f7fc83-e5cc-44e9-bf20-c6668a9c4312/e7f7fc83-e5cc-44e9-bf20-c6668a9c4312.xml'
font_path = '/Users/oah/Downloads/Filemail.com files 8_13_2024 psqhweawkqpdlkb/subtitles/dci/Elskling_FTR-2_F_NO-NO_NO_51_2K_SPR_20240812_SCN_SMPTE_OV/e7f7fc83-e5cc-44e9-bf20-c6668a9c4312/63322c33-fe56-4b79-aae0-7aba2e98ccf5.ttf'
font_size = 12

unsupported_chars_by_line = check_characters_in_font(xml_file, font_path, font_size)

if unsupported_chars_by_line:
    print("Unsupported characters found:")
    for line, chars in unsupported_chars_by_line.items():
        line_content = get_line_from_xml(xml_file, line)
        print(f"\nLine {line}:")
        print_highlighted_line(line_content, chars)
else:
    print("All characters are supported by the font.")
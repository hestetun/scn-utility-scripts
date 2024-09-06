import re
import csv

def replace_reel_names(input_file, output_file):
    with open(input_file, 'r') as file:
        lines = file.readlines()

    start_idx = 0
    for i, line in enumerate(lines):
        if line.strip() == 'Data':
            start_idx = i + 1
            break

    header_lines = lines[:start_idx]
    data_lines = lines[start_idx:]

    # Create a CSV reader to parse the data lines
    data_lines_csv = list(csv.reader(data_lines, delimiter='\t'))

    # Print header columns to diagnose the issue
    print("Headers:", data_lines_csv[0])

    try:
        file_path_index = data_lines_csv[0].index("File path")
        reel_name_index = data_lines_csv[0].index("Reel name")
    except ValueError as e:
        print("Error:", e)
        return

    def extract_file_base(path):
        return re.match(r'(.*)\.mxf', path).group(1)

    # Replace appropriate reel names
    for row in data_lines_csv[1:]:
        file_path = row[file_path_index].strip()
        if file_path.endswith('.mxf'):
            base_name = extract_file_base(file_path)
            row[reel_name_index] = base_name

    # Write back to the output file with the same structure
    with open(output_file, 'w') as file:
        for line in header_lines:
            file.write(line)
        writer = csv.writer(file, delimiter='\t', lineterminator='\n')
        writer.writerows(data_lines_csv)

# Usage
replace_reel_names('/Users/oah/Desktop/ale_fix/danceclub_sd01_240826_v001.ale', '/Users/oah/Desktop/ale_fix/danceclub_sd01_240826_v001_fix.ale')
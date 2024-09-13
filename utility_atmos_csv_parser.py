import csv
import sys
import os

def parse_csv(input_file, threshold):
    output_file = os.path.splitext(input_file)[0] + '_filtered.csv'
    
    with open(input_file, mode='r') as infile, open(output_file, mode='w', newline='') as outfile:
        reader = csv.reader(infile)
        writer = csv.writer(outfile)

        headers = []
        meta_info = []
        data_start = False

        # Read the meta information until we reach the actual table headers
        for row in reader:
            meta_trimmed = [col.strip() for col in row]
            meta_info.append(meta_trimmed)
            writer.writerow(row)
            
            if "True peak (dBTP)" in [col.strip() for col in row]:
                headers = row
                data_start = True
                break
        
        # Check if headers successfully found
        if not data_start:
            print("No headers found with 'True peak (dBTP)'. Exiting.")
            return

        # Process the data rows
        true_peak_idx = headers.index(" True peak (dBTP)")

        for row in reader:
            try:
                # Get the value from the True peak (dBTP) column
                true_peak_value = float(row[true_peak_idx].strip())

                if true_peak_value > threshold:
                    writer.writerow(row)
            except (ValueError, IndexError):
                continue

    print(f"CSV parsed based on {threshold} threshold")

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python parse_csv.py <input_file>, remember trailing backslash if space is present in filename")
        sys.exit(1)

    input_file = sys.argv[1]
    threshold = -2.3

    parse_csv(input_file, threshold)
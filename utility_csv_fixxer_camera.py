import pandas as pd
import subprocess
import os
import concurrent.futures
import traceback
from datetime import datetime

def get_camera_info(file_path):
    """Extract writing application from mediainfo output"""
    print(f"\nProcessing file: {file_path}")
    try:
        result = subprocess.run(['mediainfo', file_path], capture_output=True, text=True)
        lines = result.stdout.split('\n')
        for line in lines:
            if 'Writing application' in line:
                info = line.split(':')[-1].strip()
                print(f"Found camera info: {info}")
                return info
        print("No Writing application found in mediainfo output")
    except Exception as e:
        print(f"Error processing {file_path}: {e}")
    return None

def process_row(row):
    """Process a single row to update camera metadata"""
    try:
        full_path = os.path.join(row['Clip Directory'], row['File Name'])
        
        if os.path.exists(full_path):
            camera_info = get_camera_info(full_path)
            return camera_info if camera_info else row['Camera #']
        return row['Camera #']
    except Exception as e:
        print(f"Error processing row: {row['File Name']}")
        print(traceback.format_exc())
        return row['Camera #']

def update_camera_metadata(csv_path, max_workers=10):
    # Try different encodings
    encodings = ['utf-8', 'utf-16', 'utf-16le', 'utf-16be', 'latin1']
    
    for encoding in encodings:
        try:
            print(f"\nAttempting to read CSV with {encoding} encoding...")
            # Read the CSV with specific encoding
            df = pd.read_csv(csv_path, encoding=encoding)
            print(f"Successfully read CSV with {encoding} encoding")
            print(f"Found {len(df)} rows in CSV")
            break
        except UnicodeDecodeError:
            print(f"Failed with {encoding} encoding")
            if encoding == encodings[-1]:
                raise Exception("Failed to read CSV with any of the attempted encodings")
            continue
    
    print("\nStarting to process all rows...")
    print("Initial sample of data:")
    print(df[['Clip Directory', 'File Name', 'Camera #']].head())
    
    # Use concurrent processing for efficiency
    with concurrent.futures.ThreadPoolExecutor(max_workers=max_workers) as executor:
        total_rows = len(df)
        print(f"\nProcessing {total_rows} rows with {max_workers} workers...")
        df['Camera #'] = list(executor.map(process_row, df.to_dict('records')))
    
    print("\nProcessing complete!")
    print("Sample of results:")
    print(df[['Clip Directory', 'File Name', 'Camera #']].head())
    
    # Create timestamped filename for new CSV
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    output_path = f"{os.path.splitext(csv_path)[0]}_{timestamp}_updated.csv"
    
    # Save updated CSV
    df.to_csv(output_path, index=False)
    print(f"\nUpdated CSV saved to {output_path}")

# Example usage
csv_path = '/Users/oah/Desktop/facingwar_mm/facingwar_ftr_acescct_2160p25_base_wip001 385 Clips Metadata.csv'
update_camera_metadata(csv_path)
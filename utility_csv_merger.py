#!/usr/bin/env python3
"""
CSV Merger Utility

Merges metadata from one CSV file into another based on reel names.
Handles reel name normalization by removing everything after and including '.MXF'
"""

import pandas as pd
import os
import re
from datetime import datetime

def normalize_reel_name(reel_name):
    """
    Normalize reel name by removing everything after and including '.MXF'
    
    Example:
    A005C306_230614H4_CANON.MXF_004 -> A005C306_230614H4_CANON
    """
    if pd.isna(reel_name) or not isinstance(reel_name, str):
        return reel_name
    
    # Find the position of '.MXF' (case insensitive)
    match = re.search(r'\.mxf', reel_name, re.IGNORECASE)
    if match:
        return reel_name[:match.start()]
    
    return reel_name

def read_csv_with_encoding(csv_path):
    """Try different encodings to read the CSV file"""
    encodings = ['utf-16', 'utf-8', 'utf-16le', 'utf-16be', 'latin1']
    
    for encoding in encodings:
        try:
            print(f"Attempting to read {os.path.basename(csv_path)} with {encoding} encoding...")
            df = pd.read_csv(csv_path, encoding=encoding)
            print(f"Successfully read with {encoding} encoding - {len(df)} rows")
            return df
        except UnicodeDecodeError:
            print(f"Failed with {encoding} encoding")
            continue
        except Exception as e:
            print(f"Error with {encoding} encoding: {e}")
            continue
    
    raise Exception(f"Failed to read {csv_path} with any of the attempted encodings")

def merge_csv_metadata(source_csv, target_csv, output_csv=None):
    """
    Merge metadata from source CSV into target CSV based on normalized reel names
    
    Args:
        source_csv: Path to CSV containing metadata to be merged
        target_csv: Path to CSV that will receive the metadata
        output_csv: Optional path for output file (defaults to timestamped version)
    """
    
    print(f"Reading source CSV: {source_csv}")
    source_df = read_csv_with_encoding(source_csv)
    
    print(f"Reading target CSV: {target_csv}")
    target_df = read_csv_with_encoding(target_csv)
    
    print("\nSource CSV columns:", source_df.columns.tolist())
    print("Target CSV columns:", target_df.columns.tolist())
    
    # Check if both CSVs have 'Reel Name' column
    if 'Reel Name' not in source_df.columns:
        raise ValueError("Source CSV does not have 'Reel Name' column")
    if 'Reel Name' not in target_df.columns:
        raise ValueError("Target CSV does not have 'Reel Name' column")
    
    # Normalize reel names in both dataframes
    print("\nNormalizing reel names...")
    source_df['normalized_reel'] = source_df['Reel Name'].apply(normalize_reel_name)
    target_df['normalized_reel'] = target_df['Reel Name'].apply(normalize_reel_name)
    
    print("Sample normalized reel names from source:")
    print(source_df[['Reel Name', 'normalized_reel']].head())
    
    print("\nSample normalized reel names from target:")
    print(target_df[['Reel Name', 'normalized_reel']].head())
    
    # Find columns that exist in source but not in target (these will be merged)
    source_cols = set(source_df.columns)
    target_cols = set(target_df.columns)
    merge_cols = source_cols - target_cols - {'normalized_reel'}  # Exclude the helper column
    
    print(f"\nColumns to be merged from source: {list(merge_cols)}")
    
    if not merge_cols:
        print("No new columns to merge!")
        return target_df
    
    # Handle duplicate reel names by taking the first occurrence
    source_df_dedup = source_df.drop_duplicates(subset=['normalized_reel'], keep='first')
    
    # Create a lookup dictionary from source data
    source_lookup = source_df_dedup.set_index('normalized_reel')[list(merge_cols)].to_dict('index')
    
    # Report if there were duplicates
    duplicates = len(source_df) - len(source_df_dedup)
    if duplicates > 0:
        print(f"Found {duplicates} duplicate reel names in source, keeping first occurrence")
    
    # Add the new columns to target dataframe
    for col in merge_cols:
        target_df[col] = target_df['normalized_reel'].map(
            lambda x: source_lookup.get(x, {}).get(col, None)
        )
    
    # Remove the helper column
    target_df = target_df.drop('normalized_reel', axis=1)
    
    # Count matches
    matches = sum(1 for reel in target_df['Reel Name'].apply(normalize_reel_name) 
                  if reel in source_lookup)
    
    print(f"\nMerge complete!")
    print(f"Matched {matches} out of {len(target_df)} records")
    
    # Create output filename if not provided
    if output_csv is None:
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        base_name = os.path.splitext(target_csv)[0]
        output_csv = f"{base_name}_merged_{timestamp}.csv"
    
    # Save the merged CSV
    # Determine encoding by trying to read original target file encoding
    try:
        target_df.to_csv(output_csv, index=False, encoding='utf-16')
        print(f"Merged CSV saved to: {output_csv}")
    except Exception as e:
        # Fallback to utf-8
        print(f"Failed to save with utf-16, trying utf-8: {e}")
        output_csv_utf8 = output_csv.replace('.csv', '_utf8.csv')
        target_df.to_csv(output_csv_utf8, index=False, encoding='utf-8')
        print(f"Merged CSV saved to: {output_csv_utf8}")
    
    return target_df

def main():
    """Main function for testing"""
    source_csv = '/Users/oah/Desktop/facingwar_mm/facingwar_ftr_pl04_250131_acescct_709g24_2160p25_250214_grade_v018 400 Clips Metadata.csv'
    target_csv = '/Users/oah/Desktop/facingwar_mm/facingwar_e01_pl01_acescct_709g24_2160p25_250626_grade_v001 129 Clips Metadata.csv'
    
    try:
        merged_df = merge_csv_metadata(source_csv, target_csv)
        print("\nMerge operation completed successfully!")
        
        # Show sample of merged data
        print("\nSample of merged data:")
        print(merged_df.head())
        
    except Exception as e:
        print(f"Error during merge: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    main()
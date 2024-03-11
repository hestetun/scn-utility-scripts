#!/usr/bin/env python
from collections import OrderedDict
from itertools import dropwhile
from os import path, open
from timecode import Timecode
import csv
import argparse

## Based on simonwagner's ale2csv.py https://gist.github.com/simonwagner/0ca407314bea9862ce6b15903fdcca87

argparser = argparse.ArgumentParser()
argparser.add_argument("ale_file", metavar="ALE", type=argparse.FileType(mode="r"))
argparser.add_argument("csv_file", metavar="CSV", type=argparse.FileType(mode="w"), nargs="?", default=None)

def calculate_duration_and_frames(row):
    start_time = row.get('Start', 'N/A')
    end_time = row.get('End', 'N/A')
    fps = row.get('FPS', 'N/A')

    if start_time != 'N/A' and end_time != 'N/A' and fps != 'N/A':
        fps = float(fps)

        # Create Timecode objects for start and end times
        start_tc = Timecode(fps, start_time)
        end_tc = Timecode(fps, end_time)

        # Calculate duration and frames
        duration_tc = end_tc - start_tc + Timecode(fps, '00:00:00:00') # adds 1 frame to the duration and frames
        duration = str(duration_tc)
        frames = duration_tc.frame_number

        return duration, frames

    return 'N/A', 'N/A'

def main():
    args = argparser.parse_args()

    columns, data = convert_ale_to_dict(args.ale_file)
    args.ale_file.close()

    if args.csv_file is not None:
        csv_file = args.csv_file
    else:
        pre, ext = os.path.splitext(args.ale_file.name)
        csv_path = pre + ".csv"
        csv_file = open(csv_path, mode="wb")

    dump_csv(csv_file, columns, data)
    csv_file.close()


def convert_ale_to_dict(f):
    f_iter = iter(f)

    f_iter = dropwhile(lambda line: "Column" not in line.rstrip(), f_iter)
    column_line = next_or_none(f_iter)
    if column_line is None:
        raise Exception("No columns found")

    column_names_line = next_or_none(f_iter)
    if column_names_line is None:
        raise Exception("No values for columns")

    columns = column_names_line.replace("\n", "").split("\t")

    f_iter = dropwhile(lambda line: "Data" not in line.rstrip(), f_iter)
    data_line = next_or_none(f_iter)
    if data_line is None:
        raise Exception("No data found")

    data = []
    for data_values_line in f_iter:
        values = data_values_line.replace("\n", "").split("\t")
        values_dict = OrderedDict(zip(columns, values))

        data.append(values_dict)

    return (columns, data)


def dump_csv(f, columns, data):
    # Define the columns you want to keep in the order you want them
    columns_to_keep = ['Name', 'Start', 'End', 'Duration', 'Frames', 'Camera FPS', 'Camera Type', 'Sync Audio', 'Comments']

    # Filter the data to only include the columns you want to keep
    filtered_data = []
    for row in data:
        new_row = {col: row.get(col, 'N/A') for col in columns_to_keep}

        # Trim the 'Sync Audio' path
        if 'Sync Audio' in new_row and new_row['Sync Audio'] != 'N/A':
            path_parts = new_row['Sync Audio'].split('/')
            if 'AUDIO' in path_parts:
                index = path_parts.index('AUDIO') + 1  # increment index by 1 to exclude 'AUDIO' folder
                new_row['Sync Audio'] = '/'.join(path_parts[index:])

        # Calculate duration and frames
        new_row['Duration'], new_row['Frames'] = calculate_duration_and_frames(row)

        filtered_data.append(new_row)

    dw = csv.DictWriter(f, fieldnames=columns_to_keep)
    dw.writeheader()
    dw.writerows(filtered_data)


def next_or_none(iter):
    try:
        return next(iter)
    except StopIteration:
        return None

if __name__ == "__main__":
    main()
import os
import datetime
import subprocess

def get_directory_size(directory):
    total = 0
    try:
        for dirpath, dirnames, filenames in os.walk(directory):
            for f in filenames:
                fp = os.path.join(dirpath, f)
                if not os.path.islink(fp):
                    total += os.path.getsize(fp)
    except OSError as e:
        print(f"Error accessing {directory}: {e}")
    return total / (1024 ** 4)  # convert size to terabytes

# default volume
default_volume = "/Volumes/commercial_src"

# check if the default volume is mounted
if os.path.ismount(default_volume):
    try:
        # ask the user if they want to index the default volume
        index_default = input(f"commercial_src? (y/n): ")
    except EOFError:
        print("Input error: EOF detected")
        exit(1)
    
    if index_default.lower() == 'y':
        path_to_directories = default_volume
    else:
        try:
            # ask the user for another volume to index
            path_to_directories = input("Enter the volume to index: ")
        except EOFError:
            print("Input error: EOF detected")
            exit(1)
else:
    try:
        # ask the user for a volume to index
        path_to_directories = input("Enter the volume to index/size: ")
    except EOFError:
        print("Input error: User cancelled input")
        exit(1)

# get a list of all directories in the specified path
directories = [d for d in os.listdir(path_to_directories) if os.path.isdir(os.path.join(path_to_directories, d))]

# get the current date and time
now = datetime.datetime.now()

# approximate 6 months ago
six_months_ago = now - datetime.timedelta(days=180)

# initialize lists to hold directories
older_than_six_months = []
not_properly_formatted = []
within_six_months = []

# initialize total size
total_size = 0

# loop through directories
for directory in directories:
    try:
        # extract the date string from the directory name
        date_string = directory.split('_')[-1]
        
        # attempt to convert date string to date
        directory_date = datetime.datetime.strptime(date_string, "%y%m%d")
        
        # get the size of the directory in terabytes
        directory_size = get_directory_size(os.path.join(path_to_directories, directory))
        
        # add the size to the total size
        total_size += directory_size
        
        if directory_date < six_months_ago:
            older_than_six_months.append((directory, directory_size))
        elif directory_date >= six_months_ago:
            within_six_months.append((directory, directory_size))
    except ValueError:
        not_properly_formatted.append((directory, get_directory_size(os.path.join(path_to_directories, directory))))

# sort the lists
not_properly_formatted.sort(key=lambda x: x[0])
older_than_six_months.sort(key=lambda x: x[0])
within_six_months.sort(key=lambda x: x[0])

# print under headings
print("🤠🤠Projects Not Properly Formatted:🤠🤠")
for directory, size in not_properly_formatted:
    print(f"{directory}\n-> {round(size)}G")
print("")
print("🧨🧨Projects Older Than 6 Months:🧨🧨")
for directory, size in older_than_six_months:
    print(f"{directory}\n-> {round(size)}G")
print("")
print("🚀🚀Projects Within Last 6 Months:🚀🚀")
for directory, size in within_six_months:
    print(f"{directory}\n-> {round(size)}G")

print("")
print("Total size:")

# Run the df -h command
output = subprocess.check_output(['df', '-h'], universal_newlines=True)

# Split the output into lines
lines = output.split('\n')

# Get the first line (heading) and the line for the volume of interest
heading = lines[0]
volume_line = next((line for line in lines if path_to_directories in line), None)

# If the volume line was found, print the heading and the volume line
if volume_line:
    print(heading)
    print(volume_line)
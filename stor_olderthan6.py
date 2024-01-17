import os
import datetime

# prompt the user for the path to the directories
path_to_directories = input("Enter the path to the directories: ")

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

# loop through directories
for directory in directories:
    try:
        # extract the date string from the directory name
        date_string = directory.split('_')[-1]
        
        # attempt to convert date string to date
        directory_date = datetime.datetime.strptime(date_string, "%y%m%d")
        
        if directory_date < six_months_ago:
            older_than_six_months.append(directory)
        elif directory_date >= six_months_ago:
            within_six_months.append(directory)
    except ValueError:
        not_properly_formatted.append(directory)

# sort the lists
not_properly_formatted.sort()
older_than_six_months.sort()
within_six_months.sort()

# print under headings
print("\Projects Not Properly Formatted:")
for directory in not_properly_formatted:
    print(directory)  
print("\Projects Older Than 6 Months:")
for directory in older_than_six_months:
    print(directory)
print("\Projects Within Last 6 Months:")
for directory in within_six_months:
    print(directory)
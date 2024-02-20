from datetime import timedelta, datetime

# Function to add seconds to timecode
def add_seconds_to_timecode(time_string, seconds):
    # Parse the string into a datetime object
    time_object = datetime.strptime(time_string, '%H:%M:%S')
    
    # Add the timedelta of additional seconds
    new_time = time_object + timedelta(seconds=seconds)
    
    # Format back into a string with "frames" as zero (00) since frames are unspecified in input
    return new_time.strftime('%H:%M:%S:00')

# Input timecodes list
timecodes_list = [
    "1:00:42",
    "1:02:28",
    "1:02:58",
     # ... include all your other initial times here ...
]

# Number of seconds to add (5 in this case)
seconds_to_add = 5

# Adjusted timecodes list after adding 5 sec to each one.
adjusted_timecodes_list = [add_seconds_to_timecode(tc, seconds_to_add) for tc in timecodes_list]

print("TLC IN")
for adjusted_tc in adjusted_timecodes_list:
   print(adjusted_tc)

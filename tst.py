from timecode import Timecode

# Create two timecode objects with different frame rates
tc1 = Timecode('29.97', '00:00:00:00')
tc2 = Timecode('24', '00:00:00:10')

# Add the two timecodes
tc3 = tc1 + tc2

# Assertions to verify the results
assert tc3.framerate == '29.97'
assert tc3.frames == 12
assert str(tc3) == '00:00:00;11'

print(f"Timecode addition result: {tc3}")
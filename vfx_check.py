import os
import subprocess

def process_exr(exrfile):
    output = subprocess.getoutput(f'exrinfo -v -a {exrfile}')
    if "(EXR_ERR" in output:
        return f"Error processing '{exrfile}': {output}"
    else:
        lines = output.split('\n')
        return "\n".join([line for line in lines if 'compression' in line or 'channels' in line or 'displayWindow' in line])

dir = input("Enter a directory: ")
errors = ""

for root, dirs, files in os.walk(dir):
    for file in files:
        if file.endswith(".exr"):
            result = process_exr(os.path.join(root, file))
            if "Error processing" in result:
                errors += result + "\n"
            else:
                print(result)

if errors:
    print("\nErrors occurred while processing EXR files:\n", errors)
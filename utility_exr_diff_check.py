import os
import subprocess

# Directory containing EXR files
directory = "/Volumes/scn_ftr_05/scn_ftr_05/troll2/ftr/tmp/20250218_oah_tst/art"

# Output report file
report_file = "/Users/oah/Downloads/exr_metadata_report.txt"

# Temporary file to store metadata
temp_file = "temp_metadata.txt"

# Reference metadata file
reference_metadata_file = os.path.join(directory, "first_file_metadata.txt")

# Get a list of all EXR files in the directory
exr_files = [f for f in os.listdir(directory) if f.endswith('.exr')]

# Open the report file for writing
with open(report_file, 'w') as report:
    for exr_file in exr_files:
        file_path = os.path.join(directory, exr_file)
        report.write(f"Checking {exr_file}...\n")
        print(f"Checking {exr_file}...")

        # Extract metadata using exrheader
        with open(temp_file, 'w') as f:
            subprocess.run(['exrheader', file_path], stdout=f)

        # Compare with the first file's metadata
        if not os.path.exists(reference_metadata_file):
            # Save the first file's metadata
            with open(temp_file, 'r') as f:
                reference_metadata = f.read()
            with open(reference_metadata_file, 'w') as f:
                f.write(reference_metadata)
            report.write(f"Metadata from {exr_file} saved as reference.\n")
            print(f"Metadata from {exr_file} saved as reference.")
        else:
            # Compare with the reference metadata
            with open(temp_file, 'r') as f:
                current_metadata = f.read()
            with open(reference_metadata_file, 'r') as f:
                reference_metadata = f.read()

            if current_metadata != reference_metadata:
                report.write(f"Metadata in {exr_file} differs from the reference.\n")
                report.write("Differences:\n")

                # Generate a unified diff of the metadata
                diff_output = subprocess.run(
                    ['diff', '-u', reference_metadata_file, temp_file],
                    capture_output=True, text=True
                )
                report.write(diff_output.stdout)
                report.write("\n")

                print(f"Metadata in {exr_file} differs from the reference.")
            else:
                report.write(f"Metadata in {exr_file} matches the reference.\n")
                print(f"Metadata in {exr_file} matches the reference.")

# Clean up
if os.path.exists(temp_file):
    os.remove(temp_file)

print(f"Report saved to {report_file}")
import os
import glob
import DaVinciResolveScript as dvr_script

source_folder = '/Volumes/lapalma_src/_src/'
resolve = dvr_script.scriptapp('Resolve')
print("Successfully accessed Resolve")  # <-- New line here

project_manager = resolve.GetProjectManager()
current_project = project_manager.GetCurrentProject()

# Get the MediaPool.
media_pool = current_project.GetMediaPool()

# Get MediaStorage API object
media_storage = resolve.GetMediaStorage()

file_list=[] 

for day_dir in glob.glob(os.path.join(source_folder, 'DAY_*')):
    ocn_dir_path = os.path.join(day_dir, '01_OCN')
    if os.path.exists(ocn_dir_path):
        # Add items in the 01_OCN directory to a list.
        for file_name in os.listdir(ocn_dir_path):
            full_file_name=os.path.join(ocn_dir_path,file_name)
            file_list.append(full_file_name)
            print(f"File added: {full_file_name}")  # <-- New line here

print("All files added. Importing into Media Pool...")  # <-- New line here

# Add list of files to media pool all at once            
media_storage.AddItemsToMediaPool(file_list)

print("All files imported successfully!")   # <-- New line here
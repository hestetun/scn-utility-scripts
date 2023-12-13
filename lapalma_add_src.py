import os
import glob
import DaVinciResolveScript as dvr_script

source_folder = '/Volumes/lapalma_src/_src/'
resolve = dvr_script.scriptapp('Resolve')
project_manager = resolve.GetProjectManager()
current_project = project_manager.GetCurrentProject()

# Get the MediaPool.
media_pool = current_project.GetMediaPool()

# Get MediaStorage API object
media_storage = resolve.GetMediaStorage()

for day_dir in glob.glob(os.path.join(source_folder, 'DAY_*')):
    ocn_dir_path = os.path.join(day_dir, '01_OCN')
    if os.path.exists(ocn_dir_path):
        # Add items in the 01_OCN directory to the media pool.
        for file_name in os.listdir(ocn_dir_path):
            full_file_name=os.path.join(ocn_dir_path,file_name)
            media_storage.AddItemsToMediaPool(full_file_name)

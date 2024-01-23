#!/usr/bin/env python3

"""
This file serves to return a DaVinci Resolve object
"""

import sys
import os

def GetResolve():
    if sys.platform.startswith("darwin"):
        expectedPath="/Library/Application Support/Blackmagic Design/DaVinci Resolve/Developer/Scripting/Modules/"
    elif sys.platform.startswith("win") or sys.platform.startswith("cygwin"):
        expectedPath=os.getenv('PROGRAMDATA') + "\\Blackmagic Design\\DaVinci Resolve\\Support\\Developer\\Scripting\\Modules\\"
    elif sys.platform.startswith("linux"):
        expectedPath="/opt/resolve/libs/Fusion/Modules/"

    try:
        # The PYTHONPATH needs to be set correctly for this import statement to work.
        # An alternative is to import the DaVinciResolveScript by specifying absolute path (see ExceptionHandler logic)
        import DaVinciResolveScript as bmd
    except ImportError:
        
         # check if the default path has it...
         print("Unable to find module DaVinciResolveScript from $PYTHONPATH - trying default locations")

         try:
             import importlib.util
             spec = importlib.util.spec_from_file_location("DaVinciResolveScript", expectedPath+"DaVinciResolveScript.py")
             bmd = importlib.util.module_from_spec(spec)
             spec.loader.exec_module(bmd)
         except ImportError:
            print(f"Unable to find module Da Vinci Resolve Script - please ensure that the module is discoverable by Python")
            print(f"For a default installation, the module is expected at: {expectedPath}")
            sys.exit()

    return bmd.scriptapp('Resolve')
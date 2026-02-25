# distutils: language = c++
# distutils: extra_compile_args = ["-std=c++11", "-O3"]

import json
import re
import os
import sys
from libc.stdio cimport printf

# Import the optimized parser from the previous module
# Ensure idd_parser is compiled and in the python path
from idd_parser import parseIDDClassString

# ———————————————————————————————————————————————————————————————————————————
# Configuration & Patterns
# ———————————————————————————————————————————————————————————————————————————

# Regex for stripping comments: Matches '!' ... 'newline'
# TS: /!.+(?:\r\n|\r|\n)/g
# Note: This removes the newline character as well, effectively merging lines
# if the comment was at the end of a line, which matches the TS logic.
cdef object RE_COMMENTS = re.compile(r'!.+(?:\r\n|\r|\n)')

# Regex for finding Class Blocks
# TS: /[^\s,]+,(?:\r\n|\r|\n)(?: *\\.*(?:\r\n|\r|\n))+(?: *[^\s,]+ *[,;](?: *\\.*(?:\r\n|\r|\n))+)+/g
# We use Python's re module with VERBOSE flag for readability, though the pattern is strictly matched.
cdef object RE_CLASS_BLOCK = re.compile(
    r'[^\s,]+,(?:\r\n|\r|\n)(?: *\\.*(?:\r\n|\r|\n))+(?: *[^\s,]+ *[,;](?: *\\.*(?:\r\n|\r|\n))+)+',
    re.MULTILINE
)

# ———————————————————————————————————————————————————————————————————————————
# Helper Functions
# ———————————————————————————————————————————————————————————————————————————

def export_idd_to_ts_js(str version_code, dict idd, str file_path, bint mini=False):
    """
    Exports the processed IDD dictionary to a JS/TS file.
    """
    try:
        # Serialize to JSON
        if mini:
            json_string = json.dumps(idd, separators=(',', ':'))
        else:
            json_string = json.dumps(idd, indent=2)

        # Create output string
        # Using String.raw equivalent logic
        output_string = f"export const iddVersion = '{version_code}';\n"
        output_string += f"export const iddString = String.raw`{json_string}`"

        # Ensure directory exists
        directory = os.path.dirname(file_path)
        if directory and not os.path.exists(directory):
            os.makedirs(directory)

        # Write file
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(output_string)

        print(f"Successfully exported data to {file_path}")

    except Exception as e:
        print(f"Error writing file: {e}")

# ———————————————————————————————————————————————————————————————————————————
# Core Logic
# ———————————————————————————————————————————————————————————————————————————

def preprocess_idd(str version_code, bint test=False):
    """
    Reads .idd file, removes comments, parses classes, and exports result.
    """
    # 1. Define Paths
    # Adjust input path as needed relative to where you run the script
    cdef str file_path = f"./src/idds-preprocess/idds/V{version_code}-0-Energy+.idd"
    cdef str idd_string = ""

    # 2. Read File
    try:
        with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
            idd_string = f.read()
    except IOError:
        raise RuntimeError(f"Error reading the file '{file_path}'")

    # 3. Remove Comments
    # Replicating TS: iddString.replace(/!.+(?:\r\n|\r|\n)/g, '');
    # Note: re.sub is slightly slower than string replace, but necessary for patterns
    idd_string = RE_COMMENTS.sub('', idd_string)

    # 4. Parse Classes
    cdef dict idd = {}
    cdef list matches = RE_CLASS_BLOCK.findall(idd_string)
    cdef str class_string
    cdef dict class_prop
    cdef str class_key

    # Iterate over every regex match (Raw Class String)
    for class_string in matches:
        # Use the optimized C++ parser
        # verbose=True passes 'true' to the logic (though logic uses bool)
        class_prop = parseIDDClassString(class_string, True)

        # Convert class name to lowercase key
        class_key = class_prop['className'].lower()

        # Store in dictionary
        idd[class_key] = class_prop

    # 5. Export
    if not test:
        # .js export
        out_path = f"./idds/v{version_code}-idd.js"
        export_idd_to_ts_js(version_code, idd, out_path, True)
    else:
        # Test export
        out_path = f"./src/idds-preprocess/test-v{version_code}-idd.ts"
        export_idd_to_ts_js(version_code, idd, out_path, False)

# ———————————————————————————————————————————————————————————————————————————
# Batch Runner
# ———————————————————————————————————————————————————————————————————————————

def run_preprocess():
    """
    Main entry point to run the batch processing for all versions.
    """
    cdef list version_list = [
        '8-9', '9-0', '9-1', '9-2', '9-3', '9-4', '9-5', '9-6',
        '22-1', '22-2', '23-1', '23-2', '24-1', '24-2', '25-1'
    ]

    for version_code in version_list:
        print(f"—— {version_code} ——————")
        preprocess_idd(version_code)
        print()

# Allow running directly if executed as a script (via python -m)
if __name__ == "__main__":
    run_preprocess()

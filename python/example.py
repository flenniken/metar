
# Example python code showing how to use the metar library.

import os
import sys

# This block of code is only needed when you want to run the
# development version of metar.  It adds the development version of
# the metar module (metar.so) to the path so it can be imported.
if sys.platform.startswith('linux'):
  dir_name = 'linux'
elif 'darwin' == sys.platform:
  dir_name = 'mac'
else:
  print "unsupported development platform: %s" % sys.platform
  exit(1)
absolute_path = os.path.abspath(__file__)
parent_dir = os.path.dirname(os.path.dirname(absolute_path))
path = os.path.join(parent_dir, "bin", dir_name)
assert(os.path.exists(os.path.join(path, "metar.so")))
sys.path.insert(0, path)


import metar
import json

# Print the metar version number.
print("The metar version number = %s" % metar.get_version())

# Show help on the metar module.
# help(metar)
# todo: why is NimPyException exported and showing in the help output?

# Read metadata from image.jpg and return it as a JSON string.
filename = "testfiles/IMG_6093.JPG"
if not os.path.exists(filename):
  print("Error: the test file is missing.")
  exit(1)
string = metar.read_metadata_json(filename)
if string == '':
  print("Error: unable to read the test file.")
  exit(1)

# Convert the json string to a python dictionary.
metadata = json.loads(string)

# Print the section keys.
for key in sorted(metadata.keys()):
  print("%s" % key)

# Display the image width and height.
image = metadata['image']
print("width = %s" % image['width'])
print("height = %s" % image['height'])



# Example python code showing how to use the metar library.

import os
import sys
import metar
import json

# Print the metar version number.
print("The metar version number = %s" % metar.get_version())

# Show help on the metar module.
# help(metar)
# todo: why is NimPyException exported and showing in the help output?

# Read metadata from image.jpg and return it as a JSON string.
filename = "testfiles/image.jpg"
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
print("Section keys:")
for key in sorted(metadata.keys()):
  print("%s" % key)

# Display the image width and height.
image = metadata['image']
print()
print("width = %s" % image['width'])
print("height = %s" % image['height'])


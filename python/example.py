
# Example python code showing how to use the metar library.

import os
import sys

# This block of code is only needed when you want to run the
# development version of metar.  It adds the metar module (metar.so)
# to the path so it can be imported.
absolute_path = os.path.abspath(__file__)
parent_dir = os.path.dirname(os.path.dirname(absolute_path))
path = os.path.join(parent_dir, "bin")
assert(os.path.exists(os.path.join(path, "metar.so")))
sys.path.insert(0, path)

import metar
import json

# Get the metar version number.
print("The metar version number = %s" % metar.get_version())

# Show help on the metar module.
# print('\n')
# help(metar)
# print('\n')

# Read image.jpg and return its metadata as a JSON string.
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

for key in metadata.keys():
  print("  %s" % key)
  section = metadata['key']
  for section_key in section.keys():
    print("  %s" % section_key)

exit(0)

# Display the image width and height.
image = metadata['image']
print(image)
print('The width and height == (%s, %s)' % (
  image['width'], image['height']))

# Show the keys of the metadata dictionary.
print("Metadata dictionary keys:")
print(metadata.keys())
print('\n')

# Read the metadata and return a human readable string.
data = metar.read_metadata(filename)
# print(data)

# print()
# print("JSON:")
# print()

# print(string)
# print()

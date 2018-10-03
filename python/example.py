
# Example python code showing how to use the metar library.
# Run it like:
# cd metar
# python python/example.py

import os
import sys

# The block of code is only needed when you want to run the
# development version of metar.  Add metar bin folder containing the
# metar.so file to the path so it is imported.
absolute_path = os.path.abspath(__file__)
parent_dir = os.path.dirname(os.path.dirname(absolute_path))
path = os.path.join(parent_dir, "bin")
assert(os.path.exists(os.path.join(path, "metar.so")))
sys.path.insert(0, path)

import metar
import json
from collections import OrderedDict

# Get the metar version number.
print("The metar version number = %s" % metar.get_version())

# Show help on the metar module.
print('\n')
# help(metar)
print('\n')

# Read image.jpg and return its metadata as a JSON string.
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

# Display the image width and height.
image_section = metadata['image']
print('The image.jpg width and height == (%s, %s)' % (
  image_section['width'], image_section['height']))

# Show the keys of the metadata dictionary.
print("Metadata dictionary keys:")
print(metadata.keys())
print('\n')

# Read the metadata and return a human readable string.
data = metar.read_metadata("testfiles/image.jpg")
print(data)

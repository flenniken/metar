
# Example python code showing how to use the metar library.
# Run it like:
# cd metar
# python python/example.py

import sys
sys.path.append("bin")
import metar
import json
from collections import OrderedDict

# Get the metar version number.
print("The metar version number = %s" % metar.get_version())

# Show help on the metar module.
# print('\n')
# help(metar)
# print('\n')

# Read image.jpg and return its metadata as a JSON string.
string = metar.read_metadata_json("testfiles/image.jpg")
if string == '':
  print("Error: unable to read the image.jpg file")
  exit(1)

metadata = json.loads(string, object_pairs_hook=OrderedDict)
# print json.dumps(metadata)
for k, v in metadata.items():
  print "%s = %s" % (k,v)
print

# Show the keys "sections" of the dictionary.
print("Metadata dictionary keys:")
print(metadata.keys())
print('\n')

# Read the metadata and return a human readable string.
data = metar.read_metadata("testfiles/image.jpg")
print(data)

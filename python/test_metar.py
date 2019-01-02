
import os
import sys

# Add metar bin folder containing the metar.so file to the path so it
# is imported.
absolute_path = os.path.abspath(__file__)
parent_dir = os.path.dirname(os.path.dirname(absolute_path))
path = os.path.join(parent_dir, "bin")
assert(os.path.exists(os.path.join(path, "metar.so")))
sys.path.insert(0, path)

try:
  import metar
except:
  print("Error: The metar python library was not found.")
  exit(0)
import unittest
import re
import json

# get_version(...)
#     Return the version number.
#
# key_name(...)
#     Return a human readable name for the given key.
#
# read_metadata(...)
#     Read the given image file's metadata and return it as a human
#     readable string. Return an empty string when the file is not
#     recognized.
#
# read_metadata_json(...)
#     Read the given image file's metadata and return it as a JSON
#     string. Return an empty string when the file is not recognized.


version_pattern = re.compile('^[0-9]+\.[0-9]+\.[0-9]+$')

class TestMetar(unittest.TestCase):

  def test_get_version(self):
    version = metar.get_version()
    match = version_pattern.match(version)
    self.assertTrue(match)

  def test_key_name_jpeg(self):
    self.assertEqual(metar.key_name("jpeg", "iptc", "5"), "Title")
    self.assertEqual(metar.key_name("jpeg", "ranges", "216"), "SOI")
    self.assertEqual(metar.key_name("jpeg", "ranges", "219"), "DQT")
    self.assertEqual(metar.key_name("jpeg", "ranges", "224"), "APP0")

  def test_key_name_tiff(self):
    self.assertEqual(metar.key_name("tiff", "ifd", "254"), "NewSubfileType(254)")

  def test_read_metadata_missing(self):
    data = metar.read_metadata("missing/missing.jpg")
    self.assertEqual(data, '')

  def test_read_metadata(self):
    data = metar.read_metadata("testfiles/image.jpg")
    # print data
    part1 = """\
========== APP0 ==========
id = "JFIF"
major = 1
minor = 1
units = 1
x = 96
y = 96
width = 0
height = 0
"""
    part2 = """\
========== meta ==========
filename = "image.jpg"
reader = "jpeg"
size = 2198
"""
    part3 = """\
========== image ==========
width = 150
height = 100
pixels = [[623, 2196]]
"""
    part4 = """\
========== SOF0 ==========
precision = 8
width = 150
height = 100
components = [[1, 2, 2, 0], [2, 1, 1, 1], [3, 1, 1, 1]]
"""
    self.assertTrue(part1 in data)
    self.assertTrue(part2 in data)
    self.assertTrue(part3 in data)
    self.assertTrue(part4 in data)

  def test_read_metadata_json_missing(self):
    string = metar.read_metadata_json("missing/missing.jpg")
    self.assertEqual(string, '')

  def test_read_metadata_json(self):
    string = metar.read_metadata_json("testfiles/image.jpg")
    # print data
    metadata = json.loads(string)
    keys = sorted(metadata.keys())
    expected_keys = ['APP0', 'DHT', 'DQT', 'SOF0', 'SOS', 'image', 'meta', 'ranges']
    self.assertEqual(keys, expected_keys)

  def test_read_metadata_debug(self):
    data = metar.read_metadata("testfiles/image.jpg")
    print data
    self.assertTrue('build = "' in data)


if __name__ == '__main__':
  unittest.main()

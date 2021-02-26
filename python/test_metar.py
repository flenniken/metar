
import os
import sys
import platform
import unittest
import re
import json
try:
  import metar
except:
  print("""\
Unable to import metar. Create a virtual python env, activate it and install metar.

python3 -m venv env/linux/metarenv
source env/linux/metarenv/bin/activate
pip3 install wheel
pip3 install bin/linux

""")
  exit(1)

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
    metadata = json.loads(string)
    keys = sorted(metadata.keys())
    expected_keys = ['APP0', 'DHT', 'DQT', 'SOF0', 'SOS', 'image', 'meta', 'ranges']
    self.assertEqual(keys, expected_keys)

  def test_read_metadata_debug(self):
    data = metar.read_metadata("testfiles/image.jpg")
    self.assertTrue('build = "' in data)
    self.assertTrue('nimpyVersion = "' in data)

if __name__ == '__main__':
  unittest.main()

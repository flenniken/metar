import metar
import unittest
from capture import capture

class TestMetar(unittest.TestCase):

  def test_version(self):
      self.assertEqual(metar.__version__, "0.0.2")

  def test_read_metadata_json(self):
    data =  metar.read_metadata_json("testfiles/image.jpg")
    # print data
    start = """{"jfif":{"major":1,"minor":1,"units":1,"x":96,"y":96,"width":0,"height":0},"""

  def test_read_metadata(self):
    data = metar.read_metadata("testfiles/image.jpg")
    # print data
    start = """\
========== jfif ==========
major = 1
minor = 1
units = 1
x = 96
y = 96
width = 0
height = 0
"""
    self.assertTrue(data.startswith(start))
    contains = """\
========== meta ==========
filename = "testfiles/image.jpg"
reader = "jpeg"
size = 2198
"""
    self.assertTrue(contains in data)

  def test_key_name(self):
    self.assertEqual(metar.key_name("jpeg", "iptc", "5"), "Title")

    self.assertEqual(metar.key_name("jpeg", "ranges", "216"), "SOI")
    self.assertEqual(metar.key_name("jpeg", "ranges", "219"), "DQT")
    self.assertEqual(metar.key_name("jpeg", "ranges", "224"), "APP0")


if __name__ == '__main__':
  unittest.main()

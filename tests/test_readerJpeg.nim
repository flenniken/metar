import os
import unittest
import readerJpeg

suite "Test readerJpeg.nim":

  test "iptc_name key not found":
    require(iptc_name(0) == nil)

  test "iptc_name Title":
    require(iptc_name(5) == "Title")

  test "iptc_name Urgency":
    require(iptc_name(10) == "Urgency")

  test "iptc_name Description":
    require(iptc_name(120) == "Description")

  test "iptc_name Description Writer":
    require(iptc_name(122) == "Description Writer")

  test "iptc_name 123":
    require(iptc_name(123) == nil)

  test "iptc_name 6":
    require(iptc_name(6) == nil)

  test "jpeg_section_name 0":
    require(jpeg_section_name(0) == nil)

  test "jpeg_section_name 1":
    require(jpeg_section_name(1) == "TEM")

  test "jpeg_section_name SOF0":
    require(jpeg_section_name(0xc0) == "SOF0")

  test "jpeg_section_name 2":
    require(jpeg_section_name(0) == nil)

  test "jpeg_section_name 0xbf":
    require(jpeg_section_name(0xbf) == nil)

  test "jpeg_section_name 0xfe":
    require(jpeg_section_name(0xfe) == "COM")

  test "jpeg_section_name 0xff":
    require(jpeg_section_name(0xff) == nil)

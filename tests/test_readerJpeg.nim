import os
import unittest
import readerJpeg

suite "Test readerJpeg.nim":

  test "iptc_key key not found":
    require(iptc_key("hello") == nil)

  test "iptc_key Title":
    require(iptc_key("5") == "Title")

  test "iptc_key Urgency":
    require(iptc_key("10") == "Urgency")

  test "iptc_key Urgency":
    require(iptc_key("10") == "Urgency")

  test "iptc_key Urgency":
    require(iptc_key("10") == "Urgency")

  test "iptc_key Description":
    require(iptc_key("120") == "Description")

  test "iptc_key Description Writer":
    require(iptc_key("122") == "Description Writer")

  test "iptc_key 123":
    require(iptc_key("123") == nil)

  test "iptc_key 6":
    require(iptc_key("6") == nil)

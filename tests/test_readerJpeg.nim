import os
import strutils
import unittest
import metadata
import readerJpeg
import hexDump

proc toHex0[T](number: T): string =
  ## Remove the leading 0's from toHex output.

  let str = toHex(number)

  # Count the leading zeros.
  var count = 0
  for char in str:
    if char == '0':
      count += 1
    else:
      break;

  result = str[count..str.len-1]
  if result == "":
     return "0"

# Section is only needed when testing.
type
  Section = tuple[marker: uint8, start: int64, finish: int64]

proc toString(section: Section): string =
  # Return a string representation of a section.
  return "section = $1 ($2, $3) $4" % [toHex(section.marker),
    toHex0(section.start), toHex0(section.finish),
    $(section.finish-section.start)]

proc openTestFile(filename: string): File =
  ## Open the given test file and return the file object.
  if not open(result, filename, fmRead):
    assert(false, "test file missing: " & filename)

suite "Test readerJpeg.nim":

  test "jpegKeyName iptc Title":
    check(jpegKeyName("iptc", "5") == "Title")

  test "jpegKeyName iptc invalid":
    check(jpegKeyName("iptc", "999") == nil)

  test "jpegKeyName offsets c0":
    check(jpegKeyName("offsets", "range_c0") == "SOF0")

  test "jpegKeyName offsets c0":
    check(jpegKeyName("offsets", "range_c0_3") == "SOF0")

  test "jpegKeyName offsets invalid":
    check(jpegKeyName("offsets", "xxyzj") == nil)

  test "test toHex0":
    check(toHex0(0) == "0")
    check(toHex0(0x10'u8) == "10")
    check(toHex0(0x12'u8) == "12")
    check(toHex0(0x1'u8) == "1")
    check(toHex0(0x1234'u16) == "1234")
    check(toHex0(0x0004'u16) == "4")
    check(toHex0(0x0104'u16) == "104")
    check(toHex0(0x12345678'u32) == "12345678")
    check(toHex0(0x00000008'u32) == "8")

  when not defined(release):

    test "iptc_name key not found":
      check(iptc_name(0) == nil)

    test "iptc_name Title":
      check(iptc_name(5) == "Title")

    test "iptc_name Urgency":
      check(iptc_name(10) == "Urgency")

    test "iptc_name Description":
      check(iptc_name(120) == "Description")

    test "iptc_name Description Writer":
      check(iptc_name(122) == "Description Writer")

    test "iptc_name 123":
      check(iptc_name(123) == nil)

    test "iptc_name 6":
      check(iptc_name(6) == nil)

    test "jpeg_section_name 0":
      check(jpeg_section_name(0) == nil)

    test "jpeg_section_name 1":
      check(jpeg_section_name(1) == "TEM")

    test "jpeg_section_name SOF0":
      check(jpeg_section_name(0xc0) == "SOF0")

    test "jpeg_section_name 2":
      check(jpeg_section_name(0) == nil)

    test "jpeg_section_name 0xbf":
      check(jpeg_section_name(0xbf) == nil)

    test "jpeg_section_name 0xfe":
      check(jpeg_section_name(0xfe) == "COM")

    test "jpeg_section_name 0xff":
      check(jpeg_section_name(0xff) == nil)

    test "test readSections":
      var file = openTestFile("testfiles/image.jpg")
      defer: file.close()

      var sections = readSections(file)
      # for section in sections:
      #   echo section.toString()

      check(sections.len == 11)
      check(sections[0].marker == 0xd8)
      check(sections[0].start == 0)
      check(sections[0].finish == 2)
      check(sections[10].marker == 0xd9)
      check(sections[10].start == 0x894)
      check(sections[10].finish == 0x896)

    # Show the sections for all the test files in a dir.
    # test "test readSections all":
    #   let dir = "/Users/steve/code/thumbnailstest/"
    #   for x in walkDir(dir, false):
    #     if x.kind == pcFile:
    #       if x.path.endswith(".jpg"):
    #         echo x.path
    #         var file = openTestFile(x.path)
    #         defer: file.close()
    #         var sections = readSections(file)
    #         for section in sections:
    #           echo section.toString()

    test "test readSections not jpeg":
      var file = openTestFile("testfiles/image.tif")
      defer: file.close()
      var gotException = false
      try:
        discard readSections(file)
      except UnknownFormat:
        gotException = true
      check(gotException)

    test "test kindOfSection exif":
      let filename = "testfiles/agency-photographer-example.jpg"
      var file = openTestFile(filename)
      defer: file.close()

      # var sections = readSections(file)
      # for section in sections:
      #   echo section.toString()

      file = openTestFile(filename)
      defer: file.close()

      let xstart = 2
      let xend = 0x1ec4

      # let length = xend-xstart
      # var buffer: seq[uint8]
      # buffer.newSeq(length)
      # file.setFilePos(xstart)
      # discard file.readBytes(buffer, 0, length)
      # echo hexDump(buffer, (uint16)xstart)

      var (name, data) = kindOfSection(file, 0xe1, xstart, xend)
      check(name == "exif")
      let expectedLen = xend-xstart-4
      # data.len is the data without the "Exif0".
      if data.len != expectedLen-5:
        echo "expectedLen = " & $expectedLen
        echo "data.len = " & $data.len
        fail()

    test "test kindOfSection xmp":
      let filename = "testfiles/agency-photographer-example.jpg"
      var file = openTestFile(filename)
      defer: file.close()

      # var sections = readSections(file)
      # for section in sections:
      #   echo section.toString()

      file = openTestFile(filename)
      defer: file.close()

      var (name, data) = kindOfSection(file, 0xe1, 0x2B2E, 0x5FD0)
      check(name == "xmp")
      check(data.len < 0x5FD0 - 0x2B2E - 4)

    test "test kindOfSection key not e1":
      var file = openTestFile("testfiles/image.jpg")
      defer: file.close()

      var (name, data) = kindOfSection(file, 0xe2, 0, 100)
      check(name == "")
      check(data == "key not e1")

    test "test kindOfSection check return data":
      var filename = "testKindOfSection.bin"
      var testFile: File
      # ff, e1, length, string+0, data
      var bytes = [0xff'u8, 0xe1, 0, 11, (uint8)'E', (uint8)'x',
        (uint8)'i', (uint8)'f', 0x00, (uint8)'t',
        (uint8)'e', (uint8)'s', (uint8)'t']
      if open(testFile, filename, fmWrite):
        discard testFile.writeBytes(bytes, 0, bytes.len)
      testFile.close()
      defer: removeFile(filename)

      var file = openTestFile(filename)
      defer: file.close()

      var (name, data) = kindOfSection(testFile, 0xe1, 0, bytes.len)
      check(name == "exif")
      check(data == "test")

    test "test kindOfSection not ffe1":
      var filename = "testKindOfSection.bin"
      var testFile: File
      # ff, e1, length, string+0, data
      var bytes = [0x00'u8, 0x00]
      if open(testFile, filename, fmWrite):
        discard testFile.writeBytes(bytes, 0, bytes.len)
      testFile.close()
      defer: removeFile(filename)

      var file = openTestFile(filename)
      defer: file.close()

      var (name, data) = kindOfSection(testFile, 0xe1, 0, bytes.len)
      check(name == "")
      check(data == "not ffe1")

    test "test kindOfSection section length < 4":
      var filename = "testKindOfSection.bin"
      var testFile: File
      # ff, e1, length, string+0, data
      var bytes = [0xff'u8, 0xe1]
      if open(testFile, filename, fmWrite):
        discard testFile.writeBytes(bytes, 0, bytes.len)
      testFile.close()
      defer: removeFile(filename)

      var file = openTestFile(filename)
      defer: file.close()

      var (name, data) = kindOfSection(testFile, 0xe1, 0, bytes.len)
      check(name == "")
      check(data == "section length < 4")
      

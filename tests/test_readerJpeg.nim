import os
import strutils
import unittest
import metadata
import readerJpeg

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



proc openTestFile(filename: string): File =
  if not open(result, filename, fmRead):
    assert(false, "test file missing: " & filename)

suite "Test readerJpeg.nim":

  when not defined(release):

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

  test "jpegKeyName iptc Title":
    require(jpegKeyName("iptc", "5") == "Title")

  test "jpegKeyName iptc invalid":
    require(jpegKeyName("iptc", "999") == nil)

  test "jpegKeyName offsets c0":
    require(jpegKeyName("offsets", "range_c0") == "SOF0")

  test "jpegKeyName offsets c0":
    require(jpegKeyName("offsets", "range_c0_3") == "SOF0")

  test "jpegKeyName offsets invalid":
    require(jpegKeyName("offsets", "xxyzj") == nil)

  test "test toHex0":
    require(toHex0(0) == "0")
    require(toHex0(0x10'u8) == "10")
    require(toHex0(0x12'u8) == "12")
    require(toHex0(0x1'u8) == "1")
    require(toHex0(0x1234'u16) == "1234")
    require(toHex0(0x0004'u16) == "4")
    require(toHex0(0x0104'u16) == "104")
    require(toHex0(0x12345678'u32) == "12345678")
    require(toHex0(0x00000008'u32) == "8")

  test "test readSections":
    var file = openTestFile("testfiles/image.jpg")
    defer: file.close()

    var sections = readSections(file)
    for section in sections:
      echo "section = $1 ($2, $3)" % [toHex(section.marker),
                                      toHex0(section.start),
                                      toHex0(section.finish)]
    # section = D8 (0, 2)
    # section = E0 (2, 14)
    # section = DB (14, 59)
    # section = DB (59, 9E)
    # section = C0 (9E, B1)
    # section = C4 (B1, D2)
    # section = C4 (D2, 189)
    # section = C4 (189, 1AA)
    # section = C4 (1AA, 261)
    # section = DA (261, 894)
    # section = D9 (894, 896)

    require(sections.len == 11)
    require(sections[0].marker == 0xd8)
    require(sections[0].start == 0)
    require(sections[0].finish == 2)
    require(sections[10].marker == 0xd9)
    require(sections[10].start == 0x894)
    require(sections[10].finish == 0x896)

  test "test readSections all":
    let dir = "/Users/steve/code/thumbnailstest/"
    for x in walkDir(dir, false):
      if x.kind == pcFile:
        if x.path.endswith(".jpg"):
          echo x.path

          var file = openTestFile(x.path)
          defer: file.close()

          var sections = readSections(file)
          for section in sections:
            echo "section = $1 ($2, $3)" % [toHex(section.marker),
                                            toHex0(section.start),
                                            toHex0(section.finish)]



  test "test readSections not jpeg":
    var file = openTestFile("testfiles/image.tif")
    defer: file.close()
    try:
      discard readSections(file)
    except UnknownFormat:
      break
    assert(false, "Did not get expected exception.")

  test "test kindOfSection wrong key":
    var file = openTestFile("testfiles/image.jpg")
    defer: file.close()

    var (name, data) = kindOfSection(file, 0xe2, 0, 100)
    require(name == "")
    require(data == "")

  test "test kindOfSection wrong key":
    var file = openTestFile("testfiles/image.jpg")
    defer: file.close()

    var (name, data) = kindOfSection(file, 0xe2, 0, 100)
    require(name == "")
    require(data == "")

  test "test kindOfSection":
    var filename = "testKindOfSection.bin"
    var testFile: File
    # Create a file with a fake xmp section.
    # ff, e1, length, string+0, data
    var bytes = [0xff'u8, 0xe1, 0x0, 0x5, (uint8)'e', (uint8)'x',
        (uint8)'i', (uint8)'f', 0x0, 0x31]
    if open(testFile, filename, fmWrite):
      discard testFile.writeBytes(bytes, 0, bytes.len)
    testFile.close()

    var file = openTestFile(filename)
    defer: file.close()

    var (name, data) = kindOfSection(testFile, 0xe1, 0, bytes.len)
    require(name == "exif")
    require(data == "1")
    removeFile(filename)

  test "test kindOfSection 5":
    let filename = "testfiles/agency-photographer-example.jpg"
    var file = openTestFile(filename)
    defer: file.close()

    var sections = readSections(file)
    for section in sections:
      echo "section = $1 ($2, $3) $4" % [toHex(section.marker),
        toHex0(section.start),
        toHex0(section.finish), $(section.finish-section.start)]

    file = openTestFile(filename)
    defer: file.close()

    var (name, data) = kindOfSection(file, 0xe1, 2, 0x1EC)
    echo data
    require(name == "exif")
    echo data.len

  test "test kindOfSection 6":
    let filename = "testfiles/agency-photographer-example.jpg"
    var file = openTestFile(filename)
    defer: file.close()

    var sections = readSections(file)
    for section in sections:
      echo "section = $1 ($2, $3)" % [toHex(section.marker),
                                      toHex0(section.start),
                                      toHex0(section.finish)]

    file = openTestFile(filename)
    defer: file.close()

    var (name, data) = kindOfSection(file, 0xe1, 0x2B2E, 0x5FD0)
    require(name == "xmp")
    echo data.len


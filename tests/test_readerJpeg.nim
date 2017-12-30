import os
import strutils
import unittest
import metadata
import readerJpeg
import hexDump
import tables


proc openTestFile(filename: string): File =
  ## Open the given test file and return the file object.
  if not open(result, filename, fmRead):
    assert(false, "test file missing: " & filename)


proc readSection(filename: string, marker: uint8): seq[uint8] =
  ## Read and return a section from the given file.

  var file = openTestFile(filename)
  defer: file.close()
  # Section = tuple[marker: uint8, start: int64, finish: int64] ## \ A
  var sections = readSections(file)
  var foundSection = false
  for section in sections:
    if section.marker == marker:
      # echo $section
      let length = section.finish-section.start
      result.newSeq(length)
      file.setFilePos(section.start)
      discard file.readBytes(result, 0, length)
      foundSection = true
      break
  if not foundSection:
    raise newException(ValueError, "The section was not found.")

proc showSections(filename: string) =
  ## Show the sections for the given file.

  var file = openTestFile(filename)
  defer: file.close()
  var sections = readSections(file)
  for section in sections:
    echo $section

proc showSectionsFolder(folder: string) =
  ## Show the sections for all the jpeg files in the given folder.

  for x in walkDir(folder, false):
    if x.kind == pcFile:
      if x.path.endswith(".jpg"):
        echo x.path
        showSections(x.path)



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
      #   echo $section

      check(sections.len == 11)
      check(sections[0].marker == 0xd8)
      check(sections[0].start == 0)
      check(sections[0].finish == 2)
      check(sections[10].marker == 0xd9)
      check(sections[10].start == 0x894)
      check(sections[10].finish == 0x896)

    test "test readSections not jpeg":
      var file = openTestFile("testfiles/image.tif")
      defer: file.close()
      var gotException = false
      try:
        discard readSections(file)
      except UnknownFormatError:
        gotException = true
      check(gotException)

    test "test xmpOrExifSection exif":
      let filename = "testfiles/agency-photographer-example.jpg"
      var file = openTestFile(filename)
      defer: file.close()

      # var sections = readSections(file)
      # for section in sections:
      #   echo $section

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

      var (name, data) = xmpOrExifSection(file, 0xe1, xstart, xend)
      check(name == "exif")
      let expectedLen = xend-xstart-4
      # data.len is the data without the "Exif0".
      if data.len != expectedLen-5:
        echo "expectedLen = " & $expectedLen
        echo "data.len = " & $data.len
        fail()

    test "test xmpOrExifSection xmp":
      let filename = "testfiles/agency-photographer-example.jpg"
      var file = openTestFile(filename)
      defer: file.close()

      # var sections = readSections(file)
      # for section in sections:
      #   echo $section

      file = openTestFile(filename)
      defer: file.close()

      var (name, data) = xmpOrExifSection(file, 0xe1, 0x2B2E, 0x5FD0)
      check(name == "xmp")
      check(data.len < 0x5FD0 - 0x2B2E - 4)

    test "test xmpOrExifSection key not e1":
      var file = openTestFile("testfiles/image.jpg")
      defer: file.close()

      var (name, data) = xmpOrExifSection(file, 0xe2, 0, 100)
      check(name == "")
      check(data == "key not e1")

    test "test xmpOrExifSection check return data":
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

      var (name, data) = xmpOrExifSection(testFile, 0xe1, 0, bytes.len)
      check(name == "exif")
      check(data == "test")

    test "test xmpOrExifSection not ffe1":
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

      var (name, data) = xmpOrExifSection(testFile, 0xe1, 0, bytes.len)
      check(name == "")
      check(data == "not ffe1")

    test "test xmpOrExifSection section length < 4":
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

      var (name, data) = xmpOrExifSection(testFile, 0xe1, 0, bytes.len)
      check(name == "")
      check(data == "section length < 4")

    test "test compareBytes":
      var buffer = [0xff'u8, 0xe1, 0, 11, (uint8)'E', (uint8)'x',
              (uint8)'i', (uint8)'f', 0x00, (uint8)'t',
              (uint8)'e', (uint8)'s', (uint8)'t']
      check(compareBytes(buffer, 9, "test") == true)
      check(compareBytes(buffer, 4, "Exif") == true)
      check(compareBytes(buffer, 0, "asdf") == false)
      check(compareBytes(buffer, 4, "Exig") == false)

    test "test bytesToString":
      var buffer = [0xff'u8, 0xe1, 0, 11, (uint8)'E', (uint8)'x',
              (uint8)'i', (uint8)'f', 0x00, (uint8)'t',
              (uint8)'e', (uint8)'s', (uint8)'t']
      check(bytesToString(buffer, 9, 0) == "")
      check(bytesToString(buffer, 9, 1) == "t")
      check(bytesToString(buffer, 9, 4) == "test")
      check(bytesToString(buffer, 4, 4) == "Exif")

    test "test getSof0Info":
      var buffer = [0xff'u8, 0xc0, 0, 0x11, 0x08, 0x00, 0x64,
                    0x00, 0x96, 0x03, 0x01, 0x22, 0x00, 0x02,
                    0x11, 0x01, 0x03, 0x11, 0x01]
      let info = getSof0Info(buffer)
      # echo $info
      check(info.precision == 8)
      check(info.width == 150)
      check(info.height == 100)
      check(info.components.len == 3)
      check(info.components[0] == (1u8, 34u8, 0u8))
      check(info.components[1] == (2u8, 17u8, 1u8))
      check(info.components[2] == (3u8, 17u8, 1u8))

    test "test getSof0Info e1":
      var buffer = [0xff'u8, 0xc0]
      try:
        discard getSof0Info(buffer)
      except NotSupportedError:
        var msg = "Invalid SOF0, not enough bytes."
        check(msg == getCurrentExceptionMsg())
      except:
        check(false == true)

    test "test getSof0Info happy path":
      var buffer = readSection("testfiles/image.jpg", 0xc0)
      # echo hexDump(buffer)

      var info = getSof0Info(buffer)
      # echo $info
      check(info.width == 150)
      check(info.height == 100)

    test "test getIptcRecords":
      # let folder = "/Users/steve/code/metarnim/testfiles"
      const folder = "."
      showSectionsFolder(folder)

      let filename = "testfiles/agency-photographer-example.jpg"
      # showSections(filename)

      var buffer = readSection(filename, 0xed)
      # echo hexDump(buffer[0..<16])

      var records = getIptcRecords(buffer)
      check(records.len == 52)
      check($records[1] == """02, 05, "drp2091169d"""")
      
      for record in records:
        # echo $record
        check(record.number == 2)
        check(record.data_set >= 0u8)
        check(record.str.len >= 0)

      let info = getIptcInfo(records)
      check(info.len == 18)
      # for k, v in info:
      #   echo k & "=" & v
      var keywords = info["25"].split(',')
      check(keywords.len == 34)
      check(keywords[0] == "North America")

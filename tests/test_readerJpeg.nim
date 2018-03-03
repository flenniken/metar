# See: readerJpeg.nim(0):

import os
import strutils
import unittest
import metadata
import readerJpeg
import hexDump
import tables
import json
import readable

proc createTestFile(bytes: var openArray[uint8]):
  tuple[file:File, filename:string] =
  ## Create a test file with the given bytes.

  var filename = "testfile.bin"
  var file: File
  if open(file, filename, fmReadWrite):
    if file.writeBytes(bytes, 0, bytes.len) != bytes.len:
      raise newException(IOError, "Unable to write all the bytes.")
  result = (file, filename)

proc openTestFile(filename: string): File =
  ## Open the given test file and return the file object.
  if not open(result, filename, fmRead):
    assert(false, "test file missing: " & filename)


proc readSectionBuffer(filename: string, marker: uint8): seq[uint8] =
  ## Read and return a section buffer from the given file.

  var file = openTestFile(filename)
  defer: file.close()

  # Find the marker section.
  let sections = findMarkerSections(file, marker)
  if sections.len != 1:
    raise newException(ValueError, "One section was not found.")

  let section = sections[0]
  result = readSection(file, section.start, section.finish)


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

#[
todo: write generic tests for each reader.
* read a 0 byte file
* read a 1 byte file
]#

suite "Test readerJpeg.nim":

  test "test readJpeg":
    var file = openTestFile("testfiles/IMG_6093.JPG")
    defer: file.close()
    var metadata = readJpeg(file)
    discard metadata
    # echo readable(metadata)


  test "jpegKeyName iptc Title":
    check(jpegKeyName("iptc", "5") == "Title")

  test "jpegKeyName iptc invalid":
    check(jpegKeyName("iptc", "999") == "")

  test "jpegKeyName ranges 192":
    check(jpegKeyName("ranges", "192") == "SOF0")

  test "jpegKeyName ranges 254":
    check(jpegKeyName("ranges", "254") == "COM")

  test "jpegKeyName ranges 0":
    check(jpegKeyName("ranges", "0") == "")

  test "jpegKeyName ranges 255":
    check(jpegKeyName("ranges", "255") == "")

  test "jpegKeyName ranges invalid":
    check(jpegKeyName("ranges", "xxyzj") == "")

  when not defined(release):

    test "test handle_section":
      var file = openTestFile("testfiles/image.jpg")
      defer: file.close()
      var sections = readSections(file)
      check(sections.len == 12)

      # for ix, section in sections:
      #   var (section_name, info) = handle_section(file, section)
      #   var str:string
      #   if info == nil:
      #     str = ""
      #   else:
      #     str = $info
      #   echo "$1 $2: $3" % [$ix, section_name, str]

      var (section_name, info, known) = handle_section(file, sections[1])
      let expected1 = """{"major":1,"minor":1,"units":1,"x":96,"y":96,"width":0,"height":0}"""
      check(section_name == "jfif")
      check($info == expected1)
      check(known == true)

      (section_name, info, known) = handle_section(file, sections[4])
      let expected4 = """{"precision":8,"width":150,"height":100,"components":[[1,34,0],[2,17,1],[3,17,1]]}"""
      check(section_name == "SOF0")
      check($info == expected4)
      check(known == true)


    test "iptc_name key not found":
      check(iptc_name(0) == "")

    test "iptc_name Title":
      check(iptc_name(5) == "Title")

    test "iptc_name Urgency":
      check(iptc_name(10) == "Urgency")

    test "iptc_name Description":
      check(iptc_name(120) == "Description")

    test "iptc_name Description Writer":
      check(iptc_name(122) == "Description Writer")

    test "iptc_name 123":
      check(iptc_name(123) == "")

    test "iptc_name 6":
      check(iptc_name(6) == "")

    test "jpeg_section_name 0":
      check(jpeg_section_name(0) == "")

    test "jpeg_section_name 1":
      check(jpeg_section_name(1) == "TEM")

    test "jpeg_section_name SOF0":
      check(jpeg_section_name(0xc0) == "SOF0")

    test "jpeg_section_name 2":
      check(jpeg_section_name(0) == "")

    test "jpeg_section_name 0xbf":
      check(jpeg_section_name(0xbf) == "")

    test "jpeg_section_name 0xfe":
      check(jpeg_section_name(0xfe) == "COM")

    test "jpeg_section_name 0xff":
      check(jpeg_section_name(0xff) == "")

    test "test readSections":
      var file = openTestFile("testfiles/image.jpg")
      defer: file.close()

      var sections = readSections(file)

      var start = (int64)0
      for section in sections:
        check(section.start == start)
        start = section.finish

      var lines = newSeq[string]()
      for section in sections:
        lines.add($section)
      let got = lines.join("\n")

      let expected = """
section = D8 (0, 2) 2
section = E0 (2, 14) 12
section = DB (14, 59) 45
section = DB (59, 9E) 45
section = C0 (9E, B1) 13
section = C4 (B1, D2) 21
section = C4 (D2, 189) B7
section = C4 (189, 1AA) 21
section = C4 (1AA, 261) B7
section = DA (261, 26F) E
section = 00 (26F, 894) 625
section = D9 (894, 896) 2"""
      check(got == expected)


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

      # Find the xmp section.
      let sections = findMarkerSections(file, 0xe1)
      # echo "sections.len = " & $sections.len
      check(sections.len == 2)
      let section = sections[0]

      # # Dump the start of the section.
      # var buffer = readSection(file, section.start, section.finish)
      # echo hexDump(buffer[0..200])

      # Extract the exif data.
      var (name, data) = xmpOrExifSection(file, section.start,
                                          section.finish)
      check(name == "exif")
      check(data.len < section.finish - section.start - 4)
      # echo hexDump(data[0..200])

      check(data[0] == 0)
      check(data[1] == 0x4d)
      check(data[2] == 0x4d)

    test "test xmpOrExifSection xmp":
      let filename = "testfiles/agency-photographer-example.jpg"
      var file = openTestFile(filename)
      defer: file.close()

      # Find the xmp section.
      let sections = findMarkerSections(file, 0xe1)
      # echo "sections.len = " & $sections.len
      check(sections.len == 2)
      let section = sections[1]

      # # Dump the start of the section.
      # var buffer = readSection(file, section.start, section.finish)
      # echo hexDump(buffer[0..200])

      # Extract the xmp data.
      var (name, data) = xmpOrExifSection(file, section.start,
                                          section.finish)
      check(name == "xmp")
      check(data.len < section.finish - section.start - 4)
      # echo hexDump(data[0..200])

      var str = bytesToString(data, 0, data.len)

      let expected = "<?xpacket begin="
      check($str[0..<expected.len] == expected)


    test "test xmpOrExifSection not ffe1":
      var file = openTestFile("testfiles/image.jpg")
      defer: file.close()

      try:
        discard xmpOrExifSection(file, 0, 100)
        fail()
      except NotSupportedError:
        let msg = getCurrentExceptionMsg()
        check(msg == "xmpExif: section start not 0xffe1.")


    test "test xmpOrExifSection too short":
      # Create a test file.
      # ff, e1, length, string+0, data
      var bytes = [0x00'u8, 0x00]
      var (file, filename) = createTestFile(bytes)
      defer:
        file.close()
        removeFile(filename)

      try:
        discard xmpOrExifSection(file, 0, bytes.len)
        fail()
      except NotSupportedError:
        let msg = getCurrentExceptionMsg()
        check(msg == "xmpExif: Section too short.")

    test "test xmpOrExifSection 10":
      # Create a test file.
      # ff, e1, length, string+0, data
      var bytes = [0'u8, 0, 0, 0, 0, 0, 0, 0, 0, 0]
      var (file, filename) = createTestFile(bytes)
      defer:
        file.close()
        removeFile(filename)

      try:
        discard xmpOrExifSection(file, 0, bytes.len-1)
        fail()
      except NotSupportedError:
        let msg = getCurrentExceptionMsg()
        check(msg == "xmpExif: Section too short.")


    test "test xmpOrExifSection section length":
      # Create a test file.
      # ff, e1, length, string+0, data
      var bytes = [0xff'u8, 0xe1, 0x88, 0x99, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
      var (file, filename) = createTestFile(bytes)
      defer:
        file.close()
        removeFile(filename)

      try:
        discard xmpOrExifSection(file, 0, bytes.len)
        fail()
      except NotSupportedError:
        let msg = getCurrentExceptionMsg()
        check(msg == "xmpExif: invalid block length.")


    test "test compareBytes":
      var buffer = [0xff'u8, 0xe1, 0, 11, (uint8)'E', (uint8)'x',
              (uint8)'i', (uint8)'f', 0x00, (uint8)'t',
              (uint8)'e', (uint8)'s', (uint8)'t']
      check(compareBytes(buffer, 9, "test") == true)
      check(compareBytes(buffer, 4, "Exif") == true)
      check(compareBytes(buffer, 0, "asdf") == false)
      check(compareBytes(buffer, 4, "Exig") == false)

    test "test bytesToString":
      var buffer = [(uint8)'s', (uint8)'t', (uint8)'a', (uint8)'r',
        (uint8)'E', (uint8)'x', (uint8)'i', (uint8)'f', (uint8)'f',
        (uint8)'t', (uint8)'e', (uint8)'s', (uint8)'t']
      check(bytesToString(buffer, 0, buffer.len) == "starExifftest")
      check(bytesToString(buffer, 9, 0) == "")
      check(bytesToString(buffer, 9, 1) == "t")
      check(bytesToString(buffer, 9, 4) == "test")
      check(bytesToString(buffer, 4, 4) == "Exif")

    test "test bytesToString2":
      var buffer = newSeq[uint8]()
      check(bytesToString(buffer, 0, 0) == "")

    test "test bytesToString error":
      var buffer = [0x1u8, 0x02, 0x03, 0x04]
      try:
        discard bytesToString(buffer, 0, buffer.len+1)
        fail()
      except:
        # echo repr(getCurrentException())
        # echo getCurrentException().name
        # echo getCurrentExceptionMsg()
        discard


    test "test bytesToString error2":
      var buffer:seq[uint8] = @[]
      try:
        discard bytesToString(buffer, 0, buffer.len+1)
        fail()
      except:
        # echo repr(getCurrentException())
        # echo getCurrentException().name
        # echo getCurrentExceptionMsg()
        discard


    test "test getSofInfo":
      var buffer = [0xff'u8, 0xc0, 0, 0x11, 0x08, 0x00, 0x64,
                    0x00, 0x96, 0x03, 0x01, 0x22, 0x00, 0x02,
                    0x11, 0x01, 0x03, 0x11, 0x01]
      let info = getSofInfo(buffer)

      let expected = """
precision: 8, width: 150, height: 100, num components: 3
1, 34, 0
2, 17, 1
3, 17, 1"""
      check($info == expected)
      check(info.precision == 8)
      check(info.width == 150)
      check(info.height == 100)
      check(info.components.len == 3)
      check(info.components[0] == (1u8, 34u8, 0u8))
      check(info.components[1] == (2u8, 17u8, 1u8))
      check(info.components[2] == (3u8, 17u8, 1u8))

    test "test getSofInfo e1":
      var buffer = [0xff'u8, 0xc0]
      try:
        discard getSofInfo(buffer)
      except NotSupportedError:
        var msg = "SOF: buffer too small."
        check(msg == getCurrentExceptionMsg())
      except:
        echo getCurrentExceptionMsg()
        check(false == true)

    test "test getSofInfo happy path":
      var buffer = readSectionBuffer("testfiles/image.jpg", 0xc0)
      # echo hexDump(buffer)

      var info = getSofInfo(buffer)
      # echo $info
      check(info.width == 150)
      check(info.height == 100)

      var metadata: Metadata = newJObject()
      metadata["sofname"] = SofInfoToMeta(info)
      # echo pretty(metadata)


    test "test getIptcRecords":
      # let folder = "/Users/steve/code/metarnim/testfiles"
      const folder = "."
      showSectionsFolder(folder)

      let filename = "testfiles/agency-photographer-example.jpg"
      # showSections(filename)

      var buffer = readSectionBuffer(filename, 0xed)
      # echo hexDump(buffer, 0x5FD0)

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

    test "test SofInfoToMeta":

      var components = newSeq[tuple[x: uint8, y:uint8, z:uint8]]()
      components.add((1u8, 2u8, 3u8))
      components.add((4u8, 5u8, 6u8))
      var info = SofInfo(precision: 8u8, width: 200u16, height: 100u16,
                          components: components)
      let json = $SofInfoToMeta(info)
      let expected = """{"precision":8,"width":200,"height":100,"components":[[1,2,3],[4,5,6]]}"""
      check(json == expected)


    test "test stripInvalidUtf8":

      check(stripInvalidUtf8("string") == "string")

    test "test stripInvalidUtf8 2":

      let buffer = [0xa9'u8, (uint8)'a', (uint8)'b', (uint8)'c']
      var str = newStringOfCap(buffer.len)
      for ix in 0..buffer.len-1:
        str.add((char)buffer[ix])
      check(stripInvalidUtf8(str) == "abc")

    test "test stripInvalidUtf8 3":
      let buffer = [(uint8)'a', (uint8)'b', 0xa9'u8, (uint8)'c']
      var str = newStringOfCap(buffer.len)
      for ix in 0..buffer.len-1:
        str.add((char)buffer[ix])
      check(stripInvalidUtf8(str) == "abc")

    test "test getHdtInfo":
      var buffer = [
        0xff'u8, 0xc4, 0, 0x1f, 0x00, 0x00, 0x01, 0x05,
        0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x02,
        0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a,
        0x0b]
      # 0000  FF C4 00 1F 00 00 01 05 01 01 01 01 01 01 00 00  ................
      # 0010  00 00 00 00 00 00 01 02 03 04 05 06 07 08 09 0A  ................
      # 0020  0B
      let info = getHdtInfo(buffer)
      # echo info
      let expected = """{"bits":0,"counts":[0,1,5,1,1,1,1,1,1,0,0,0,0,0,0,0],"symbols":[0,1,2,3,4,5,6,7,8,9,10,11]}"""
      check($info == expected)

      #todo: add more getHdtInfo tests

    test "test getDqtInfo":
      var buffer = [
        0xFF'u8, 0xDB, 0x00, 0x43, 0x00, 0x08, 0x06, 0x06,
        0x07, 0x06, 0x05, 0x08, 0x07, 0x07, 0x07, 0x09,
        0x09, 0x08, 0x0A, 0x0C, 0x14, 0x0D, 0x0C, 0x0B,
        0x0B, 0x0C, 0x19, 0x12, 0x13, 0x0F, 0x14, 0x1D,
        0x1A, 0x1F, 0x1E, 0x1D, 0x1A, 0x1C, 0x1C, 0x20,
        0x24, 0x2E, 0x27, 0x20, 0x22, 0x2C, 0x23, 0x1C,
        0x1C, 0x28, 0x37, 0x29, 0x2C, 0x30, 0x31, 0x34,
        0x34, 0x34, 0x1F, 0x27, 0x39, 0x3D, 0x38, 0x32,
        0x3C, 0x2E, 0x33, 0x34, 0x32,
      ]
      let info = getDqtInfo(buffer)
      let expected = """{"bits":0,"qts":[8,6,6,7,6,5,8,7,7,7,9,9,8,10,12,20,13,12,11,11,12,25,18,19,15,20,29,26,31,30,29,26,28,28,32,36,46,39,32,34,44,35,28,28,40,55,41,44,48,49,52,52,52,31,39,57,61,56,50,60,46,51,52,50]}"""
      check($info == expected)

    test "test getSosInfo":
      var buffer = [
        0xFF'u8, 0xDA, 0x00, 0x0C, 0x03, 0x01, 0x00, 0x02,
        0x11, 0x03, 0x11, 0x00, 0x3F, 0x00,
      ]
      let info = getSosInfo(buffer)
      # echo info
      let expected = """{"components":[[1,0],[2,17],[3,17]],"skip1":0,"skip2":63,"skip3":0}"""
      check($info == expected)


    test "test getAppeInfo":

      # 0000  FF EE 00 0E 41 64 6F 62 65 00 64 00 00 00 00 01  ....Adobe.d.....
      var buffer = [
        0xFF'u8, 0xEE, 0x00, 0x0E, 0x41, 0x64, 0x6F, 0x62,
        0x65, 0x00, 0x64, 0x00, 0x00, 0x00, 0x00, 0x01,
      ]
      let info = getAppeInfo(buffer)
      # echo $info
      let expected = """{"version":100,"flags0":0,"flags1":256}"""
      check($info == expected)

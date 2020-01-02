# See: readerJpeg.nim(0):

import os
import strutils
import unittest
import metadata
import json
import testFile
import ranges
import readerJpeg
import imageData

static:
  doAssert defined(test), ": test not defined."

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

  test "keyNameJpeg iptc Title":
    check(keyNameJpeg("iptc", "5") == "Title")

  test "keyNameJpeg iptc invalid":
    check(keyNameJpeg("iptc", "999") == "")

  test "keyNameJpeg iptc asterisk":
    check(keyNameJpeg("iptc", "5*") == "")

  test "keyNameJpeg ranges 192":
    check(keyNameJpeg("ranges", "192") == "SOF0")

  test "keyNameJpeg ranges 254":
    check(keyNameJpeg("ranges", "254") == "COM")

  test "keyNameJpeg ranges 0":
    check(keyNameJpeg("ranges", "0") == "")

  test "keyNameJpeg ranges 255":
    check(keyNameJpeg("ranges", "255") == "")

  test "keyNameJpeg ranges invalid":
    check(keyNameJpeg("ranges", "xxyzj") == "")

  test "keyNameJpeg exif":
    check(keyNameJpeg("exif", "700") == "XMP(700)")

  test "test handleSection":
    var file = openTestFile("testfiles/image.jpg")
    defer: file.close()
    var sections = readSections(file)
    check(sections.len == 12)

    var imageData = ImageData()
    var ranges = newSeq[Range]()
    for ix, section in sections:
      let sectionInfo = handleSection(file, section, imageData, ranges)
      if sectionInfo.known:
        # echo $sectionInfo
        discard
      else:
        echo "section not known: " & toHex(section.marker)
        echo $sectionInfo
        for range in ranges:
          echo $range
      # var str:string
      # if sectionInfo.node == nil:
      #   str = ""
      # else:
      #   str = $sectionInfo.node
      # echo "$1 $2($4) = $3" % [$ix, sectionInfo.name, str, $sectionInfo.marker]

  test "test app0 jfif":
    var file = openTestFile("testfiles/image.jpg")
    defer: file.close()
    var sections = readSections(file)
    check(sections.len == 12)

    var imageData = ImageData()
    var ranges = newSeq[Range]()
    let sectionInfo = handleSection(file, sections[1], imageData, ranges)
    # echo sectionInfo
    let expected1 = """{"id":"JFIF","major":1,"minor":1,"units":1,"x":96,"y":96,"width":0,"height":0}"""
    check(sectionInfo.name == "APP0")
    check($sectionInfo.node == expected1)
    check(sectionInfo.known == true)
    # for range in ranges:
    #   echo $range
    let expectedRange = Range(start: 2, finish: 20, name: "APP0", message: "", known: true)
    check(ranges.len == 1)
    check(ranges[0] == expectedRange)
    check(imageData.width == 0)



    # let sectionInfo2 = handleSection(file, sections[4], imageData, ranges)
    # let expected4 = """{"precision":8,"width":150,"height":100,"components":[[1,2,2,0],[2,1,1,1],[3,1,1,1]]}"""
    # check(sectionInfo2.name == "SOF0")
    # check($sectionInfo2.node == expected4)
    # check(sectionInfo2.known == true)
    # # echo $imageData
    # check(imageData.pixelOffsets.len == 0)
    # check(imageData.height == 100)
    # check(imageData.width == 150)


  test "iptcLongName key not found":
    check(iptcLongName(0) == "0")

  test "iptcLongName Title":
    check(iptcLongName(5) == "Title(5)")

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
(marker: 216, start: 0, finish: 2)
(marker: 224, start: 2, finish: 20)
(marker: 219, start: 20, finish: 89)
(marker: 219, start: 89, finish: 158)
(marker: 192, start: 158, finish: 177)
(marker: 196, start: 177, finish: 210)
(marker: 196, start: 210, finish: 393)
(marker: 196, start: 393, finish: 426)
(marker: 196, start: 426, finish: 609)
(marker: 218, start: 609, finish: 623)
(marker: 0, start: 623, finish: 2196)
(marker: 217, start: 2196, finish: 2198)"""
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

  # test "test xmpOrExifSection exif":
  #   let filename = "testfiles.save/agency-photographer-example.jpg"
  #   var file = openTestFile(filename)
  #   defer: file.close()

  #   # Find the xmp section.
  #   let sections = findMarkerSections(file, 0xe1)
  #   # echo "sections.len = " & $sections.len
  #   check(sections.len == 2)
  #   let section = sections[0]

  #   # # Dump the start of the section.
  #   # var buffer = readSection(file, section.start, section.finish)
  #   # echo hexDump(buffer[0..200])

  #   # Extract the exif data.
  #   var sectionKind = xmpOrExifSection(file, section.start,
  #                                       section.finish)
  #   let name = sectionKind.name
  #   let data = sectionKind.data
  #   check(name == "exif")
  #   check(data.len < section.finish - section.start - 4)
  #   # echo hexDump(data[0..200])

  #   check(data[0] == 0)
  #   check(data[1] == 0x4d)
  #   check(data[2] == 0x4d)

  # test "test xmpOrExifSection xmp":
  #   let filename = "testfiles.save/agency-photographer-example.jpg"
  #   var file = openTestFile(filename)
  #   defer: file.close()

  #   # Find the xmp section.
  #   let sections = findMarkerSections(file, 0xe1)
  #   # echo "sections.len = " & $sections.len
  #   check(sections.len == 2)
  #   let section = sections[1]

  #   # # Dump the start of the section.
  #   # var buffer = readSection(file, section.start, section.finish)
  #   # echo hexDump(buffer[0..200])

  #   # Extract the xmp data.
  #   let sectionKind = xmpOrExifSection(file, section.start,
  #                                       section.finish)
  #   let name = sectionKind.name
  #   let data = sectionKind.data
  #   check(name == "xmp")
  #   check(data.len < section.finish - section.start - 4)
  #   # echo hexDump(data[0..200])

  #   var str = bytesToString(data, 0, data.len)

  #   let expected = "<?xpacket begin="
  #   check($str[0..<expected.len] == expected)


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

  test "test getSofInfo":
    var buffer = [0xff'u8, 0xc0, 0, 0x11, 0x08, 0x00, 0x64,
                  0x00, 0x96, 0x03, 0x01, 0x22, 0x00, 0x02,
                  0x11, 0x01, 0x03, 0x11, 0x01]
    let info = getSofInfo(buffer)

    let expected = """
precision: 8, width: 150, height: 100, num components: 3
1, 2, 2, 0
2, 1, 1, 1
3, 1, 1, 1"""
    check($info == expected)
    check(info.precision == 8)
    check(info.width == 150)
    check(info.height == 100)
    check(info.components.len == 3)
    check(info.components[0] == (1u8, 2u8, 2u8, 0u8))
    check(info.components[1] == (2u8, 1u8, 1u8, 1u8))
    check(info.components[2] == (3u8, 1u8, 1u8, 1u8))

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

  # todo: test getIptcRecords
  # test "test getIptcRecords":
  #   # let folder = "/Users/steve/code/metarnim/testfiles"
  #   const folder = "."
  #   showSectionsFolder(folder)

  #   let filename = "testfiles/agency-photographer-example.jpg"
  #   # showSections(filename)

  #   var buffer = readSectionBuffer(filename, 0xed)
  #   # echo hexDump(buffer, 0x5FD0)

  #   var records = getIptcRecords(buffer)
  #   check(records.len == 52)
  #   check($records[1] == """02, 05, "drp2091169d"""")

  #   for record in records:
  #     # echo $record
  #     check(record.number == 2)
  #     check(record.data_set >= 0u8)
  #     check(record.str.len >= 0)

  #   let info = getIptcInfo(records)
  #   check(info.len == 18)
  #   # for k, v in info:
  #   #   echo k & "=" & v
  #   var keywords = info["25"].split(',')
  #   check(keywords.len == 34)
  #   check(keywords[0] == "North America")

  test "test SofInfoToMeta":

    var components = newSeq[tuple[c: uint8, h:uint8, v:uint8, tq:uint8]]()
    components.add((1u8, 3u8, 0x2u8, 3u8))
    components.add((4u8, 0x6u8, 0x5u8, 6u8))
    var info = SofInfo(precision: 8u8, width: 200u16, height: 100u16,
                        components: components)
    let json = $SofInfoToMeta(info)
    let expected = """{"precision":8,"width":200,"height":100,"components":[[1,3,2,3],[4,6,5,6]]}"""
    check(json == expected)


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


  test "test readSections few bytes":
    # Test with very small files to test that the code handles bogus
    # files well. The first test is of an empty file.

    # ff d8 ff marker1 length2
    var bytesList = newSeq[seq[uint8]]()
    bytesList.add(@[])
    bytesList.add(@[0xff'u8])
    bytesList.add(@[0xff'u8, 0xd8])
    bytesList.add(@[0xff'u8, 0xd8, 0xff])
    bytesList.add(@[0xff'u8, 0xd8, 0xff, 0xda])
    bytesList.add(@[0xff'u8, 0xd8, 0xff, 0xda, 0])
    bytesList.add(@[0xff'u8, 0xd8, 0xff, 0xda, 0, 0])

    for bytes in bytesList:
      # echo "bytes = " & $bytes

      var (file, filename) = createTestFile(bytes)
      defer:
        file.close()
        removeFile(filename)
      var gotException = false
      try:
        discard readSections(file)
      except UnknownFormatError, NotSupportedError:
        # echo getCurrentExceptionMsg()
        gotException = true
      check(gotException == true)

  test "test readSections shortest":
    # Shortest file we identify as a "jpeg". It passes and does not
    # return UnknownFormatError, but it will fail later with
    # NotSupportedError.
    let bytes = @[0xff'u8, 0xd8, 0xff, 0xda, 0, 2]

    var (file, filename) = createTestFile(bytes)
    defer:
      file.close()
      removeFile(filename)
    let sections = readSections(file)
    # for section in sections:
    #   echo $section
    check(sections.len == 4)

  test "test readJpeg":
    let filename = "testfiles/image.jpg"
    var file = openTestFile(filename)
    defer: file.close()
    var metadata = readJpeg(file)
    discard metadata
    # echo readable(metadata, "jpeg")
    check("APP0" in metadata)

  when false:
    test "write iptc.bin":
      # Write iptc data to file iptc.bin.

      var file = openTestFile("testfiles.extra/agency-photographer-example.jpg")
      defer: file.close()

      let bufferSize = 33422 - 24528
      var buffer = newSeq[uint8](bufferSize)
      file.setFilePos((int64)24528)
      if file.readBytes(buffer, 0, bufferSize) != bufferSize:
        fail()

      file = open("testfiles/iptc.bin", fmReadWrite)
      defer: file.close()
      if file.writeBytes(buffer, 0, buffer.len) != bufferSize:
        fail()

      # echo hexDumpSource(buffer)
      # echo hexDumpFileRange(file, 24528, 99706)

  test "iptc invalid buffer size":
    var ranges = newSeq[Range]()
    var buffer = [
      0xFF'u8, 0xED, 0x22, 0xBC, 0x50, 0x68, 0x6F, 0x74,
      0x6F, 0x73, 0x68, 0x6F, 0x70, 0x20, 0x33, 0x2E,
    ]
    try:
      let node = readIptc(buffer, 0, 7, ranges)
    except NotSupportedError:
      let msg = getCurrentExceptionMsg()
      check(msg == "Iptc: Invalid buffer size.")
    except:
      check("false" == "unexpected error")


  test "iptc invalid header":
    var ranges = newSeq[Range]()
    var buffer = [
      0xFF'u8, 0xEE, 0x22, 0xBC, 0x50, 0x68, 0x6F, 0x74,
      0x6F, 0x73, 0x68, 0x6F, 0x70, 0x20, 0x33, 0x2E,
      0x30, 0x00, 0x38, 0x42, 0x49, 0x4D, 0x04, 0x04,
      0x00, 0x00, 0x00, 0x00, 0x04, 0x8A, 0x1C, 0x02,
      0x00, 0x00, 0x02, 0x00, 0x02, 0x1C, 0x02, 0x05,
      0x00, 0x0B, 0x64, 0x72, 0x70, 0x32, 0x30, 0x39,
      0x31, 0x31,
    ]
    try:
      let node = readIptc(buffer, 0, buffer.len, ranges)
    except NotSupportedError:
      let msg = getCurrentExceptionMsg()
      check(msg == "Iptc: Invalid header.")
    except:
      check("false" == "unexpected error")


  test "iptc happy path":
    var ranges = newSeq[Range]()

    # Read the iptc data into the memory buffer.
    var file = openTestFile("testfiles/iptc.bin")
    defer: file.close()
    let fileSize = file.getFileSize()
    var buffer = newSeq[uint8](fileSize)
    file.setFilePos((int64)0)
    if file.readBytes(buffer, 0, buffer.len) != fileSize:
      fail()

    let node = readIptc(buffer, 0, buffer.len, ranges)
    # echo pretty(node)
    check(node["Headline(105)"].getStr() == "Lincoln Memorial")
    # for range in ranges:
    #   echo $range
    check(ranges.len > 20)
    check(ranges[0].start == 0)
    check(ranges[0].finish == 22)
    check(ranges[0].name == "iptc")
    check(ranges[0].message == "header")
    check(ranges[0].known == true)

  test "getDriInfo 4":
    var buffer = [
      0xFF'u8, 0xdd, 0x00, 0x04, 0x00, 0x01,
    ]
    let node = getDriInfo(buffer)
    # echo pretty(node)
    check(node["interval"].getInt() == 4)

  test "getDriInfo 1":
    var buffer = [
      0xFF'u8, 0xdd, 0x00, 0x04, 0x00,
    ]
    try:
      let node = getDriInfo(buffer)
    except NotSupportedError:
      let msg = getCurrentExceptionMsg()
      check(msg == "DRI: wrong size buffer.")
    except:
      check("false" == "unexpected error")

  test "getDriInfo 2":
    var buffer = [
      0xFE'u8, 0xdd, 0x00, 0x04, 0x00, 0x01,
    ]
    try:
      let node = getDriInfo(buffer)
    except NotSupportedError:
      let msg = getCurrentExceptionMsg()
      check(msg == "DRI: not 0xffdd.")
    except:
      check("false" == "unexpected error")


  test "getDriInfo 3":
    var buffer = [
      0xFF'u8, 0xdd, 0x00, 0x03, 0x00, 0x01,
    ]
    try:
      let node = getDriInfo(buffer)
    except NotSupportedError:
      let msg = getCurrentExceptionMsg()
      check(msg == "DRI: length not 4.")
    except:
      check("false" == "unexpected error")

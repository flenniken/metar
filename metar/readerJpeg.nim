##[
`Home <index.html>`_

readerJpeg
==========

The readerJpeg module reads JPEG images and returns its metadata. It
implements the reader interface.

]##

import tables
import strutils
import metadata
import tpub
import readBytes
import endians
import sequtils
import hexDump
import unicode
import json
import xmpparser

# See:
# http://vip.sugovica.hu/Sardi/kepnezo/JPEG%20File%20Layout%20and%20Format.htm

# see http://exiv2.org/iptc.html
const known_iptc_names = {
  5'u8: "Title",
  10'u8: "Urgency",
  15'u8: "Category",
  20'u8: "Other Categories",
  25'u8: "Keywords",
  40'u8: "Instructions",
  55'u8: "Date Created",
  80'u8: "Photographer",
  85'u8: "Photographer's Job Title",
  90'u8: "City",
  92'u8: "Location",
  95'u8: "State",
  101'u8: "Country",
  103'u8: "Reference",
  105'u8: "Headline",
  110'u8: "Credit",
  115'u8: "Source",
  116'u8: "Copyright",
  120'u8: "Description",
  122'u8: "Description Writer",
}.toOrderedTable

const known_jpeg_section_names = {
  0x01'u8: "TEM",
  # 02 - BF Reserved
  0xc0'u8: "SOF0",
  0xc1'u8: "SOF1",
  0xc2'u8: "SOF2",
  0xc3'u8: "SOF3",
  0xc4'u8: "SOF4",
  0xc5'u8: "SOF5",
  0xc6'u8: "SOF6",
  0xc7'u8: "SOF7",
  0xc8'u8: "JPG",
  0xc9'u8: "SOF9",
  0xca'u8: "SOF10",
  0xcb'u8: "SOF11",
  0xcd'u8: "SOF13",
  0xce'u8: "SOF14",
  0xcf'u8: "SOF15",
  0xc4'u8: "DHT",
  0xcc'u8: "DAC",
  0xd0'u8: "RST0",
  0xd1'u8: "RST1",
  0xd2'u8: "RST2",
  0xd3'u8: "RST3",
  0xd4'u8: "RST4",
  0xd5'u8: "RST5",
  0xd6'u8: "RST6",
  0xd7'u8: "RST7",
  0xd8'u8: "SOI",
  0xd9'u8: "EOI",
  0xda'u8: "SOS",
  0xdb'u8: "DQT",
  0xdc'u8: "DNL",
  0xdd'u8: "DRI",
  0xde'u8: "DHP",
  0xdf'u8: "EXP",
  0xe0'u8: "APP0",
  0xe1'u8: "APP1",
  0xe2'u8: "APP2",
  0xe3'u8: "APP3",
  0xe4'u8: "APP4",
  0xe5'u8: "APP5",
  0xe6'u8: "APP6",
  0xe7'u8: "APP7",
  0xe8'u8: "APP8",
  0xe9'u8: "APP9",
  0xea'u8: "APPA",
  0xeb'u8: "APPB",
  0xec'u8: "APPC",
  0xed'u8: "APPD",
  0xee'u8: "APPE",
  0xef'u8: "APPF",
  0xf0'u8: "JPG0",
  0xf1'u8: "JPG1",
  0xf2'u8: "JPG2",
  0xf3'u8: "JPG3",
  0xf4'u8: "JPG4",
  0xf5'u8: "JPG5",
  0xf6'u8: "JPG6",
  0xf7'u8: "JPG7",
  0xf8'u8: "JPG8",
  0xf9'u8: "JPG9",
  0xfa'u8: "JPGA",
  0xfb'u8: "JPGB",
  0xfc'u8: "JPGC",
  0xfd'u8: "JPGD",
  0xfe'u8: "COM",
}.toOrderedTable

# http://www.w3.org/Graphics/JPEG/itu-t81.pdf

const standAlone = {
    0x01'u8,
    0xd0'u8,
    0xd1'u8,
    0xd2'u8,
    0xd3'u8,
    0xd4'u8,
    0xd5'u8,
    0xd6'u8,
    0xd7'u8,
    0xd8'u8,
    0xd9'u8,
}


proc compareBytes(buffer: openArray[uint8|char], start: Natural,
                   str: string): bool {.tpub.} =
  ## Compare a section of the buffer with the given string. Start at
  ## the given index. Return true when they match.
  try:
    for ix, ch in str:
      if ch != (char)buffer[start+ix]:
        return false
  except:
    return false
  return true


proc stripInvalidUtf8(str: string): string {.tpub.} =
  ## Strip out invalid utf characters and return a new string.

  result = newStringOfCap(str.len)

  var start = 0
  while true:
    var pos = validateUtf8(str[start..<str.len])
    if pos == -1:
      pos = str.len

    for ix in start..<pos:
      result.add(str[ix])

    start = pos + 1
    if start > str.len:
      break


proc bytesToString(buffer: openArray[uint8|char], index: Natural=0,
                   length: Natural=0): string {.tpub.} =
  # Create a string from bytes in a buffer.  Use bytes starting at the
  # given index and use length bytes.
  if length == 0:
    return ""

  result = newStringOfCap(length)
  for ix in index..index+length-1:
    result.add((char)buffer[ix])

  # Strip invalid unicode characters.
  result = stripInvalidUtf8(result)

  # Remove 0 bytes.
  result = result.replace("\0")


# proc stringToBytes(str: string): seq[char] {.tpub.} =
#   # Convert a string to a list of bytes.
#   result = newSeq[char]()
#   for ch in string:
#     result.add(str[ch])



proc readSection(file: File, start: int64, finish: int64,
                 maxLength: Natural=64*1024): seq[uint8] {.tpub.} =
  ## Read the given section of the file. Raise an exception if
  ## finish-start > the maxLength.

  file.setFilePos(start)
  var length = finish - start
  if length > maxLength:
    raise newException(NotSupportedError, "Jpeg: max section length exceeded.")

  result = newSeq[uint8](length)
  if file.readBytes(result, 0, length) != length:
    raise newException(NotSupportedError, "Jpeg: unable to read all bytes.")


proc jpeg_section_name(value: uint8): string {.tpub.} =
  ## Return the name for the given jpeg section value or nil when not
  ## known.
  result = known_jpeg_section_names.getOrDefault(value)


proc iptc_name(value: uint8): string {.tpub.} =
  ## Return the iptc name for the given value or nil when not
  ## known.
  result = known_iptc_names.getOrDefault(value)




type
  IptcRecord = tuple[number: uint8, data_set: uint8, str: string] ## \
  ## Identifies an IPTC record. A number, byte identifier and a utf8 string.


proc `$`(self: IptcRecord): string {.tpub.} =
  result = "$1, $2, \"$3\"" % [
    toHex(self.number), toHex(self.data_set), self.str]


proc getIptcRecords(buffer: var openArray[uint8]): seq[IptcRecord] {.tpub.} =
  ## Return a list of all iptc records for the given iptc block.
  ## Raise a NotSupportedError exception for an invalid IPTC buffer.

  # See: http://www.iptc.org/IIM/ and
  # https://www.iptc.org/std/IIM/4.1/specification/IIMV4.1.pdf

  let size = buffer.len
  if size < 30 or size > 65502:
    raise newException(NotSupportedError, "Iptc: Invalid buffer size.")

  # ff, ed, length, ...
  if length2(buffer) != 0xffed:  # index 0, 1
    raise newException(NotSupportedError, "Iptc: Invalid header.")

  if length2(buffer, 2) + 2 > size: # index 2, 3
    raise newException(NotSupportedError, "Iptc: Invalid header length.")

  if not compareBytes(buffer, 4, "Photoshop 3.0"):
    raise newException(NotSupportedError, "Iptc: Not photoshop 3.")
  if buffer[17] != 0 or not compareBytes(buffer, 18, "8BIM"):
    raise newException(NotSupportedError, "Iptc: Not 0 8BIM.")
  # let type = length2(buffer, 22)  # index 22, 23

  # one = buffer[24]
  # two = buffer[25]
  # three = buffer[26]
  # four = buffer[27]
  let all_size = length2(buffer, 28)  # index 28, 29
  if all_size == 0 or all_size + 30 > size:
    raise newException(NotSupportedError, "Iptc: Inconsistent size.")

  # 5FD0  FF ED 22 BC 50 68 6F 74 6F 73 68 6F 70 20 33 2E  ..".Photoshop 3.
  # 5FE0  30 00 38 42 49 4D 04 04 00 00 00 00 04 8A 1C 02  0.8BIM..........
  # 5FF0  00 00 02 00 02 1C 02 05 00 0B 64 72 70 32 30 39  ..........drp209
  # 6000  31 31 36 39 64 1C 02 0A 00 01 31 1C 02 19 00 0D  1169d.....1.....
  # 6010  4E 6F 72 74 68 20 41 6D 65 72 69 63 61 1C 02 19  North America...
  # 6020  00 18 55 6E 69 74 65 64 20 53 74 61 74 65 73 20  ..United States
  # 6030  6F 66 20 41 6D 65 72 69 63 61 1C 02 19 00 07 41  of America.....A

  # 1C number(1) data_set(1) value_len(2)  value
  # 1c 2         0           2              0002
  # 1c 2         5           000B           drp2091169d
  # 1c 2         5           000B           drp2091169d
  # 1C 02        0A          0001           31
  # 1C 02        19          000D           North America
  # 1C 02        19          0018           United States of America

  var start = 30
  let finish = 30 + all_size
  # todo: decode this part of the iptc section:
  # echo hexDump(@buffer[finish..buffer.len-1])
  result = newSeq[IptcRecord]()
  while true:
    let marker = buffer[start + 0]
    if marker != 0x1c:
      raise newException(NotSupportedError, "Iptc: marker not 0x1c.")
    let number = buffer[start + 1]
    let data_set = buffer[start + 2]
    # index start+3, start+4
    let string_len = length2(buffer, start + 3)
    if string_len > 0x7fff:
      # The length is over 32k. The next length bytes (removing high bit)
      # are the count. But we don't support this.
      raise newException(NotSupportedError, "Iptc: over 32k.")
    if start + string_len > finish:
      raise newException(NotSupportedError, "Iptc: invalid string length.")
    var str = bytesToString(buffer, start + 5, string_len)

    # let record: IptcRecord = (number, data_set, str)
    result.add((number, data_set, str))
    start += string_len + 5
    if start >= finish:
      break  # done



type
  Section* = tuple[marker: uint8, start: int64, finish: int64] ## \ A
  ## section of a file. A section contains a byte identifier, the
  ## start offset and one past the ending offset.


proc `$`(section: Section): string {.tpub.} =
  # Return a string representation of a section.
  return "section = $1 ($2, $3) $4" % [toHex(section.marker),
    toHex0(section.start), toHex0(section.finish),
    toHex0(section.finish-section.start)]


proc readSections(file: File): seq[Section] {.tpub.} =
  ## Read the Jpeg file and return a list of sections.  Raise an
  ## UnknownFormatError exception when the file is not a jpeg.  Raise
  ## an NotSupportedError exception when the file cannot be decoded.

  # A JPEG starts with ff, d8.
  file.setFilePos(0)
  if read2(file) != 0xffd8:
    raise newException(UnknownFormatError, "Invalid JPEG, first bytes not 0xffd8.")

  result = @[]
  var finish: int64 = 2
  result.add((0xd8'u8, 0'i64, finish))

  while true:
    var start = finish
    if read1(file) != 0xff:
      raise newException(NotSupportedError, "Jpeg: byte not 0xff.")
    var marker = read1(file)
    if marker == 0xda:
      # The rest of the file except the last two bytes are the pixels.
      finish = file.getFileSize()
      result.add((marker, start, finish - 2))
      result.add((0xd9'u8, finish - 2, finish))
      break # done
    elif marker in standAlone:
      # When the marker is stand alone, it means there is no
      # associated block following the marker.
      result.add((marker, start, start + 2))
      if marker == 0xd9:
        break # done
    else:
      var length = read2(file)
      if length < 2:
        raise newException(NotSupportedError, "Jpeg: block is less than 2 bytes.")

      finish = start + int64(length + 2)
      result.add((marker, start, finish))
      file.setFilePos(finish)


proc findMarkerSections(file: File, marker: uint8): seq[Section] {.tpub.} =
  ## Read and return all the sections with the given marker.

  result = @[]
  var sections = readSections(file)
  for section in sections:
    if section.marker == marker:
      result.add(section)


# proc read2Check(file, "Invalid section length"): int =
#   ## Read two bytes big endian from the current file position.  If
#   ## there is not two bytes remaining, raise a NotSupportedError with
#   ## the given message.

#   # Read the block length.
#   let sectionLen = finish - start
#   if sectionLen < 4:
#     raise newException(NotSupportedError, "section length < 4")
#   let length = (int32)read2(file)
#   if length != sectionLen-2:
#     raise newException(NotSupportedError, "Invalid section length")

type
  SectionKind = tuple[name: string, data: seq[uint8]] ##\
  ## The section name and associated data.


proc xmpOrExifSection(file: File, start: int64, finish: int64):
                  SectionKind {.tpub.} =
  ## Determine whether the section is xmp or exif and return its name
  ## and associated string. Return an empty name when not xmp or exif.

  # ff, e1, length2, string+0, data

  if finish - start < 10:
    raise newException(NotSupportedError, "xmpExif: Section too short.")

  # Read the section.
  file.setFilePos(start)
  var buffer = readSection(file, start, finish)

  if length2(buffer, 0) != 0xffe1:
    raise newException(NotSupportedError, "xmpExif: section start not 0xffe1.")

  # Read the block length.
  let length = (int32)length2(buffer, 2)
  if length != finish - start - 2:
    raise newException(NotSupportedError, "xmpExif: invalid block length.")

  # Return the exif or xmp data. The block contains Exif|xmp, 0, data.
  const mtypes = {
    "exif": "Exif",
    "xmp": "http://ns.adobe.com/xap/1.0/",
  }.toOrderedTable

  result = ("", nil)
  for name, value in mtypes:
    if compareBytes(buffer, 4, value):
      let start = 4 + value.len + 1
      let length = buffer.len - start
      let data = buffer[start..<start+length]
      result = (name, data)


proc getIptcInfo(records: seq[IptcRecord]): OrderedTable[string, string] {.tpub.} =
  ## Extract the metadata from the iptc records.
  ## Return a dictionary.

  result = initOrderedTable[string, string]()
  var keywords = newSeq[string]()
  const keyword_key = 0x19
  for record in records:
    if record.number != 2:
      continue
    if record.data_set == 0:
      continue
      # result["ModelVersion"] = length2(record, 2)
    elif record.data_set == keyword_key:
      # Make a list of keywords.
      if record.str != nil:
        keywords.add(record.str)
    else:
      # The key is the data_set number.
      result[$record.data_set] = record.str

  if keywords.len > 0:
    result[$keyword_key] = keywords.join(",")
  return result

# procprocess_exif(exif):
#   """
#   Convert xp keys from 16 bit unicode to utf8 strings.
#   """
# # XPTitle(40091)
# # XPComment(40092)
# # XPAuthor(40093)
# # XPKeywords(40094)
# # XPSubject(40095)
#   for key in range(40091, 40095):
#     lofb = exif.get(key)
#     if lofb:
#       if lofb[-2] == 0 and lofb[-1] == 0:
#         ba = bytearray(lofb[:-2])
#       else:
#         ba = bytearray(lofb)
#       string = ba.decode("utf-16LE")
#       exif[key] = string

# # JPEGs with an SOF0 segment are known as Baseline JPEGs. They are
# # always lossy, not progressive, use Huffman coding, and have a bit
# # depth of 8. Every application that supports JPEG is supposed to at
# # least support Baseline JPEG.

# # Progressive JPEG rearranges the image data, so that the the first
# # part of it represents a very low quality version of the entire
# # image, rather than a high quality version of a small part of the
# # image. A progressive JPEG is identified by the presence of an
# # SOF2, SOF6, SOF10, or SOF14 segment.


# SOF0 (Start Of Frame 0) marker:
# Field                 Size       Description
# Marker Identifier     2 bytes    0xff, 0xc0 to identify SOF0 marker
# Length                2 bytes    This value equals to 8 + components*3 value
# Data precision        1 byte     This is in bits/sample, usually 8 (12 and 16 not supported by most software).
# Image height          2 bytes    This must be > 0
# Image Width           2 bytes    This must be > 0
# Number of components  1 byte     Usually 1 = grey scaled, 3 = color YcbCr or YIQ 4 = color CMYK
# Each component        3 bytes    Read each component data of 3 bytes.
# It contains, (component Id(1byte)(1 = Y, 2 = Cb, 3 = Cr, 4 = I, 5 = Q),
# sampling factors (1byte) (bit 0-3 vertical., 4-7 horizontal.),
# quantization table number (1 byte)).

# Remarks:     JFIF uses either 1 component (Y, greyscaled) or 3 components (YCbCr, sometimes called YUV, colour).

#  11932-11951 	     19 range_192
# 0000   FF C0 00 11 08 08 AB 0D 01 03 01 11 00 02 11 01    ................
# 0010   03 11 01                                           ...

# todo: make a macro like tpub for types.
type
  SofInfo* = ref object of RootObj
    precision*: uint8
    height*: uint16
    width*: uint16
    components*: seq[tuple[x: uint8, y:uint8, z:uint8]] ## \
  ## SofInfo contains the information from the JPEG SOF sections.

proc SofInfoToMeta(self: SofInfo): Metadata {.tpub.} =
  ## Return metadata for the given SofInfo object.

  result = newJObject()
  result["precision"] = newJInt((int)self.precision)
  result["width"] = newJInt((int)self.width)
  result["height"] = newJInt((int)self.height)
  var jarray = newJArray()
  for c in self.components:
    var comps = newJArray()
    comps.elems.add(newJInt((int)c.x))
    comps.elems.add(newJInt((int)c.y))
    comps.elems.add(newJInt((int)c.z))
    jarray.add(comps)
  result["components"] = jarray


proc `$`(self: SofInfo): string {.tpub.} =
  ## Return a string representation of the given SofInfo object.

  var lines = newSeq[string]()
  lines.add("precision: $1, width: $2, height: $3, num components: $4" % [
    $self.precision, $self.width, $self.height, $self.components.len])
  for c in self.components:
    lines.add("$1, $2, $3" % [$c.x, $c.y, $c.z])
  result = lines.join("\n")


proc getSofInfo(buffer: var openArray[uint8]): SofInfo {.tpub.} =
  ## Return the SOF information from the given buffer. Raise
  ## NotSupportedError when the buffer cannot be decoded.

  if buffer.len < 13:
    raise newException(NotSupportedError, "SOF: not enough bytes.")

  if buffer[0] != 0xff:  # index 0
    raise newException(NotSupportedError, "SOF: not 0xff.")

  if buffer[1] < 0xc0u8 or buffer[1] > 0xd0u8:  # index 1
    raise newException(NotSupportedError, "SOF: not in range.")

  let size = length2(buffer, 2)  # index 2, 3
  if size + 2 != buffer.len:
    raise newException(NotSupportedError, "SOF: wrong size.")

  let precision = buffer[4]  # index 4
  let height = (uint16)length2(buffer, 5)  # index 5, 6
  let width = (uint16)length2(buffer, 7)  # index 7, 8
  let number_components = (int)buffer[9]  # index 9

  if number_components < 1 or
     10 + 3 * number_components > buffer.len:
    raise newException(NotSupportedError, "SOF: number of components.")

  var components = newSeq[tuple[x: uint8, y:uint8, z:uint8]]()
  for ix in 0..number_components-1:
    let start = 10 + 3 * ix
    let x = buffer[start + 0]
    let y = buffer[start + 1]
    let z = buffer[start + 2]
    components.add((x, y, z))

  result = SofInfo(precision: precision, width: width, height: height,
                    components: components)

proc jpegKeyName*(section: string, key: string): string =
  ## Return the name of the key for the given section of metadata or
  ## nil when not known.

  try:
    if section == "iptc":
      return iptc_name(cast[uint8](parseUInt(key)))
    elif section == "offsets":
      # Strip off the leading range_ and trailing _xx.
      let parts = key.split({'_'})
      # let sectionKey = cast[uint8](parseUInt(parts[1]))
      let value = parseHexInt(parts[1])
      return jpeg_section_name(cast[uint8](value))
    # elif section == "exif":
    #   from .tiff import tag_name
    #   return tag_name(key)
  except:
    discard
  result = nil


proc readJpeg*(file: File): Metadata =
  ## Read the given file and return its metadata.  Return nil when the
  ## file format is unknown. It may generate UnknownFormatError and
  ## NotSupportedError exceptions.

  result = newJObject()
  let sections = readSections(file)

  var offsets = initOrderedTable[string, tuple[start:int64, finish:int64]]()
  var dups = initTable[string, int]()

  for section in sections:
    var (marker, start, finish) = section
    var name:string
    if marker == 0xe0:
      # todo: read the JFIF.
      # len2, "JFIF"0, major1, minor1, density units 1, x density 2, y
      # density 2, thumbnail width 1, thumbnail height 1, 3 * width * height thumbnail pixels.
      discard

    elif marker == 0xed:
      # Process IPTC metadata.
      var buffer = readSection(file, start, finish)
      let iptc_records = getIptcRecords(buffer)
      if iptc_records.len > 0:
        var info = getIptcInfo(iptc_records)
        var jInfo = newJObject()
        for k, v in info.pairs():
          jInfo[k] = newJString(v)
        result["iptc"] = jInfo
        name = "APPD($1)(range_iptc)" % [$marker]

    elif marker == 0xe1:
      # Could be xmp or exif.
      let sectionKind = xmpOrExifSection(file, start, finish)
      if sectionKind.name == "xmp":
        let xml = bytesToString(sectionKind.data, 0, sectionKind.data.len-1)
        result["xmp"] = xmpParser(xml)
        name = "APP1($1)(range_xmp)" % [$marker]
#[
      elif sectionKind.name == "exif":
        # Parse the exif. It is stored as a tiff file.
        from .tiff import read_header, read_ifd, print_ifd
        header_offset = start+4+len("exif\x00")+1
        ifd_offset, endian = read_header(file, header_offset)
        if ifd_offset is not nil:
          # print("ifd_offset = {}".format(ifd_offset))
          # print("endian = {}".format(endian))
          ifd = read_ifd(file, header_offset, endian, ifd_offset)
          # print_ifd("exif", ifd)
          process_exif(ifd)

          # Move the range_ keys to the offsets dictionary.
          delete_keys = []
          for key, value in ifd.items():
            if isinstance(key, str) and key.startswith("range_"):
              offsets[key] = value
              delete_keys.add(key)
          for key in delete_keys:
            del ifd[key]

          result["exif"] = ifd
          name = "APP1({})(range_exif)".format(marker)
]#

    # sof0 - sof15
    elif marker >= 0xc0u8 and marker < 0xc0u8 + 16u8:
      # There can be multiple c4.
      # sof4 = [{}, {}, {},...]
      var buffer = readSection(file, start, finish)
      let sofx = getSofInfo(buffer)
      let sofname = "sof$1" % [$(marker-192)]
      var list: JsonNode
      if result.hasKey(sofname):
        list = result[sofname]
      else:
        list = newJArray()
      list.add(SofInfoToMeta(sofx))
      result[sofname] = list
      name = "$1($2)(range_$3)" % [sofname, $marker, $marker]

    if name == nil:
      name = "range_" & $marker
    if name in offsets:
      # We have more than one section with the same marker. Create a
      # unigue name for it, by appending a number to the normal name,
      # i.e., range_d0_2.
      var count = dups.getOrDefault(name)
      if count == 0:
        count = 2
      else:
        count += 1
      dups[name] = count
      name = "$1_$2" % [name, $count]

    offsets[name] = (start, finish)

  var jOffsets = newJObject()
  for k, v in offsets.pairs:
    var a = newJArray()
    a.add(newJInt(v.start))
    a.add(newJInt(v.finish))
    jOffsets[k] = a
  result["offsets"] = jOffsets

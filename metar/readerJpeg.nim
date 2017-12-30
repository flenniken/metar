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

# See:
# http://vip.sugovica.hu/Sardi/kepnezo/JPEG%20File%20Layout%20and%20Format.htm

# from .XmpParser import parse_xmp_xml
# from .read_bytes import read1, read2, length1, length2


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

proc bytesToString(buffer: openArray[uint8|char], index: Natural,
                   length: Natural): string {.tpub.}=
  # Convert bytes in a buffer to a string. Start at the given index
  # and use length bytes.
  result = newStringOfCap(length)
  for ix in index..index+length-1:
    result.add((char)buffer[ix])

# proc stringToBytes(str: string): seq[char] {.tpub.} =
#   # Convert a string to a list of bytes.
#   result = newSeq[char]()
#   for ch in string:
#     result.add(str[ch])


proc jpeg_section_name(value: uint8): string {.tpub.} =
  ## Return the name for the given jpeg section value or nil when not
  ## known.
  result = known_jpeg_section_names.getOrDefault(value)

proc iptc_name(value: uint8): string {.tpub.} =
  ## Return the iptc name for the given value or nil when not
  ## known.
  result = known_iptc_names.getOrDefault(value)

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


type
  IptcRecord = tuple[number: uint8, data_set: uint8, str: string] ## \
  ## Identifies an IPTC record. A number, byte identifier and a utf8 string.

# todo: rename to $ all toString procs.
proc toString(self: IptcRecord): string {.tpub.} =
  result = "$1, $2, \"$3\"" % [
    toHex(self.number), toHex(self.data_set), self.str]

proc getIptcRecords(buffer: var openArray[uint8]): seq[IptcRecord] {.tpub.} =
  ## Return a list of all iptc records for the given iptc block.

  # See: http://www.iptc.org/IIM/ and
  # https://www.iptc.org/std/IIM/4.1/specification/IIMV4.1.pdf

  let size = buffer.len
  if size < 30 or size > 65502:
    # todo: rename NotSupported to NotSupportedError everywhere.
    # todo: rename all exception objects to end with "Error".
    raise newException(NotSupported, "Invalid iptc buffer size.")

  # ff, ed, length, ...
  if length2(buffer) != 0xffed:  # index 0, 1
    raise newException(NotSupported, "Invalid iptc header.")

  if length2(buffer, 2) + 2 > size: # index 2, 3
    raise newException(NotSupported, "Invalid iptc header length.")

  if not compareBytes(buffer, 4, "Photoshop 3.0"):
    raise newException(NotSupported, "Not photoshop 3.")
  if buffer[17] != 0 or not compareBytes(buffer, 18, "8BIM"):
    raise newException(NotSupported, "Not 0 8BIM.")
  # let type = length2(buffer, 22)  # index 22, 23

  # one = buffer[24]
  # two = buffer[25]
  # three = buffer[26]
  # four = buffer[27]
  let all_size = length2(buffer, 28)  # index 28, 29
  if all_size == 0 or all_size + 30 > size:
    raise newException(NotSupported, "Inconsistent size.")

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
  result = newSeq[IptcRecord]()
  while true:
    let marker = buffer[start + 0]
    if marker != 0x1c:
      break  # done
    let number = buffer[start + 1]
    let data_set = buffer[start + 2]
    # index start+3, start+4
    let string_len = length2(buffer, start + 3)
    if string_len > 0x7fff:
      # The length is over 32k. The next length bytes (removing high bit)
      # are the count. But we don't support this.
      raise newException(NotSupported, "Over 32k.")
    if start + string_len > finish:
      return # Bad format.
    var str = bytesToString(buffer, start + 5, string_len)
    if validateUtf8(str) != -1:
      str = ""
    else:
      # Remove 0 bytes.
      str = str.replace("\0")

    # let record: IptcRecord = (number, data_set, str)
    result.add((number, data_set, str))
    start += string_len + 5
    if start >= finish:
      break  # done



proc readJpeg*(file: File): Metadata =
  ## Read the given file and return its metadata.  Return nil when the
  ## file format is unknown. It may generate UnknownFormat and
  ## NotSupported exceptions.
  return nil


type
  Section = tuple[marker: uint8, start: int64, finish: int64] ## \ A
  ## section of a file. A section contains a byte identifier, the
  ## start offset and one past the ending offset.

proc toString(section: Section): string {.tpub.} =
  # Return a string representation of a section.
  return "section = $1 ($2, $3) $4" % [toHex(section.marker),
    toHex0(section.start), toHex0(section.finish),
    toHex0(section.finish-section.start)]


proc readSections(file: File): seq[Section] {.tpub.} =
  ## Read the Jpeg file and return a list of sections.  Raise an
  ## UnknownFormat exception when the file is not a jpeg.  Raise an
  ## NotSupported exception when the file is bad.

  # A JPEG starts with ff, d8.
  file.setFilePos(0)
  if read2(file) != 0xffd8:
    raise newException(UnknownFormat, "Invalid JPEG, first bytes not 0xffd8.")

  result = @[]
  var finish: int64 = 2
  result.add((0xd8'u8, 0'i64, finish))

  while true:
    var start = finish
    if read1(file) != 0xff:
      raise newException(NotSupported, "Invalid JPEG. Byte not 0xff.")
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
        raise newException(NotSupported, "Invalid JPEG, block is less than 2 bytes.")

      finish = start + int64(length + 2)
      result.add((marker, start, finish))
      file.setFilePos(finish)


type
  SectionKind = tuple[name: string, data: string] ## The section name and data.

proc xmpOrExifSection(file: File, key: uint8, start: int64, finish: int64):
                  SectionKind {.tpub.} =
  ## Determine whether the section is xmp or exif and return its name
  ## and associated string. Return an empty name when not xmp or exif.

  result = ("", "")
  if key != 0xe1:
    result.data = "key not e1"
    return

  # ff, e1, length, string+0, data
  # length + 2 is the total section length.
  file.setFilePos(start)
  if read2(file) != 0xffe1:
    result.data = "not ffe1"
    return

  # Read the block length.
  let sectionLen = finish - start
  if sectionLen < 4:
    result.data = "section length < 4"
    return
  let length = (int32)read2(file)
  if length != sectionLen-2:
    result.data = "Invalid section length, " & $length & " != " & $(sectionLen-2)
    return

  # Read in the block to the buffer.
  var buffer: seq[char]
  buffer.newSeq(length-2)
  if file.readChars(buffer, 0, length-2) != length-2:
    result.data = "did not read enough"
    return

  # Return the exif or xmp data. The block contains Exif|xmp, 0, data.
  const sections = {
    "exif": "Exif",
    "xmp": "http://ns.adobe.com/xap/1.0/",
  }.toOrderedTable

  for key, value in sections:
    if buffer.len > value.len+2:
      if compareBytes(buffer, 0, value):
        let str = bytesToString(buffer, value.len+1, buffer.len - value.len - 1)
        return (key, str)

  result.data = "section not xmp or exif"

#[
proc readMetadata*(file: File): Metadata =
  ## Read and return the file metadata.

  var sections = readSections(file)

  file.setFilePos(0)
  # file_size = file.getFileSize()

  offsets = OrderedDict()
  dups = {}.toTable

  for key, start, finish in sections:
    name = nil
    if key == 0xe0:
      # todo: read the JFIF.
      # len2, "JFIF"0, major1, minor1, density units 1, x density 2, y
      # density 2, thumbnail width 1, thumbnail height 1, 3 * width * height thumbnail pixels.
      discard

    elif key == 0xed:
      # IPTC
      file.setFilePos(start)
      buffer = file.read(finish - start)
      iptc_records = getIptcRecords(buffer)
      if iptc_records:
        result["iptc"] = getIptcInfo(iptc_records)
        name = "APPD({})(range_iptc)".format(key)

    elif key == 0xe1:
      # Could be xmp or iptc.
      data = xmpOrExifSection(file, key, start, finish)
      if not data:
        continue
      kind, metadata_bytearray = data
      if kind == "xmp":
        xmp_bytearray = bytearray(metadata_bytearray)
        result["xmp"] = parse_xmp_xml(xmp_bytearray)
        name = "APP1({})(range_xmp)".format(key)
      elif kind == "exif":
        # Parse th exif, it is stored as a tiff file.
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
          name = "APP1({})(range_exif)".format(key)

    # sof0 - sof15
    elif key >= 0xc0 and key < 0xc0 + 16: # 192, 192 + 16

# SOF0 (Start Of Frame 0) marker:
# Field                 Size       Description
# Marker Identifier     2 bytes    0xff, 0xc0 to identify SOF0 marker
# Length                2 bytes    This value equals to 8 + components*3 value
# Data precision        1 byte     This is in bits/sample, usually 8 (12 and 16 not supported by most software).
# Image height          2 bytes    This must be > 0
# Image Width           2 bytes    This must be > 0
# Number of components  1 byte     Usually 1 = grey scaled, 3 = color YcbCr or YIQ 4 = color CMYK
# Each component        3 bytes    Read each component data of 3 bytes. It contains, (component Id(1byte)(1 = Y, 2 = Cb, 3 = Cr, 4 = I, 5 = Q), sampling factors (1byte) (bit 0-3 vertical., 4-7 horizontal.), quantization table number (1 byte)).

# Remarks:     JFIF uses either 1 component (Y, greyscaled) or 3 components (YCbCr, sometimes called YUV, colour).


      file.setFilePos(start)
      buffer = file.read(finish - start)
      sofx = getSOF0Info(buffer)
      if sofx:
        sofname = "sof{}".format(key-192)
        result[sofname] = sofx
        name = "{}({})(range_{})".format(sofname, key, key)

    if not name:
      name = "range_{}".format(key)
    if name in offsets:
      # We have more than one section with the same key. Create a
      # unigue name for it, by appending a number to the normal name,
      # i.e., range_d0_2.
      count = dups.get(name)
      if count:
        count += 1
      else:
        count = 2
      dups[name] = count
      name = "{}_{}".format(name, count)
    offsets[name] = (start, finish)

  result["offsets"] = offsets
]#

# #todo: change "offset" to section? or range?


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


type
  Sof0Info = ref object of RootObj
    precision*: uint8
    height*: uint16
    width*: uint16
    components*: seq[tuple[x: uint8, y:uint8, z:uint8]]

proc toString(self: Sof0Info): string {.tpub.} =
  var lines = newSeq[string]()
  lines.add("precision: $1, width: $2, height: $3, num components: $4" % [
    $self.precision, $self.width, $self.height, $self.components.len])
  for c in self.components:
    lines.add("$1, $2, $3" % [$c.x, $c.y, $c.z])
  result = lines.join("\n")

proc getSof0Info(buffer: var openArray[uint8]): Sof0Info {.tpub.} =
  ## Return the SOF0 information from the given buffer. Raise
  ## NotSupported when the buffer cannot be decoded.

  if buffer.len < 13:
    raise newException(NotSupported, "Invalid SOF0, not enough bytes.")

  if length2(buffer) != 0xffc0:  # index 0, 1
    raise newException(NotSupported, "Invalid SOF0, not 0xffc0.")

  let size = length2(buffer, 2)  # index 2, 3
  if size + 2 != buffer.len:
    raise newException(NotSupported, "Invalid SOF0, wrong size.")

  let precision = buffer[4]  # index 4
  let height = (uint16)length2(buffer, 5)  # index 5, 6
  let width = (uint16)length2(buffer, 7)  # index 7, 8
  let number_components = (int)buffer[9]  # index 9

  if number_components < 1 or
     10 + 3 * number_components > buffer.len:
    raise newException(NotSupported, "Invalid SOF0, number of components.")

  var components = newSeq[tuple[x: uint8, y:uint8, z:uint8]]()
  for ix in 0..number_components-1:
    let start = 10 + 3 * ix
    let x = buffer[start + 0]
    let y = buffer[start + 1]
    let z = buffer[start + 2]
    components.add((x, y, z))

  result = Sof0Info(precision: precision, width: width, height: height,
                    components: components)

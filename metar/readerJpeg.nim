# See: test_readerJpeg.nim(0):

## The readerJpeg module reads JPEG images and returns its metadata. It
## implements the reader interface.

import tables
import strutils
import metadata
import tpub
import readNumber
import endians
import sequtils
import unicode
import json
import xmpparser
import bytesToString
import algorithm
import ranges
import imageData
import tiff
import tiffTags
import hexDump


tpubType:
  type
    SectionInfo = object
      name*: string
      node*: JsonNode
      known*: bool

    Section = tuple[marker: uint8, start: int64, finish: int64] ## \ A
    ## section of a file. A section contains a byte identifier, the
    ## start offset and one past the ending offset.


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
  ## Return the name for the given jpeg section value or "" when not
  ## known.
  result = known_jpeg_section_names.getOrDefault(value)
  if result == nil:
    result = ""


proc iptc_name(value: uint8): string {.tpub.} =
  ## Return the iptc name for the given value or "" when not known.
  result = known_iptc_names.getOrDefault(value)
  if result == nil:
    result = ""


type
  IptcRecord = object
    ## Identifies an IPTC record.  When the iptc record cannot be
    ## decoded, the error is set and the string is the error message.
    number*: uint8
    data_set*: uint8
    str*: string
    error*: bool




# when not defined(release):
#   proc `$`(self: IptcRecord): string {.tpub.} =
#     result = "$1, $2, \"$3\"" % [
#       toHex(self.number), toHex(self.data_set), self.str]

# todo: treat iptc like exif where each record is a range. Remove * logic.

proc getIptcRecords(buffer: var openArray[uint8]): seq[IptcRecord] {.tpub.} =
  ## Return a list of all iptc records for the given iptc block.
  ## Raise a NotSupportedError exception for an invalid IPTC buffer.

  # See: http://www.iptc.org/IIM/ and
  # https://www.iptc.org/std/IIM/4.1/specification/IIMV4.1.pdf

  let size = buffer.len
  if size < 30 or size > 65502:
    raise newException(NotSupportedError, "Iptc: Invalid buffer size.")

  if length2(buffer, 0) != 0xffed:  # index 0, 1
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
    var str: string
    try:
      str = bytesToString(buffer, start + 5, string_len)
      result.add(IptcRecord(number: number, data_set: data_set, str: str, error: false))
    except NotSupportedError:
      str = getCurrentExceptionMsg()
      result.add(IptcRecord(number: number, data_set: data_set, str: str, error: true))

    start += string_len + 5
    if start >= finish:
      break  # done




# proc `$`(section: Section): string {.tpub.} =
#   ## Return a string representation of a section.
#   return "section = $1 ($2, $3) $4" % [toHex(section.marker),
#     toHex0(section.start), toHex0(section.finish),
#     toHex0(section.finish-section.start)]


proc readSectionsRaw(file: File): seq[Section] =
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
  var foundSos = false

  while true:
    var start = finish

    if foundSos:
      # The rest of the file except the last two bytes are the pixels.
      finish = file.getFileSize()
      # Use 0 marker for the pixels.
      result.add((0'u8, start, finish - 2))
      result.add((0xd9'u8, finish - 2, finish))
      break # done

    if read1(file) != 0xff:
      raise newException(NotSupportedError, "Jpeg: byte not 0xff.")
    var marker = read1(file)

    if marker == 0xda:
      foundSos = true
    elif marker in standAlone:
      # When the marker is stand alone, it means there is no
      # associated block following the marker.
      result.add((marker, start, start + 2))
      continue

    var length = read2(file)
    if length < 2:
      raise newException(NotSupportedError, "Jpeg: block is less than 2 bytes.")

    finish = start + int64(length + 2)
    result.add((marker, start, finish))
    file.setFilePos(finish)


proc readSections(file: File): seq[Section] {.tpub.} =
  # Read sections and handle errors.
  try:
    result = readSectionsRaw(file)
  except UnknownFormatError, NotSupportedError:
    raise
  except:
    # This handles the cases where the file doesn't have enough bytes.
    raise newException(UnknownFormatError, "Invalid JPEG")


when not defined(release):
  proc findMarkerSections(file: File, marker: uint8): seq[Section] {.tpub.} =
    ## Read and return all the sections with the given marker.

    result = @[]
    var sections = readSections(file)
    for section in sections:
      if section.marker == marker:
        result.add(section)


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

  for name, value in mtypes:
    if compareBytes(buffer, 4, value):
      let start = 4 + value.len + 1
      let length = buffer.len - start
      let data = buffer[start..<start+length]
      return (name, data)
  result = ("", nil)


# proc getIptcInfo(records: seq[IptcRecord]): OrderedTable[string, string] {.tpub.} =
#   ## Extract the metadata from the iptc records.
#   ## Return a dictionary.

#   result = initOrderedTable[string, string]()
#   var keywords = newSeq[string]()
#   const keyword_key = 0x19
#   for record in records:
#     # if record.number != 2:
#     #   continue
#     # if record.data_set == 0:
#     #   continue
#       # result["ModelVersion"] = length2(record, 2)
#     if record.error:
#       # todo: put * after left side instead.
#       result[$record.data_set] =  "* " & record.str

#     elif record.data_set == keyword_key:
#       # Make a list of keywords.
#       if record.str != nil:
#         keywords.add(record.str)
#     else:
#       # The key is the data_set number.
#       result[$record.data_set] = record.str

#   if keywords.len > 0:
#     result[$keyword_key] = keywords.join(",")
#   return result

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

tpubType:
  type
    SofInfo = ref object of RootObj
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


when not defined(release):
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

  if buffer.len < 10:
    raise newException(NotSupportedError, "SOF: buffer too small.")

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

proc getHdtInfo(buffer: var openArray[uint8]): Metadata {.tpub.} =
  ## Return the HDT information from the given buffer. Raise
  ## NotSupportedError when the buffer cannot be decoded.

  # 0000  FF C4 00 1F 00 00 01 05 01 01 01 01 01 01 00 00  ................
  # 0010  00 00 00 00 00 00 01 02 03 04 05 06 07 08 09 0A  ................
  # 0020  0B

  # A single DHT segment may contain multiple HTs, each with its own
  # information byte.

  result = newJObject()

  if length2(buffer, 0) != 0xffc4:  # index 0, 1
    raise newException(NotSupportedError, "DHT: not 0xffc4.")

  let size = length2(buffer, 2)  # index 2, 3
  if size + 2 != buffer.len:
    raise newException(NotSupportedError, "DHT: wrong size.")

  # HT information 1 byte -- bit 0..3 : number of HT (0..3, otherwise error)
  #   bit 4     : type of HT, 0 = DC table, 1 = AC table
  #   bit 5..7 : not used, must be 0
  let bits = buffer[4]  # index 4
  # 0 1 2 3 number of HT
  #         4 -- type of HT, 0 = DC table, 1 = AC table
  #           5 6 7 -- 0
  #
  result["bits"] = newJInt((int)bits)
  # let acdcTable = bits and 0b1000
  # let numberHT = bits and 0b11110000 >> 4

  # Number of Symbols 16 bytes -- Number of symbols with codes of
  # length 1..16, the sum of these bytes is the total number of codes,
  # which must be <= 256.
  var counts = newJArray()
  var sum = 0
  for ix in 0..15:
    let num = buffer[ix+5]
    counts.add(newJInt((int)num))
    sum += (int)num
  if sum > 256:
    raise newException(NotSupportedError, "DHT: more than 256 symbols.")
  if sum+21 != buffer.len:
    raise newException(NotSupportedError, "DHT: more symbols than space.")
  result["counts"] = counts
  # result["sum"] = newJInt(sum)

  # The symbols in order of increasing code length.
  var symbols = newJArray()
  for ix in 0..sum-1:
    symbols.add(newJInt((int)buffer[ix+21]))
  result["symbols"] = symbols


proc getDqtInfo(buffer: var openArray[uint8]): Metadata {.tpub.} =
  ## Return the DQT Define Quantization Table information from the
  ## given buffer. Raise NotSupportedError when the buffer cannot be
  ## decoded.

  # 0000  FF DB 00 43 00 08 06 06 07 06 05 08 07 07 07 09  ...C............
  # 0010  09 08 0A 0C 14 0D 0C 0B 0B 0C 19 12 13 0F 14 1D  ................
  # 0020  1A 1F 1E 1D 1A 1C 1C 20 24 2E 27 20 22 2C 23 1C  ....... $.' ",#.
  # 0030  1C 28 37 29 2C 30 31 34 34 34 1F 27 39 3D 38 32  .(7),01444.'9=82
  # 0040  3C 2E 33 34 32

  # QT information 1 byte  bit 0..3: number of QT (0..3, otherwise error)
  #                        bit 4..7: precision of QT, 0 = 8 bit, otherwise 16 bit
  # Bytes    n bytes       This gives QT values, n = 64*(precision+1)

  result = newJObject()

  if buffer.len < 69:
    raise newException(NotSupportedError, "DQT: buffer too small.")

  if length2(buffer, 0) != 0xffdb:  # index 0, 1
    raise newException(NotSupportedError, "DQT: not 0xffdb.")

  let size = length2(buffer, 2)  # index 2, 3
  if size + 2 != buffer.len:
    raise newException(NotSupportedError, "DQT: wrong size.")

  let bits = buffer[4]  # index 4
  result["bits"] = newJInt((int)bits)
  # let num = bits and 0b1111
  let precision = (bits and 0b11110000) shr 4
  let count = 64*((int)precision+1)
  # echo "num = " & $(int)num
  # echo "precision = " & $(int)precision
  # echo "count = " & $(int)count
  # echo hexDump(@buffer)

  if count+5 != buffer.len:
    raise newException(NotSupportedError, "DQT: more QTs than space.")

  var qts = newJArray()
  for ix in 0..count-1:
    qts.add(newJInt((int)buffer[ix+5]))
  result["qts"] = qts


proc getSosInfo(buffer: var openArray[uint8]): Metadata {.tpub.} =
  ## Return the SOS Start Of Scan information from the given
  ## buffer. Raise NotSupportedError when the buffer cannot be
  ## decoded.

  # 0000  FF DA 00 0C 03 01 00 02 11 03 11 00 3F 00        ............?.

# Number of Components in scan  1 byte This must be >= 1 and <=4 (otherwise error), usually 1 or 3
# Each component        2 bytes      For each component, read 2 bytes. It contains,
#        1 byte   Component Id (1=Y, 2=Cb, 3=Cr, 4=I, 5=Q),
#        1 byte   Huffman table to use :
#             bit 0..3 : AC table (0..3)
#             bit 4..7 : DC table (0..3)
# Ignorable Bytes          3 bytes      We have to skip 3 bytes.
# Remarks:    The image data (scans) is immediately following the SOS segment.

  result = newJObject()

  if buffer.len < 10:
    raise newException(NotSupportedError, "SOS: buffer too small.")

  if length2(buffer, 0) != 0xffda:  # index 0, 1
    raise newException(NotSupportedError, "SOS: not 0xffda.")

  let size = length2(buffer, 2)  # index 2, 3
  if size + 2 != buffer.len:
    raise newException(NotSupportedError, "SOS: wrong buffer size.")

  let numberOfComponents = (int)buffer[4]  # index 4
  if numberOfComponents < 1 or numberOfComponents > 4:
    raise newException(NotSupportedError, "SOS: invalid number of components.")

  if numberOfComponents * 2 + 5 + 3 > buffer.len:
    raise newException(NotSupportedError, "SOS: no space for components.")

  var components = newJArray()
  var offset = 5
  for ix in 1..numberOfComponents:
    var component = newJArray()
    component.add(newJInt((int)buffer[offset]))
    component.add(newJInt((int)buffer[offset+1]))
    components.add(component)
    offset += 2
  result["components"] = components
  result["skip1"] = newJInt((int)buffer[offset+0])
  result["skip2"] = newJInt((int)buffer[offset+1])
  result["skip3"] = newJInt((int)buffer[offset+2])


proc getDriInfo(buffer: var openArray[uint8]): Metadata {.tpub.} =
  ## Return the DRI Define Restart Interval information from the given
  ## buffer. Raise NotSupportedError when the buffer cannot be
  ## decoded.

  # 0000  FF DD 00 04 00 01

  result = newJObject()

  if buffer.len != 6:
    raise newException(NotSupportedError, "DRI: wrong size buffer.")

  if length2(buffer, 0) != 0xffdd:  # index 0, 1
    raise newException(NotSupportedError, "DRI: not 0xffdd.")

  let size = length2(buffer, 2)  # index 2, 3
  if size != 4:
    raise newException(NotSupportedError, "DRI: length not 4.")

  let interval = length2(buffer, 2)  # index 4, 5
  result["interval"] = newJInt((int)interval)


proc keyNameJpeg(section: string, key: string): string {.tpub.} =
  ## Return the name of the key for the given section of metadata or
  ## "" when not known.

  try:
    if section == "iptc":
      # Handle unknown iptc records (name ending with *).
      var unknown = false
      var num_str: string
      if key.len > 1 and key[key.len-1] == '*':
        unknown = true
        num_str = key[0..<key.len-1]
      else:
        num_str = key

      var name = iptc_name(cast[uint8](parseUInt(num_str)))
      if name == "":
        name = $num_str

      if unknown:
        return name & "*"
      else:
        return name

    elif section == "ranges":
      return jpeg_section_name(cast[uint8](parseUInt(key)))
    elif section == "exif":
      return tagName(key)
  except:
    discard
  result = ""

proc getApp0(buffer: var openArray[uint8]): Metadata {.tpub.} =
  ## Return the jfif metadata information for the given buffer.  Raise
  ## an NotSupportedError when the buffer cannot be decoded.

  # ----------APP0(224)----------
  # 0000  FF E0 00 10 4A 46 49 46 00 01 01 01 00 60 00 60  ....JFIF.....`.`
  # 0010  00 00

  # len2, "JFIF"0, major1, minor1, density units 1, x density 2, y
  # density 2, thumbnail width 1, thumbnail height 1, 3 * width * height thumbnail pixels.

  result = newJObject()

  if length2(buffer, 0) != 0xffe0: # index 0, 1
    raise newException(NotSupportedError, "jfif: Invalid header.")

  var length = length2(buffer, 2) # index 2, 3
  if length > buffer.len-2:
    raise newException(NotSupportedError, "jfif: Invalid length.")

  if not compareBytes(buffer, 4, "JFIF") or buffer[8] != 0u8:
    raise newException(NotSupportedError, "jfif: Not JFIF0.")

  result["major"] = newJInt((int)buffer[9])
  result["minor"] = newJInt((int)buffer[10])

  result["units"] = newJInt((int)buffer[11])
  result["x"] = newJInt(length2(buffer, 12))
  result["y"] = newJInt(length2(buffer, 14))
  result["width"] = newJInt((int)buffer[16])
  result["height"] = newJInt((int)buffer[17])

  # todo: If width and height are not 0, the thumbnail image follows.

proc length2l(buffer: var openArray[uint8], index: Natural=0): int =
  ## Read two bytes from the buffer in big-endian starting at the
  ## given index.
  return (int)length[uint16](buffer, index, littleEndian)

proc getAppeInfo(buffer: var openArray[uint8]): Metadata {.tpub.} =
  # Get the Adobe APPE metadata.

  # 0000  FF EE 00 0E 41 64 6F 62 65 00 64 00 00 00 00 01  ....Adobe.d.....
  result = newJObject()

  if length2(buffer, 0) != 0xffee: # index 0, 1
    raise newException(NotSupportedError, "appe: Invalid header.")

  var length = length2(buffer, 2) # index 2, 3
  if length > buffer.len-2:
    raise newException(NotSupportedError, "appe: Invalid length.")

  if not compareBytes(buffer, 4, "Adobe") or buffer[9] != 0u8:
    raise newException(NotSupportedError, "appe: Not Adobe.")

  var version = length2l(buffer, 10)
  if version != 0x64:
    raise newException(NotSupportedError, "appe: unknown version")
  result["version"] = newJInt((int)version)

  # Two-byte flags0 0x8000 bit: Encoder used Blend=1 downsampling
  var flags0 = length2l(buffer, 12)
  result["flags0"] = newJInt((int)flags0)

  var flags1 = length2l(buffer, 14)
  result["flags1"] = newJInt((int)flags1)

  # # One-byte color transform code
  # result["transform"] = newJInt((int)buffer[16])


proc handleSection2(file: File, section: Section, imageData: var ImageData,
          ranges: var seq[Range]): SectionInfo {.tpub.} =
  ## Handle a section of the jpeg file. Return the section information
  ## and fill in the image data and ranges.

  var (marker, start, finish) = section
  var sectionName = jpeg_section_name(marker)
  var node: JsonNode
  var known = true
  var rangesAdded = false

  # Read the section into memory, except for a couple of types.
  var buffer: seq[uint8]
  if marker != 0 and marker != 0xe1:
    buffer = readSection(file, start, finish)

  case marker
  of 0:
    # The pixel scan lines.
    sectionName = "scans"
    imageData.pixelOffsets.add((start, finish))

  of 0xd8, 0xd9:
    # SOI(216) 0xd8, 0xffd8 header
    # EOI(217) 0xd9, 0xffd9 footer
    discard

  of 0xed:
    # APPD, IPTC metadata.
    sectionName = "iptc"

    var allKnown = true
    node = newJObject()
    for record in getIptcRecords(buffer):
      if record.error:
        allKnown = false
        node[$record.data_set & "*"] = newJString(record.str)
      else:
        node[$record.data_set] = newJString(record.str)

    var message: string
    if not allKnown:
      message = "Some IPTC records were not decoded."
    else:
      message = ""
    ranges.add(newRange(start, finish, sectionName, allKnown, message))
    rangesAdded = true


  of 0xe1:
    # APP1, Could be xmp or exif.
    let sectionKind = xmpOrExifSection(file, start, finish)
    if sectionKind.name == "xmp":
      let xml = bytesToString(sectionKind.data, 0, sectionKind.data.len-1)
      sectionName = "xmp"
      node = xmpParser(xml)

    elif sectionKind.name == "exif":
      # Parse the exif.
      sectionName = "exif"
      let headerOffset = start + 10
      ranges.add(Range(name: sectionName, start: start, finish: headerOffset,
                     known: true, message: "id"))
      # Make sure casts to uint32 are ok.
      if headerOffset > ((int64)high(uint32)) or finish > ((int64)high(uint32)):
        raise newException(NotSupportedError, "invalid large offset.")
      node = readExif(file, (uint32)headerOffset, (uint32)finish, ranges)
      rangesAdded = true

  of 0xc0:
    # SOF0(192) 0xc0
    let sofx = getSofInfo(buffer)
    imageData.width = (int)sofx.width
    imageData.height = (int)sofx.height
    node = SofInfoToMeta(sofx)

  of 0xc4:
    # DHT(196) 0xc4, Define Huffman Table
    node = getHdtInfo(buffer)

  of 0xe0:
    # APP0(224) 0xe0, jfif metadata
    # todo: support jfxx too:
    # https://en.wikipedia.org/wiki/JPEG_File_Interchange_Format#JFIF_APP0_marker_segment
    node = getApp0(buffer)
    sectionName = "jfif"

  of 0xdb:
    # DQT(219) 0xdb, Define Quantization Table
    node = getDqtInfo(buffer)

  of 0xda:
    # SOS(218) 0xda
    node = getSosInfo(buffer)

  of 0xdd:
    # DRI (Define Restart Interval)
    node = getDriInfo(buffer)

  of 0xee:
    # APPE, Adobe Application-Specific JPEG Marker
    # http://www.lprng.com/RESOURCES/ADOBE/5116.DCT_Filter.pdf
    node = getAppeInfo(buffer)

  else:
    # echo "$1($2) 0x$3" % [sectionName, $marker, toHex(marker).toLowerAscii()]
    # let finish = if buffer.len > 200: 200 else: buffer.len-1
    # echo hexDump(buffer[0..finish])
    # echo hexDumpSource(buffer[0..finish])
    known = false

  # Add in the overall range when the range hasn't already been handled.
  if not rangesAdded:
    ranges.add(newRange(start, finish, sectionName, known, ""))

  result = SectionInfo(name: sectionName, node: node, known: known)


proc handleSection(file: File, section: Section, imageData: var ImageData,
          ranges: var seq[Range]): SectionInfo {.tpub.} =

  # Catch errors for a section and mark it unknown.
  try:
    result = handleSection2(file, section, imageData, ranges)
  except NotSupportedError:
    let message = getCurrentExceptionMsg()
    var sectionName = jpeg_section_name(section.marker)
    ranges.add(newRange(section.start, section.finish, sectionName, false, message))


proc readJpeg(file: File): Metadata {.tpub.} =
  ## Read the given JPEG file and return its metadata.  Return
  ## UnknownFormatError when the file format is unknown.

  result = newJObject()
  var dups = initTable[string, int]()
  var imageData = newImageData()
  var ranges = newSeq[Range]()

  let sections = readSections(file)
  for section in sections:
    let sectionInfo = handleSection(file, section, imageData, ranges)
    if sectionInfo.node != nil:
      addSection(result, dups, sectionInfo.name, sectionInfo.node)

  let imageNode = createImageNode(imageData)
  if imageNode == nil:
    raise newException(NotSupportedError, "image data not found.")
  addSection(result, dups, "image", imageNode)

  # todo: xmp range should appear in the ranges list not APP1.
  let fileSize = file.getFileSize()
  let rangesNode = createRangesNode(file, 0, fileSize, ranges)
  addSection(result, dups, "ranges", rangesNode)


const reader* = (read: readJpeg, keyName: keyNameJpeg)

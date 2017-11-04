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

# See:
# http://vip.sugovica.hu/Sardi/kepnezo/JPEG%20File%20Layout%20and%20Format.htm

# from .XmpParser import parse_xmp_xml
# from .read_bytes import readOne, readTwo, length1, length2




# see http://exiv2.org/iptc.html
let known_iptc_names = {
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

let known_jpeg_section_names = {
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

# let standAlone = {
#     0x01,
#     0xd0,
#     0xd1,
#     0xd2,
#     0xd3,
#     0xd4,
#     0xd5,
#     0xd6,
#     0xd7,
#     0xd8,
#     0xd9,
# }.toOrderedTable

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
    # elif section == 'exif':
    #   from .tiff import tag_name
    #   return tag_name(key)
  except:
    discard
  result = nil

proc readJpeg*(file: File): Metadata =
  ## Read the given file and return its metadata.  Return nil when the
  ## file format is unknown. It may generate UnknownFormat and
  ## NotSupported exceptions.
  return nil

#[
def read_metadata(fh):
  """Return a dictionary of dictionaries containing metadata or return
  None when the file is not understood. Fail quickly when the file is
  not the correct format.
  """
  sections = read_sections(file)

  fh.setFilePos(0,2)
  file_size = fh.tell()

  result = {}

  offsets = OrderedDict()
  dups = {}

  for key, start, finish in sections:
    name = None
    if key == 0xe0:
      # todo: read the JFIF.
      # len2, 'JFIF'0, major1, minor1, density units 1, x density 2, y
      # density 2, thumbnail width 1, thumbnail height 1, 3 * width * height thumbnail pixels.
      pass

    elif key == 0xed:
      # IPTC
      fh.setFilePos(start)
      buffer = fh.read(finish - start)
      iptc_records = get_iptc_records(buffer)
      if iptc_records:
        result['iptc'] = get_iptc_info(iptc_records)
        name = 'APPD({})(range_iptc)'.format(key)

    elif key == 0xe1:
      # Could be xmp or iptc.
      data = kind_of_section(fh, key, start, finish)
      if not data:
        continue
      kind, metadata_bytearray = data
      if kind == 'xmp':
        xmp_bytearray = bytearray(metadata_bytearray)
        result['xmp'] = parse_xmp_xml(xmp_bytearray)
        name = 'APP1({})(range_xmp)'.format(key)
      elif kind == 'exif':
        # Parse th exif, it is stored as a tiff file.
        from .tiff import read_header, read_ifd, print_ifd
        header_offset = start+4+len('exif\x00')+1
        ifd_offset, endian = read_header(fh, header_offset)
        if ifd_offset is not None:
          # print("ifd_offset = {}".format(ifd_offset))
          # print("endian = {}".format(endian))
          ifd = read_ifd(fh, header_offset, endian, ifd_offset)
          # print_ifd('exif', ifd)
          process_exif(ifd)

          # Move the range_ keys to the offsets dictionary.
          delete_keys = []
          for key, value in ifd.items():
            if isinstance(key, str) and key.startswith('range_'):
              offsets[key] = value
              delete_keys.add(key)
          for key in delete_keys:
            del ifd[key]

          result['exif'] = ifd
          name = 'APP1({})(range_exif)'.format(key)

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


      fh.setFilePos(start)
      buffer = fh.read(finish - start)
      sofx = get_sof0_info(key, buffer)
      if sofx:
        sofname = 'sof{}'.format(key-192)
        result[sofname] = sofx
        name = '{}({})(range_{})'.format(sofname, key, key)

    if not name:
      name = 'range_{}'.format(key)
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
      name = '{}_{}'.format(name, count)
    offsets[name] = (start, finish)

  result['offsets'] = offsets
  return result
]#


#[
#todo: change 'offset' to section? or range?


proc readSections(file: file): seg[Section] =
  ## Read the Jpeg file and return a list of sections.

  # A JPEG starts with ff, d8.
  file.setFilePos(0)
  if file.readOne() != 0xff:
    raise UnknownFormat("Not JPEG, first byte not 0xff.")
  if file.readOne() != 0xd8:
    raise UnknownFormat("Not JPEG, second byte not 0xd8.")

  result = @[]
  var finish = 2
  sections.add((0xd8, 0, finish))
  while 1:
    start = finish
    var byte = readOne(fh)
    if byte != 0xff:
      raise NotSupported("Byte not 0xff.")
    var marker = readOne(fh)

    if marker == 0xda:
      # The rest of the file except the last two bytes are the pixels.
      finish = fh.getFileSize()
      sections.add((marker, start, finish - 2))
      sections.add((0xd9, finish - 2, finish))
      break
    elif marker in standAlone:
      # When the marker is stand alone, it means there is no
      # associated block following the marker.
      sections.add((marker, start, start + 2))
      if marker == 0xd9:
        break
      continue

    var length = readTwo(fh)
    if length < 2:
      raise NotSupported("Block is less than 2 bytes.")
    # Seek from the current position to the start of the next block.
    fh.setFilePos(length - 2, fspCur)
    finish = start + length + 2
    sections.add((marker, start, finish))

  return sections


def kind_of_section(fh, key, start, finish):
  """Determine whether the section is xmp or exif and return its name and
metadata bytes.  Return None when not xmp or exif.
  """
  if key != 0xe1:
    return None
  section_len = finish - start
  if section_len < 4:
    return None

  # ff, e1, length, string+0, metadata
  fh.setFilePos(start)
  ff = readOne(fh)
  if ff != 0xff:
    return None
  e1 = readOne(fh)
  if e1 != 0xe1:
    return None
  length = readTwo(fh)
  if length != section_len-2:
    return None
  buffer = fh.read(length-2)

  type_byte_ids = [(b"Exif\x00", 'exif'), (b"http://ns.adobe.com/xap/1.0/\x00", 'xmp')]
  for byte_id, name in type_byte_ids:
    blen = len(byte_id)
    if blen > length:
      continue
    if buffer[0:blen] == byte_id:
      metadata = buffer[blen:]
      return name, metadata

  return None

class IptcRecord:
  """
  Identifies an IPTC record.
  """

  def __init__(self, number, data_set, string):
    self.number = number
    self.data_set = data_set  # byte identifier
    self.string = string      # utf8 string

  def __str__(self):
    return "number: {0}, data_set: {1}, string: {2}".format(
        self.number, self.data_set, self.string)

def get_iptc_records(block):
  """Create a list of all iptc records for the given iptc block.
  A list is returned containing all the records from the block.
  See iimv4.1.pdf at http://www.iptc.org/IIM/
  """
  records = []
  size = len(block)
  if size == 0:
    return records
  if size < 30:
    return records  # Too small for a valid iptc header.
  if size > 65502:
    return records  # Too much metadata for a jpg.

  # ff, ed, length, ...
  if block[0] != 0xff and block[0] != '\xff':
    return records  # Bad format.
  if block[1] != 0xed and block[1] != '\xed':
    return records  # Bad format.

  first_size = length2(block, 2)  # index 2, 3
  if first_size + 2 != size:
    return records  # Bad format.
  photoshop = block[4:17]
  if photoshop != b"Photoshop 3.0":
    return records  # Bad format.
  if block[17] != 0 and block[17] != '\x00':
    return records  # Bad format.
  eightBIM = block[18:22]
  if eightBIM != b"8BIM":
    return records  # Bad format.
  type = length2(block, 22)  # index 22, 23

  # one = block[24]
  # two = block[25]
  # three = block[26]
  # four = block[27]
  all_size = length2(block, 28)  # index 28, 29
  if all_size == 0:
    return records  # Bad format.
  if all_size + 30 > size:
    return records  # Bad format.

# 5FD0   FF ED 22 BC 50 68 6F 74 6F 73 68 6F 70 20 33 2E    ..".Photoshop 3.
# 5FE0   30 00 38 42 49 4D 04 04 00 00 00 00 04 8A 1C 02    0.8BIM..........
# 5FF0   00 00 02 00 02 1C 02 05 00 0B 64 72 70 32 30 39    ..........drp209
# 6000   31 31 36 39 64 1C 02 0A 00 01 31 1C 02 19 00 0D    1169d.....1.....
# 6010   4E 6F 72 74 68 20 41 6D 65 72 69 63 61 1C 02 19    North America...
# 6020   00 18 55 6E 69 74 65 64 20 53 74 61 74 65 73 20    ..United States
# 6030   6F 66 20 41 6D 65 72 69 63 61 1C 02 19 00 07 41    of America.....A

  # 1C number(1) data_set(1) value_len(2)  value
  # 1c 2         0           2              0002
  # 1c 2         5           000B           drp2091169d
  # 1c 2         5           000B           drp2091169d
  # 1C 02        0A          0001           31
  # 1C 02        19          000D           North America
  # 1C 02        19          0018           United States of America

  start = 30
  finish = 30 + all_size
  while 1:
    marker = length1(block, start + 0)
    if marker != 0x1c and marker != '\x1c':
      break  # done
    number = length1(block, start + 1)
    data_set = length1(block, start + 2)
    # index start+3, start+4
    string_len = length2(block, start + 3)
    if string_len > 0x7fff:
      # The length is over 32k. The next length bytes (removing high bit)
      # are the count. But we don't support this.
      return records  # Bad format.
    if start + string_len > finish:
      return records  # Bad format.
    bytes = block[start + 5: start + 5 + string_len]
    # strict, ignore, replace, backslashreplace, xmlcharrefreplace,
    string = bytes.decode('utf-8', 'ignore')
    # string = unicode(bytes, 'utf-8', 'ignore')

    records.add(IptcRecord(number, data_set, string))
    start += string_len + 5
    if start >= finish:
      break  # done
  return records
]#



#[
def get_iptc_info(records):
  """
  Extract the metadata from the iptc records.
  Return a dictionary.
  """
  info = {}
  keywords = []
  keyword_key = 0x19
  for record in records:
    if record.number != 2:
      continue
    if record.data_set == 0x00:
      continue
      # info['ModelVersion'] = length2(record, 2)
    elif record.data_set == keyword_key:
      # keywords
      if not record.string:
        break
      keywords.add(record.string)
    else:
      # The key is the data_set number.
      info[record.data_set] = record.string
      # print record

  if keywords:
    info[keyword_key] = ','.join(keywords)
  return info

def process_exif(exif):
  """
  Convert xp keys from 16 bit unicode to strings.
  """
# XPTitle(40091)
# XPComment(40092)
# XPAuthor(40093)
# XPKeywords(40094)
# XPSubject(40095)
  for key in range(40091, 40095):
    lofb = exif.get(key)
    if lofb:
      if lofb[-2] == 0 and lofb[-1] == 0:
        ba = bytearray(lofb[:-2])
      else:
        ba = bytearray(lofb)
      string = ba.decode('utf-16LE')
      exif[key] = string

# Baseline
# JPEGs with an SOF0 segment are known as Baseline JPEGs. They are always lossy, not progressive, use Huffman coding, and have a bit depth of 8. Every application that supports JPEG is supposed to at least support Baseline JPEG.

# Progressive
# Progressive JPEG rearranges the image data, so that the the first part of it represents a very low quality version of the entire image, rather than a high quality version of a small part of the image.

# A progressive JPEG is identified by the presence of an SOF2, SOF6, SOF10, or SOF14 segment.


def get_sof0_info(key, block):
  """ Return a dictionary given the SOF0 data.
  """
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

  size = len(block)
  if size < 13:
    return None  # Bad format.

  # ff, c0, length, ...
  if block[0] != 0xff and block[0] != '\xff':
    return None  # Bad format.
  # if block[1] != key:
  #   return None  # Bad format.

  first_size = length2(block, 2)  # index 2, 3
  if first_size + 2 != size:
    return None  # Bad format.

  d = {}
  d['precision'] = length1(block, 4)  # index 4
  d['height'] = length2(block, 5)  # index 5, 6
  d['width'] = length2(block, 7)  # index 7, 8

  number_components = length1(block, 9)  # index 9
  d['number_components'] = number_components

  if number_components < 1:
    return None  # Bad format.
  if 10 + 3 * number_components > size:
    return None  # Bad format.

  for ix in range(0, number_components):
    start = 10 + 3 * ix
    a = [length1(block, start + pos) for pos in (0, 1, 2)]
    d['component{}'.format(ix)] = a

  return d
]#

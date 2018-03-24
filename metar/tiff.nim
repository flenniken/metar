
import tables
import readNumber
import endians
import metadata
import tiffTags
import strutils

#[

This is the layout of a Tiff file:

header -> IFD
IFD starts with a count, then that many IFD entries (IDFEntry),
  then an offset to the next IFD or 0.
IFD.next -> IFD or 0
IFD.SubIFDs = [->IFD, ->IFD,...]
IFD.Exif_IFD -> IFD
Each IFD entry contains a tag and a list of values.

]#

type
  Kind {.pure.} = enum
    dummy
    bytes
    strings
    shorts
    longs
    rationals
    sbytes
    sstrings
    sshorts
    slongs
    srationals
    floats
    doubles

  ValueList = ref object
    case kind: Kind
    of Kind.dummy:
      discard
    of Kind.bytes:
      bytesList: seq[uint8]
    of Kind.strings:
      # a list of bytes containing ascii strings 0 terminated.
      stringsList: seq[uint8]
    of Kind.shorts:
      shortsList: seq[uint16]
    of Kind.longs:
      longsList: seq[uint32]
    of Kind.rationals:
      rationalsList: seq[uint32]
    of Kind.sbytes:
      sbytesList: seq[int8]
    of Kind.sstrings:
      sstringsList: seq[uint8]
    of Kind.sshorts:
      sshortsList: seq[int16]
    of Kind.slongs:
      slongsList: seq[int32]
    of Kind.srationals:
      srationalsList: seq[int32]
    of Kind.floats:
      floatsList: seq[float32]
    of Kind.doubles:
      doublesList: seq[float64]

  IFDEntry = object
    tag: uint16
    kind: Kind
    count: uint32
    packed: array[4, uint8]

    # headerOffset: int64
    # values: ValueList
    # endian: Endianness

proc tagName*(tag: uint16): string =
  ## Return the name of the given tag or "" when not known.

  result = tagToString.getOrDefault(tag)
  if result == nil:
    result = ""


proc `$`*(entry: IFDEntry): string =
  # Return a string representation of the IFDEntry.
  "$1($2, $3h), $4 $5, packed: $6 $7 $8 $9"  %
    [tagName(entry.tag), $entry.tag, toHex(entry.tag),
    $entry.count, $entry.kind,
    toHex(entry.packed[0]), toHex(entry.packed[1]),
    toHex(entry.packed[2]), toHex(entry.packed[3])]



proc readHeader*(file: File, headerOffset: int64):
    tuple[ifdOffset: int64, endian: Endianness] =
  ## Read the tiff header at the given header offset and return the
  ## offset of the first image file directory (IFD), and the endianness of
  ## the file.  Raise UnknownFormatError when the file format is
  ## unknown.

  # A header is made up of a three elements, order, magic and offset:
  # 2 bytes: byte order, 0x4949 or 0x4d4d
  # 2 bytes: magic number, 0x2a (42)
  # 4 bytes: offset

  try:
    file.setFilePos(headerOffset)

    # Determine the endian of the file by reading the byte order marker.
    var endian: Endianness
    var order = readNumber[uint16](file, system.cpuEndian)
    if order == 0x4d4d:
      endian = bigEndian
    elif order == 0x4949:
      endian = littleEndian
    else:
      raise newException(UnknownFormatError, "Tiff: invalid byte order marker.")

    # Check for the magic 42.
    var magic = readNumber[uint16](file, endian)
    if magic != 0x2a: # 42
      raise newException(UnknownFormatError, "Tiff: wrong magic number.")

    # Read the offset of the first image file directory (IFD).
    var ifdOffset = readNumber[uint32](file, endian)
    result = ((int64)ifdOffset, endian)
  except UnknownFormatError:
    raise
  except:
    raise newException(UnknownFormatError, "Tiff: not a tiff file.")



#[
class IFDEntry:
  """ Image File Directory Entry
  usage:
  entry = IFDEntry(fh, header_offset, endian)
  if entry.tag == 123:
    values = entry.get_values()
  """
  # IFD entry is made up of a 2 byte tag, a 2 byte kind, a 4 byte count, and
  # a packed 4 bytes for a total of 12 bytes.
  #
  # There are associated values with the entry. If the values are small
  # enough, they are stored directly in the packed 4 bytes. If there
  # isn't enough room in the 4 bytes, all the values are stored in the
  # file outside the entry in a continuous block pointed to by the
  # packed 4 bytes treated as an offset.
  #
  # The 2 byte kind can have the values 1, 2, ..., 12. A value of 1
  # means the values are bytes, 2 means the values are shorts and 4
  # means the values are longs, etc. Skip unknown kinds.
  #
  # The 4 byte count is the number of values.
  #
  # The 4 packed bytes are values or an offset to values, depending on
  # whether the values fit in the 4 packed bytes or not.
  #
  # The IFD.offset attribute is a pointer to the values stored outside
  # the entry or None when all the values are stored internally.
  #
  # Only the embedded values are read when the entry is
  # constructed. Use the values method, if you want to get the values
  # stored outside as well as inside.


  def get_values(self):
    if not self.values:
      self.read_outside_values()
    return self.values

  def get_value_range(self):
    """Return the start and end offset of the value in the file. Or None
    when it is stored in the entry itself.
    """
    if not self.offset:
      return None
    value_size = bytes_per_kind.get(self.kind)
    if not value_size:
      return None
    start = self.header_offset + self.offset
    end = start + self.count * value_size
    return start, end

  def read_outside_values(self):
    """Read the values stored outside the IFDEntry. The file position is left
    unchanged.
    """
    if self.values:
      return
    value_range = self.get_value_range()
    if not value_range:
      return
    fh = self.fh
    endian = self.endian
    save_pos = fh.tell()
    values = []
    self.fh.seek(value_range[0])

    if self.kind == 2:
      packed = fh.read(self.count)
      values = get_strings(packed)
    else:
      for ix in range(0, self.count):
        if self.kind == 1 or self.kind == 7:
          values.append(read_one(fh))
        elif self.kind == 3:
          values.append(read_two(fh, endian))
        elif self.kind == 8:
          values.append(read_two(fh, endian, 1))
        elif self.kind == 4:
          values.append(read_four(fh, endian))
        elif self.kind == 9:
          values.append(read_four(fh, endian, 1))
        elif self.kind == 5:
          numerator = read_four(fh, endian)
          denominator = read_four(fh, endian)
          values.append((numerator, denominator))
        elif self.kind == 10:
          numerator = read_four(fh, endian, 1)
          denominator = read_four(fh, endian, 1)
          values.append((numerator, denominator))
        elif self.kind == 11:
          values.append(read_float(fh, endian))
        elif self.kind == 12:
          values.append(read_double(fh, endian))

    fh.seek(save_pos)
    self.values = values

  def __str__(self):
    if self.offset == None:
      offset = 'None'
    else:
      offset = '0x{:04X}'.format(self.offset)
    count = len(self.values)
    if count > 4:
      values = self.values[0:4]
      values.append('...')
    else:
      values = self.values
    return "tag={0}(0x{0:02X}), kind={1}, count={2}, offset={3}, values={4}".format(
      self.tag, self.kind, self.count, offset, values)

bytes_per_kind = {
  1: 1,
  2: 1,
  3: 2,
  4: 4,
  5: 8,
  6: 1,
  7: 1,
  8: 2,
  9: 4,
  10: 8,
  11: 4,
  12: 8,
}

def get_strings(packed):
  """Convert the given packed bytes to an array of strings and return
  it.  The bytes contain one or more 0 terminated ascii strings.
  """

  # Find the 0 terminators.
  zeros = []
  if sys.version_info[0] < 3:
    zero = '\x00'
  else:
    zero = 0x00
  for ix in range(0, len(packed)):
    if packed[ix] == zero:
      zeros.append(ix)

  # [2, 5, 9] -> packed[0:2], [3:5], [6:9]
  strings = []
  start = 0
  for pos in zeros:
    if pos - start > 0:
      try:
        string = packed[start:pos].decode('utf-8')
        strings.append(string)
      except:
        pass
        # raise
    start = pos+1

  return strings


def read_ifd(fh, header_offset, endian, ifd_offset):
  """Read the Image File Directory at the given offset and return a
  dictionary of the entries. The dictionary key is the entry tag, and
  the value is a list of the entry's values.

  fh: file handle
  header_offset: offset to the tiff header
  endian: < or >
  ifd_offset: offset to the ifd relative to the header
  """
  ifd = OrderedDict()

  # Read the count of entries.
  fh.seek(header_offset + ifd_offset)
  count = read_two(fh, endian)
  if count is None:
    return None

  # Loop through the directory entries.
  for i in range(0, count):
    entry = IFDEntry(fh, header_offset, endian)
    ifd[entry.tag] = entry.get_values()
    if entry.offset:
      value_range_name = "range_{}".format(entry.tag)
      ifd[value_range_name] = entry.get_value_range()

  # Add a range for each strip or tile.
  add_pixel_ranges(ifd, header_offset)

  # Get the offset to the next IFD.
  ifd['next'] = read_four(fh, endian)
  ifd['range_ifd'] = (header_offset+ifd_offset, int(str(fh.tell())))
  return ifd

def add_pixel_ranges(ifd, header_offset):
  """
  Add strip or tile ranges to the given ifd.
  """
  # (StripOffsets, StripByteCounts), (TileOffsets, TileByteCounts)
  tups = [('strip', 273, 279), ('tile', 324, 325)]

  for name, tag_offset, tag_byte_counts in tups:
    offsets = ifd.get(tag_offset)
    byte_counts = ifd.get(tag_byte_counts)
    if offsets and byte_counts:
      if len(offsets) != len(byte_counts):
        raise NotSupported("The number of offsets is not the same as the number of byte counts.")
      for ix, offset in enumerate(offsets):
        value_range_name = "range_{}{}".format(name, ix)
        start = header_offset + offset
        end = start + byte_counts[ix]
        ifd[value_range_name] = (start, end)


def print_ifd(name, ifd):
  """
  Print out the given IFD.
  """
  print('-'*20 + name + '-'*20)
  for key, values in ifd.items():
    if isinstance(key, int):
      count = len(values)
      if count > 4:
        values = values[0:4]
        values.append('..{}..'.format(count))
    tname = tagName(key)
    if not tname:
      tag = '{}'.format(key)
    else:
      tag = '{}({})'.format(tname, key)
    print('{} = {}'.format(tag, values))


]#




#[
  if entry.values == nil:
    echo "values = nil"
  else:
    case entry.kind:
      of dummy:
        discard
      of bytes:
        echo $entry.values.bytesList
      of strings:
        echo $entry.values.stringsList
      of shorts:
        echo $entry.values.shortsList
      of longs:
        echo $entry.values.longsList
      of rationals:
        echo $entry.values.rationalsList
      of sbytes:
        echo $entry.values.sbytesList
      of sstrings:
        echo $entry.values.sstringsList
      of sshorts:
        echo $entry.values.sshortsList
      of slongs:
        echo $entry.values.slongsList
      of srationals:
        echo $entry.values.srationalsList
      of floats:
        echo $entry.values.floatsList
      of doubles:
        echo $entry.values.doublesList
]#

proc getIFDEntry*(buffer: var openArray[uint8], endian: Endianness,
                  index: Natural = 0): IFDEntry =
  ## Given a buffer of IFDEntry bytes starting at the given index,
  ## return an IFDEntry object.
  if buffer.len()-index < 12:
    raise newException(NotSupportedError, "Tiff: not enough bytes for IFD entry.")

  # 2 tag bytes, 2 kind bytes, 4 count bytes, 4 packed bytes
  result.tag = length[uint16](buffer, index+0, endian)
  let kind = length[uint16](buffer, index+2, endian)
  try:
    result.kind = Kind(kind)
  except RangeError:
    raise newException(NotSupportedError,
      "Tiff: IFD entry kind is not known: " & $kind)
  result.count = length[uint32](buffer, index+4, endian)
  result.packed[0] = buffer[index+8]
  result.packed[1] = buffer[index+9]
  result.packed[2] = buffer[index+10]
  result.packed[3] = buffer[index+11]


    
    #[
proc readValue(entry: IFDEntry, headerOffset: int64):

  if count == 0:
    return

  let packed = result.packed

  # Get the values when they fit in the packed 4 bytes.
  case result.kind:
    of Kind.bytes:
      if count <= 4:
        result.values.bytesList = newSeq[uint8]()
        for ix in 0..count-1:
          let item = length[uint8](packed, (int)ix, system.cpuEndian)
          result.values.bytesList.add(item)
    of Kinds.strings:
      # todo: parse strings
      discard
      # if count <= 4:
      #   result.values = getStrings(packed, result.values)
    of Kinds.shorts:
      if count <= 2:
        result.values.shortsList = newSeq[uint16]()
        for ix in 0..count-1:
          result.values.shortsList.add(length[uint16](packed, ix*2, system.cpuEndian))
    of Kinds.longs:
      if count <= 1:
        result.values.longsList = newSeq[uint32]()
        result.values.longsList.add(length[uint32](packed, 0, system.cpuEndian))

    of Kind.sbytes:
      if count <= 4:
        result.values.sbytesList = newSeq[int8]()
        for ix in 0..count-1:
          result.values.sbytesList.add(length[int8](packed, ix, system.cpuEndian))
    of Kinds.strings:
      # todo: parse strings
      discard
      # if count <= 4:
      #   result.values = getStrings(packed, result.values)
    of Kinds.sshorts:
      if count <= 2:
        result.values.sshortsList = newSeq[int16]()
        for ix in 0..count-1:
          result.values.sshortsList.add(length[int16](packed, ix*2, system.cpuEndian))
    of Kinds.slongs:
      if count <= 1:
        result.values.slongsList = newSeq[int32]()
        result.values.slongsList.add(length[int32](packed, 0, system.cpuEndian))

    of Kinds.floats:
      if count <= 1:
        result.values.floadsList = newSeq[float32]()
        result.values.floadsList.add(length[float32](packed, 0, system.cpuEndian))

    of Kinds.rationals:
      # todo: rationals
      discard
    of Kinds.srationals:
      # todo: srationals
      discard
    of Kinds.doubles:
      discard

]#

  # # Get the values when they fit in the packed 4 bytes.
  # if self.kind == 1 or self.kind == 6 or self.kind == 7: # one byte numbers
  #   if self.count <= 4:
  #     signed = 1 if self.kind == 6 else 0
  #     for ix in range(0, self.count):
  #       self.values.append(length1(packed, ix, signed))
  # elif self.kind == 2: # one or more ascii strings each 0 terminated
  #   if self.count <= 4:
  #     values = get_strings(packed)
  #     if not values:
  #       return
  #     self.values = values
  # elif self.kind == 3 or self.kind == 8: # shorts
  #   if self.count <= 2:
  #     signed = 1 if self.kind == 8 else 0
  #     for ix in range(0, self.count, 2):
  #       self.values.append(length2(packed, ix, endian, signed))
  # elif self.kind == 4 or self.kind == 9: # longs
  #   if self.count == 1:
  #     signed = 1 if self.kind == 9 else 0
  #     self.values.append(length4(packed, 0, endian, signed))
  # elif self.kind == 5: # rational: long / long
  #   pass
  # elif self.kind == 10: # SRATIONAL Two SLONG's
  #   pass
  # elif self.kind == 11: # float 4 bytes
  #   self.values.append(float_me(packed, 0, endian))
  # elif self.kind == 12: # Double precision (8-byte) IEEE
  #   pass
  # else:
  #   # It's not an error when the kind is not known.
  #   self.offset = packed
  #   return

  # # If the values do not fit in the packed 4 bytes, the packed bytes
  # # are an offset to the values somewhere else in the file.
  # if not self.values:
  #   self.offset = length4(packed, 0, endian)

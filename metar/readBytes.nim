##[
`Home <index.html>`_

readBytes
========

The readBytes module implements procedures to read numbers from a file
or buffer.

]##

import endians

proc length*[T](buffer: var openArray[uint8], index=0,
                endian: Endianness=littleEndian): T =
  ## Return a number from the buffer at the given index with the
  ## specified endianness. Specify the number type with T.
  ##
  ## .. code-block:: nim
  ##   import readBytes, os
  ##   var buffer = [0x01'u8, 0x23, 0x45, 0x67, 0x89, 0xab, 0xcd, 0xef]
  ##   var num16 = length[uint16](buffer)
  ##   echo toHex(num16)
  ##   2301
  ##   num16 = length[uint16](buffer, 3, bigEndian)
  ##   echo toHex(num16)
  ##   6789
  when not (T is uint8 or T is int8 or T is uint16 or T is int16 or
        T is uint32 or T is int32 or T is uint64 or T is int64 or
        T is float or T is float32 or T is float64):
    assert(false, "T is not a number type.")
  else:
    let pointer = addr(buffer[index])
    when sizeof(T) == 1:
      copyMem(addr(result), pointer, 1)
      return
    if endian == littleEndian:
      when sizeof(T) == 2:
        littleEndian16(addr(result), pointer)
      elif sizeof(T) == 4:
        littleEndian32(addr(result), pointer)
      else: #sizeof(T) == 8:
        littleEndian64(addr(result), pointer)
    else:
      when sizeof(T) == 2:
        bigEndian16(addr(result), pointer)
      elif sizeof(T) == 4:
        bigEndian32(addr(result), pointer)
      else: # sizeof(T) == 8:
        bigEndian64(addr(result), pointer)

proc readNumber*[T](file: File, endian: Endianness=littleEndian): T =
  ## Read a number from the current file position.
  ##
  ## You can specify the endianness of the number being read with
  ## the endian parameter. For example:
  ##
  ## .. code-block:: nim
  ##   import readBytes
  ##   var num16 = readNumber[uint16](file)
  ##   var num32 = readNumber[uint32](file, bigEndian)
  ##   var num32 = readNumber[uint32](file, system.cpuEndian)

  var buffer: array[sizeof(T), uint8]
  if file.readBytes(buffer, 0, sizeof(T)) != sizeof(T):
    raise newException(IOError, "Error reading file.")

  result = length[T](buffer, 0, endian)

proc read1*(file: File): uint8 =
  ## Read one byte from the current file position.
  return readNumber[uint8](file)

proc read2*(file: File): uint16 =
  ## Read two bytes from the current file position in big-endian.
  return readNumber[uint16](file, bigEndian)

proc length2*(buffer: var openArray[uint8], index: Natural=0): int =
  ## Read two bytes from the buffer in big-endian starting at the
  ## given index.
  return (int)length[uint16](buffer, index, bigEndian)

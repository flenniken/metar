import endians

## Read numbers from a file or byte buffer.

proc length*[T](buffer: var openArray[uint8], index=0,
                endian: Endianness=littleEndian): T =
  ## Return a number from the buffer at the given index with the
  ## specified endianness.
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

  let pointer = addr(buffer[index])
  when sizeof(T) == 1:
    copyMem(addr(result), pointer, 1)
    return
  if endian == littleEndian:
    when sizeof(T) == 2:
      littleEndian16(addr(result), pointer)
    elif sizeof(T) == 4:
      littleEndian32(addr(result), pointer)
    elif sizeof(T) == 8:
      littleEndian64(addr(result), pointer)
    else:
      assert(false, "Invalid type")
  else:
    when sizeof(T) == 2:
      bigEndian16(addr(result), pointer)
    elif sizeof(T) == 4:
      bigEndian32(addr(result), pointer)
    elif sizeof(T) == 8:
      bigEndian64(addr(result), pointer)
    else:
      assert(false, "Invalid type")

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

import endians

## Read numbers from a file.

proc read_number*[T](file: File, endian: Endianness=littleEndian): T =
  ## Read a number from the current file position.
  ##
  ## You can specify the endianness of the number being read with
  ## the endian parameter. For example:
  ##
  ## .. code-block:: nim
  ##   import readBytes
  ##   var num16 = read_number[uint16](file)
  ##   var num32 = read_number[uint32](file, bigEndian)
  ##   var num32 = read_number[uint32](file, system.cpuEndian)

  var buffer: array[sizeof(T), uint8]
  if file.readBytes(buffer, 0, sizeof(T)) != sizeof(T):
    raise newException(IOError, "Error reading file.")

  if system.cpuEndian == endian:
    result = cast[T](buffer)
  else:
    when sizeof(T) == 1:
      result = cast[T](buffer)
    elif sizeof(T) == 2:
      swapEndian16(addr(result), addr buffer)
    elif sizeof(T) == 4:
      swapEndian32(addr(result), addr buffer)
    elif sizeof(T) == 8:
      swapEndian64(addr(result), addr buffer)
    else:
      assert(false, "Invalid type")

proc length*[T](buffer: var openArray[uint8], index=0, endian: Endianness=littleEndian): T =
  ## Return a number from the buffer at the given index with the
  ## specified endianness.
  ## .. code-block:: nim
  ##   import readBytes, os
  ##   var buffer = [0x01'u8, 0x23, 0x45, 0x67, 0x89, 0xab, 0xcd, 0xef] 
  ##   var num16 = length[uint16](buffer)
  ##   echo toHex(num16)
  ##   2301
  ##   num16 = length[uint16](buffer, 3, bigEndian)
  ##   echo toHex(num16)
  ##   6789

  var pointer = addr(buffer[index])
  if endian == littleEndian:
    when sizeof(T) == 1:
      copyMem(addr(result), pointer, 1)
    elif sizeof(T) == 2:
      littleEndian16(addr(result), pointer)
    elif sizeof(T) == 4:
      littleEndian32(addr(result), pointer)
    elif sizeof(T) == 8:
      littleEndian64(addr(result), pointer)
    else:
      assert(false, "Invalid type")
  else:
    when sizeof(T) == 1:
      copyMem(addr(result), pointer, 1)
    elif sizeof(T) == 2:
      bigEndian16(addr(result), pointer)
    elif sizeof(T) == 4:
      bigEndian32(addr(result), pointer)
    elif sizeof(T) == 8:
      bigEndian64(addr(result), pointer)
    else:
      assert(false, "Invalid type")
  

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

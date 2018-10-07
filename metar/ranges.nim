# See: test_ranges.nim(0):

## You use the ranges modules to hold ranges, merge them and to create a
## ranges metadata node from a list of ranges.

import metadata
import json
import algorithm
import strutils
import tables
import tpub

type
  OffsetList = seq[tuple[start: int64, finish: int64]]
    ## A list of file offsets. Each tuple is a half open interval,
    ## [start, finish).

  Range* = object
    ## A range object describes a byte range of the file.  The start
    ## is the offset of the beginning of the range and finish is one
    ## past the end. The name is a short string, like "header". The
    ## message is an optional short string with more information about
    ## the range. The known field is true when the range format is
    ## known and handled by the current code, false when the format of
    ## the section is unknown.
    start*: int64
    finish*: int64
    name*: string
    message*: string
    known*: bool

  # Doesn't do what I want. I want any of these types to work not just Offset.
  # Offset* = int | uint32 | int64
  #   ## A byte offset into a file.

proc newRange*(start: int | uint32 | int64, finish: int | uint32 | int64, name: string = "",
               known: bool = true, message: string = ""): Range =
  ## Create a new range.
  result = Range(start: (int64)start, finish: (int64)finish,
                 name: name, known: known, message: message)


proc mergeRanges*(ranges: seq[Range], paddingShift: Natural = 0):
    tuple[minList: OffsetList, gapList: OffsetList] =
  ## Given a list of ranges, merge them into the smallest set of
  ## contiguous ranges. Return the new list of ranges. Also return a
  ## list of ranges that cover the gaps.  You can add the ranges (0,0)
  ## or (totalSize, totalSize) to the range list to cover the
  ## beginning and end of the file. The paddingShift number determines
  ## the end of the padding. 0 is no padding, 1 align on even
  ## boundaries, 2 align on 4 bit boundaries, etc.

  var minList = newSeq[tuple[start: int64, finish: int64]]()
  var gapList = newSeq[tuple[start: int64, finish: int64]]()

  if ranges.len == 0:
    result = (minList, gapList)
    return

  # Sort the ranges by the start offset.
  let sortedRanges = ranges.sortedByIt(it.start)

  var start = ranges[0].start
  var finish = ranges[0].finish

  for ix in 1..sortedRanges.len-1:
    let range = sortedRanges[ix]
    let r_start = range.start
    let r_finish = range.finish

    var boundary: int64
    if paddingShift > 0:
      boundary = ((finish shr paddingShift) + 1) shl paddingShift

    if finish >= r_start or (paddingShift > 0 and boundary == r_start):
      # Contiguous, ovelapping range or padding, merge.
      if r_finish > finish:
        finish = r_finish
    else:
      # Found a gap
      if start < finish:
        minList.add((start, finish))
      gapList.add((finish, r_start))
      start = r_start
      finish = r_finish

  if start < finish:
    minList.add((start, finish))
  result = (minList, gapList)


proc readGap*(file: File, start: int64, finish: int64): string =
  ## Read the range of the file and return a short hex representation.

  let count = finish - start
  if count <= 0:
    raise newException(NotSupportedError, "Invalid gap byte range.")

  var readCount: int
  if count > 8:
     readCount = 8
  else:
    readCount = (int)count
  var buffer = newSeq[uint8](readCount)
  file.setFilePos((int64)start)
  if file.readBytes(buffer, 0, readCount) != readCount:
    raise newException(NotSupportedError, "Unable to read all the gap bytes.")

  #todo: remove the error prefix from all error messages that are shared between readers.
  #todo: or remove them from all messages?

  if count == 1:
    result = $count & " gap byte:"
  else:
    result = $count & " gap bytes:"

  for item in buffer:
    result.add(" $1" % [toHex(item)])
  if count != readCount:
    result.add("...")
  result.add("  ")
  for ascii in buffer:
    if ascii >= 0x20'u8 and ascii <= 0x7f'u8:
      result.add($char(ascii))
    else:
      result.add(".")


# proc cmpRanges(one: Range, two: Range): int =
#   if one.start < two.start:
#     result = -1
#   elif one.start > two.start:
#     result = 1
#   else:
#     result = 0


proc createRangeNode(item: Range): JsonNode {.tpub.} =
  ## Create a range node from a range.

  result = newJArray()
  result.add(newJString(item.name))
  result.add(newJInt((BiggestInt)item.start))
  result.add(newJInt((BiggestInt)item.finish))
  result.add(newJBool(item.known))
  result.add(newJString(item.message))


proc createRangesNode*(file: File, start: int | uint32 | int64, finish: int | uint32 | int64,
                       ranges: var seq[Range]): JsonNode =
  ## Return a json node for the given list of ranges.  The node
  ## contains the gaps and the ranges are sorted. The start and finish
  ## define the file boundries. You can pass 0 and fileSize to capture
  ## the whole file.

  var offsetList = newSeq[Range](ranges.len)
  for ix, item in ranges:
    offsetList[ix] = newRange(item.start, item.finish)
  let s64 = (int64)start
  let f64 = (int64)finish
  offsetList.add(newRange(s64, s64))
  offsetList.add(newRange(f64, f64))

  let (_, gaps) = mergeRanges(offsetList)
  for start, finish in gaps.items():
    let gapHex = readGap(file, start, finish)
    ranges.add(Range(name: "gap", start: start, finish: finish,
                   known: false, message:gapHex))
  let sortedRanges = ranges.sortedByIt(it.start)

  # Create a ranges node from the ranges list.
  result = newJArray()
  for rangeItem in sortedRanges:
    result.add(createRangeNode(rangeItem))

import json
import metadata
import ranges

type
  ImageData* = ref object
    width*: int
    height*: int
    pixelOffsets*: seq[tuple[start: int64, finish: int64]] ## \
  ## ImageData holds an image width, height and the location of the
  ## pixel data in the file.


proc newImageData*(width: int = -1, height: int = -1, capacity: Natural = 0): ImageData =
  ## Create a new ImageData object.
  var pixelOffsets = newSeq[tuple[start: int64, finish: int64]](capacity)
  result = ImageData(width: width, height: height, pixelOffsets: pixelOffsets)


proc newImageData*(width: int32, height: int32, starts: seq[uint32],
                   counts: seq[uint32]): ImageData =
  ## Create a new ImageData object.

  # Make sure the imageData has all its fields filled in.
  if width < 1 or height < 1 or starts.len == 0 or
      counts.len == 0:
    return
    # return nil # no image

  # The two lists must have the same number of items.
  if starts.len != counts.len:
    raise newException(NotSupportedError, "invalid image parameters.")

  # Create a list of ranges.
  var offsets = newSeq[Range](starts.len)
  for ix in 0..<starts.len:
    let start = (int64)starts[ix]
    let finish = start + (int64)counts[ix]
    offsets[ix] = newRange(start, finish)

  # Merge the ranges.
  let (sections, _) = mergeOffsets(offsets, paddingShift = 1)

  # Make a new ImageData object.
  result = newImageData((int)width, (int)height, sections.len)
  for ix, section in sections:
    result.pixelOffsets[ix] = (section.start, section.finish)


proc createImageNode*(imageData: ImageData): JsonNode =
  ## Create an image node from the given image data. Return nil when
  ## the image data is incomplete.

  # Return nil when the image data is incomplete.
  if imageData.width == -1 or imageData.height == -1 or imageData.pixelOffsets.len == 0:
    return nil

  result = newJObject()
  result["width"] = newJInt((BiggestInt)imageData.width)
  result["height"] = newJInt((BiggestInt)imageData.height)

  var pixels = newJArray()
  for offset in imageData.pixelOffsets:
    var part = newJArray()
    part.add(newJInt((BiggestInt)offset.start))
    part.add(newJInt((BiggestInt)offset.finish))
    pixels.add(part)
  result["pixels"] = pixels

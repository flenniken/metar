import json

type
  ImageData* = object
    width*: int
    height*: int
    pixelRanges*: seq[tuple[start: int64, finish: int64]] ## \
  ## ImageData holds an image width, height and the location of the
  ## pixel data in the file.


proc newImageData*(): ImageData =
  ## Create a new empty ImageData object.
  var pixelRanges = newSeq[tuple[start: int64, finish: int64]]()
  result = ImageData(width: -1, height: -1, pixelRanges: pixelRanges)


proc createImageNode*(imageData: ImageData): JsonNode =
  ## Create an image node from the given image data. Return nil when
  ## the image data is incomplete.

  # Return nil when the image data is incomplete.
  if imageData.width == -1 or imageData.height == -1 or imageData.pixelRanges.len == 0:
    return nil

  result = newJObject()
  result["width"] = newJInt((BiggestInt)imageData.width)
  result["height"] = newJInt((BiggestInt)imageData.height)

  var pixels = newJArray()
  for offset in imageData.pixelRanges:
    var part = newJArray()
    part.add(newJInt((BiggestInt)offset.start))
    part.add(newJInt((BiggestInt)offset.finish))
    pixels.add(part)
  result["pixels"] = pixels

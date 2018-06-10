import unittest
import imageData
import json


suite "Test imageData":

  test "test newImageData":
    let imageData = newImageData()
    check(imageData.width == -1)
    check(imageData.height == -1)
    check(imageData.pixelRanges.len == 0)

  test "test createImageNode":
    var imageData = newImageData()
    imageData.width = 1000
    imageData.height = 500
    imageData.pixelRanges.add((111'i64, 222'i64))
    let imageNode = createImageNode(imageData)
    check(imageNode != nil)
    check($imageNode == """{"width":1000,"height":500,"pixels":[[111,222]]}""")

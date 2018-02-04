import nimpy
import strutils
import version
import json # for $metadata
import readMetadata
import printMetadata

proc get_version*(): string {.exportpy.} =
  result = versionNumber

proc py_read_metadata(filename: string): string {.exportpy.} =
  var metadata = readMetadata(filename)
  if metadata == nil:
    result = ""
  else:
    result = $metadata

proc py_read_metadata_human(filename: string): string {.exportpy.} =
  var metadata = readMetadata(filename)
  if metadata == nil:
    result = ""
  else:
    var lines = newSeq[string]()
    for line in metadata.lines():
      lines.add(line)
    result = lines.join("\n")

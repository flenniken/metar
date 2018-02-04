import nimpy
import strutils
import version
import json # for $metadata
import readMetadata
import printMetadata
import metadata

#todo: document these functions
proc py_get_version*(): string {.exportpy.} =
  result = versionNumber

proc py_read_metadata_json*(filename: string): string {.exportpy.} =
  try:
    result = $readMetadata(filename)
  except UnknownFormatError:
    result = ""

proc py_read_metadata*(filename: string): string {.exportpy.} =
  try:
    result = readMetadata(filename).readable()
  except UnknownFormatError:
    result = ""

proc py_key_name*(readerName: string, section: string,
                  key: string): string {.exportpy.} =
  result = keyName(readerName, section, key)


## Parses XMP metadata.

import os
import streams
import parsexml
import strutils
import tables
import metadata
import json
import tpub

# todo: The start of xml has a unique id. Store that too.
# <?xpacket begin=' ' id="W5M0MpCehiHzreSzNTczkc9d"?>
# xpacket_id = W5M0MpCehiHzreSzNTczkc9d

proc parseXpacket(xpacket: string): seq[tuple[key:string, value:string]] {.tpub.}=
  # Parse the xpacket and return a list of key=value pairs.

  result = newSeq[tuple[key:string, value:string]]()
  var x = xpacket.strip()
  for pair in x.split():
    var keyValuePair = pair.split('=')
    if keyValuePair.len == 2:
      var key = keyValuePair[0].strip()
      var value = keyValuePair[1].strip(chars=WhiteSpace+{'"'})
      result.add(("xpacket:" & key, value))

proc parseNamespaces(xmp: string): OrderedTable[string, string] {.tpub.} =
  ## Return a dictionary of the namespace values mapped to their short
  ## form.

  var stream = newStringStream(xmp)
  # var stream = newFileStream(filename, fmRead)

  var xmlParser: XmlParser
  open(xmlParser, stream, "filename")
  defer: xmlParser.close()

  result = initOrderedTable[string, string]()

  while true:
    xmlParser.next()

    case xmlParser.kind
    of xmlAttribute:
      let key = xmlParser.attrKey
      if key.startsWith("xmlns:"):
        let ns = key[6..key.len-1]
        result[xmlParser.attrValue] = ns
    of xmlEof:
      break # end of file reached
    else:
      discard # ignore other events

#[
  Normal items become strings.  For example:

         <tiff:Make>Canon</tiff:Make>

  becomes

    "tiff:Make": "Canon"

  Bag and Seq become lists of items. For example the following:

         <dc:subject>
            <rdf:Bag>
               <rdf:li>Raw test</rdf:li>
               <rdf:li>photo</rdf:li>
               <rdf:li>Tiapei</rdf:li>
            </rdf:Bag>
         </dc:subject>
         <tiff:BitsPerSample>
            <rdf:Seq>
               <rdf:li>8</rdf:li>
               <rdf:li>8</rdf:li>
               <rdf:li>8</rdf:li>
            </rdf:Seq>
         </tiff:BitsPerSample>

  becomes:

    "dc:subject": ["Raw test", "photo", "Tiapei"],
    "tiff:BitsPerSample": ["8", "8", "8"]

  Alt items:

         <dc:title>
            <rdf:Alt>
               <rdf:li xml:lang="x-default">Raw Title</rdf:li>
            </rdf:Alt>
         </dc:title>

  become dictionaries:

    "dc:title": {"x-default": "Raw Title"}


<?xpacket begin="" id="W5M0MpCehiHzreSzNTczkc9d"?>
<x:xmpmeta xmlns:x="adobe:ns:meta/" x:xmptk="Public XMP Toolkit Core 3.5">

  "begin" = ""
  "id" = "W5M0MpCehiHzreSzNTczkc9d"
  "xmlns:x" = "adobe:ns:meta/"
  "x:xmptk" = "Public XMP Toolkit Core 3.5"

]#

type
  XmpKind = enum
    kUnknown, kString, kList, kTable

proc xmpParser*(xmp: string): Metadata =
  ## Parse the xmp xml and return its metadata.

  var stream = newStringStream(xmp)
  # var stream = newFileStream(filename, fmRead)

  var xmlParser: XmlParser
  open(xmlParser, stream, "filename")
  defer: xmlParser.close()

  result = newJObject()
  # result["filename"] = %* filename

  var name = ""

  var kind = XmpKind.kUnknown
  var item = ""
  var list = newSeq[string]()
  var table = initOrderedTable[string, string]()
  var key = ""

  while true:
    xmlParser.next()

    case xmlParser.kind

    of xmlElementStart:

      if xmlParser.elementName == "rdf:Alt":
        kind = kTable
      elif not xmlParser.elementName.startsWith("rdf:"):
        name = xmlParser.elementName
        kind = kString
      elif xmlParser.elementName == "rdf:li":
        if kind != kTable:
          kind = kList

    of xmlAttribute:
      # echo "$1 = $2, $3" % [$xmlParser.kind, xmlParser.attrKey, xmlParser.attrValue]
      if xmlParser.attrKey == "xml:lang":
        key = xmlParser.attrValue

    # of xmlEntity:
    #   echo "$1 = $2" % [$xmlParser.kind, xmlParser.entityName]

    of xmlPI:
      if xmlParser.piName == "xpacket":
        var list = parseXpacket(xmlParser.piRest)
        for item in list:
          result[item.key] = newJString(item.value)

    of xmlCharData:
      case kind
      of kUnknown:
        discard
      of kString:
        item = xmlParser.charData
      of kList:
        list.add(xmlParser.charData)
      of kTable:
        if key != "":
          table[key] = xmlParser.charData

    of xmlElementEnd:
      if name == xmlParser.elementName:
        case kind
        of kString:
          result[name] = newJString(item)
        of kList:
          var jarray = newJArray()
          for item in list:
            jarray.elems.add(newJString(item))
          result[name] = jarray
        of kTable:
          var jobject = newJObject()
          for k,v in table.pairs:
            jobject[k] = newJString(v)
          result[name] = jobject
        of kUnknown:
          discard

        name = ""
        kind = XmpKind.kUnknown
        item = ""
        list = newSeq[string]()
        table = initOrderedTable[string, string]()
        key = ""

    of xmlEof:
      break # end of file reached
    else:
      discard # ignore other events

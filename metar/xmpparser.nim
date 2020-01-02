
## Parses XMP metadata from an xmp xml string.

import streams
import parsexml
import strutils
import tables
import json
import tpub

type
  XmpKind = enum
    kUnknown, kString, kList, kTable


proc parseXpacket(xpacket: string): seq[tuple[key:string, value:string]] {.tpub.}=
  # Parse the xpacket and return a list of key=value pairs.

  result = newSeq[tuple[key:string, value:string]]()
  var x = xpacket.strip()
  for pair in x.split():
    var keyValuePair = pair.split('=')
    if keyValuePair.len == 2:
      var key = keyValuePair[0].strip()
      var value = keyValuePair[1].strip(chars=WhiteSpace+{'"', '\''})
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
      if key.startsWith("xmlns:") or key.startsWith("x:xmptk"):
        result[key] = xmlParser.attrValue
      # else:
      #   echo "key='$1'" % [key]
    of xmlEof:
      break # end of file reached
    else:
      discard # ignore other events



proc xmpParser*(xmp: string): JsonNode =
  ## Parse the xmp xml and return its metadata as a JSON object of key
  ## value pairs.
  ##
  ## Normal items become strings.  For example:
  ##
  ## .. code-block::
  ##
  ##   <tiff:Make>Canon</tiff:Make>
  ##
  ## becomes key value pair:
  ##
  ## .. code-block::
  ##
  ##   "tiff:Make": "Canon"
  ##
  ## Bag and Seq become lists of items. For example the following:
  ##
  ## .. code-block::
  ##
  ##   <dc:subject>
  ##     <rdf:Bag>
  ##        <rdf:li>Raw test</rdf:li>
  ##        <rdf:li>photo</rdf:li>
  ##        <rdf:li>Tiapei</rdf:li>
  ##     </rdf:Bag>
  ##   </dc:subject>
  ##   <tiff:BitsPerSample>
  ##     <rdf:Seq>
  ##        <rdf:li>8</rdf:li>
  ##        <rdf:li>8</rdf:li>
  ##        <rdf:li>8</rdf:li>
  ##     </rdf:Seq>
  ##   </tiff:BitsPerSample>
  ##
  ## becomes:
  ##
  ## .. code-block::
  ##
  ##   "dc:subject": ["Raw test", "photo", "Tiapei"],
  ##   "tiff:BitsPerSample": ["8", "8", "8"]
  ##
  ## Alt items:
  ##
  ## .. code-block::
  ##
  ##   <dc:title>
  ##     <rdf:Alt>
  ##        <rdf:li xml:lang="x-default">Raw Title</rdf:li>
  ##     </rdf:Alt>
  ##   </dc:title>
  ##
  ## becomes dictionaries:
  ##
  ## .. code-block::
  ##
  ##   "dc:title": {"x-default": "Raw Title"}
  ##
  ## The xpacket:
  ##
  ## .. code-block::
  ##
  ##   <?xpacket begin="" id="W5M0MpCehiHzreSzNTczkc9d"?>
  ##
  ## becomes:
  ##
  ## .. code-block::
  ##
  ##   "xpacket:begin": ""
  ##   "xpacket:id": "W5M0MpCehiHzreSzNTczkc9d"
  ##
  ## The xmpmeta:
  ##
  ## .. code-block::
  ##
  ##   <x:xmpmeta xmlns:x="adobe:ns:meta/" x:xmptk="Public XMP Toolkit Core 3.5">
  ##
  ## becomes:
  ##
  ## .. code-block::
  ##
  ##   "xmlns:x" = "adobe:ns:meta/"
  ##   "x:xmptk" = "Public XMP Toolkit Core 3.5"
  ##
  ## The names spaces:
  ##
  ## .. code-block::
  ##
  ##   <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
  ##   <rdf:Description rdf:about=""
  ##          xmlns:tiff="http://ns.adobe.com/tiff/1.0/">
  ##
  ## becomes:
  ##
  ## .. code-block::
  ##
  ##   "xmlns:rdf" = "http://www.w3.org/1999/02/22-rdf-syntax-ns#"
  ##   "xmlns:tiff" = "http://ns.adobe.com/tiff/1.0/"

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
      # else:
      #   echo "xmlParser.elementName = '$1'" % [$xmlParser.elementName]

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
      # else:
      #   echo "xmlParser.piName = '" & xmlParser.piName & "'"

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
    # of xmlElementOpen:
    #   continue
    # of xmlElementClose:
    #   continue
    else:
      # echo "xmlParser.kind = '" & $xmlParser.kind & "'"
      discard # ignore other events

  # Add all the namespaces to the metadata.
  let namespaces = parseNamespaces(xmp)
  for k, v in namespaces.pairs:
    result[k] = newJString(v)

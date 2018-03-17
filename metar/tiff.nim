
import tables
import readNumber
import endians
import metadata

#[

This is the layout of a Tiff file:

header -> IFD
IFD.next -> IFD or 0
IFD.SubIFDs = [->IFD, ->IFD,...]
IFD.Exif_IFD -> IFD
IFD starts with a count, then that many IFDEntries,
  then an offset to the next IFD or 0.
Each IFDEntry contains a tag and a list of values.

]#


#[
http://www.digitalpreservation.gov/formats/content/tiff_tags.shtml

You can grab the tags from the HTML table by following this procedure:
Save the page to a file, add jquery to it and add an id="thetable" to
the tab table. Then open the new file and run the following script in
the console window.

var allCells = $("#thetable td");
one = allCells.filter(":nth-child(1)")
two = allCells.filter(":nth-child(3)")
for (i = 0; i < one.length; i++) {
  t = $(one[i])
  t2 = $(two[i])
  t2 = t2.text().replace(/ /g, '_')
  t2 = t2.text().replace(|/|g, '_')
  console.log(t.text() + ': "' + t2 + '",')
}
]#

const tagToString = {
  254'u16: "NewSubfileType",
  255'u16: "SubfileType",
  256'u16: "ImageWidth",
  257'u16: "ImageLength",
  258'u16: "BitsPerSample",
  259'u16: "Compression",
  262'u16: "PhotometricInterpretation",
  263'u16: "Threshholding",
  264'u16: "CellWidth",
  265'u16: "CellLength",
  266'u16: "FillOrder",
  269'u16: "DocumentName",
  270'u16: "ImageDescription",
  271'u16: "Make",
  272'u16: "Model",
  273'u16: "StripOffsets",
  274'u16: "Orientation",
  277'u16: "SamplesPerPixel",
  278'u16: "RowsPerStrip",
  279'u16: "StripByteCounts",
  280'u16: "MinSampleValue",
  281'u16: "MaxSampleValue",
  282'u16: "XResolution",
  283'u16: "YResolution",
  284'u16: "PlanarConfiguration",
  285'u16: "PageName",
  286'u16: "XPosition",
  287'u16: "YPosition",
  288'u16: "FreeOffsets",
  289'u16: "FreeByteCounts",
  290'u16: "GrayResponseUnit",
  291'u16: "GrayResponseCurve",
  292'u16: "T4Options",
  293'u16: "T6Options",
  296'u16: "ResolutionUnit",
  297'u16: "PageNumber",
  301'u16: "TransferFunction",
  305'u16: "Software",
  306'u16: "DateTime",
  315'u16: "Artist",
  316'u16: "HostComputer",
  317'u16: "Predictor",
  318'u16: "WhitePoint",
  319'u16: "PrimaryChromaticities",
  320'u16: "ColorMap",
  321'u16: "HalftoneHints",
  322'u16: "TileWidth",
  323'u16: "TileLength",
  324'u16: "TileOffsets",
  325'u16: "TileByteCounts",
  326'u16: "BadFaxLines",
  327'u16: "CleanFaxData",
  328'u16: "ConsecutiveBadFaxLines",
  330'u16: "SubIFDs",
  332'u16: "InkSet",
  333'u16: "InkNames",
  334'u16: "NumberOfInks",
  336'u16: "DotRange",
  337'u16: "TargetPrinter",
  338'u16: "ExtraSamples",
  339'u16: "SampleFormat",
  340'u16: "SMinSampleValue",
  341'u16: "SMaxSampleValue",
  342'u16: "TransferRange",
  343'u16: "ClipPath",
  344'u16: "XClipPathUnits",
  345'u16: "YClipPathUnits",
  346'u16: "Indexed",
  347'u16: "JPEGTables",
  351'u16: "OPIProxy",
  400'u16: "GlobalParametersIFD",
  401'u16: "ProfileType",
  402'u16: "FaxProfile",
  403'u16: "CodingMethods",
  404'u16: "VersionYear",
  405'u16: "ModeNumber",
  433'u16: "Decode",
  434'u16: "DefaultImageColor",
  512'u16: "JPEGProc",
  513'u16: "JPEGInterchangeFormat",
  514'u16: "JPEGInterchangeFormatLength",
  515'u16: "JPEGRestartInterval",
  517'u16: "JPEGLosslessPredictors",
  518'u16: "JPEGPointTransforms",
  519'u16: "JPEGQTables",
  520'u16: "JPEGDCTables",
  521'u16: "JPEGACTables",
  529'u16: "YCbCrCoefficients",
  530'u16: "YCbCrSubSampling",
  531'u16: "YCbCrPositioning",
  532'u16: "ReferenceBlackWhite",
  559'u16: "StripRowCounts",
  700'u16: "XMP",
  18246'u16: "Image.Rating",
  18249'u16: "Image.RatingPercent",
  32781'u16: "ImageID",
  32932'u16: "Wang_Annotation",
  33421'u16: "CFARepeatPatternDim",
  33422'u16: "CFAPattern",
  33423'u16: "BatteryLevel",
  33432'u16: "Copyright",
  33434'u16: "ExposureTime",
  33437'u16: "FNumber",
  33445'u16: "MD_FileTag",
  33446'u16: "MD_ScalePixel",
  33447'u16: "MD_ColorTable",
  33448'u16: "MD_LabName",
  33449'u16: "MD_SampleInfo",
  33450'u16: "MD_PrepDate",
  33451'u16: "MD_PrepTime",
  33452'u16: "MD_FileUnits",
  33550'u16: "ModelPixelScaleTag",
  33723'u16: "IPTC_NAA",
  33918'u16: "INGR_Packet_Data_Tag",
  33919'u16: "INGR_Flag_Registers",
  33920'u16: "IrasB_Transformation_Matrix",
  33922'u16: "ModelTiepointTag",
  34016'u16: "Site",
  34017'u16: "ColorSequence",
  34018'u16: "IT8Header",
  34019'u16: "RasterPadding",
  34020'u16: "BitsPerRunLength",
  34021'u16: "BitsPerExtendedRunLength",
  34022'u16: "ColorTable",
  34023'u16: "ImageColorIndicator",
  34024'u16: "BackgroundColorIndicator",
  34025'u16: "ImageColorValue",
  34026'u16: "BackgroundColorValue",
  34027'u16: "PixelIntensityRange",
  34028'u16: "TransparencyIndicator",
  34029'u16: "ColorCharacterization",
  34030'u16: "HCUsage",
  34031'u16: "TrapIndicator",
  34032'u16: "CMYKEquivalent",
  34033'u16: "Reserved",
  34034'u16: "Reserved",
  34035'u16: "Reserved",
  34264'u16: "ModelTransformationTag",
  34377'u16: "Photoshop",
  34665'u16: "Exif_IFD",
  34675'u16: "InterColorProfile",
  34732'u16: "ImageLayer",
  34735'u16: "GeoKeyDirectoryTag",
  34736'u16: "GeoDoubleParamsTag",
  34737'u16: "GeoAsciiParamsTag",
  34850'u16: "ExposureProgram",
  34852'u16: "SpectralSensitivity",
  34853'u16: "GPSInfo",
  34855'u16: "ISOSpeedRatings",
  34856'u16: "OECF",
  34857'u16: "Interlace",
  34858'u16: "TimeZoneOffset",
  34859'u16: "SelfTimeMode",
  34864'u16: "SensitivityType",
  34865'u16: "StandardOutputSensitivity",
  34866'u16: "RecommendedExposureIndex",
  34867'u16: "ISOSpeed",
  34868'u16: "ISOSpeedLatitudeyyy",
  34869'u16: "ISOSpeedLatitudezzz",
  34908'u16: "HylaFAX_FaxRecvParams",
  34909'u16: "HylaFAX_FaxSubAddress",
  34910'u16: "HylaFAX_FaxRecvTime",
  36864'u16: "ExifVersion",
  36867'u16: "DateTimeOriginal",
  36868'u16: "DateTimeDigitized",
  37121'u16: "ComponentsConfiguration",
  37122'u16: "CompressedBitsPerPixel",
  37377'u16: "ShutterSpeedValue",
  37378'u16: "ApertureValue",
  37379'u16: "BrightnessValue",
  37380'u16: "ExposureBiasValue",
  37381'u16: "MaxApertureValue",
  37382'u16: "SubjectDistance",
  37383'u16: "MeteringMode",
  37384'u16: "LightSource",
  37385'u16: "Flash",
  37386'u16: "FocalLength",
  37387'u16: "FlashEnergy",
  37388'u16: "SpatialFrequencyResponse",
  37389'u16: "Noise",
  37390'u16: "FocalPlaneXResolution",
  37391'u16: "FocalPlaneYResolution",
  37392'u16: "FocalPlaneResolutionUnit",
  37393'u16: "ImageNumber",
  37394'u16: "SecurityClassification",
  37395'u16: "ImageHistory",
  37396'u16: "SubjectLocation",
  37397'u16: "ExposureIndex",
  37398'u16: "TIFF_EPStandardID",
  37399'u16: "SensingMethod",
  37500'u16: "MakerNote",
  37510'u16: "UserComment",
  37520'u16: "SubsecTime",
  37521'u16: "SubsecTimeOriginal",
  37522'u16: "SubsecTimeDigitized",
  37724'u16: "ImageSourceData",
  40091'u16: "XPTitle",
  40092'u16: "XPComment",
  40093'u16: "XPAuthor",
  40094'u16: "XPKeywords",
  40095'u16: "XPSubject",
  40960'u16: "FlashpixVersion",
  40961'u16: "ColorSpace",
  40962'u16: "PixelXDimension",
  40963'u16: "PixelYDimension",
  40964'u16: "RelatedSoundFile",
  40965'u16: "Interoperability_IFD",
  41483'u16: "FlashEnergy",
  41484'u16: "SpatialFrequencyResponse",
  41486'u16: "FocalPlaneXResolution",
  41487'u16: "FocalPlaneYResolution",
  41488'u16: "FocalPlaneResolutionUnit",
  41492'u16: "SubjectLocation",
  41493'u16: "ExposureIndex",
  41495'u16: "SensingMethod",
  41728'u16: "FileSource",
  41729'u16: "SceneType",
  41730'u16: "CFAPattern",
  41985'u16: "CustomRendered",
  41986'u16: "ExposureMode",
  41987'u16: "WhiteBalance",
  41988'u16: "DigitalZoomRatio",
  41989'u16: "FocalLengthIn35mmFilm",
  41990'u16: "SceneCaptureType",
  41991'u16: "GainControl",
  41992'u16: "Contrast",
  41993'u16: "Saturation",
  41994'u16: "Sharpness",
  41995'u16: "DeviceSettingDescription",
  41996'u16: "SubjectDistanceRange",
  42016'u16: "ImageUniqueID",
  42032'u16: "CameraOwnerName",
  42033'u16: "BodySerialNumber",
  42034'u16: "LensSpecification",
  42035'u16: "LensMake",
  42036'u16: "LensModel",
  42037'u16: "LensSerialNumber",
  42112'u16: "GDAL_METADATA",
  42113'u16: "GDAL_NODATA",
  48129'u16: "PixelFormat",
  48130'u16: "Transformation",
  48131'u16: "Uncompressed",
  48132'u16: "ImageType",
  48256'u16: "ImageWidth",
  48257'u16: "ImageHeight",
  48258'u16: "WidthResolution",
  48259'u16: "HeightResolution",
  48320'u16: "ImageOffset",
  48321'u16: "ImageByteCount",
  48322'u16: "AlphaOffset",
  48323'u16: "AlphaByteCount",
  48324'u16: "ImageDataDiscard",
  48325'u16: "AlphaDataDiscard",
  48132'u16: "ImageType",
  50215'u16: "Oce_Scanjob_Description",
  50216'u16: "Oce_Application_Selector",
  50217'u16: "Oce_Identification_Number",
  50218'u16: "Oce_ImageLogic_Characteristics",
  50341'u16: "PrintImageMatching",
  50706'u16: "DNGVersion",
  50707'u16: "DNGBackwardVersion",
  50708'u16: "UniqueCameraModel",
  50709'u16: "LocalizedCameraModel",
  50710'u16: "CFAPlaneColor",
  50711'u16: "CFALayout",
  50712'u16: "LinearizationTable",
  50713'u16: "BlackLevelRepeatDim",
  50714'u16: "BlackLevel",
  50715'u16: "BlackLevelDeltaH",
  50716'u16: "BlackLevelDeltaV",
  50717'u16: "WhiteLevel",
  50718'u16: "DefaultScale",
  50719'u16: "DefaultCropOrigin",
  50720'u16: "DefaultCropSize",
  50721'u16: "ColorMatrix1",
  50722'u16: "ColorMatrix2",
  50723'u16: "CameraCalibration1",
  50724'u16: "CameraCalibration2",
  50725'u16: "ReductionMatrix1",
  50726'u16: "ReductionMatrix2",
  50727'u16: "AnalogBalance",
  50728'u16: "AsShotNeutral",
  50729'u16: "AsShotWhiteXY",
  50730'u16: "BaselineExposure",
  50731'u16: "BaselineNoise",
  50732'u16: "BaselineSharpness",
  50733'u16: "BayerGreenSplit",
  50734'u16: "LinearResponseLimit",
  50735'u16: "CameraSerialNumber",
  50736'u16: "LensInfo",
  50737'u16: "ChromaBlurRadius",
  50738'u16: "AntiAliasStrength",
  50739'u16: "ShadowScale",
  50740'u16: "DNGPrivateData",
  50741'u16: "MakerNoteSafety",
  50778'u16: "CalibrationIlluminant1",
  50779'u16: "CalibrationIlluminant2",
  50780'u16: "BestQualityScale",
  50781'u16: "RawDataUniqueID",
  50784'u16: "Alias_Layer_Metadata",
  50827'u16: "OriginalRawFileName",
  50828'u16: "OriginalRawFileData",
  50829'u16: "ActiveArea",
  50830'u16: "MaskedAreas",
  50831'u16: "AsShotICCProfile",
  50832'u16: "AsShotPreProfileMatrix",
  50833'u16: "CurrentICCProfile",
  50834'u16: "CurrentPreProfileMatrix",
  50879'u16: "ColorimetricReference",
  50931'u16: "CameraCalibrationSignature",
  50932'u16: "ProfileCalibrationSignature",
  50933'u16: "ExtraCameraProfiles",
  50934'u16: "AsShotProfileName",
  50935'u16: "NoiseReductionApplied",
  50936'u16: "ProfileName",
  50937'u16: "ProfileHueSatMapDims",
  50938'u16: "ProfileHueSatMapData1",
  50939'u16: "ProfileHueSatMapData2",
  50940'u16: "ProfileToneCurve",
  50941'u16: "ProfileEmbedPolicy",
  50942'u16: "ProfileCopyright",
  50964'u16: "ForwardMatrix1",
  50965'u16: "ForwardMatrix2",
  50966'u16: "PreviewApplicationName",
  50967'u16: "PreviewApplicationVersion",
  50968'u16: "PreviewSettingsName",
  50969'u16: "PreviewSettingsDigest",
  50970'u16: "PreviewColorSpace",
  50971'u16: "PreviewDateTime",
  50972'u16: "RawImageDigest",
  50973'u16: "OriginalRawFileDigest",
  50974'u16: "SubTileBlockSize",
  50975'u16: "RowInterleaveFactor",
  50981'u16: "ProfileLookTableDims",
  50982'u16: "ProfileLookTableData",
  51008'u16: "OpcodeList1",
  51009'u16: "OpcodeList2",
  51022'u16: "OpcodeList3",
  51041'u16: "NoiseProfile",
  51089'u16: "OriginalDefaultFinalSize",
  51090'u16: "OriginalBestQualityFinalSize",
  51091'u16: "OriginalDefaultCropSize",
  51107'u16: "ProfileHueSatMapEncoding",
  51108'u16: "ProfileLookTableEncoding",
  51109'u16: "BaselineExposureOffset",
  51110'u16: "DefaultBlackRender",
  51111'u16: "NewRawImageDigest",
  51112'u16: "RawToPreviewGain",
  51125'u16: "DefaultUserCrop",
}.toOrderedTable


proc readHeader*(file: File, start: int64):
    tuple[offset: uint16, endian: Endianness] =
  ## Read the tiff header at the given start offset and return the
  ## offset of the first image file directory (IFD), and the endianness of
  ## the file.  Raise UnknownFormatError when the file format is
  ## unknown.

  # A header is made up of a three elements, order, magic and offset:
  # 2 bytes: byte order, 0x4949 or 0x4d4d
  # 2 bytes: magic number, 0x2a (42)
  # 4 bytes: offset

  try:
    file.setFilePos(start)

    # Determine the endian of the file by reading the byte order marker.
    var endian: Endianness
    var order = readNumber[uint16](file, system.cpuEndian)
    if order == 0x4d4d:
      endian = bigEndian
    elif order == 0x4949:
      endian = littleEndian
    else:
      raise newException(UnknownFormatError, "Tiff: invalid byte order marker.")

    # Check for the magic 42.
    var magic = readNumber[uint16](file, endian)
    if magic != 0x2a: # 42
      raise newException(UnknownFormatError, "Tiff: wrong magic number.")

    # Read the offset of the first image file directory (IFD).
    var offset = readNumber[uint16](file, endian)
    result = (offset, endian)
  except UnknownFormatError:
    raise
  except:
    raise newException(UnknownFormatError, "Tiff: not a tiff file.")


proc tagName*(tag: uint16): string =
  ## Return the name of the given tag or "" when not known.

  result = tagToString.getOrDefault(tag)
  if result == nil:
    result = ""



#[
class IFDEntry:
  """ Image File Directory Entry
  usage:
  entry = IFDEntry(fh, header_offset, endian)
  if entry.tag == 123:
    values = entry.get_values()
  """
  # IFD entry is made up of a 2 byte tag, a 2 byte kind, a 4 byte count, and
  # a packed 4 bytes for a total of 12 bytes.
  #
  # There are associated values with the entry. If the values are small
  # enough, they are stored directly in the packed 4 bytes. If there
  # isn't enough room in the 4 bytes, all the values are stored in the
  # file outside the entry in a continuous block pointed to by the
  # packed 4 bytes treated as an offset.
  #
  # The 2 byte kind can have the values 1, 2, ..., 12. A value of 1
  # means the values are bytes, 2 means the values are shorts and 4
  # means the values are longs, etc. Skip unknown kinds.
  #
  # The 4 byte count is the number of values.
  #
  # The 4 packed bytes are values or an offset to values, depending on
  # whether the values fit in the 4 packed bytes or not.
  #
  # The IFD.offset attribute is a pointer to the values stored outside
  # the entry or None when all the values are stored internally.
  #
  # Only the embedded values are read when the entry is
  # constructed. Use the values method, if you want to get the values
  # stored outside as well as inside.

  def __init__(self, fh, header_offset, endian):
    """Read an image file directory at the file handle's current location
    and return an IFDEntry object. fh is a file handle and endian is
    '>' or '<'. The current position advances past the
    IFDEntry. header_offset is the offset of the header and is used
    when fetching values stored outside the entry.
    """
    self.fh = fh
    self.header_offset = header_offset
    self.endian = endian

    # tag 2 bytes, kind 2 bytes, count 4 bytes, packed 4 bytes
    self.tag = read_two(fh, endian)
    self.kind = read_two(fh, endian)
    self.count = read_four(fh, endian)
    packed = fh.read(4)

    self.offset = None
    self.values = []
    if not self.count:
      return

    # Get the values when they fit in the packed 4 bytes.
    if self.kind == 1 or self.kind == 6 or self.kind == 7: # one byte numbers
      if self.count <= 4:
        signed = 1 if self.kind == 6 else 0
        for ix in range(0, self.count):
          self.values.append(length1(packed, ix, signed))
    elif self.kind == 2: # one or more ascii strings each 0 terminated
      if self.count <= 4:
        values = get_strings(packed)
        if not values:
          return
        self.values = values
    elif self.kind == 3 or self.kind == 8: # shorts
      if self.count <= 2:
        signed = 1 if self.kind == 8 else 0
        for ix in range(0, self.count, 2):
          self.values.append(length2(packed, ix, endian, signed))
    elif self.kind == 4 or self.kind == 9: # longs
      if self.count == 1:
        signed = 1 if self.kind == 9 else 0
        self.values.append(length4(packed, 0, endian, signed))
    elif self.kind == 5: # rational: long / long
      pass
    elif self.kind == 10: # SRATIONAL Two SLONG's
      pass
    elif self.kind == 11: # float 4 bytes
      self.values.append(float_me(packed, 0, endian))
    elif self.kind == 12: # Double precision (8-byte) IEEE
      pass
    else:
      # It's not an error when the kind is not known.
      self.offset = packed
      return

    # If the values do not fit in the packed 4 bytes, the packed bytes
    # are an offset to the values somewhere else in the file.
    if not self.values:
      self.offset = length4(packed, 0, endian)

  def get_values(self):
    if not self.values:
      self.read_outside_values()
    return self.values

  def get_value_range(self):
    """Return the start and end offset of the value in the file. Or None
    when it is stored in the entry itself.
    """
    if not self.offset:
      return None
    value_size = bytes_per_kind.get(self.kind)
    if not value_size:
      return None
    start = self.header_offset + self.offset
    end = start + self.count * value_size
    return start, end

  def read_outside_values(self):
    """Read the values stored outside the IFDEntry. The file position is left
    unchanged.
    """
    if self.values:
      return
    value_range = self.get_value_range()
    if not value_range:
      return
    fh = self.fh
    endian = self.endian
    save_pos = fh.tell()
    values = []
    self.fh.seek(value_range[0])

    if self.kind == 2:
      packed = fh.read(self.count)
      values = get_strings(packed)
    else:
      for ix in range(0, self.count):
        if self.kind == 1 or self.kind == 7:
          values.append(read_one(fh))
        elif self.kind == 3:
          values.append(read_two(fh, endian))
        elif self.kind == 8:
          values.append(read_two(fh, endian, 1))
        elif self.kind == 4:
          values.append(read_four(fh, endian))
        elif self.kind == 9:
          values.append(read_four(fh, endian, 1))
        elif self.kind == 5:
          numerator = read_four(fh, endian)
          denominator = read_four(fh, endian)
          values.append((numerator, denominator))
        elif self.kind == 10:
          numerator = read_four(fh, endian, 1)
          denominator = read_four(fh, endian, 1)
          values.append((numerator, denominator))
        elif self.kind == 11:
          values.append(read_float(fh, endian))
        elif self.kind == 12:
          values.append(read_double(fh, endian))

    fh.seek(save_pos)
    self.values = values

  def __str__(self):
    if self.offset == None:
      offset = 'None'
    else:
      offset = '0x{:04X}'.format(self.offset)
    count = len(self.values)
    if count > 4:
      values = self.values[0:4]
      values.append('...')
    else:
      values = self.values
    return "tag={0}(0x{0:02X}), kind={1}, count={2}, offset={3}, values={4}".format(
      self.tag, self.kind, self.count, offset, values)

bytes_per_kind = {
  1: 1,
  2: 1,
  3: 2,
  4: 4,
  5: 8,
  6: 1,
  7: 1,
  8: 2,
  9: 4,
  10: 8,
  11: 4,
  12: 8,
}

def get_strings(packed):
  """Convert the given packed bytes to an array of strings and return
  it.  The bytes contain one or more 0 terminated ascii strings.
  """

  # Find the 0 terminators.
  zeros = []
  if sys.version_info[0] < 3:
    zero = '\x00'
  else:
    zero = 0x00
  for ix in range(0, len(packed)):
    if packed[ix] == zero:
      zeros.append(ix)

  # [2, 5, 9] -> packed[0:2], [3:5], [6:9]
  strings = []
  start = 0
  for pos in zeros:
    if pos - start > 0:
      try:
        string = packed[start:pos].decode('utf-8')
        strings.append(string)
      except:
        pass
        # raise
    start = pos+1

  return strings


def read_ifd(fh, header_offset, endian, ifd_offset):
  """Read the Image File Directory at the given offset and return a
  dictionary of the entries. The dictionary key is the entry tag, and
  the value is a list of the entry's values.

  fh: file handle
  header_offset: offset to the tiff header
  endian: < or >
  ifd_offset: offset to the ifd relative to the header
  """
  ifd = OrderedDict()

  # Read the count of entries.
  fh.seek(header_offset + ifd_offset)
  count = read_two(fh, endian)
  if count is None:
    return None

  # Loop through the directory entries.
  for i in range(0, count):
    entry = IFDEntry(fh, header_offset, endian)
    ifd[entry.tag] = entry.get_values()
    if entry.offset:
      value_range_name = "range_{}".format(entry.tag)
      ifd[value_range_name] = entry.get_value_range()

  # Add a range for each strip or tile.
  add_pixel_ranges(ifd, header_offset)

  # Get the offset to the next IFD.
  ifd['next'] = read_four(fh, endian)
  ifd['range_ifd'] = (header_offset+ifd_offset, int(str(fh.tell())))
  return ifd

def add_pixel_ranges(ifd, header_offset):
  """
  Add strip or tile ranges to the given ifd.
  """
  # (StripOffsets, StripByteCounts), (TileOffsets, TileByteCounts)
  tups = [('strip', 273, 279), ('tile', 324, 325)]

  for name, tag_offset, tag_byte_counts in tups:
    offsets = ifd.get(tag_offset)
    byte_counts = ifd.get(tag_byte_counts)
    if offsets and byte_counts:
      if len(offsets) != len(byte_counts):
        raise NotSupported("The number of offsets is not the same as the number of byte counts.")
      for ix, offset in enumerate(offsets):
        value_range_name = "range_{}{}".format(name, ix)
        start = header_offset + offset
        end = start + byte_counts[ix]
        ifd[value_range_name] = (start, end)


def print_ifd(name, ifd):
  """
  Print out the given IFD.
  """
  print('-'*20 + name + '-'*20)
  for key, values in ifd.items():
    if isinstance(key, int):
      count = len(values)
      if count > 4:
        values = values[0:4]
        values.append('..{}..'.format(count))
    tname = tagName(key)
    if not tname:
      tag = '{}'.format(key)
    else:
      tag = '{}({})'.format(tname, key)
    print('{} = {}'.format(tag, values))





]#

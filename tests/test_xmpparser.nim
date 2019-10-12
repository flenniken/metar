import unittest
import xmpparser
import tables

const xmpSample = """
<?xpacket begin="" id="W5M0MpCehiHzreSzNTczkc9d"?>
<x:xmpmeta xmlns:x="adobe:ns:meta/" x:xmptk="Public XMP Toolkit Core 3.5">
   <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
      <rdf:Description rdf:about=""
            xmlns:crs="http://ns.adobe.com/camera-raw-settings/1.0/">
         <crs:Version>3.2</crs:Version>
         <crs:RawFileName>IMG_6093.dng</crs:RawFileName>
         <crs:WhiteBalance>Custom</crs:WhiteBalance>
         <crs:Temperature>3400</crs:Temperature>
         <crs:Tint>0</crs:Tint>
         <crs:Exposure>+0.35</crs:Exposure>
         <crs:Shadows>2</crs:Shadows>
         <crs:Brightness>67</crs:Brightness>
         <crs:Contrast>+25</crs:Contrast>
         <crs:Saturation>-2</crs:Saturation>
         <crs:Sharpness>25</crs:Sharpness>
         <crs:LuminanceSmoothing>0</crs:LuminanceSmoothing>
         <crs:ColorNoiseReduction>25</crs:ColorNoiseReduction>
         <crs:ChromaticAberrationR>0</crs:ChromaticAberrationR>
         <crs:ChromaticAberrationB>0</crs:ChromaticAberrationB>
         <crs:VignetteAmount>0</crs:VignetteAmount>
         <crs:ShadowTint>0</crs:ShadowTint>
         <crs:RedHue>0</crs:RedHue>
         <crs:RedSaturation>0</crs:RedSaturation>
         <crs:GreenHue>0</crs:GreenHue>
         <crs:GreenSaturation>0</crs:GreenSaturation>
         <crs:BlueHue>0</crs:BlueHue>
         <crs:BlueSaturation>0</crs:BlueSaturation>
         <crs:ToneCurveName>Medium Contrast</crs:ToneCurveName>
         <crs:ToneCurve>
            <rdf:Seq>
               <rdf:li>0, 0</rdf:li>
               <rdf:li>32, 22</rdf:li>
               <rdf:li>64, 56</rdf:li>
               <rdf:li>128, 128</rdf:li>
               <rdf:li>192, 196</rdf:li>
               <rdf:li>255, 255</rdf:li>
            </rdf:Seq>
         </crs:ToneCurve>
         <crs:CameraProfile>ACR 2.4</crs:CameraProfile>
         <crs:HasSettings>True</crs:HasSettings>
         <crs:CropTop>0.002557</crs:CropTop>
         <crs:CropLeft>0.050593</crs:CropLeft>
         <crs:CropBottom>1</crs:CropBottom>
         <crs:CropRight>0.978571</crs:CropRight>
         <crs:CropAngle>1.934207</crs:CropAngle>
         <crs:HasCrop>True</crs:HasCrop>
      </rdf:Description>
      <rdf:Description rdf:about=""
            xmlns:exif="http://ns.adobe.com/exif/1.0/">
         <exif:ExifVersion>0221</exif:ExifVersion>
         <exif:ExposureTime>1/40</exif:ExposureTime>
         <exif:ShutterSpeedValue>5321928/1000000</exif:ShutterSpeedValue>
         <exif:FNumber>28/10</exif:FNumber>
         <exif:ApertureValue>2970854/1000000</exif:ApertureValue>
         <exif:ExposureProgram>2</exif:ExposureProgram>
         <exif:DateTimeOriginal>2014-10-04T06:14:16-07:00</exif:DateTimeOriginal>
         <exif:DateTimeDigitized>2014-10-04T06:14:16-07:00</exif:DateTimeDigitized>
         <exif:ExposureBiasValue>0/1</exif:ExposureBiasValue>
         <exif:MeteringMode>1</exif:MeteringMode>
         <exif:FocalLength>27/1</exif:FocalLength>
         <exif:CustomRendered>0</exif:CustomRendered>
         <exif:ExposureMode>0</exif:ExposureMode>
         <exif:WhiteBalance>1</exif:WhiteBalance>
         <exif:SceneCaptureType>0</exif:SceneCaptureType>
         <exif:FocalPlaneXResolution>3504000/885</exif:FocalPlaneXResolution>
         <exif:FocalPlaneYResolution>2336000/590</exif:FocalPlaneYResolution>
         <exif:FocalPlaneResolutionUnit>2</exif:FocalPlaneResolutionUnit>
         <exif:ISOSpeedRatings>
            <rdf:Seq>
               <rdf:li>100</rdf:li>
            </rdf:Seq>
         </exif:ISOSpeedRatings>
         <exif:Flash rdf:parseType="Resource">
            <exif:Fired>False</exif:Fired>
            <exif:Return>0</exif:Return>
            <exif:Mode>2</exif:Mode>
            <exif:Function>False</exif:Function>
            <exif:RedEyeMode>False</exif:RedEyeMode>
         </exif:Flash>
      </rdf:Description>
      <rdf:Description rdf:about=""
            xmlns:aux="http://ns.adobe.com/exif/1.0/aux/">
         <aux:SerialNumber>620423455</aux:SerialNumber>
         <aux:LensInfo>24/1 70/1 0/0 0/0</aux:LensInfo>
         <aux:Lens>24.0-70.0 mm</aux:Lens>
         <aux:ImageNumber>205</aux:ImageNumber>
         <aux:FlashCompensation>0/1</aux:FlashCompensation>
         <aux:OwnerName>unknown</aux:OwnerName>
         <aux:Firmware>1.1.0</aux:Firmware>
      </rdf:Description>
      <rdf:Description rdf:about=""
            xmlns:tiff="http://ns.adobe.com/tiff/1.0/">
         <tiff:Make>Canon</tiff:Make>
         <tiff:Model>Canon EOS 20D</tiff:Model>
         <tiff:ImageWidth>3329</tiff:ImageWidth>
         <tiff:ImageLength>2219</tiff:ImageLength>
         <tiff:BitsPerSample>
            <rdf:Seq>
               <rdf:li>8</rdf:li>
               <rdf:li>8</rdf:li>
               <rdf:li>8</rdf:li>
            </rdf:Seq>
         </tiff:BitsPerSample>
         <tiff:PhotometricInterpretation>2</tiff:PhotometricInterpretation>
         <tiff:XResolution>240/1</tiff:XResolution>
         <tiff:YResolution>240/1</tiff:YResolution>
         <tiff:ResolutionUnit>2</tiff:ResolutionUnit>
      </rdf:Description>
      <rdf:Description rdf:about=""
            xmlns:xap="http://ns.adobe.com/xap/1.0/">
         <xap:ModifyDate>2014-10-04T06:14:16-07:00</xap:ModifyDate>
         <xap:Rating>2</xap:Rating>
         <xap:MetadataDate>2015-01-02T17:43:40-08:00</xap:MetadataDate>
      </rdf:Description>
      <rdf:Description rdf:about=""
            xmlns:dc="http://purl.org/dc/elements/1.1/">
         <dc:creator>
            <rdf:Seq>
               <rdf:li>unknown</rdf:li>
            </rdf:Seq>
         </dc:creator>
         <dc:title>
            <rdf:Alt>
               <rdf:li xml:lang="x-default">Raw Title</rdf:li>
            </rdf:Alt>
         </dc:title>
         <dc:description>
            <rdf:Alt>
               <rdf:li xml:lang="x-default">This is the description of the photo.</rdf:li>
            </rdf:Alt>
         </dc:description>
         <dc:subject>
            <rdf:Bag>
               <rdf:li>Raw test</rdf:li>
               <rdf:li>photo</rdf:li>
               <rdf:li>Tiapei</rdf:li>
            </rdf:Bag>
         </dc:subject>
      </rdf:Description>
   </rdf:RDF>
</x:xmpmeta>

<?xpacket end="w"?>
"""

#[
const expectedJson = """
{
  "crs:Version": "3.2",
  "crs:RawFileName": "IMG_6093.dng",
  "crs:WhiteBalance": "Custom",
  "crs:Temperature": "3400",
  "crs:Tint": "0",
  "crs:Exposure": "+0.35",
  "crs:Shadows": "2",
  "crs:Brightness": "67",
  "crs:Contrast": "+25",
  "crs:Saturation": "-2",
  "crs:Sharpness": "25",
  "crs:LuminanceSmoothing": "0",
  "crs:ColorNoiseReduction": "25",
  "crs:ChromaticAberrationR": "0",
  "crs:ChromaticAberrationB": "0",
  "crs:VignetteAmount": "0",
  "crs:ShadowTint": "0",
  "crs:RedHue": "0",
  "crs:RedSaturation": "0",
  "crs:GreenHue": "0",
  "crs:GreenSaturation": "0",
  "crs:BlueHue": "0",
  "crs:BlueSaturation": "0",
  "crs:ToneCurveName": "Medium Contrast",
  "crs:ToneCurve": [
    "0, 0",
    "32, 22",
    "64, 56",
    "128, 128",
    "192, 196",
    "255, 255"
  ],
  "crs:CameraProfile": "ACR 2.4",
  "crs:HasSettings": "True",
  "crs:CropTop": "0.002557",
  "crs:CropLeft": "0.050593",
  "crs:CropBottom": "1",
  "crs:CropRight": "0.978571",
  "crs:CropAngle": "1.934207",
  "crs:HasCrop": "True",
  "exif:ExifVersion": "0221",
  "exif:ExposureTime": "1/40",
  "exif:ShutterSpeedValue": "5321928/1000000",
  "exif:FNumber": "28/10",
  "exif:ApertureValue": "2970854/1000000",
  "exif:ExposureProgram": "2",
  "exif:DateTimeOriginal": "2014-10-04T06:14:16-07:00",
  "exif:DateTimeDigitized": "2014-10-04T06:14:16-07:00",
  "exif:ExposureBiasValue": "0/1",
  "exif:MeteringMode": "1",
  "exif:FocalLength": "27/1",
  "exif:CustomRendered": "0",
  "exif:ExposureMode": "0",
  "exif:WhiteBalance": "1",
  "exif:SceneCaptureType": "0",
  "exif:FocalPlaneXResolution": "3504000/885",
  "exif:FocalPlaneYResolution": "2336000/590",
  "exif:FocalPlaneResolutionUnit": "2",
  "exif:ISOSpeedRatings": [
    "100"
  ],
  "exif:Fired": "False",
  "exif:Return": "0",
  "exif:Mode": "2",
  "exif:Function": "False",
  "exif:RedEyeMode": "False",
  "aux:SerialNumber": "620423455",
  "aux:LensInfo": "24/1 70/1 0/0 0/0",
  "aux:Lens": "24.0-70.0 mm",
  "aux:ImageNumber": "205",
  "aux:FlashCompensation": "0/1",
  "aux:OwnerName": "unknown",
  "aux:Firmware": "1.1.0",
  "tiff:Make": "Canon",
  "tiff:Model": "Canon EOS 20D",
  "tiff:ImageWidth": "3329",
  "tiff:ImageLength": "2219",
  "tiff:BitsPerSample": [
    "8",
    "8",
    "8"
  ],
  "tiff:PhotometricInterpretation": "2",
  "tiff:XResolution": "240/1",
  "tiff:YResolution": "240/1",
  "tiff:ResolutionUnit": "2",
  "xap:ModifyDate": "2014-10-04T06:14:16-07:00",
  "xap:Rating": "2",
  "xap:MetadataDate": "2015-01-02T17:43:40-08:00",
  "dc:creator": [
    "unknown"
  ],
  "dc:title": {
    "x-default": "Raw Title"
  },
  "dc:description": {
    "x-default": "This is the description of the photo."
  },
  "dc:subject": [
    "Raw test",
    "photo",
    "Tiapei"
  ]
}
"""
]#

suite "test xmpparser.nim":

  test "test parseXpacket begin":
    var list = parseXpacket(""" begin="" id="W5M0MpCehiHzreSzNTczkc9d"""")
    check(list.len == 2)
    check(list[0].key == "xpacket:begin")
    check(list[0].value == "")
    check(list[1].key == "xpacket:id")
    check(list[1].value == "W5M0MpCehiHzreSzNTczkc9d")

  test "test parseXpacket begin2":
    var list = parseXpacket(""" begin="" id='W5M0MpCehiHzreSzNTczkc9d'""")
    check(list.len == 2)
    check(list[0].key == "xpacket:begin")
    check(list[0].value == "")
    check(list[1].key == "xpacket:id")
    check(list[1].value == "W5M0MpCehiHzreSzNTczkc9d")

  test "test parseXpacket end":
    var list = parseXpacket(""" end="w"""")
    check(list.len == 1)
    check(list[0].key == "xpacket:end")
    check(list[0].value == "w")

  test "test parseNamespaces":
    # echo xmpSample
    var table = parseNamespaces(xmpSample)

    # echo $table.len
    # for k,v in table.pairs:
    #   echo $k & " = " & v

    check(table.len == 9)
    check(table["xmlns:crs"] == "http://ns.adobe.com/camera-raw-settings/1.0/")
    check(table["xmlns:x"] == "adobe:ns:meta/")
    check(table["xmlns:dc"] == "http://purl.org/dc/elements/1.1/")
    check(table["xmlns:aux"] == "http://ns.adobe.com/exif/1.0/aux/")
    check(table["xmlns:rdf"] == "http://www.w3.org/1999/02/22-rdf-syntax-ns#")
    check(table["xmlns:exif"] == "http://ns.adobe.com/exif/1.0/")
    check(table["xmlns:tiff"] == "http://ns.adobe.com/tiff/1.0/")
    check(table["xmlns:xap"] == "http://ns.adobe.com/xap/1.0/")
    check(table["x:xmptk"] == "Public XMP Toolkit Core 3.5")


  test "test xmpParser":
    var metadata = xmpParser(xmpSample)
    # echo pretty(metadata)
    #todo: test xmpParser

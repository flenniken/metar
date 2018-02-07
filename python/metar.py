import sys
# todo: remove hard coded path.
sys.path.append("/Users/steve/code/metarnim/bin")
import metarlib

__version__ = metarlib.getVersion()
read_metadata_json = metarlib.readMetadataJson
read_metadata = metarlib.readMetadata
key_name = metarlib.keyName

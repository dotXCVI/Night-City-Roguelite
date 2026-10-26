#!/usr/bin/env python3
"""en-us.tsv -> WolvenKit JSON for an ArchiveXL onscreens resource.

  python3 build_loc.py en-us.tsv en-us.json.json
  WolvenKit.CLI convert deserialize en-us.json.json   ->  en-us.json (CR2W)

The CR2W file goes into the archive at nightcityroguelite\\localization\\en-us.json
and NightCityRoguelite.archive.xl points ArchiveXL at it.
"""
import json, sys
src, dst = sys.argv[1], sys.argv[2]
entries = []
for line in open(src, encoding='utf-8'):
    line = line.rstrip('\n')
    if not line:
        continue
    key, text = line.split('\t', 1)
    entries.append({
        "$type": "localizationPersistenceOnScreenEntry",
        "femaleVariant": text,
        "maleVariant": "",
        "primaryKey": "0",
        "secondaryKey": key,
    })
doc = {
    "Header": {"WKitJsonVersion": "0.0.9", "DataType": "CR2W"},
    "Data": {
        "Version": 195,
        "BuildVersion": 0,
        "RootChunk": {
            "$type": "JsonResource",
            "cookingPlatform": "PLATFORM_PC",
            "root": {"HandleId": "0", "Data": {"$type": "localizationPersistenceOnScreenEntries", "entries": entries}},
        },
        "EmbeddedFiles": [],
    },
}
json.dump(doc, open(dst, 'w', encoding='utf-8'), indent=2, ensure_ascii=False)
print(len(entries), 'entries')

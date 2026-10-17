"""Generate safe scalar/list metadata definitions from the bundled ExifTool."""
import json, pathlib, subprocess, xml.etree.ElementTree as ET
root = pathlib.Path(__file__).resolve().parents[1]
xml = subprocess.check_output(['perl', str(root/'Sources/Memora/Resources/ExifTool/exiftool'), '-listx', '-f'])
entries = {}
photographic = {'ImageDescription','UserComment','Software','Rating','RatingPercent','ExposureTime','FNumber','ISO','ExposureCompensation','LensModel','LensMake','LensSerialNumber','BodySerialNumber','ShutterSpeedValue','ApertureValue','BrightnessValue','MaxApertureValue','SubjectDistance','MeteringMode','LightSource','Flash','FocalLength','ExposureProgram','ExposureMode','WhiteBalance','DigitalZoomRatio','FocalLengthIn35mmFormat','SceneCaptureType','GainControl','Contrast','Saturation','Sharpness','SubjectDistanceRange','CustomRendered','SensingMethod'}
for table in ET.fromstring(xml).findall('table'):
    family = table.get('g0')
    if family not in ('EXIF', 'XMP', 'IPTC'): continue
    for tag in table.findall('tag'):
        flags = tag.get('flags', '').split(',')
        kind = tag.get('type', '')
        group = tag.get('g1', table.get('g1'))
        category = tag.get('g2', table.get('g2'))
        name = tag.get('name')
        if tag.get('writable') != 'true' or (kind in ('?', 'undef', 'struct', 'binary') and name != 'UserComment') or any(f in flags for f in ('Protected', 'Binary', 'Unsafe')): continue
        if family == 'EXIF' and category not in ('Camera', 'Time', 'Location', 'Author') and name not in photographic: continue
        if 'Offset' in name and not name.startswith('OffsetTime'): continue
        if name.endswith(('Data', 'Image', 'Digest')): continue
        options = []
        for key in tag.findall('./values/key'):
            value = key.find("val[@lang='en']")
            if value is not None: options.append({'value': key.get('id'), 'label': value.text or key.get('id')})
        title = tag.find("desc[@lang='zh_cn']")
        if title is None: title = tag.find("desc[@lang='en']")
        entry = {'id': f'{group}:{name}', 'title': title.text if title is not None else name, 'type': kind, 'isList': 'List' in flags, 'options': options[:100]}
        entries[entry['id']] = entry
out = root/'Sources/Memora/Resources/WritableTags.json'
out.write_text(json.dumps(sorted(entries.values(), key=lambda x:x['id']), ensure_ascii=False, indent=2))
print(f'{len(entries)} editable tag definitions')

import json
import re
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parent
TEXT_FILE = ROOT / "assets/quran/quran-uthmani.txt"
META_FILE = ROOT / "assets/quran/quran-data.xml"
OUTPUT_FILE = ROOT / "assets/quran/quran.json"

# Read Tanzil metadata.
tree = ET.parse(META_FILE)
root = tree.getroot()

sura_nodes = root.find("suras")
juz_nodes = root.find("juzs")

if sura_nodes is None or juz_nodes is None:
    raise RuntimeError("Required Tanzil metadata sections were not found.")

surahs = {}
for node in sura_nodes.findall("sura"):
    number = int(node.attrib["index"])
    surahs[number] = {
        "number": number,
        "nameArabic": node.attrib["name"],
        "nameEnglish": node.attrib["ename"],
        "nameTransliteration": node.attrib["tname"],
        "ayahCount": int(node.attrib["ayas"]),
        "type": node.attrib["type"],
        "rukuCount": int(node.attrib["rukus"]),
        "ayahs": [],
    }

if len(surahs) != 114:
    raise RuntimeError(f"Expected 114 Surahs, found {len(surahs)}.")

# Read the original Tanzil text without changing its Arabic content.
ayah_pattern = re.compile(r"^(\d+)\|(\d+)\|(.*)$")
ayah_total = 0

with TEXT_FILE.open("r", encoding="utf-8-sig") as handle:
    for raw_line in handle:
        line = raw_line.rstrip("\r\n")

        if not line or line.startswith("#"):
            continue

        match = ayah_pattern.match(line)
        if not match:
            raise RuntimeError(f"Unexpected Quran text line: {line!r}")

        surah_number = int(match.group(1))
        ayah_number = int(match.group(2))
        arabic_text = match.group(3)

        if surah_number not in surahs:
            raise RuntimeError(f"Unknown Surah number: {surah_number}")

        expected_ayah = len(surahs[surah_number]["ayahs"]) + 1
        if ayah_number != expected_ayah:
            raise RuntimeError(
                f"Unexpected ayah number in Surah {surah_number}: "
                f"expected {expected_ayah}, found {ayah_number}"
            )

        surahs[surah_number]["ayahs"].append({
            "number": ayah_number,
            "arabicText": arabic_text,
        })
        ayah_total += 1

if ayah_total != 6236:
    raise RuntimeError(f"Expected 6236 ayahs, found {ayah_total}.")

# Verify every Surah has exactly the metadata-declared number of ayahs.
for number in range(1, 115):
    actual = len(surahs[number]["ayahs"])
    expected = surahs[number]["ayahCount"]
    if actual != expected:
        raise RuntimeError(
            f"Surah {number}: metadata says {expected} ayahs, "
            f"text contains {actual}"
        )

# Build Juz boundaries directly from Tanzil metadata.
juzs = []
for node in juz_nodes.findall("juz"):
    juzs.append({
        "number": int(node.attrib["index"]),
        "startSurahNumber": int(node.attrib["sura"]),
        "startAyahNumber": int(node.attrib["aya"]),
    })

if len(juzs) != 30:
    raise RuntimeError(f"Expected 30 Juz, found {len(juzs)}.")

# Add a simple display name while keeping the source boundary exact.
for juz in juzs:
    juz["name"] = f"Juz {juz['number']}"

data = {
    "source": {
        "name": "Tanzil Quran Text",
        "url": "https://tanzil.net",
        "textVersion": "Uthmani",
        "license": "CC BY",
        "note": "Arabic Quran text is preserved from the Tanzil source file."
    },
    "surahs": [surahs[number] for number in range(1, 115)],
    "juzs": juzs,
}

OUTPUT_FILE.write_text(
    json.dumps(data, ensure_ascii=False, indent=2) + "\n",
    encoding="utf-8",
)

print(f"Created {OUTPUT_FILE}")
print(f"Surahs: {len(data['surahs'])}")
print(f"Ayahs: {ayah_total}")
print(f"Juz: {len(data['juzs'])}")

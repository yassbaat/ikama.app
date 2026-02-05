#!/usr/bin/env python3
"""Fetch and analyze the Mawaqit page to extract confData"""

import requests
import re
import json

url = "https://mawaqit.net/en/jamii-lqsiba-benzrt-7000-tunisia"
headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
}

print(f"Fetching: {url}")
resp = requests.get(url, headers=headers)
print(f"Status: {resp.status_code}")
print(f"Content length: {len(resp.text)} bytes")
print()

# Try multiple patterns to extract confData
patterns = [
    r'let\s+confData\s*=\s*(\{[\s\S]+?\});\s*</script>',
    r'let\s+confData\s*=\s*(\{[\s\S]+?\});\s*\n</script>',
    r'let\s+confData\s*=\s*(\{[\s\S]+?\});',
]

json_str = None
for i, pattern in enumerate(patterns):
    match = re.search(pattern, resp.text)
    if match:
        print(f"Pattern {i+1} matched!")
        json_str = match.group(1)
        break

if json_str:
    print(f"\nFound confData! Length: {len(json_str)} chars")
    print(f"First 200 chars: {json_str[:200]}")
    print(f"Last 200 chars: {json_str[-200:]}")
    print()
    
    try:
        data = json.loads(json_str)
        
        print("=" * 60)
        print("EXTRACTED DATA")
        print("=" * 60)
        print(f"\nMosque Name: {data.get('name', 'N/A')}")
        print(f"Label: {data.get('label', 'N/A')}")
        print(f"Times: {data.get('times', [])}")
        print(f"Shuruq: {data.get('shuruq', 'N/A')}")
        print(f"Jumua: {data.get('jumua', 'N/A')}")
        print(f"Timezone: {data.get('timezone', 'N/A')}")
        print()
        
        # Iqama
        iqama_cal = data.get('iqamaCalendar', [])
        print(f"Iqama Calendar: {len(iqama_cal)} entries")
        if iqama_cal:
            print(f"First month keys: {list(iqama_cal[0].keys())[:5]}")
            print(f"Sample day: {iqama_cal[0].get('1', [])}")
        
        print("\nSUCCESS!")
        
    except json.JSONDecodeError as e:
        print(f"\nJSON parse error: {e}")
        print(f"Position: {e.pos}")
        print(f"Problem area:\n...{json_str[e.pos-50:e.pos+50]}...")
else:
    print("ERROR: Could not find confData with any pattern!")

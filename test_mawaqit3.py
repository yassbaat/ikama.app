#!/usr/bin/env python3
"""Extract prayer times from confData"""

import requests
import json
import re
import sys
from bs4 import BeautifulSoup

sys.stdout.reconfigure(encoding='utf-8')

HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
}

def extract_prayer_times():
    """Extract prayer times from the mosque page"""
    url = "https://mawaqit.net/en/jamii-lqsiba-benzrt-7000-tunisia"
    
    try:
        response = requests.get(url, headers=HEADERS, timeout=30)
        soup = BeautifulSoup(response.text, 'html.parser')
        
        # Find the first script tag
        script = soup.find('script')
        if script and script.string:
            text = script.string
            
            # Extract confData JSON
            match = re.search(r'let\s+confData\s*=\s*(\{.+?\});\s*</script>', text, re.DOTALL)
            if not match:
                # Try without the </script> part
                match = re.search(r'let\s+confData\s*=\s*(\{.+?\});', text, re.DOTALL)
            
            if match:
                json_str = match.group(1)
                print("Extracted confData JSON (first 3000 chars):")
                print(json_str[:3000])
                print("\n... [truncated]\n")
                
                try:
                    data = json.loads(json_str)
                    
                    print("\n" + "=" * 80)
                    print("PARSED CONFIG DATA")
                    print("=" * 80)
                    
                    print(f"\nMosque Name: {data.get('name', 'N/A')}")
                    print(f"Label: {data.get('label', 'N/A')}")
                    print(f"Type: {data.get('type', 'N/A')}")
                    print(f"Country: {data.get('countryCode', 'N/A')}")
                    print(f"Timezone: {data.get('timezone', 'N/A')}")
                    print(f"Latitude: {data.get('latitude', 'N/A')}")
                    print(f"Longitude: {data.get('longitude', 'N/A')}")
                    print(f"URL: {data.get('url', 'N/A')}")
                    
                    # Look for prayer times
                    print("\n" + "=" * 80)
                    print("PRAYER TIMES DATA")
                    print("=" * 80)
                    
                    for key in data.keys():
                        if any(prayer in key.lower() for prayer in ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha', 'time', 'salah', 'prayer']):
                            value = data[key]
                            print(f"\n{key}: {value}")
                    
                    # Print all keys for reference
                    print("\n" + "=" * 80)
                    print("ALL AVAILABLE KEYS")
                    print("=" * 80)
                    for key in sorted(data.keys()):
                        value_type = type(data[key]).__name__
                        preview = str(data[key])[:80] if data[key] is not None else "None"
                        print(f"  {key} ({value_type}): {preview}")
                    
                    return data
                    
                except json.JSONDecodeError as e:
                    print(f"Failed to parse JSON: {e}")
                    print(f"JSON string around error (first 500 chars):\n{json_str[:500]}")
            else:
                print("Could not find confData in script")
    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()

def test_api_v3():
    """Test v3 API if available"""
    print("\n" + "=" * 80)
    print("TESTING V3 API")
    print("=" * 80)
    print()
    
    mosque_id = "7000"
    slug = "jamii-lqsiba-benzrt-7000-tunisia"
    
    urls = [
        f"https://mawaqit.net/api/3.0/mosque/{mosque_id}",
        f"https://mawaqit.net/api/3.0/mosque/{slug}",
        f"https://mawaqit.net/api/v3/mosque/{mosque_id}",
        f"https://mawaqit.net/api/v3/mosque/{slug}",
        f"https://mawaqit.net/api/2.0/mosque/{slug}",
    ]
    
    for url in urls:
        print(f"\nTrying: {url}")
        try:
            resp = requests.get(url, headers=HEADERS, timeout=10)
            print(f"  Status: {resp.status_code}")
            
            if resp.status_code == 200:
                try:
                    data = resp.json()
                    print(f"  JSON Response:")
                    print(json.dumps(data, indent=2, ensure_ascii=False)[:2000])
                except:
                    print(f"  Response: {resp.text[:500]}")
        except Exception as e:
            print(f"  Error: {e}")

def get_mosque_by_slug_from_map():
    """Try to find the Tunisia mosque in the map API"""
    print("\n" + "=" * 80)
    print("FINDING MOSQUE IN MAP API")
    print("=" * 80)
    print()
    
    url = "https://mawaqit.net/api/2.0/mosque/map/TN"
    
    try:
        resp = requests.get(url, headers=HEADERS, timeout=30)
        mosques = resp.json()
        
        # Look for our specific mosque
        target_slug = "jamii-lqsiba-benzrt-7000-tunisia"
        
        for mosque in mosques:
            if mosque.get('slug') == target_slug:
                print(f"Found mosque in map API:")
                print(json.dumps(mosque, indent=2, ensure_ascii=False))
                return mosque
        
        # If not found, show first few mosques
        print(f"Mosque with slug '{target_slug}' not found")
        print(f"\nFirst 5 mosques in Tunisia:")
        for mosque in mosques[:5]:
            print(f"  - {mosque.get('name')} (slug: {mosque.get('slug')})")
            
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    extract_prayer_times()
    test_api_v3()
    get_mosque_by_slug_from_map()

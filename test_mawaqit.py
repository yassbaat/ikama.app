#!/usr/bin/env python3
"""Test Mawaqit API endpoints to determine the best approach"""

import requests
import json
import re
import sys
from bs4 import BeautifulSoup

# Fix encoding for Windows
sys.stdout.reconfigure(encoding='utf-8')

# Test headers to mimic a browser
HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept': 'application/json, text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.5',
}

def test_api_endpoint():
    """Test the Mawaqit API endpoint"""
    print("=" * 80)
    print("TEST 1: API Endpoint - https://mawaqit.net/api/2.0/mosque/map/FR")
    print("=" * 80)
    
    url = "https://mawaqit.net/api/2.0/mosque/map/FR"
    
    try:
        response = requests.get(url, headers=HEADERS, timeout=30)
        print(f"Status Code: {response.status_code}")
        print(f"Content-Type: {response.headers.get('Content-Type', 'Unknown')}")
        print(f"Content Length: {len(response.text)} bytes")
        print()
        
        if response.status_code == 200:
            try:
                data = response.json()
                print(f"Response is JSON: YES")
                print(f"Number of mosques: {len(data) if isinstance(data, list) else 'N/A'}")
                print()
                
                if isinstance(data, list) and len(data) > 0:
                    print("Sample mosque entry (first one):")
                    print(json.dumps(data[0], indent=2, ensure_ascii=False))
                    print()
                    
                    # Check available fields
                    print("Available fields in each mosque:")
                    for key, value in data[0].items():
                        value_preview = str(value)[:50] if value is not None else "None"
                        print(f"  - {key}: {type(value).__name__} = {value_preview}")
                    print()
                    
                return data
            except json.JSONDecodeError as e:
                print(f"Failed to parse JSON: {e}")
                print(f"First 500 chars of response:\n{response.text[:500]}")
                return None
        else:
            print(f"Error: HTTP {response.status_code}")
            print(f"Response: {response.text[:500]}")
            return None
            
    except Exception as e:
        print(f"Error: {e}")
        return None

def test_search_api():
    """Test search endpoint"""
    print("=" * 80)
    print("TEST 2: Search API - https://mawaqit.net/api/2.0/mosque/search?q=paris")
    print("=" * 80)
    
    url = "https://mawaqit.net/api/2.0/mosque/search?q=paris"
    
    try:
        response = requests.get(url, headers=HEADERS, timeout=30)
        print(f"Status Code: {response.status_code}")
        print(f"Content Length: {len(response.text)} bytes")
        print()
        
        if response.status_code == 200:
            try:
                data = response.json()
                print(f"Response is JSON: YES")
                print(f"Type: {type(data).__name__}")
                
                if isinstance(data, list):
                    print(f"Number of results: {len(data)}")
                    if len(data) > 0:
                        print("\nSample result:")
                        print(json.dumps(data[0], indent=2, ensure_ascii=False))
                elif isinstance(data, dict):
                    print(f"Keys: {list(data.keys())}")
                    print("\nFull response:")
                    print(json.dumps(data, indent=2, ensure_ascii=False))
                
                return data
            except json.JSONDecodeError as e:
                print(f"Not JSON: {e}")
                print(f"Response text (first 500 chars):\n{response.text[:500]}")
        else:
            print(f"Error: HTTP {response.status_code}")
            print(f"Response: {response.text[:500]}")
            
    except Exception as e:
        print(f"Error: {e}")
    
    return None

def test_mosque_page():
    """Test scraping a mosque page"""
    print("=" * 80)
    print("TEST 3: Mosque Page Scraping")
    print("URL: https://mawaqit.net/en/jamii-lqsiba-benzrt-7000-tunisia")
    print("=" * 80)
    
    url = "https://mawaqit.net/en/jamii-lqsiba-benzrt-7000-tunisia"
    
    try:
        response = requests.get(url, headers=HEADERS, timeout=30)
        print(f"Status Code: {response.status_code}")
        print(f"Content Length: {len(response.text)} bytes")
        print()
        
        if response.status_code == 200:
            soup = BeautifulSoup(response.text, 'html.parser')
            
            # Extract mosque ID from URL
            mosque_id_match = re.search(r'-(\d+)-', url)
            if mosque_id_match:
                mosque_id = mosque_id_match.group(1)
                print(f"Extracted Mosque ID: {mosque_id}")
                print()
            
            # Try to find prayer times in JavaScript variables
            scripts = soup.find_all('script')
            print(f"Found {len(scripts)} script tags")
            print()
            
            # Look for prayer times data in scripts
            for i, script in enumerate(scripts):
                if script.string:
                    text = script.string
                    
                    # Look for times data
                    if '"times"' in text or '"fajr"' in text.lower() or 'iqama' in text.lower():
                        print(f"Script {i} contains prayer times data!")
                        print("-" * 40)
                        
                        # Try to extract the JSON
                        try:
                            # Find JSON pattern
                            patterns = [
                                r'var\s+times\s*=\s*(\{[^;]+\});',
                                r'"times":\s*(\{[^}]+\})',
                                r'let\s+times\s*=\s*(\{[^;]+\});',
                            ]
                            
                            for pattern in patterns:
                                match = re.search(pattern, text, re.DOTALL)
                                if match:
                                    json_str = match.group(1)
                                    print(f"Found match with pattern: {pattern[:40]}...")
                                    print(f"JSON string length: {len(json_str)}")
                                    print(f"First 500 chars:\n{json_str[:500]}")
                                    print()
                                    break
                        except Exception as e:
                            print(f"Could not extract: {e}")
                        
                        # Print script preview
                        if len(text) < 2000:
                            print(f"Full script:\n{text}")
                        else:
                            print(f"Script preview (first 1000 chars):\n{text[:1000]}")
                        print()
                        break
            
            # Look for data in HTML
            print("\nLooking for prayer time elements...")
            
            # Find all elements with times
            time_elements = soup.find_all(attrs={"class": re.compile("time|salah|prayer", re.I)})
            print(f"Found {len(time_elements)} elements with time/prayer class")
            
            # Look for specific prayers
            prayers = ['fajr', 'sunrise', 'dhuhr', 'asr', 'maghrib', 'isha']
            for prayer in prayers:
                elements = soup.find_all(attrs={"data-prayer": prayer})
                if elements:
                    print(f"\nFound {len(elements)} elements with data-prayer='{prayer}'")
                    for el in elements[:2]:
                        print(f"  {el.get_text(strip=True)}")
            
            return True
        else:
            print(f"Error: HTTP {response.status_code}")
            return False
            
    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()
        return False

def test_mosque_api_with_id():
    """Try to get mosque data using the ID from the URL"""
    print("=" * 80)
    print("TEST 4: Mosque API by ID")
    print("=" * 80)
    
    mosque_id = "7000"  # From the URL
    
    # Try different API patterns
    urls = [
        f"https://mawaqit.net/api/2.0/mosque/{mosque_id}",
        f"https://mawaqit.net/api/2.0/mosque/info?id={mosque_id}",
        f"https://mawaqit.net/api/2.0/mosque/times?id={mosque_id}",
        f"https://mawaqit.net/fr/id/{mosque_id}",
    ]
    
    for url in urls:
        print(f"\nTrying: {url}")
        try:
            resp = requests.get(url, headers=HEADERS, timeout=10)
            print(f"  Status: {resp.status_code}")
            print(f"  Content-Type: {resp.headers.get('Content-Type', 'Unknown')}")
            
            if resp.status_code == 200:
                content_type = resp.headers.get('Content-Type', '')
                if 'json' in content_type:
                    try:
                        data = resp.json()
                        print(f"  JSON Response:")
                        print(json.dumps(data, indent=2, ensure_ascii=False)[:1500])
                    except:
                        print(f"  Response: {resp.text[:500]}")
                else:
                    print(f"  HTML Response (first 500 chars): {resp.text[:500]}")
        except Exception as e:
            print(f"  Error: {e}")

if __name__ == "__main__":
    print("\n")
    print("=" * 80)
    print("MAWAQIT API FEASIBILITY TEST")
    print("=" * 80)
    print("\n")
    
    # Test 1: API endpoint for map
    api_data = test_api_endpoint()
    
    print("\n\n")
    
    # Test 2: Search API
    search_data = test_search_api()
    
    print("\n\n")
    
    # Test 3: Page scraping
    page_result = test_mosque_page()
    
    print("\n\n")
    
    # Test 4: API by ID
    test_mosque_api_with_id()
    
    print("\n")
    print("=" * 80)
    print("TEST COMPLETE")
    print("=" * 80)

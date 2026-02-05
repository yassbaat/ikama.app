#!/usr/bin/env python3
"""Deep dive into Mawaqit page structure"""

import requests
import json
import re
import sys
from bs4 import BeautifulSoup

sys.stdout.reconfigure(encoding='utf-8')

HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
}

def extract_all_scripts():
    """Extract all JavaScript data from the mosque page"""
    url = "https://mawaqit.net/en/jamii-lqsiba-benzrt-7000-tunisia"
    
    try:
        response = requests.get(url, headers=HEADERS, timeout=30)
        soup = BeautifulSoup(response.text, 'html.parser')
        
        print("=" * 80)
        print("EXTRACTING ALL JAVASCRIPT DATA")
        print("=" * 80)
        print()
        
        scripts = soup.find_all('script')
        
        for i, script in enumerate(scripts):
            if script.string:
                text = script.string.strip()
                
                # Look for times data
                if 'times' in text.lower() or 'prayer' in text.lower() or 'fajr' in text.lower():
                    print(f"\n{'=' * 80}")
                    print(f"SCRIPT {i}")
                    print('=' * 80)
                    
                    # Try to find and print the specific prayer times section
                    lines = text.split('\n')
                    for line in lines:
                        if any(keyword in line.lower() for keyword in ['times', 'fajr', 'dhuhr', 'asr', 'maghrib', 'isha', 'iqama', 'adhan']):
                            print(line.strip())
                    
                    # If script is small, print it all
                    if len(text) < 3000:
                        print("\n--- FULL SCRIPT ---")
                        print(text)
                    else:
                        print(f"\n--- SCRIPT TOO LONG ({len(text)} chars) ---")
                        print(text[:2000])
                        print("...")
                    
                    print()
        
        # Also look for JSON-LD or data attributes
        print("\n" + "=" * 80)
        print("LOOKING FOR JSON-LD / STRUCTURED DATA")
        print("=" * 80)
        
        json_ld_scripts = soup.find_all('script', type='application/ld+json')
        for script in json_ld_scripts:
            if script.string:
                print("\nJSON-LD found:")
                print(script.string[:2000])
        
    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()

def test_different_countries():
    """Test the map API for different countries"""
    print("\n" + "=" * 80)
    print("TESTING MAP API FOR DIFFERENT COUNTRIES")
    print("=" * 80)
    print()
    
    countries = ['FR', 'US', 'GB', 'CA', 'TN', 'MA', 'DZ']
    
    for country in countries:
        url = f"https://mawaqit.net/api/2.0/mosque/map/{country}"
        print(f"\n{country}: ", end='', flush=True)
        
        try:
            resp = requests.get(url, headers=HEADERS, timeout=10)
            if resp.status_code == 200:
                try:
                    data = resp.json()
                    if isinstance(data, list):
                        print(f"OK - {len(data)} mosques")
                        if len(data) > 0:
                            print(f"  Sample: {data[0].get('name', 'N/A')} in {data[0].get('city', 'N/A')}")
                    else:
                        print(f"OK - Unexpected format: {type(data)}")
                except:
                    print(f"OK - Not JSON")
            else:
                print(f"HTTP {resp.status_code}")
        except Exception as e:
            print(f"Error: {e}")

def test_mosque_detail_page():
    """Get detailed prayer times from a page"""
    print("\n" + "=" * 80)
    print("TESTING PRAYER TIMES FROM A FRENCH MOSQUE")
    print("=" * 80)
    print()
    
    # Get the first mosque from the FR list
    url = "https://mawaqit.net/api/2.0/mosque/map/FR"
    
    try:
        resp = requests.get(url, headers=HEADERS, timeout=10)
        mosques = resp.json()
        
        if len(mosques) > 0:
            first_mosque = mosques[0]
            slug = first_mosque['slug']
            
            print(f"Testing with mosque: {first_mosque['name']} (slug: {slug})")
            
            # Try to access its page
            page_url = f"https://mawaqit.net/en/{slug}"
            print(f"URL: {page_url}")
            
            page_resp = requests.get(page_url, headers=HEADERS, timeout=10)
            
            if page_resp.status_code == 200:
                soup = BeautifulSoup(page_resp.text, 'html.parser')
                
                # Look for times in the HTML directly
                print("\nLooking for time elements in HTML...")
                
                # Find elements with specific classes
                time_containers = soup.find_all(['div', 'span', 'td'], class_=re.compile('time|hour|prayer'))
                print(f"Found {len(time_containers)} potential time elements")
                
                for el in time_containers[:10]:
                    text = el.get_text(strip=True)
                    if ':' in text and len(text) < 20:
                        print(f"  - {text}")
                
                # Look in scripts for JSON
                print("\nLooking for prayer times JSON in scripts...")
                scripts = soup.find_all('script')
                
                for script in scripts:
                    if script.string and '"times"' in script.string:
                        # Try to extract times JSON
                        text = script.string
                        
                        # Find the times object
                        match = re.search(r'"times":\s*(\{[^}]+\})', text)
                        if match:
                            print("\nFound times object!")
                            print(match.group(1)[:1000])
                        
                        # Also look for iqama
                        match2 = re.search(r'"iqama":\s*(\{[^}]+\})', text)
                        if match2:
                            print("\nFound iqama object!")
                            print(match2.group(1)[:1000])
                        
                        break
            else:
                print(f"Failed to load page: HTTP {page_resp.status_code}")
                
    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    extract_all_scripts()
    test_different_countries()
    test_mosque_detail_page()

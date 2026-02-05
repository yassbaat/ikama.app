# Mawaqit API Analysis

## Test Results

### Option 1: Map API (`/api/2.0/mosque/map/{country}`)

**Endpoint:** `https://mawaqit.net/api/2.0/mosque/map/{country_code}`

**Working Country Codes Tested:**
- FR: 1,615 mosques (France)
- US: 276 mosques (USA)
- GB: 197 mosques (UK)
- CA: 212 mosques (Canada)
- TN: 2,143 mosques (Tunisia)
- MA: 1,092 mosques (Morocco)
- DZ: 5,582 mosques (Algeria)

**Response Format:**
```json
[
  {
    "slug": "mosquee-falah-cachan",
    "name": "Mosquée El Falah",
    "image1": "https://cdn.mawaqit.net/images/...",
    "address": "12 rue des peupliers",
    "city": "Cachan",
    "zipcode": "94230",
    "countryFullName": "France",
    "lng": 2.326027082209,
    "lat": 48.78357926042
  }
]
```

**Pros:**
- Fast, returns all mosques in a country
- No authentication needed
- JSON format

**Cons:**
- No prayer times (only basic info)
- Must search/scrape individual pages for times

---

### Option 2: Mosque Page Scraping

**URL Format:** `https://mawaqit.net/{lang}/{slug}`

**Example:** `https://mawaqit.net/en/jamii-lqsiba-benzrt-7000-tunisia`

**Data Available:**
The page contains a `confData` JSON object with complete information:

```javascript
let confData = {
  // Basic Info
  "name": "جامع القصيبة - بنزرت",
  "label": "جامع القصيبة - بنزرت",
  "type": "MOSQUE",
  "countryCode": "TN",
  "timezone": "Africa/Tunis",
  "latitude": 37.2780626,
  "longitude": 9.8766209,
  "url": "http://mawaqit.net/en/jamii-lqsiba-benzrt-7000-tunisia",
  
  // Prayer Times (Adhan) - Array: [Fajr, Dhuhr, Asr, Maghrib, Isha]
  "times": ["05:50", "12:41", "15:27", "17:52", "19:19"],
  
  // Sunrise
  "shuruq": "07:19",
  
  // Friday Prayer
  "jumua": "12:42",
  "jumua2": null,
  "jumua3": null,
  
  // Iqama Times (relative to adhan)
  "iqamaCalendar": [
    {
      "1": ["+30", "+15", "+15", "+10", "+15"],  // Fajr, Dhuhr, Asr, Maghrib, Isha
      // ... more days
    }
  ],
  
  // Annual Calendar
  "calendar": [
    {
      "1": ["06:00", "07:34", "12:31", "14:55", "17:17", "18:48"],
      "2": ["06:01", "07:35", "12:31", "14:55", "17:17", "18:48"],
      // ... day numbers with [Fajr, Shuruq, Dhuhr, Asr, Maghrib, Isha]
    }
  ],
  
  // Features
  "womenSpace": true,
  "janazaPrayer": true,
  "aidPrayer": true,
  "ablutions": true,
  "parking": false,
  "handicapAccessibility": false,
  
  // Images
  "image": "https://cdn.mawaqit.net/images/...",
  "interiorPicture": "https://cdn.mawaqit.net/images/...",
  "exteriorPicture": "https://cdn.mawaqit.net/images/...",
  
  // Settings
  "iqamaEnabled": true,
  "iqamaDisplayTime": 30,
  "timeDisplayFormat": "24",
  "hijriDateEnabled": true,
  "temperatureEnabled": true,
  "temperatureUnit": "C"
};
```

**Pros:**
- Complete data including prayer times
- Iqama times available
- Annual calendar available
- No authentication needed

**Cons:**
- Requires scraping (parsing HTML/JS)
- One request per mosque

---

### Search API Test

**Endpoint:** `https://mawaqit.net/api/2.0/mosque/search?q={query}`

**Result:** Returns empty list `[]` (not working)

---

## Recommended Implementation

### Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    USER SEARCH FLOW                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. User searches for mosque by name/city                       │
│     │                                                           │
│     ▼                                                           │
│  2. If country known:                                           │
│     Call /api/2.0/mosque/map/{country}                          │
│     Filter results locally by name/city                         │
│                                                                 │
│  3. If country unknown:                                         │
│     Try multiple country APIs or ask user                       │
│                                                                 │
│  4. Show search results (name, city, address)                   │
│     │                                                           │
│     ▼                                                           │
│  5. User selects mosque                                         │
│     │                                                           │
│     ▼                                                           │
│  6. Scrape mosque page for prayer times                         │
│     GET https://mawaqit.net/en/{slug}                           │
│     Extract confData.times, confData.iqamaCalendar              │
│     │                                                           │
│     ▼                                                           │
│  7. Cache prayer times locally (SQLite)                         │
│     Refresh daily or on user request                            │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Provider Implementation

**MawaqitScrapingProvider:**

```rust
impl PrayerDataProvider for MawaqitScrapingProvider {
    async fn search_mosques(&self, query: &str, country: Option<&str>) {
        // If country specified, fetch that country's map
        // Otherwise, could try multiple countries or default to common ones
        let url = format!("https://mawaqit.net/api/2.0/mosque/map/{}", country.unwrap_or("FR"));
        let mosques = fetch_json(url).await?;
        
        // Filter locally by name/city
        mosques.into_iter()
            .filter(|m| m.name.contains(query) || m.city.contains(query))
            .collect()
    }
    
    async fn get_prayer_times(&self, mosque_slug: &str) {
        // Scrape the mosque page
        let url = format!("https://mawaqit.net/en/{}", mosque_slug);
        let html = fetch_html(url).await?;
        
        // Extract confData JSON
        let conf_data = extract_conf_data(&html)?;
        
        // Parse times array [Fajr, Dhuhr, Asr, Maghrib, Isha]
        let times = conf_data["times"].as_array()?;
        
        // Parse iqama (relative times like "+30" = 30 min after adhan)
        let iqama_calendar = conf_data["iqamaCalendar"].as_array()?;
        
        PrayerTimes {
            fajr: Prayer { adhan: times[0], iqama: calculate_iqama(times[0], iqama[0]) },
            dhuhr: Prayer { adhan: times[1], iqama: calculate_iqama(times[1], iqama[1]) },
            // ... etc
        }
    }
}
```

### Key Points

1. **No Authentication Required** - Both API and scraping work without API keys
2. **Two-Step Process**:
   - Search: Use `/api/2.0/mosque/map/{country}`
   - Times: Scrape `/{lang}/{slug}` page
3. **Data Format**:
   - Times: `['HH:MM', 'HH:MM', 'HH:MM', 'HH:MM', 'HH:MM']` (24h format)
   - Order: Fajr, Dhuhr, Asr, Maghrib, Isha
   - Iqama: Relative minutes (`+30` = 30 min after adhan)
4. **Caching Essential** - Scrape once, cache locally, refresh daily
5. **Rate Limiting** - Be respectful, add delays between requests

### Country Codes to Support

Priority countries based on mosque count:
1. **DZ** (Algeria) - 5,582 mosques
2. **TN** (Tunisia) - 2,143 mosques  
3. **FR** (France) - 1,615 mosques
4. **MA** (Morocco) - 1,092 mosques
5. **CA** (Canada) - 212 mosques
6. **GB** (UK) - 197 mosques
7. **US** (USA) - 276 mosques

### UI Flow

1. User clicks "Search Mosques"
2. Show country selector (dropdown with flags)
3. User enters search term
4. App fetches map for selected country
5. Filter and display matching mosques
6. User selects mosque
7. App scrapes prayer times
8. Cache and display times

---

## Summary

| Feature | Map API | Page Scraping |
|---------|---------|---------------|
| Authentication | None | None |
| Search | Yes (country-based) | No |
| Prayer Times | No | Yes |
| Iqama Times | No | Yes |
| Annual Calendar | No | Yes |
| Speed | Fast (~500KB) | Slower (~60KB per page) |
| Reliability | High | High |

**Best Approach:** Use Map API for search, page scraping for prayer times.

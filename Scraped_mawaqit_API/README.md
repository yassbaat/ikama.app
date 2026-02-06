# Scraped Mawaqit API

A serverless API that fetches and caches mosque data and prayer times from Mawaqit.

## Endpoints

| Endpoint | Description |
|----------|-------------|
| `GET /api/countries` | List all 159 supported countries |
| `GET /api/mosques/{country}` | Get mosques by country code (e.g., `/api/mosques/TN`) |
| `GET /api/prayer-times/{slug}` | Get prayer times for a mosque |
| `GET /api/health` | Health check |

## Quick Start

```bash
# Install dependencies
npm install

# Parse countries data (one-time setup)
npm run parse-countries

# Run locally
npm run dev
```

## Deployment

```bash
# Deploy to Vercel
vercel --prod
```

## API Examples

```bash
# Get all countries
curl https://your-api.vercel.app/api/countries

# Search mosques in Tunisia
curl "https://your-api.vercel.app/api/mosques/TN?q=جامع"

# Get prayer times
curl https://your-api.vercel.app/api/prayer-times/jm-lhd-qsyb-sws-4041-tunisia
```

## Response Formats

### Countries
```json
{
  "count": 159,
  "countries": [
    { "code": "DZ", "name": "ALGERIA", "mosqueCount": 8540, "coordinates": {...} }
  ]
}
```

### Mosques
```json
{
  "country": "TN",
  "count": 2627,
  "mosques": [
    { "slug": "mosque-slug", "name": "المسجد", "city": "Tunis", "lat": 36.8, "lng": 10.1 }
  ],
  "cached": true
}
```

### Prayer Times
```json
{
  "slug": "mosque-slug",
  "name": "المسجد",
  "fajr": { "adhan": "05:50", "iqama": "06:20" },
  "dhuhr": { "adhan": "12:41", "iqama": "12:56" },
  "asr": { "adhan": "15:27", "iqama": "15:42" },
  "maghrib": { "adhan": "17:52", "iqama": "18:02" },
  "isha": { "adhan": "19:19", "iqama": "19:34" },
  "shuruq": "07:19",
  "jumua": "12:42"
}
```

## Caching

- **Countries**: Static, cached indefinitely
- **Mosque lists**: 24 hour TTL
- **Prayer times**: 6 hour TTL (scraped on-demand)

## Rate Limits

Be respectful to Mawaqit servers. The API uses:
- Edge caching (1 hour)
- Local JSON file caching
- On-demand scraping (not batch)

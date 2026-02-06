// TypeScript types for the Mawaqit Scraper API

// Country data extracted from the Mawaqit countries list
export interface Country {
    code: string;           // ISO 2-letter code e.g. "TN"
    name: string;           // Full name e.g. "TUNISIA"
    mosqueCount: number;    // Number of mosques registered
    coordinates: {
        lat: number;
        lng: number;
    };
}

// Mosque basic info from the map API
export interface Mosque {
    slug: string;           // Unique identifier e.g. "jm-lhd-qsyb-sws-4041-tunisia"
    name: string;           // Mosque name (often in Arabic)
    image1?: string;        // Primary image URL
    address?: string;       // Street address
    city: string;           // City name
    zipcode?: string;       // Postal code
    countryFullName: string; // Country name
    lat: number;            // Latitude
    lng: number;            // Longitude
}

// Single prayer time with adhan and iqama
export interface PrayerTime {
    adhan: string;          // Time in HH:MM format
    iqama: string | null;   // Iqama time (null if not set)
}

// Complete prayer times for a mosque
export interface PrayerTimes {
    slug: string;
    name: string;
    fajr: PrayerTime;
    dhuhr: PrayerTime;
    asr: PrayerTime;
    maghrib: PrayerTime;
    isha: PrayerTime;
    shuruq: string;         // Sunrise time
    jumua: string | null;   // Friday prayer time
    jumua2: string | null;  // Second Friday prayer (if available)
    lastUpdated: string;    // ISO timestamp of last scrape
}

// Raw confData object from Mawaqit page (partial, only fields we use)
export interface MawaqitConfData {
    name: string;
    label?: string;
    times: string[];        // [Fajr, Dhuhr, Asr, Maghrib, Isha]
    shuruq: string;
    jumua: string | null;
    jumua2: string | null;
    iqamaCalendar?: IqamaCalendar[];
    iqamaEnabled?: boolean;
    timezone?: string;
    countryCode?: string;
}

// Iqama calendar structure - maps day numbers to iqama offsets
export interface IqamaCalendar {
    [day: string]: string[]; // e.g. "1": ["+30", "+15", "+15", "+10", "+15"]
}

// API response for the countries endpoint
export interface CountriesResponse {
    count: number;
    countries: Country[];
}

// API response for the mosques endpoint
export interface MosquesResponse {
    country: string;
    count: number;
    mosques: Mosque[];
    cached: boolean;
    lastUpdated: string;
}

// API response for the prayer times endpoint
export interface PrayerTimesResponse extends PrayerTimes {
    cached: boolean;
}

// Cache metadata stored alongside cached data
export interface CacheMetadata {
    lastUpdated: string;    // ISO timestamp
    expiresAt: string;      // ISO timestamp
    source: 'mawaqit';
}

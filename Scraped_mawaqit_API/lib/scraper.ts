// Core scraper module for fetching data from Mawaqit
// Handles HTTP requests with proper error handling and rate limiting

import { Mosque, MawaqitConfData, PrayerTimes } from './types';
import { extractConfData, confDataToPrayerTimes } from './parser';

// Base URLs for Mawaqit APIs
const MAWAQIT_MAP_API = 'https://mawaqit.net/api/2.0/mosque/map';
const MAWAQIT_PAGE_BASE = 'https://mawaqit.net/en';

// User-Agent to identify our scraper (be respectful)
const USER_AGENT = 'MawaqitScraperAPI/1.0 (Prayer Times Aggregator)';

// Fetch mosque list for a specific country from the Mawaqit Map API
// Returns array of Mosque objects
export async function fetchMosquesByCountry(countryCode: string): Promise<Mosque[]> {
    const url = `${MAWAQIT_MAP_API}/${countryCode.toUpperCase()}`;

    try {
        const response = await fetch(url, {
            headers: {
                'User-Agent': USER_AGENT,
                'Accept': 'application/json'
            }
        });

        if (!response.ok) {
            throw new Error(`Mawaqit API error: ${response.status} ${response.statusText}`);
        }

        const mosques = await response.json() as Mosque[];
        return mosques;
    } catch (error) {
        console.error(`Failed to fetch mosques for ${countryCode}:`, error);
        throw error;
    }
}

// Fetch and parse prayer times for a specific mosque
// Scrapes the mosque page and extracts confData
export async function fetchPrayerTimes(slug: string): Promise<PrayerTimes> {
    const url = `${MAWAQIT_PAGE_BASE}/${slug}`;

    try {
        const response = await fetch(url, {
            headers: {
                'User-Agent': USER_AGENT,
                'Accept': 'text/html'
            }
        });

        if (!response.ok) {
            throw new Error(`Failed to fetch mosque page: ${response.status} ${response.statusText}`);
        }

        const html = await response.text();

        // Extract confData from the page
        const confData = extractConfData(html);
        if (!confData) {
            throw new Error('Could not extract prayer times from page');
        }

        // Convert to our PrayerTimes format
        return confDataToPrayerTimes(confData, slug);
    } catch (error) {
        console.error(`Failed to fetch prayer times for ${slug}:`, error);
        throw error;
    }
}

// Validate that a country code is a valid 2-letter ISO code
export function isValidCountryCode(code: string): boolean {
    return /^[A-Z]{2}$/.test(code.toUpperCase());
}

// Validate that a mosque slug looks correct
export function isValidSlug(slug: string): boolean {
    // Slugs are lowercase with hyphens, typically ending with country name
    return /^[a-z0-9-]+$/.test(slug) && slug.length > 3;
}

// Sleep utility for rate limiting
export function sleep(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
}

// Batch fetch mosques with rate limiting
// Used for initial data population, not for API responses
export async function batchFetchMosques(
    countryCodes: string[],
    delayMs: number = 1000
): Promise<Map<string, Mosque[]>> {
    const results = new Map<string, Mosque[]>();

    for (const code of countryCodes) {
        try {
            console.log(`Fetching mosques for ${code}...`);
            const mosques = await fetchMosquesByCountry(code);
            results.set(code, mosques);
            console.log(`  Found ${mosques.length} mosques`);

            // Respect rate limits
            await sleep(delayMs);
        } catch (error) {
            console.error(`  Failed: ${error}`);
            results.set(code, []);
        }
    }

    return results;
}

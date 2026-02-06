import type { Mosque, PrayerTimes } from '../types';

const API_BASE_URL = 'https://mawaqit-prayer-api.vercel.app';

export interface Country {
    code: string;
    name: string;
    mosqueCount: number;
    flag?: string;
}

/**
 * Fetch list of supported countries from the scraper API
 */
export const getCountries = async (): Promise<Country[]> => {
    try {
        const response = await fetch(`${API_BASE_URL}/api/countries`);
        if (!response.ok) throw new Error('Failed to fetch countries');
        const data = await response.json();
        return data.countries;
    } catch (error) {
        console.error('Error fetching countries:', error);
        return [];
    }
};

/**
 * Search for mosques in a country via the scraper API
 */
export const searchMosques = async (countryCode: string, query?: string): Promise<Mosque[]> => {
    try {
        const url = new URL(`${API_BASE_URL}/api/mosques/${countryCode}`);
        if (query) url.searchParams.append('q', query);

        const response = await fetch(url.toString());
        if (!response.ok) throw new Error('Failed to search mosques');

        const data = await response.json();

        // Convert API mosque format to app Mosque format
        return data.mosques.map((m: any) => ({
            id: m.slug,
            name: m.name || m.slug,
            address: m.address,
            city: m.city,
            country: countryCode,
            latitude: m.lat,
            longitude: m.lng,
            is_favorite: false,
        }));
    } catch (error) {
        console.error('Error searching mosques:', error);
        return [];
    }
};

/**
 * Fetch prayer times for a mosque slug from the scraper API
 */
export const getPrayerTimes = async (slug: string, date?: string): Promise<PrayerTimes | null> => {
    try {
        const url = new URL(`${API_BASE_URL}/api/prayer-times/${slug}`);
        if (date) url.searchParams.append('date', date);

        const response = await fetch(url.toString());
        if (!response.ok) throw new Error('Failed to fetch prayer times');

        return await response.json();
    } catch (error) {
        console.error('Error fetching prayer times:', error);
        return null;
    }
};

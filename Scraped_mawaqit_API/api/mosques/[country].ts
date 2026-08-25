// API endpoint: GET /api/mosques/[country]
// Returns list of mosques for a specific country code by fetching from Mawaqit API

import type { VercelRequest, VercelResponse } from '@vercel/node';
import { fetchMosquesByCountry } from '../../lib/scraper';
import { Mosque } from '../../lib/types';

export default async function handler(
    req: VercelRequest,
    res: VercelResponse
): Promise<void> {
    // Only allow GET requests
    if (req.method !== 'GET') {
        res.status(405).json({ error: 'Method not allowed' });
        return;
    }

    // Extract country code from URL path
    const countryCode = (req.query.country as string)?.toUpperCase();

    // Validate country code (must be 2-letter ISO code)
    if (!countryCode || !/^[A-Z]{2}$/.test(countryCode)) {
        res.status(400).json({
            error: 'Invalid country code',
            message: 'Please provide a valid 2-letter ISO country code (e.g., TN, FR, US)'
        });
        return;
    }

    try {
        // Fetch mosques using shared scraper logic
        const mosques = await fetchMosquesByCountry(countryCode);

        // Optional: filter by search query
        const query = req.query.q as string | undefined;
        let filteredMosques: Mosque[] = mosques;

        if (query) {
            const normalize = (str: string) =>
                str.normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase();

            const searchTerm = normalize(query);

            filteredMosques = mosques.filter((m) => {
                const name = normalize(m.name || '');
                const city = normalize(m.city || '');
                const address = normalize(m.address || '');
                // Also search by slug as a fallback
                const slug = normalize(m.slug || '');

                return name.includes(searchTerm) ||
                    city.includes(searchTerm) ||
                    address.includes(searchTerm) ||
                    slug.includes(searchTerm);
            });
        }

        // Build response
        const response = {
            country: countryCode,
            count: filteredMosques.length,
            mosques: filteredMosques,
            lastUpdated: new Date().toISOString()
        };

        // Send response with caching headers (1 hour edge cache)
        res.setHeader('Cache-Control', 's-maxage=3600, stale-while-revalidate');
        res.status(200).json(response);

    } catch (error) {
        console.error(`Mosques endpoint error for ${countryCode}:`, error);
        res.status(500).json({
            error: 'Failed to fetch mosques',
            country: countryCode,
            message: error instanceof Error ? error.message : 'Unknown error'
        });
    }
}

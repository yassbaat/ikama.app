// API endpoint: GET /api/mosques/[country]
// Returns list of mosques for a specific country code by fetching from Mawaqit API

import type { VercelRequest, VercelResponse } from '@vercel/node';

// Mawaqit Map API endpoint
const MAWAQIT_MAP_API = 'https://mawaqit.net/api/2.0/mosque/map';

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
        // Fetch mosques directly from Mawaqit API
        const url = `${MAWAQIT_MAP_API}/${countryCode}`;
        const mawaqitResponse = await fetch(url, {
            headers: {
                'User-Agent': 'MawaqitScraperAPI/1.0',
                'Accept': 'application/json'
            }
        });

        if (!mawaqitResponse.ok) {
            throw new Error(`Mawaqit API error: ${mawaqitResponse.status}`);
        }

        // Define mosque type for filtering
        interface MawaqitMosque {
            slug: string;
            name?: string;
            city?: string;
            address?: string;
            lat?: number;
            lng?: number;
        }

        const mosques = (await mawaqitResponse.json()) as MawaqitMosque[];

        // Optional: filter by search query
        const query = req.query.q as string | undefined;
        let filteredMosques: MawaqitMosque[] = mosques;

        if (query) {
            const searchTerm = query.toLowerCase();
            filteredMosques = mosques.filter((m) =>
                (m.name?.toLowerCase() || '').includes(searchTerm) ||
                (m.city?.toLowerCase() || '').includes(searchTerm) ||
                (m.address?.toLowerCase() || '').includes(searchTerm)
            );
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

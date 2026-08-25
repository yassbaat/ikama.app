import type { VercelRequest, VercelResponse } from '@vercel/node';
import { fetchPrayerTimes, isValidSlug } from '../../lib/scraper';

export default async function handler(
    req: VercelRequest,
    res: VercelResponse
): Promise<void> {
    if (req.method !== 'GET') {
        res.status(405).json({ error: 'Method not allowed' });
        return;
    }

    const slug = req.query.slug as string;

    // Validate slug
    if (!slug || !isValidSlug(slug)) {
        res.status(400).json({
            error: 'Invalid slug',
            message: 'Slug must be valid lowercase alphanumeric string from Mawaqit'
        });
        return;
    }

    try {
        const result = await fetchPrayerTimes(slug);

        res.setHeader('Cache-Control', 's-maxage=3600, stale-while-revalidate');
        res.status(200).json(result);

    } catch (error) {
        console.error(`Prayer times endpoint error for ${slug}:`, error);
        res.status(500).json({
            error: 'Failed to fetch prayer times',
            message: error instanceof Error ? error.message : 'Unknown'
        });
    }
}

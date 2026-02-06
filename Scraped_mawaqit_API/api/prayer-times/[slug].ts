// API endpoint: GET /api/prayer-times/[slug]
// Returns prayer times for a specific mosque by scraping its page

import type { VercelRequest, VercelResponse } from '@vercel/node';
import * as cheerio from 'cheerio';

// Mawaqit page base URL
const MAWAQIT_PAGE_BASE = 'https://mawaqit.net/en';

export default async function handler(
    req: VercelRequest,
    res: VercelResponse
): Promise<void> {
    // Only allow GET requests
    if (req.method !== 'GET') {
        res.status(405).json({ error: 'Method not allowed' });
        return;
    }

    // Extract slug from URL path
    const slug = req.query.slug as string;

    // Validate slug format (lowercase with hyphens, at least 4 chars)
    if (!slug || !/^[a-z0-9-]+$/.test(slug) || slug.length < 4) {
        res.status(400).json({
            error: 'Invalid mosque slug',
            message: 'Please provide a valid mosque slug (e.g., mosquee-falah-cachan)'
        });
        return;
    }

    try {
        // Fetch mosque page
        const url = `${MAWAQIT_PAGE_BASE}/${slug}`;
        const response = await fetch(url, {
            headers: {
                'User-Agent': 'MawaqitScraperAPI/1.0',
                'Accept': 'text/html'
            }
        });

        if (!response.ok) {
            throw new Error(`Failed to fetch mosque page: ${response.status}`);
        }

        const html = await response.text();

        // Extract confData from the page
        const confData = extractConfData(html);
        if (!confData) {
            throw new Error('Could not extract prayer times from page');
        }

        // Convert to our format
        const prayerTimes = formatPrayerTimes(confData, slug);

        // Send response with caching headers (1 hour edge cache)
        res.setHeader('Cache-Control', 's-maxage=3600, stale-while-revalidate');
        res.status(200).json(prayerTimes);

    } catch (error) {
        console.error(`Prayer times endpoint error for ${slug}:`, error);
        res.status(500).json({
            error: 'Failed to fetch prayer times',
            slug,
            message: error instanceof Error ? error.message : 'Unknown error'
        });
    }
}

// Extract confData JSON from Mawaqit page HTML
function extractConfData(html: string): Record<string, unknown> | null {
    try {
        // Look for: var confData = {...}
        const match = html.match(/var\s+confData\s*=\s*(\{[\s\S]*?\});/);
        if (match && match[1]) {
            return JSON.parse(match[1]);
        }
        return null;
    } catch (error) {
        console.error('Failed to parse confData:', error);
        return null;
    }
}

// Format confData into clean prayer times response
function formatPrayerTimes(confData: Record<string, unknown>, slug: string) {
    const times = confData.times as string[] || [];
    const iqamaCalendar = confData.iqamaCalendar as Record<string, string[]> | undefined;
    const name = confData.name as string || slug;

    // Get today's date for iqama lookup
    const today = new Date();
    const month = today.getMonth(); // 0-indexed
    const day = today.getDate() - 1; // 0-indexed for array

    // Get iqama times for today if available
    let iqamaTimes: string[] = [];
    if (iqamaCalendar && Array.isArray(iqamaCalendar[month])) {
        const monthData = iqamaCalendar[month];
        if (monthData[day]) {
            iqamaTimes = monthData[day].split(',');
        }
    }

    return {
        slug,
        name,
        date: today.toISOString().split('T')[0],
        fajr: {
            adhan: times[0] || null,
            iqama: iqamaTimes[0] || null
        },
        shuruq: times[1] || null,
        dhuhr: {
            adhan: times[2] || null,
            iqama: iqamaTimes[1] || null
        },
        asr: {
            adhan: times[3] || null,
            iqama: iqamaTimes[2] || null
        },
        maghrib: {
            adhan: times[4] || null,
            iqama: iqamaTimes[3] || null
        },
        isha: {
            adhan: times[5] || null,
            iqama: iqamaTimes[4] || null
        },
        jumua: confData.jumpiua || confData.jumuaTime || null,
        lastUpdated: new Date().toISOString()
    };
}

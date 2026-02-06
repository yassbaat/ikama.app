import type { VercelRequest, VercelResponse } from '@vercel/node';

// Mawaqit page base URL
const MAWAQIT_PAGE_BASE = 'https://mawaqit.net/en';
const USER_AGENT = 'MawaqitScraperAPI/1.0';

export default async function handler(
    req: VercelRequest,
    res: VercelResponse
): Promise<void> {
    if (req.method !== 'GET') {
        res.status(405).json({ error: 'Method not allowed' });
        return;
    }

    const slug = req.query.slug as string;
    if (!slug || !/^[a-z0-9-]+$/.test(slug) || slug.length < 4) {
        res.status(400).json({ error: 'Invalid slug' });
        return;
    }

    try {
        const url = `${MAWAQIT_PAGE_BASE}/${slug}`;
        const response = await fetch(url, {
            headers: {
                'User-Agent': USER_AGENT,
                'Accept': 'text/html'
            }
        });

        if (!response.ok) {
            throw new Error(`Mawaqit error: ${response.status}`);
        }

        const html = await response.text();

        // Find confData
        const match = html.match(/let\s+confData\s*=\s*(\{[\s\S]*?\});/);
        if (!match || !match[1]) {
            throw new Error('Could not find confData');
        }

        const confData = JSON.parse(match[1]);

        // Extract times
        const times = confData.times || [];
        const iqamaCalendar = confData.iqamaCalendar || [];

        // Get today's iqamas
        const today = new Date();
        const month = today.getMonth();
        const day = today.getDate().toString();

        let iqamaOffsets: (string | null)[] = [null, null, null, null, null];
        if (iqamaCalendar[0] && iqamaCalendar[0][day]) {
            iqamaOffsets = iqamaCalendar[0][day];
        }

        // Calculate iqama times
        const iqamaTimes = times.map((adhan: string, i: number) => {
            const offset = iqamaOffsets[i];
            if (!offset) return null;
            if (offset.startsWith('+') || offset.startsWith('-')) {
                const [h, m] = adhan.split(':').map(Number);
                const total = h * 60 + m + parseInt(offset, 10);
                const nh = Math.floor(total / 60) % 24;
                const nm = total % 60;
                return `${nh.toString().padStart(2, '0')}:${nm.toString().padStart(2, '0')}`;
            }
            return offset;
        });

        const result = {
            mosque_id: slug,
            mosque_name: confData.name || slug,
            date: today.toISOString().split('T')[0],
            fajr: { name: 'Fajr', adhan: times[0], iqama: iqamaTimes[0] },
            dhuhr: { name: 'Dhuhr', adhan: times[1], iqama: iqamaTimes[1] },
            asr: { name: 'Asr', adhan: times[2], iqama: iqamaTimes[2] },
            maghrib: { name: 'Maghrib', adhan: times[3], iqama: iqamaTimes[3] },
            isha: { name: 'Isha', adhan: times[4], iqama: iqamaTimes[4] },
            lastUpdated: new Date().toISOString()
        };

        res.setHeader('Cache-Control', 's-maxage=3600, stale-while-revalidate');
        res.status(200).json(result);

    } catch (error) {
        res.status(500).json({ error: 'Scraper error', message: error instanceof Error ? error.message : 'Unknown' });
    }
}

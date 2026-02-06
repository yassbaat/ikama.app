// HTML parser utilities for extracting data from Mawaqit pages
// Uses Cheerio for server-side HTML parsing

import * as cheerio from 'cheerio';
import { Country, MawaqitConfData, PrayerTimes } from './types';

/**
 * Parse the countries HTML file and extract country data
 */
export function parseCountriesHtml(html: string): Country[] {
    const $ = cheerio.load(html);
    const countries: Country[] = [];

    $('button.country').each((_, element) => {
        const $btn = $(element);
        const dataAttr = $btn.attr('data-data');

        if (!dataAttr) return;

        try {
            const data = JSON.parse(dataAttr);
            const fullText = $btn.text().trim();
            const name = fullText.replace(/\d+$/, '').trim();

            countries.push({
                code: data.country,
                name: name,
                mosqueCount: data.nb,
                coordinates: {
                    lat: data.coordinates.lat,
                    lng: data.coordinates.lng
                }
            });
        } catch (error) {
            console.error('Failed to parse country data:', error);
        }
    });

    return countries;
}

/**
 * Extract confData JSON from a Mawaqit mosque page
 */
export function extractConfData(html: string): MawaqitConfData | null {
    // Audit HTML content for bot protection
    if (html.includes('cf-browser-verification') || html.includes('Cloudflare') || html.includes('captcha')) {
        console.error('Bot protection (Cloudflare/Captcha) detected in HTML');
    }

    const scriptCount = (html.match(/<script/g) || []).length;
    console.log(`Found ${scriptCount} script tags in HTML`);

    // The confData is embedded as: let confData = {...};
    // We use a more robust regex to find the configuration object
    const confDataMatch = html.match(/let\s+confData\s*=\s*(\{[\s\S]*?\});/);

    if (!confDataMatch || !confDataMatch[1]) {
        console.error('Could not find confData in page script tags');
        return null;
    }

    try {
        const confData = JSON.parse(confDataMatch[1]) as MawaqitConfData;
        return confData;
    } catch (error) {
        console.error('Failed to parse confData JSON string:', error);
        return null;
    }
}

/**
 * Convert confData to our PrayerTimes format
 */
export function confDataToPrayerTimes(confData: MawaqitConfData, slug: string): PrayerTimes {
    const today = new Date();
    const dayOfMonth = today.getDate().toString();

    const iqamaTimes = calculateIqamaTimes(confData.times, confData.iqamaCalendar, dayOfMonth);

    return {
        slug,
        name: confData.name || confData.label || 'Unknown Mosque',
        fajr: { adhan: confData.times[0], iqama: iqamaTimes[0] },
        dhuhr: { adhan: confData.times[1], iqama: iqamaTimes[1] },
        asr: { adhan: confData.times[2], iqama: iqamaTimes[2] },
        maghrib: { adhan: confData.times[3], iqama: iqamaTimes[3] },
        isha: { adhan: confData.times[4], iqama: iqamaTimes[4] },
        shuruq: confData.shuruq,
        jumua: confData.jumua,
        jumua2: confData.jumua2,
        lastUpdated: new Date().toISOString()
    };
}

/**
 * Calculate iqama times using adhan times and mosque's iqama offsets
 */
function calculateIqamaTimes(
    adhanTimes: string[],
    iqamaCalendar: MawaqitConfData['iqamaCalendar'],
    dayOfMonth: string
): (string | null)[] {
    if (!iqamaCalendar || iqamaCalendar.length === 0) {
        return [null, null, null, null, null];
    }

    const currentMonthData = iqamaCalendar[0];
    if (!currentMonthData) return [null, null, null, null, null];

    const todayOffsets = currentMonthData[dayOfMonth];
    if (!todayOffsets || todayOffsets.length < 5) {
        return [null, null, null, null, null];
    }

    return adhanTimes.map((adhan, index) => {
        const offset = todayOffsets[index];
        if (!offset) return null;

        if (offset.startsWith('+') || offset.startsWith('-')) {
            const minutes = parseInt(offset, 10);
            return addMinutesToTime(adhan, minutes);
        }

        return offset;
    });
}

/**
 * Utility to add minutes to a time string
 */
function addMinutesToTime(time: string, minutes: number): string {
    const [hours, mins] = time.split(':').map(Number);
    const totalMinutes = hours * 60 + mins + minutes;
    const newHours = Math.floor(totalMinutes / 60) % 24;
    const newMins = totalMinutes % 60;
    return `${newHours.toString().padStart(2, '0')}:${newMins.toString().padStart(2, '0')}`;
}

// HTML parser utilities for extracting data from Mawaqit pages
// Uses Cheerio for server-side HTML parsing

import * as cheerio from 'cheerio';
import { Country, MawaqitConfData, PrayerTimes } from './types';

// Parse the countries HTML file and extract country data
// Input: raw HTML containing button elements with data-data attributes
// Output: array of Country objects
export function parseCountriesHtml(html: string): Country[] {
    const $ = cheerio.load(html);
    const countries: Country[] = [];

    // Each country is a button with class "country" and data-data attribute
    $('button.country').each((_, element) => {
        const $btn = $(element);
        // Get the data-data attribute (contains JSON with country info)
        const dataAttr = $btn.attr('data-data');

        if (!dataAttr) return;

        try {
            // Parse the JSON from data-data attribute
            // The HTML entities are already decoded by cheerio
            const data = JSON.parse(dataAttr);

            // Extract country name from button text (before the badge span)
            const fullText = $btn.text().trim();
            // Remove the badge number at the end
            const name = fullText.replace(/\d+$/, '').trim();

            countries.push({
                code: data.country,           // e.g. "TN"
                name: name,                   // e.g. "TUNISIA"
                mosqueCount: data.nb,         // e.g. 2627
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

// Extract confData JSON from a Mawaqit mosque page
// Input: raw HTML of the mosque page
// Output: parsed MawaqitConfData object or null if not found
export function extractConfData(html: string): MawaqitConfData | null {
    // The confData is embedded as: let confData = {...};
    const confDataMatch = html.match(/let\s+confData\s*=\s*(\{[\s\S]*?\});/);

    if (!confDataMatch || !confDataMatch[1]) {
        console.error('Could not find confData in page');
        return null;
    }

    try {
        // Parse the JSON object
        const confData = JSON.parse(confDataMatch[1]) as MawaqitConfData;
        return confData;
    } catch (error) {
        console.error('Failed to parse confData:', error);
        return null;
    }
}

// Convert confData to our PrayerTimes format
// Input: raw confData from Mawaqit page, mosque slug
// Output: formatted PrayerTimes object
export function confDataToPrayerTimes(confData: MawaqitConfData, slug: string): PrayerTimes {
    // Get today's iqama offsets (day 1-31 within current month)
    const today = new Date();
    const dayOfMonth = today.getDate().toString();

    // Calculate iqama times from offsets
    const iqamaTimes = calculateIqamaTimes(confData.times, confData.iqamaCalendar, dayOfMonth);

    return {
        slug,
        name: confData.name || confData.label || 'Unknown Mosque',
        fajr: {
            adhan: confData.times[0],
            iqama: iqamaTimes[0]
        },
        dhuhr: {
            adhan: confData.times[1],
            iqama: iqamaTimes[1]
        },
        asr: {
            adhan: confData.times[2],
            iqama: iqamaTimes[2]
        },
        maghrib: {
            adhan: confData.times[3],
            iqama: iqamaTimes[3]
        },
        isha: {
            adhan: confData.times[4],
            iqama: iqamaTimes[4]
        },
        shuruq: confData.shuruq,
        jumua: confData.jumua,
        jumua2: confData.jumua2,
        lastUpdated: new Date().toISOString()
    };
}

// Calculate iqama times from adhan times and offsets
// Offsets can be: "+30" (add 30 min), "14:30" (absolute time), or null
function calculateIqamaTimes(
    adhanTimes: string[],
    iqamaCalendar: MawaqitConfData['iqamaCalendar'],
    dayOfMonth: string
): (string | null)[] {
    // If no iqama calendar, return nulls
    if (!iqamaCalendar || iqamaCalendar.length === 0) {
        return [null, null, null, null, null];
    }

    // Get the current month's iqama data (index 0 = current month in most cases)
    const currentMonthData = iqamaCalendar[0];
    if (!currentMonthData) {
        return [null, null, null, null, null];
    }

    // Get today's iqama offsets
    const todayOffsets = currentMonthData[dayOfMonth];
    if (!todayOffsets || todayOffsets.length < 5) {
        return [null, null, null, null, null];
    }

    // Calculate each iqama time
    return adhanTimes.map((adhan, index) => {
        const offset = todayOffsets[index];
        if (!offset) return null;

        // Check if it's a relative offset (starts with + or -)
        if (offset.startsWith('+') || offset.startsWith('-')) {
            const minutes = parseInt(offset, 10);
            return addMinutesToTime(adhan, minutes);
        }

        // Otherwise it's an absolute time
        return offset;
    });
}

// Add minutes to a time string in HH:MM format
function addMinutesToTime(time: string, minutes: number): string {
    const [hours, mins] = time.split(':').map(Number);
    const totalMinutes = hours * 60 + mins + minutes;
    const newHours = Math.floor(totalMinutes / 60) % 24;
    const newMins = totalMinutes % 60;
    return `${newHours.toString().padStart(2, '0')}:${newMins.toString().padStart(2, '0')}`;
}

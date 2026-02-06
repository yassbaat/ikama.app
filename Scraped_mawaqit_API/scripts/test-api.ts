// Test script to verify the API functions work correctly
// Run with: npx ts-node scripts/test-api.ts

import * as fs from 'fs';
import * as path from 'path';
import { fetchMosquesByCountry, fetchPrayerTimes } from '../lib/scraper';

const COUNTRIES_FILE = path.join(__dirname, '..', 'data', 'countries.json');

async function main() {
    console.log('🧪 Testing Scraped Mawaqit API Functions\n');

    // Test 1: Check countries.json exists
    console.log('1. Checking countries.json...');
    if (!fs.existsSync(COUNTRIES_FILE)) {
        console.error('   ❌ FAIL: countries.json not found!');
        process.exit(1);
    }
    const countries = JSON.parse(fs.readFileSync(COUNTRIES_FILE, 'utf-8'));
    console.log(`   ✅ PASS: Found ${countries.length} countries`);

    // Test 2: Fetch mosques for a small country (faster test)
    console.log('\n2. Testing fetchMosquesByCountry("MT") [Malta - small]...');
    try {
        const mosques = await fetchMosquesByCountry('MT');
        console.log(`   ✅ PASS: Found ${mosques.length} mosques in Malta`);
        if (mosques.length > 0) {
            console.log(`   Sample mosque: ${mosques[0].name} (${mosques[0].slug})`);
        }
    } catch (error) {
        console.error(`   ❌ FAIL: ${error}`);
    }

    // Test 3: Fetch prayer times for a mosque
    console.log('\n3. Testing fetchPrayerTimes with a real mosque slug...');
    try {
        // Use a known mosque from Tunisia
        const slug = 'jm-lhd-qsyb-sws-4041-tunisia';
        const times = await fetchPrayerTimes(slug);
        console.log(`   ✅ PASS: Got prayer times for "${times.name}"`);
        console.log(`   Fajr: ${times.fajr.adhan} (iqama: ${times.fajr.iqama || 'N/A'})`);
        console.log(`   Dhuhr: ${times.dhuhr.adhan}`);
        console.log(`   Asr: ${times.asr.adhan}`);
        console.log(`   Maghrib: ${times.maghrib.adhan}`);
        console.log(`   Isha: ${times.isha.adhan}`);
    } catch (error) {
        console.error(`   ❌ FAIL: ${error}`);
    }

    console.log('\n✨ All tests complete!');
}

main().catch(error => {
    console.error('Test script failed:', error);
    process.exit(1);
});

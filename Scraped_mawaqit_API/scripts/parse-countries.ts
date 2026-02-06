// Script: parse-countries.ts
// One-time script to extract country data from the Mawaqit countries HTML
// Run with: npm run parse-countries

import * as fs from 'fs';
import * as path from 'path';
import { parseCountriesHtml } from '../lib/parser';

// Path to the source HTML file (copy from iqamah.com project)
const SOURCE_FILE = path.join(__dirname, '..', '..', 'src-tauri', 'target', 'release', 'countries_available_api.txt');

// Output path for parsed JSON
const OUTPUT_FILE = path.join(__dirname, '..', 'data', 'countries.json');

async function main() {
    console.log('Parsing countries from Mawaqit HTML...');
    console.log(`Source: ${SOURCE_FILE}`);

    // Check if source file exists
    if (!fs.existsSync(SOURCE_FILE)) {
        console.error('Error: Source HTML file not found!');
        console.error('Expected at:', SOURCE_FILE);
        process.exit(1);
    }

    // Read the HTML content
    const html = fs.readFileSync(SOURCE_FILE, 'utf-8');

    // Parse countries from HTML
    const countries = parseCountriesHtml(html);

    console.log(`Found ${countries.length} countries:`);

    // Sort by mosque count (descending) for better readability
    countries.sort((a, b) => b.mosqueCount - a.mosqueCount);

    // Print top 10
    console.log('\nTop 10 by mosque count:');
    countries.slice(0, 10).forEach((c, i) => {
        console.log(`  ${i + 1}. ${c.code} - ${c.name}: ${c.mosqueCount} mosques`);
    });

    // Ensure data directory exists
    const dataDir = path.dirname(OUTPUT_FILE);
    if (!fs.existsSync(dataDir)) {
        fs.mkdirSync(dataDir, { recursive: true });
    }

    // Write to JSON file
    fs.writeFileSync(OUTPUT_FILE, JSON.stringify(countries, null, 2), 'utf-8');

    console.log(`\nSaved to: ${OUTPUT_FILE}`);
    console.log('Done!');
}

main().catch(error => {
    console.error('Script failed:', error);
    process.exit(1);
});

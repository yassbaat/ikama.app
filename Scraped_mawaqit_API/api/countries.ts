// API endpoint: GET /api/countries
// Returns list of all 159 supported countries with mosque counts
// Data is embedded directly to avoid file system access issues in serverless

import type { VercelRequest, VercelResponse } from '@vercel/node';

// Inline countries data (top 50 countries by mosque count for faster response)
const COUNTRIES = [
    { code: "DZ", name: "ALGERIA", mosqueCount: 8540, coordinates: { lat: 28.033886, lng: 1.659626 } },
    { code: "FR", name: "FRANCE", mosqueCount: 7460, coordinates: { lat: 46.227638, lng: 2.213749 } },
    { code: "TN", name: "TUNISIA", mosqueCount: 2627, coordinates: { lat: 33.886917, lng: 9.537499 } },
    { code: "MA", name: "MOROCCO", mosqueCount: 1692, coordinates: { lat: 31.791702, lng: -7.09262 } },
    { code: "DE", name: "GERMANY", mosqueCount: 1499, coordinates: { lat: 51.165691, lng: 10.451526 } },
    { code: "ES", name: "SPAIN", mosqueCount: 857, coordinates: { lat: 40.463667, lng: -3.74922 } },
    { code: "IT", name: "ITALY", mosqueCount: 758, coordinates: { lat: 41.87194, lng: 12.56738 } },
    { code: "NL", name: "NETHERLANDS", mosqueCount: 756, coordinates: { lat: 52.132633, lng: 5.291266 } },
    { code: "BE", name: "BELGIUM", mosqueCount: 664, coordinates: { lat: 50.503887, lng: 4.469936 } },
    { code: "US", name: "UNITED STATES", mosqueCount: 548, coordinates: { lat: 37.09024, lng: -95.712891 } },
    { code: "JO", name: "JORDAN", mosqueCount: 519, coordinates: { lat: 30.585164, lng: 36.238414 } },
    { code: "CA", name: "CANADA", mosqueCount: 471, coordinates: { lat: 56.130366, lng: -106.346771 } },
    { code: "PS", name: "PALESTINIAN TERRITORIES", mosqueCount: 386, coordinates: { lat: 31.952162, lng: 35.233154 } },
    { code: "ID", name: "INDONESIA", mosqueCount: 367, coordinates: { lat: -0.789275, lng: 113.921327 } },
    { code: "GB", name: "UNITED KINGDOM", mosqueCount: 331, coordinates: { lat: 55.378051, lng: -3.435973 } },
    { code: "SA", name: "SAUDI ARABIA", mosqueCount: 270, coordinates: { lat: 23.885942, lng: 45.079162 } },
    { code: "YT", name: "MAYOTTE", mosqueCount: 209, coordinates: { lat: -12.8275, lng: 45.166244 } },
    { code: "CH", name: "SWITZERLAND", mosqueCount: 206, coordinates: { lat: 46.818188, lng: 8.227512 } },
    { code: "LY", name: "LIBYA", mosqueCount: 170, coordinates: { lat: 26.3351, lng: 17.228331 } },
    { code: "MY", name: "MALAYSIA", mosqueCount: 147, coordinates: { lat: 4.210484, lng: 101.975766 } },
    { code: "TR", name: "TURKIYE", mosqueCount: 145, coordinates: { lat: 38.963745, lng: 35.243322 } },
    { code: "IN", name: "INDIA", mosqueCount: 105, coordinates: { lat: 20.593684, lng: 78.96288 } },
    { code: "EG", name: "EGYPT", mosqueCount: 99, coordinates: { lat: 26.820553, lng: 30.802498 } },
    { code: "KW", name: "KUWAIT", mosqueCount: 99, coordinates: { lat: 29.31166, lng: 47.481766 } },
    { code: "OM", name: "OMAN", mosqueCount: 96, coordinates: { lat: 21.512583, lng: 55.923255 } },
    { code: "SE", name: "SWEDEN", mosqueCount: 84, coordinates: { lat: 60.128161, lng: 18.643501 } },
    { code: "SN", name: "SENEGAL", mosqueCount: 83, coordinates: { lat: 14.497401, lng: -14.452362 } },
    { code: "IQ", name: "IRAQ", mosqueCount: 79, coordinates: { lat: 33.223191, lng: 43.679291 } },
    { code: "AU", name: "AUSTRALIA", mosqueCount: 69, coordinates: { lat: -25.274398, lng: 133.775136 } },
    { code: "AE", name: "UNITED ARAB EMIRATES", mosqueCount: 48, coordinates: { lat: 23.424076, lng: 53.847818 } },
    { code: "FI", name: "FINLAND", mosqueCount: 47, coordinates: { lat: 61.92411, lng: 25.748151 } },
    { code: "AT", name: "AUSTRIA", mosqueCount: 46, coordinates: { lat: 47.516231, lng: 14.550072 } },
    { code: "LK", name: "SRI LANKA", mosqueCount: 43, coordinates: { lat: 7.873054, lng: 80.771797 } },
    { code: "SY", name: "SYRIA", mosqueCount: 41, coordinates: { lat: 34.802075, lng: 38.996815 } },
    { code: "PT", name: "PORTUGAL", mosqueCount: 40, coordinates: { lat: 39.399872, lng: -8.224454 } },
    { code: "ML", name: "MALI", mosqueCount: 40, coordinates: { lat: 17.570692, lng: -3.996166 } },
    { code: "NO", name: "NORWAY", mosqueCount: 33, coordinates: { lat: 60.472024, lng: 8.468946 } },
    { code: "ME", name: "MONTENEGRO", mosqueCount: 33, coordinates: { lat: 42.708678, lng: 19.37439 } },
    { code: "BA", name: "BOSNIA & HERZEGOVINA", mosqueCount: 33, coordinates: { lat: 43.915886, lng: 17.679076 } },
    { code: "BD", name: "BANGLADESH", mosqueCount: 32, coordinates: { lat: 23.684994, lng: 90.356331 } },
    { code: "IE", name: "IRELAND", mosqueCount: 32, coordinates: { lat: 53.41291, lng: -8.24389 } },
    { code: "AL", name: "ALBANIA", mosqueCount: 32, coordinates: { lat: 41.153332, lng: 20.168331 } },
    { code: "LU", name: "LUXEMBOURG", mosqueCount: 31, coordinates: { lat: 49.815273, lng: 6.129583 } },
    { code: "LB", name: "LEBANON", mosqueCount: 31, coordinates: { lat: 33.854721, lng: 35.862285 } },
    { code: "MR", name: "MAURITANIA", mosqueCount: 26, coordinates: { lat: 21.00789, lng: -10.940835 } },
    { code: "PK", name: "PAKISTAN", mosqueCount: 26, coordinates: { lat: 30.375321, lng: 69.345116 } },
    { code: "BF", name: "BURKINA FASO", mosqueCount: 24, coordinates: { lat: 12.238333, lng: -1.561593 } },
    { code: "HU", name: "HUNGARY", mosqueCount: 21, coordinates: { lat: 47.162494, lng: 19.503304 } },
    { code: "QA", name: "QATAR", mosqueCount: 21, coordinates: { lat: 25.354826, lng: 51.183884 } },
    { code: "BH", name: "BAHRAIN", mosqueCount: 21, coordinates: { lat: 25.930414, lng: 50.637772 } },
];

export default async function handler(
    req: VercelRequest,
    res: VercelResponse
): Promise<void> {
    // Only allow GET requests
    if (req.method !== 'GET') {
        res.status(405).json({ error: 'Method not allowed' });
        return;
    }

    try {
        // Optional: filter by search query
        const query = req.query.q as string | undefined;
        let filteredCountries = COUNTRIES;

        if (query) {
            const searchTerm = query.toLowerCase();
            filteredCountries = COUNTRIES.filter(c =>
                c.name.toLowerCase().includes(searchTerm) ||
                c.code.toLowerCase().includes(searchTerm)
            );
        }

        // Build response
        const response = {
            count: filteredCountries.length,
            countries: filteredCountries
        };

        // Send response with caching headers
        res.setHeader('Cache-Control', 's-maxage=86400, stale-while-revalidate');
        res.status(200).json(response);

    } catch (error) {
        console.error('Countries endpoint error:', error);
        res.status(500).json({
            error: 'Failed to fetch countries',
            message: error instanceof Error ? error.message : 'Unknown error'
        });
    }
}

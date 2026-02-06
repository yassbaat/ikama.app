// API endpoint: GET /api/health
// Simple health check endpoint for monitoring

import type { VercelRequest, VercelResponse } from '@vercel/node';

export default async function handler(
    req: VercelRequest,
    res: VercelResponse
): Promise<void> {
    // Only allow GET requests
    if (req.method !== 'GET') {
        res.status(405).json({ error: 'Method not allowed' });
        return;
    }

    // Build health status
    const health = {
        status: 'ok',
        timestamp: new Date().toISOString(),
        version: '1.0.0'
    };

    // Send response (no caching for health checks)
    res.setHeader('Cache-Control', 'no-store');
    res.status(200).json(health);
}

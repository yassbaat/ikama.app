// Cache utilities for storing and retrieving scraped data
// Uses JSON files stored in the data/ directory

import * as fs from 'fs';
import * as path from 'path';
import { CacheMetadata } from './types';

// Base directory for cached data files
const DATA_DIR = path.join(__dirname, '..', 'data');
const MOSQUES_DIR = path.join(DATA_DIR, 'mosques');

// Default cache duration: 6 hours for prayer times, 24 hours for mosque lists
const PRAYER_TIMES_TTL_MS = 6 * 60 * 60 * 1000;   // 6 hours
const MOSQUE_LIST_TTL_MS = 24 * 60 * 60 * 1000;   // 24 hours

// Ensure data directories exist
export function ensureDataDirs(): void {
    if (!fs.existsSync(DATA_DIR)) {
        fs.mkdirSync(DATA_DIR, { recursive: true });
    }
    if (!fs.existsSync(MOSQUES_DIR)) {
        fs.mkdirSync(MOSQUES_DIR, { recursive: true });
    }
}

// Generic cache read function
// Returns null if cache miss or expired
export function readCache<T>(cacheKey: string, ttlMs: number = MOSQUE_LIST_TTL_MS): T | null {
    const filePath = getCacheFilePath(cacheKey);

    // Check if file exists
    if (!fs.existsSync(filePath)) {
        return null;
    }

    try {
        const raw = fs.readFileSync(filePath, 'utf-8');
        const cached = JSON.parse(raw) as { data: T; meta: CacheMetadata };

        // Check if cache is still valid
        const expiresAt = new Date(cached.meta.expiresAt).getTime();
        if (Date.now() > expiresAt) {
            // Cache expired
            return null;
        }

        return cached.data;
    } catch (error) {
        // Corrupted cache file, return null to trigger fresh fetch
        console.error(`Cache read error for ${cacheKey}:`, error);
        return null;
    }
}

// Generic cache write function
export function writeCache<T>(cacheKey: string, data: T, ttlMs: number = MOSQUE_LIST_TTL_MS): void {
    ensureDataDirs();

    const filePath = getCacheFilePath(cacheKey);
    const now = new Date();

    const cacheEntry = {
        data,
        meta: {
            lastUpdated: now.toISOString(),
            expiresAt: new Date(now.getTime() + ttlMs).toISOString(),
            source: 'mawaqit' as const
        }
    };

    fs.writeFileSync(filePath, JSON.stringify(cacheEntry, null, 2), 'utf-8');
}

// Convert cache key to file path
// Keys like "mosques/TN" become "data/mosques/TN.json"
// Keys like "countries" become "data/countries.json"
function getCacheFilePath(cacheKey: string): string {
    if (cacheKey.startsWith('mosques/')) {
        const country = cacheKey.replace('mosques/', '');
        return path.join(MOSQUES_DIR, `${country}.json`);
    }
    return path.join(DATA_DIR, `${cacheKey}.json`);
}

// Read mosque list cache for a specific country
export function readMosqueCache(countryCode: string) {
    return readCache(`mosques/${countryCode}`, MOSQUE_LIST_TTL_MS);
}

// Write mosque list cache for a specific country
export function writeMosqueCache(countryCode: string, data: unknown): void {
    writeCache(`mosques/${countryCode}`, data, MOSQUE_LIST_TTL_MS);
}

// Check if a cache entry exists and is valid
export function isCacheValid(cacheKey: string, ttlMs?: number): boolean {
    return readCache(cacheKey, ttlMs) !== null;
}

// Get cache metadata without full data
export function getCacheInfo(cacheKey: string): CacheMetadata | null {
    const filePath = getCacheFilePath(cacheKey);

    if (!fs.existsSync(filePath)) {
        return null;
    }

    try {
        const raw = fs.readFileSync(filePath, 'utf-8');
        const cached = JSON.parse(raw);
        return cached.meta as CacheMetadata;
    } catch {
        return null;
    }
}

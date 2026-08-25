// Cache utilities for storing and retrieving scraped data
// Uses in-memory cache (primary) and JSON files (secondary/persistence)

import * as fs from 'fs';
import * as path from 'path';
import * as os from 'os';
import { CacheMetadata } from './types';

// In-memory cache for fast access and serverless environments
// This persists as long as the container/process is alive
const memoryCache = new Map<string, { data: any; meta: CacheMetadata }>();

// Base directory for cached data files
// In Vercel/Serverless, we must use /tmp (which is ephemeral)
// In local development, we use the local file system for persistence
const isServerless = process.env.VERCEL || process.env.NODE_ENV === 'production';
const DATA_DIR = isServerless
    ? path.join(os.tmpdir(), 'mawaqit-data')
    : path.join(__dirname, '..', 'data');

const MOSQUES_DIR = path.join(DATA_DIR, 'mosques');

// Default cache duration: 6 hours for prayer times, 24 hours for mosque lists
const PRAYER_TIMES_TTL_MS = 6 * 60 * 60 * 1000;   // 6 hours
const MOSQUE_LIST_TTL_MS = 24 * 60 * 60 * 1000;   // 24 hours

// Ensure data directories exist
export function ensureDataDirs(): void {
    try {
        if (!fs.existsSync(DATA_DIR)) {
            fs.mkdirSync(DATA_DIR, { recursive: true });
        }
        if (!fs.existsSync(MOSQUES_DIR)) {
            fs.mkdirSync(MOSQUES_DIR, { recursive: true });
        }
    } catch (error) {
        // Ignore FS errors in serverless if readonly, we have memory cache
        if (!isServerless) console.warn('Failed to create cache directories:', error);
    }
}

// Generic cache read function
// Returns null if cache miss or expired
export function readCache<T>(cacheKey: string, ttlMs: number = MOSQUE_LIST_TTL_MS): T | null {
    // 1. Try Memory Cache first
    const memEntry = memoryCache.get(cacheKey);
    if (memEntry) {
        const expiresAt = new Date(memEntry.meta.expiresAt).getTime();
        if (Date.now() <= expiresAt) {
            return memEntry.data as T;
        } else {
            memoryCache.delete(cacheKey); // Cleanup expired
        }
    }

    // 2. Try File System Cache
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

        // Populate memory cache for next time
        memoryCache.set(cacheKey, cached);

        return cached.data;
    } catch (error) {
        // Corrupted cache file, return null to trigger fresh fetch
        // console.error(`Cache read error for ${cacheKey}:`, error); // specific error logging is noisy
        return null;
    }
}

// Generic cache write function
export function writeCache<T>(cacheKey: string, data: T, ttlMs: number = MOSQUE_LIST_TTL_MS): void {
    const now = new Date();
    const cacheEntry = {
        data,
        meta: {
            lastUpdated: now.toISOString(),
            expiresAt: new Date(now.getTime() + ttlMs).toISOString(),
            source: 'mawaqit' as const
        }
    };

    // 1. Write to Memory Cache
    memoryCache.set(cacheKey, cacheEntry);

    // 2. Write to File System Cache (Best Effort)
    try {
        ensureDataDirs();
        const filePath = getCacheFilePath(cacheKey);
        fs.writeFileSync(filePath, JSON.stringify(cacheEntry, null, 2), 'utf-8');
    } catch (error) {
        // Ignore write errors (common in serverless /tmp if space full or permissions issue)
    }
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
    // Check memory first
    const memEntry = memoryCache.get(cacheKey);
    if (memEntry) return memEntry.meta;

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

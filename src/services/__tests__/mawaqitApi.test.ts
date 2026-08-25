import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { getCountries, searchMosques, getPrayerTimes } from '../mawaqitApi';

// Mock fetch globally
const mockFetch = vi.fn();
global.fetch = mockFetch;

describe('Mawaqit API Service', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  describe('getCountries', () => {
    it('should fetch and return countries successfully', async () => {
      const mockCountries = [
        { code: 'FR', name: 'France', mosqueCount: 1500 },
        { code: 'US', name: 'United States', mosqueCount: 2500 },
      ];

      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: () => Promise.resolve({ countries: mockCountries }),
      });

      const result = await getCountries();

      expect(mockFetch).toHaveBeenCalledWith(
        'https://mawaqit-prayer-api.vercel.app/api/countries'
      );
      expect(result).toEqual(mockCountries);
    });

    it('should return empty array on fetch error', async () => {
      mockFetch.mockRejectedValueOnce(new Error('Network error'));

      const result = await getCountries();

      expect(result).toEqual([]);
    });

    it('should return empty array on non-ok response', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: false,
        status: 500,
      });

      const result = await getCountries();

      expect(result).toEqual([]);
    });
  });

  describe('searchMosques', () => {
    it('should search mosques without query', async () => {
      const mockMosques = [
        { slug: 'mosque-1', name: 'Mosque One', address: '123 Main St', city: 'Paris', lat: 48.8566, lng: 2.3522 },
        { slug: 'mosque-2', name: 'Mosque Two', address: '456 Oak St', city: 'Lyon', lat: 45.7640, lng: 4.8357 },
      ];

      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: () => Promise.resolve({ mosques: mockMosques }),
      });

      const result = await searchMosques('FR');

      expect(mockFetch).toHaveBeenCalledWith(
        'https://mawaqit-prayer-api.vercel.app/api/mosques/FR'
      );
      expect(result).toHaveLength(2);
      expect(result[0]).toMatchObject({
        id: 'mosque-1',
        name: 'Mosque One',
        address: '123 Main St',
        city: 'Paris',
        country: 'FR',
        latitude: 48.8566,
        longitude: 2.3522,
        is_favorite: false,
      });
    });

    it('should search mosques with query', async () => {
      const mockMosques = [
        { slug: 'grand-mosque', name: 'Grand Mosque', address: '789 Center St', city: 'Marseille', lat: 43.2965, lng: 5.3698 },
      ];

      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: () => Promise.resolve({ mosques: mockMosques }),
      });

      const result = await searchMosques('FR', 'grand');

      expect(mockFetch).toHaveBeenCalledWith(
        expect.stringContaining('/api/mosques/FR')
      );
      expect(mockFetch).toHaveBeenCalledWith(
        expect.stringContaining('q=grand')
      );
    });

    it('should handle mosque without optional fields', async () => {
      const mockMosques = [
        { slug: 'simple-mosque', name: null },
      ];

      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: () => Promise.resolve({ mosques: mockMosques }),
      });

      const result = await searchMosques('FR');

      expect(result[0].name).toBe('simple-mosque'); // Falls back to slug
      expect(result[0].address).toBeUndefined();
    });

    it('should return empty array on error', async () => {
      mockFetch.mockRejectedValueOnce(new Error('Network error'));

      const result = await searchMosques('FR');

      expect(result).toEqual([]);
    });
  });

  describe('getPrayerTimes', () => {
    it('should fetch prayer times without date', async () => {
      const mockPrayerTimes = {
        fajr: { name: 'Fajr', adhan: '2026-02-07T05:30:00Z', iqama: '2026-02-07T05:45:00Z' },
        dhuhr: { name: 'Dhuhr', adhan: '2026-02-07T12:30:00Z', iqama: '2026-02-07T12:45:00Z' },
        asr: { name: 'Asr', adhan: '2026-02-07T15:30:00Z', iqama: '2026-02-07T15:45:00Z' },
        maghrib: { name: 'Maghrib', adhan: '2026-02-07T18:15:00Z', iqama: '2026-02-07T18:20:00Z' },
        isha: { name: 'Isha', adhan: '2026-02-07T19:45:00Z', iqama: '2026-02-07T20:00:00Z' },
      };

      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: () => Promise.resolve(mockPrayerTimes),
      });

      const result = await getPrayerTimes('test-mosque');

      expect(mockFetch).toHaveBeenCalledWith(
        'https://mawaqit-prayer-api.vercel.app/api/prayer-times/test-mosque'
      );
      expect(result).toEqual(mockPrayerTimes);
    });

    it('should fetch prayer times with date', async () => {
      const mockPrayerTimes = {
        fajr: { name: 'Fajr', adhan: '2026-02-08T05:29:00Z', iqama: '2026-02-08T05:44:00Z' },
      };

      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: () => Promise.resolve(mockPrayerTimes),
      });

      const result = await getPrayerTimes('test-mosque', '2026-02-08');

      expect(mockFetch).toHaveBeenCalledWith(
        expect.stringContaining('/api/prayer-times/test-mosque')
      );
      expect(mockFetch).toHaveBeenCalledWith(
        expect.stringContaining('date=2026-02-08')
      );
    });

    it('should return null on fetch error', async () => {
      mockFetch.mockRejectedValueOnce(new Error('Network error'));

      const result = await getPrayerTimes('test-mosque');

      expect(result).toBeNull();
    });

    it('should return null on non-ok response', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: false,
        status: 404,
      });

      const result = await getPrayerTimes('non-existent-mosque');

      expect(result).toBeNull();
    });
  });
});

import { useState, useEffect } from 'react';
import { useStore } from '../hooks/useStore';
import { useFavoriteMosques } from '../hooks/usePrayerTimes';
import * as tauri from '../services/tauri';
import * as mawaqitApi from '../services/mawaqitApi';
import { Search, MapPin, Star, Plus, X, Check, Globe, Link2 } from 'lucide-react';
import type { Mosque, ProviderInfo } from '../types';
import type { Country as ApiCountry } from '../services/mawaqitApi';

const COUNTRIES = [
  { code: 'FR', name: 'France', flag: '🇫🇷' },
  { code: 'TN', name: 'Tunisia', flag: '🇹🇳' },
  { code: 'MA', name: 'Morocco', flag: '🇲🇦' },
  { code: 'DZ', name: 'Algeria', flag: '🇩🇿' },
  { code: 'US', name: 'United States', flag: '🇺🇸' },
  { code: 'GB', name: 'United Kingdom', flag: '🇬🇧' },
  { code: 'CA', name: 'Canada', flag: '🇨🇦' },
];

export const MosqueSelector = () => {
  const { currentMosque, setCurrentMosque, setCurrentPrayerTimes, setError, clearError, selectedDate } = useStore();
  const { favoriteMosques, addFavorite, removeFavorite } = useFavoriteMosques();
  const [isOpen, setIsOpen] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const [searchResults, setSearchResults] = useState<Mosque[]>([]);
  const [isSearching, setIsSearching] = useState(false);
  const [activeProvider, setActiveProvider] = useState<ProviderInfo | null>(null);
  const [searchError, setSearchError] = useState<string | null>(null);
  const [selectedCountry, setSelectedCountry] = useState('FR');
  const [apiCountries, setApiCountries] = useState<ApiCountry[]>([]);
  const [isLoadingCountries, setIsLoadingCountries] = useState(false);

  // Manual URL entry
  const [showManualEntry, setShowManualEntry] = useState(false);
  const [manualUrl, setManualUrl] = useState('');
  const [isLoadingPrayerTimes, setIsLoadingPrayerTimes] = useState(false);

  useEffect(() => {
    tauri.getActiveProvider().then((provider) => {
      setActiveProvider(provider);
    }).catch(() => {
      setActiveProvider(null);
    });

    // Fetch countries from Scraper API
    setIsLoadingCountries(true);
    mawaqitApi.getCountries().then((countries) => {
      if (countries && countries.length > 0) {
        setApiCountries(countries);
      }
    }).finally(() => {
      setIsLoadingCountries(false);
    });
  }, []);

  const handleSearch = async () => {
    if (!searchQuery.trim()) return; // Don't search if query is empty

    setIsSearching(true); // Start loading state
    setSearchError(null); // Clear previous errors
    clearError(); // Clear global errors

    try {
      // Use the new Scraped Mawaqit API for searching
      const results = await mawaqitApi.searchMosques(selectedCountry, searchQuery);
      setSearchResults(results); // Update UI with results

      if (results.length === 0) {
        // Show user-friendly error if no results found
        setSearchError(`No mosques found in ${selectedCountry}. Try another country or enter URL manually.`);
      }
    } catch (err) {
      console.error('Search failed:', err);
      setSearchError('Search failed. Please try again.');
    } finally {
      setIsSearching(false); // End loading state
    }
  };

  const extractSlugFromUrl = (url: string): string | null => {
    // Handle various Mawaqit URL formats
    // https://mawaqit.net/en/jamii-lqsiba-benzrt-7000-tunisia
    // https://mawaqit.net/fr/mosquee-name-1234-france

    try {
      const urlObj = new URL(url);
      if (!urlObj.hostname.includes('mawaqit.net')) {
        return null;
      }

      const pathParts = urlObj.pathname.split('/').filter(Boolean);
      // Should be at least 2 parts: language and slug
      if (pathParts.length >= 2) {
        return pathParts[pathParts.length - 1];
      }
      return null;
    } catch {
      // If not a valid URL, assume it's a slug directly
      if (url.includes('-') && url.length > 5) {
        return url.trim();
      }
      return null;
    }
  };

  const handleManualUrlSubmit = async () => {
    if (!manualUrl.trim()) return;

    setIsLoadingPrayerTimes(true);
    setSearchError(null);
    clearError();

    try {
      const slug = extractSlugFromUrl(manualUrl);

      if (!slug) {
        setSearchError('Invalid Mawaqit URL. Please use format: https://mawaqit.net/en/mosque-name-id-country');
        setIsLoadingPrayerTimes(false);
        return;
      }

      console.log('Fetching prayer times for slug:', slug, 'on date:', selectedDate);

      // Try to get prayer times from Scraper API
      const prayerTimes = await mawaqitApi.getPrayerTimes(slug, selectedDate);

      if (prayerTimes) {
        // Create mosque object from prayer times
        const mosque: Mosque = {
          id: slug,
          name: prayerTimes.mosque_id || slug,
          address: manualUrl,
          city: undefined,
          country: undefined,
          is_favorite: false,
        };

        setCurrentMosque(mosque);
        setCurrentPrayerTimes(prayerTimes);
        setIsOpen(false);
        setShowManualEntry(false);
        setManualUrl('');

        // Add to favorites automatically
        await addFavorite(mosque);

        // Save selected mosque for persistence
        try {
          await tauri.saveSelectedMosque(mosque);
          console.log('Saved selected mosque to database (manual URL)');
        } catch (saveErr) {
          console.error('Failed to save mosque selection:', saveErr);
        }
      }
    } catch (err) {
      console.error('Failed to load prayer times:', err);
      setError('Failed to load prayer times. Please check the URL and try again.');
      setSearchError('Could not fetch prayer times. The URL may be invalid or the mosque page may not have prayer times available.');
    } finally {
      setIsLoadingPrayerTimes(false);
    }
  };

  const handleSelectMosque = async (mosque: Mosque) => {
    setIsLoadingPrayerTimes(true); // Start loading state
    clearError(); // Clear global errors

    try {
      console.log('Loading prayer times for mosque:', mosque.id, 'on date:', selectedDate);

      // Use the new Scraped Mawaqit API for fetching times
      const prayerTimes = await mawaqitApi.getPrayerTimes(mosque.id, selectedDate);

      if (!prayerTimes) {
        throw new Error('No prayer times returned');
      }

      setCurrentMosque(mosque); // Set active mosque in state
      setCurrentPrayerTimes(prayerTimes); // Set prayer times in state
      setIsOpen(false); // Close dropdown

      // Sync with local database for persistence
      try {
        await tauri.saveSelectedMosque(mosque);
        console.log('Saved selected mosque to database');
      } catch (saveErr) {
        console.error('Failed to save mosque selection:', saveErr);
      }
    } catch (err) {
      console.error('Failed to load prayer times:', err);
      setError('Failed to load prayer times for this mosque. Please try again or use manual URL entry.');
    } finally {
      setIsLoadingPrayerTimes(false); // End loading state
    }
  };

  const isFavorite = (mosqueId: string) => {
    return favoriteMosques.some((m) => m.id === mosqueId);
  };



  return (
    <div className="relative">
      {/* Current mosque display */}
      <button
        onClick={() => setIsOpen(!isOpen)}
        className="flex items-center gap-3 w-full glass-card p-4 hover:bg-gray-800/70 transition-colors"
      >
        <div className="w-10 h-10 rounded-full bg-primary-600 flex items-center justify-center">
          <MapPin className="w-5 h-5 text-white" />
        </div>
        <div className="flex-1 text-left">
          {currentMosque ? (
            <>
              <p className="font-semibold truncate">{currentMosque.name}</p>
              {currentMosque.address && (
                <p className="text-sm text-gray-400 truncate">{currentMosque.address}</p>
              )}
            </>
          ) : (
            <p className="text-gray-400">Select a mosque</p>
          )}
        </div>
        <div className="flex items-center gap-2">
          {isLoadingPrayerTimes && (
            <div className="w-4 h-4 border-2 border-primary-500 border-t-transparent rounded-full animate-spin" />
          )}
          {currentMosque && isFavorite(currentMosque.id) && (
            <Star className="w-5 h-5 text-yellow-400 fill-yellow-400" />
          )}
          <span className="text-gray-400">▼</span>
        </div>
      </button>

      {/* Dropdown */}
      {isOpen && (
        <div className="absolute top-full left-0 right-0 mt-2 glass-card z-50 max-h-[600px] overflow-hidden">
          {/* Provider status */}
          {activeProvider && (
            <div className="px-4 py-2 bg-primary-900/20 border-b border-primary-500/30">
              <p className="text-xs text-primary-400">
                Using {activeProvider.name}
              </p>
            </div>
          )}

          {/* Country selector */}
          <div className="p-3 border-b border-gray-700/50">
            <div className="flex items-center gap-2">
              <Globe className="w-4 h-4 text-gray-400" />
              <select
                value={selectedCountry}
                onChange={(e) => setSelectedCountry(e.target.value)}
                className="bg-gray-800 border border-gray-700 rounded px-2 py-1 text-sm text-white"
                disabled={isLoadingCountries}
              >
                {/* Show static list if API list hasn't loaded yet */}
                {(apiCountries.length > 0 ? apiCountries : COUNTRIES).map((country) => (
                  <option key={country.code} value={country.code}>
                    {'flag' in country ? country.flag : '📍'} {country.name}
                  </option>
                ))}
              </select>
              <span className="text-xs text-gray-400">
                {isLoadingCountries ? 'Loading countries...' : `${apiCountries.length || COUNTRIES.length} countries supported`}
              </span>
            </div>
          </div>

          {/* Manual URL Entry Toggle */}
          <div className="p-3 border-b border-gray-700/50 bg-gray-800/30">
            <button
              onClick={() => setShowManualEntry(!showManualEntry)}
              className="flex items-center gap-2 text-sm text-primary-400 hover:text-primary-300"
            >
              <Link2 className="w-4 h-4" />
              {showManualEntry ? 'Hide manual URL entry' : 'Add mosque by Mawaqit URL'}
            </button>

            {showManualEntry && (
              <div className="mt-3 space-y-2">
                <p className="text-xs text-gray-400">
                  Enter the full Mawaqit URL for your mosque:
                </p>
                <input
                  type="text"
                  placeholder="https://mawaqit.net/en/mosque-name-id-country"
                  value={manualUrl}
                  onChange={(e) => setManualUrl(e.target.value)}
                  className="input-field w-full text-sm"
                />
                <button
                  onClick={handleManualUrlSubmit}
                  disabled={isLoadingPrayerTimes || !manualUrl.trim()}
                  className="btn-primary w-full text-sm"
                >
                  {isLoadingPrayerTimes ? 'Loading...' : 'Load Prayer Times'}
                </button>
                <p className="text-xs text-gray-500">
                  Example: https://mawaqit.net/en/jamii-lqsiba-benzrt-7000-tunisia
                </p>
              </div>
            )}
          </div>

          {/* Search */}
          <div className="p-4 border-b border-gray-700/50">
            <div className="flex gap-2">
              <div className="relative flex-1">
                <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
                <input
                  type="text"
                  placeholder="Search mosques..."
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  onKeyPress={(e) => e.key === 'Enter' && handleSearch()}
                  className="input-field w-full pl-10"
                />
              </div>
              <button
                onClick={handleSearch}
                disabled={isSearching}
                className="btn-primary"
              >
                {isSearching ? '...' : 'Search'}
              </button>
            </div>

            {/* Search error */}
            {searchError && (
              <p className="text-xs text-red-400 mt-2">{searchError}</p>
            )}
          </div>

          {/* Search results */}
          {searchResults.length > 0 && (
            <div className="p-2 border-b border-gray-700/50 max-h-48 overflow-y-auto">
              <p className="text-xs text-gray-400 px-2 mb-2">
                Search Results ({searchResults.length})
              </p>
              {searchResults.map((mosque) => (
                <div
                  key={mosque.id}
                  className="flex items-center gap-2 p-2 rounded-lg hover:bg-gray-800/50"
                >
                  <button
                    onClick={() => handleSelectMosque(mosque)}
                    className="flex-1 text-left"
                  >
                    <p className="font-medium">{mosque.name}</p>
                    {mosque.address && (
                      <p className="text-sm text-gray-400">{mosque.address}</p>
                    )}
                    {mosque.city && (
                      <p className="text-xs text-gray-500">
                        {mosque.city}{mosque.country && `, ${mosque.country}`}
                      </p>
                    )}
                  </button>
                  <button
                    onClick={() =>
                      isFavorite(mosque.id)
                        ? removeFavorite(mosque.id)
                        : addFavorite(mosque)
                    }
                    className="p-2 hover:bg-gray-700 rounded-lg transition-colors"
                  >
                    {isFavorite(mosque.id) ? (
                      <Star className="w-4 h-4 text-yellow-400 fill-yellow-400" />
                    ) : (
                      <Plus className="w-4 h-4 text-gray-400" />
                    )}
                  </button>
                </div>
              ))}
            </div>
          )}

          {/* Favorites */}
          <div className="p-2 max-h-48 overflow-y-auto">
            <p className="text-xs text-gray-400 px-2 mb-2">Favorites</p>
            {favoriteMosques.length === 0 ? (
              <p className="text-gray-500 text-sm px-2 py-4 text-center">
                No favorite mosques yet
              </p>
            ) : (
              favoriteMosques.map((mosque) => (
                <div
                  key={mosque.id}
                  className={`flex items-center gap-2 p-2 rounded-lg cursor-pointer transition-colors ${currentMosque?.id === mosque.id
                    ? 'bg-primary-900/30 border border-primary-500/30'
                    : 'hover:bg-gray-800/50'
                    }`}
                >
                  <button
                    onClick={() => handleSelectMosque(mosque)}
                    className="flex-1 text-left flex items-center gap-2"
                  >
                    {currentMosque?.id === mosque.id && (
                      <Check className="w-4 h-4 text-primary-400" />
                    )}
                    <span className={currentMosque?.id === mosque.id ? 'text-primary-400' : ''}>
                      {mosque.name}
                    </span>
                  </button>
                  <button
                    onClick={() => removeFavorite(mosque.id)}
                    className="p-2 hover:bg-gray-700 rounded-lg transition-colors"
                  >
                    <X className="w-4 h-4 text-gray-400" />
                  </button>
                </div>
              ))
            )}
          </div>
        </div>
      )}

      {/* Overlay to close dropdown */}
      {isOpen && (
        <div
          className="fixed inset-0 z-40"
          onClick={() => setIsOpen(false)}
        />
      )}
    </div>
  );
};

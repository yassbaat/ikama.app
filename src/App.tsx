import { useEffect } from 'react';
import { Header } from './components/Header';
import { MosqueSelector } from './components/MosqueSelector';
import { NextPrayerCard } from './components/NextPrayerCard';
import { PrayerList } from './components/PrayerList';
import { TravelTimeCard } from './components/TravelTimeCard';
import { ErrorDisplay } from './components/ErrorDisplay';
import { NightPrayerCard } from './components/NightPrayerCard';
import { usePrayerTimes } from './hooks/usePrayerTimes';
import { useStore } from './hooks/useStore';
import * as tauri from './services/tauri';
import * as mawaqitApi from './services/mawaqitApi';

function App() {
  const {
    isLoading,
    currentMosque,
    currentPrayerTimes,
    setCurrentMosque,
    setCurrentPrayerTimes,
    setError,
    selectedDate
  } = useStore();
  usePrayerTimes();

  // Load saved mosque on startup
  useEffect(() => {
    const loadSavedMosque = async () => {
      // Only load if no mosque is currently selected
      if (currentMosque) return;

      try {
        console.log('Loading saved mosque...');
        const savedMosque = await tauri.getSelectedMosque();

        if (savedMosque) {
          console.log('Found saved mosque:', savedMosque.name);

          // Load prayer times for the saved mosque from the Scraper API
          try {
            const prayerTimes = await mawaqitApi.getPrayerTimes(savedMosque.id, selectedDate);

            if (!prayerTimes) {
              throw new Error('Could not fetch prayer times from API');
            }

            setCurrentMosque(savedMosque);
            setCurrentPrayerTimes(prayerTimes);
            console.log('Loaded prayer times for saved mosque');
          } catch (ptErr) {
            console.error('Failed to load prayer times for saved mosque:', ptErr);
            // Still set the mosque so user can see it was selected
            setCurrentMosque(savedMosque);
            setError('Failed to load prayer times. Please try refreshing or selecting the mosque again.');
          }
        } else {
          console.log('No saved mosque found');
        }
      } catch (err) {
        console.error('Failed to load saved mosque:', err);
      }
    };

    loadSavedMosque();
  }, [currentMosque, setCurrentMosque, setCurrentPrayerTimes, setError, selectedDate]);

  return (
    <div className="min-h-screen bg-gradient-to-b from-gray-900 via-gray-900 to-gray-800">
      <div className="max-w-6xl mx-auto p-4">
        <Header />

        <main className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          {/* Left column - Mosque selector and main countdown */}
          <div className="lg:col-span-2 space-y-6">
            <MosqueSelector />

            {currentMosque && !currentPrayerTimes && (
              <div className="glass-card p-6 text-center">
                <p className="text-yellow-400">
                  Loading prayer times... If this persists, try using the manual URL entry option.
                </p>
              </div>
            )}

            {currentPrayerTimes && (
              <>
                <NextPrayerCard />
                <PrayerList />
                <NightPrayerCard />
              </>
            )}

            {!currentMosque && (
              <div className="glass-card p-8 text-center">
                <p className="text-gray-400 mb-2">Welcome to Iqamah!</p>
                <p className="text-sm text-gray-500">
                  Select a mosque from the dropdown above to view prayer times.
                </p>
                <p className="text-sm text-gray-500 mt-2">
                  You can search by country or enter a Mawaqit URL manually.
                </p>
              </div>
            )}
          </div>

          {/* Right column - Travel time and additional info */}
          <div className="space-y-6">
            {currentPrayerTimes && <TravelTimeCard />}

            {/* Info card */}
            <div className="glass-card p-6">
              <h3 className="text-lg font-semibold mb-4">About</h3>
              <p className="text-sm text-gray-400 leading-relaxed">
                Iqamah helps you track prayer times and estimate which rak'ah
                you might catch based on your travel time.
              </p>
              <div className="mt-4 p-3 bg-primary-900/20 border border-primary-500/30 rounded-lg">
                <p className="text-xs text-primary-400">
                  <strong>Note:</strong> Rak'ah estimation is approximate.
                  Always hurry to the mosque—you may still catch the prayer!
                </p>
              </div>
            </div>
          </div>
        </main>

        {/* Loading overlay */}
        {isLoading && (
          <div className="fixed inset-0 bg-black/50 backdrop-blur-sm flex items-center justify-center z-50">
            <div className="flex items-center gap-3 glass-card px-6 py-4">
              <div className="w-6 h-6 border-2 border-primary-500 border-t-transparent rounded-full animate-spin" />
              <span className="text-gray-300">Loading...</span>
            </div>
          </div>
        )}

        {/* Error display */}
        <ErrorDisplay />

        {/* Footer */}
        <footer className="mt-12 py-6 text-center text-sm text-gray-500">
          <p>Iqamah Prayer Times App</p>
          <p className="mt-1">Built with Tauri + React + Rust</p>
        </footer>
      </div>
    </div>
  );
}

export default App;

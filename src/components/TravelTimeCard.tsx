import { useState } from 'react';
import { useStore } from '../hooks/useStore';
import * as tauri from '../services/tauri';
import { formatCountdown, formatTime, getPrayerIcon } from '../services/time';
import { Car, AlertCircle, CheckCircle, Clock } from 'lucide-react';
import type { TravelPrediction } from '../types';

export const TravelTimeCard = () => {
  const { currentMosque, nextPrayer } = useStore();
  const [travelMinutes, setTravelMinutes] = useState(15);
  const [prediction, setPrediction] = useState<TravelPrediction | null>(null);
  const [loading, setLoading] = useState(false);

  const calculatePrediction = async () => {
    if (!currentMosque || !nextPrayer) return;

    setLoading(true);
    try {
      const result = await tauri.calculateTravelPrediction(
        currentMosque.id,
        nextPrayer.prayer.name,
        travelMinutes * 60
      );
      setPrediction(result);
    } catch (err) {
      console.error('Failed to calculate prediction:', err);
    } finally {
      setLoading(false);
    }
  };

  if (!currentMosque || !nextPrayer) {
    return null;
  }

  return (
    <div className="glass-card p-6">
      <h3 className="text-lg font-semibold mb-4 flex items-center gap-2">
        <Car className="w-5 h-5 text-primary-500" />
        Travel Time Calculator
      </h3>

      <div className="flex items-center gap-4 mb-6">
        <input
          type="range"
          min="1"
          max="60"
          value={travelMinutes}
          onChange={(e) => setTravelMinutes(Number(e.target.value))}
          className="flex-1 h-2 bg-gray-700 rounded-lg appearance-none cursor-pointer
            accent-primary-500"
        />
        <div className="flex items-center gap-2 bg-gray-800 rounded-lg px-3 py-2">
          <Clock className="w-4 h-4 text-gray-400" />
          <span className="font-mono">{travelMinutes} min</span>
        </div>
      </div>

      <button
        onClick={calculatePrediction}
        disabled={loading}
        className="btn-primary w-full mb-4"
      >
        {loading ? 'Calculating...' : 'Calculate'}
      </button>

      {prediction && (
        <div className="space-y-4 animate-fade-in">
          {/* Status indicator */}
          <div
            className={`p-4 rounded-lg ${
              prediction.should_leave_now
                ? 'bg-emerald-900/20 border border-emerald-500/30'
                : prediction.is_late
                ? 'bg-red-900/20 border border-red-500/30'
                : 'bg-primary-900/20 border border-primary-500/30'
            }`}
          >
            <div className="flex items-start gap-3">
              {prediction.should_leave_now ? (
                <CheckCircle className="w-5 h-5 text-emerald-400 mt-0.5" />
              ) : prediction.is_late ? (
                <AlertCircle className="w-5 h-5 text-red-400 mt-0.5" />
              ) : (
                <Clock className="w-5 h-5 text-primary-400 mt-0.5" />
              )}
              <div>
                <p
                  className={`font-medium ${
                    prediction.should_leave_now
                      ? 'text-emerald-400'
                      : prediction.is_late
                      ? 'text-red-400'
                      : 'text-primary-400'
                  }`}
                >
                  {prediction.should_leave_now
                    ? 'Leave Now!'
                    : prediction.is_late
                    ? 'You may be late'
                    : 'You have time'}
                </p>
                <p className="text-sm text-gray-400 mt-1">
                  {prediction.time_until_leave_secs
                    ? `Leave in ${formatCountdown(prediction.time_until_leave_secs)}`
                    : prediction.is_late
                    ? 'Prayer already started'
                    : 'Recommended leave time approaching'}
                </p>
              </div>
            </div>
          </div>

          {/* Details */}
          <div className="grid grid-cols-2 gap-3 text-sm">
            <div className="bg-gray-800/50 rounded-lg p-3">
              <p className="text-gray-400 mb-1">Leave at</p>
              <p className="font-semibold">{formatTime(prediction.recommended_leave_time)}</p>
            </div>
            <div className="bg-gray-800/50 rounded-lg p-3">
              <p className="text-gray-400 mb-1">Arrive at</p>
              <p className="font-semibold">{formatTime(prediction.arrival_time)}</p>
            </div>
          </div>

          {/* Arrival prediction */}
          {prediction.arrival_rakah !== undefined && (
            <div className="bg-gray-800/30 rounded-lg p-4">
              <div className="flex items-center gap-2 mb-2">
                <span className="text-lg">{getPrayerIcon(nextPrayer.prayer.name)}</span>
                <span className="text-gray-400">Estimated arrival:</span>
              </div>
              <p className="text-lg font-medium">
                {prediction.arrival_rakah === 0 ? (
                  <span className="text-emerald-400">Before prayer starts ✓</span>
                ) : prediction.arrival_rakah ? (
                  <>
                    Rak'ah{' '}
                    <span className="text-primary-400">{prediction.arrival_rakah}</span>
                  </>
                ) : (
                  <span className="text-gray-400">After estimated end</span>
                )}
              </p>
            </div>
          )}

          <p className="text-xs text-gray-500 text-center">
            Estimate—still go; you may catch it.
          </p>
        </div>
      )}
    </div>
  );
};

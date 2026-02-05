import { useEffect, useState } from 'react';
import { useStore } from '../hooks/useStore';
import { calculateNightPrayer, formatDuration, formatTime, NightPrayerInfo } from '../services/nightPrayer';
import { LiveTimer } from './LiveTimer';
import { Moon, Stars, Clock, Info, Sunrise } from 'lucide-react';

export const NightPrayerCard = () => {
  const { currentPrayerTimes, showNightPrayer, setShowNightPrayer } = useStore();
  const [nightPrayerInfo, setNightPrayerInfo] = useState<NightPrayerInfo | null>(null);
  const [now, setNow] = useState(new Date());

  useEffect(() => {
    if (!currentPrayerTimes) return;

    const updateNightPrayer = () => {
      const currentTime = new Date();
      setNow(currentTime);

      const info = calculateNightPrayer(
        currentPrayerTimes.maghrib.adhan,
        currentPrayerTimes.fajr.adhan,
        currentTime
      );

      setNightPrayerInfo(info);
    };

    updateNightPrayer();
    const interval = setInterval(updateNightPrayer, 60000); // Update every minute

    return () => clearInterval(interval);
  }, [currentPrayerTimes]);

  if (!currentPrayerTimes || !nightPrayerInfo) {
    return null;
  }

  // Only show after Isha (Maghrib) time
  const maghribTime = new Date(currentPrayerTimes.maghrib.adhan).getTime();
  const fajrTime = new Date(currentPrayerTimes.fajr.adhan).getTime();
  const currentTime = now.getTime();

  // Don't show if before Maghrib or after Fajr
  if (currentTime < maghribTime || currentTime >= fajrTime) {
    return null;
  }

  const isInLastThird = nightPrayerInfo.isActive;
  const lastThirdStart = new Date(nightPrayerInfo.startTime);
  const fajr = new Date(nightPrayerInfo.endTime);

  return (
    <div className="relative overflow-hidden rounded-2xl bg-gradient-to-br from-slate-900 via-indigo-950 to-slate-900 border border-indigo-500/30 p-6">
      {/* Stars background effect */}
      <div className="absolute inset-0 overflow-hidden">
        <div className="absolute top-4 left-8 w-1 h-1 bg-white rounded-full animate-pulse opacity-60" />
        <div className="absolute top-12 right-12 w-0.5 h-0.5 bg-white rounded-full animate-pulse opacity-40" style={{ animationDelay: '0.5s' }} />
        <div className="absolute top-8 left-1/4 w-0.5 h-0.5 bg-white rounded-full animate-pulse opacity-50" style={{ animationDelay: '1s' }} />
        <div className="absolute bottom-16 right-1/3 w-1 h-1 bg-white rounded-full animate-pulse opacity-30" style={{ animationDelay: '1.5s' }} />
        <div className="absolute top-1/3 right-8 w-0.5 h-0.5 bg-white rounded-full animate-pulse opacity-70" style={{ animationDelay: '0.3s' }} />
      </div>

      {/* Moon glow effect */}
      <div className="absolute -top-20 -right-20 w-64 h-64 bg-indigo-500/10 rounded-full blur-3xl" />
      <div className="absolute -bottom-20 -left-20 w-48 h-48 bg-purple-500/10 rounded-full blur-3xl" />

      <div className="relative z-10">
        {/* Header */}
        <div className="flex items-center justify-between mb-6">
          <div className="flex items-center gap-3">
            <div className="relative">
              <div className="w-12 h-12 rounded-full bg-gradient-to-br from-indigo-300 to-purple-400 flex items-center justify-center shadow-lg shadow-indigo-500/30">
                <Moon className="w-6 h-6 text-indigo-950 fill-indigo-950" />
              </div>
              {/* Glow effect */}
              <div className="absolute inset-0 w-12 h-12 rounded-full bg-indigo-400/30 blur-md -z-10" />
            </div>
            <div>
              <h3 className="text-lg font-semibold text-indigo-100">Night Prayer</h3>
              <p className="text-xs text-indigo-300/70">Tahajjud / Qiyam al-Layl</p>
            </div>
          </div>

          {/* Toggle button */}
          <button
            onClick={() => setShowNightPrayer(!showNightPrayer)}
            className="text-xs text-indigo-400/60 hover:text-indigo-300 transition-colors px-2 py-1 rounded"
          >
            {showNightPrayer ? 'Hide' : 'Show'}
          </button>
        </div>

        {!showNightPrayer ? (
          <div className="text-center py-4">
            <p className="text-indigo-300/50 text-sm">Night prayer card hidden</p>
            <button
              onClick={() => setShowNightPrayer(true)}
              className="mt-2 text-xs text-indigo-400 hover:text-indigo-300 underline"
            >
              Show night prayer times
            </button>
          </div>
        ) : (
          <>
            {/* Last third status */}
            <div className={`p-4 rounded-xl mb-4 ${
              isInLastThird 
                ? 'bg-emerald-500/10 border border-emerald-500/30' 
                : 'bg-indigo-500/10 border border-indigo-500/20'
            }`}>
              <div className="flex items-start gap-3">
                {isInLastThird ? (
                  <Stars className="w-5 h-5 text-emerald-400 flex-shrink-0 mt-0.5" />
                ) : (
                  <Clock className="w-5 h-5 text-indigo-400 flex-shrink-0 mt-0.5" />
                )}
                <div>
                  <p className={`text-sm font-medium ${
                    isInLastThird ? 'text-emerald-300' : 'text-indigo-200'
                  }`}>
                    {isInLastThird 
                      ? '🌙 Last Third of the Night - Best Time for Prayer'
                      : '⏳ Waiting for Last Third of the Night'
                    }
                  </p>
                  <p className="text-xs text-indigo-300/60 mt-1">
                    {isInLastThird 
                      ? 'The Prophet ﷺ said: "Our Lord descends every night to the lowest heaven when the last third of the night remains"'
                      : `Last third starts at ${formatTime(lastThirdStart.toISOString())}`
                    }
                  </p>
                </div>
              </div>
            </div>

            {/* Timer section */}
            <div className="grid grid-cols-2 gap-4 mb-4">
              {/* Last third start */}
              <div className="bg-slate-800/50 rounded-lg p-3 border border-slate-700/50">
                <div className="flex items-center gap-2 text-indigo-400/70 mb-1">
                  <Moon className="w-3 h-3" />
                  <span className="text-xs">Last Third Starts</span>
                </div>
                <p className="text-lg font-semibold text-indigo-100">
                  {formatTime(lastThirdStart.toISOString())}
                </p>
              </div>

              {/* Fajr */}
              <div className="bg-slate-800/50 rounded-lg p-3 border border-slate-700/50">
                <div className="flex items-center gap-2 text-indigo-400/70 mb-1">
                  <Sunrise className="w-3 h-3" />
                  <span className="text-xs">Fajr (End Time)</span>
                </div>
                <p className="text-lg font-semibold text-indigo-100">
                  {formatTime(fajr.toISOString())}
                </p>
              </div>
            </div>

            {/* Live countdown */}
            {isInLastThird ? (
              <div className="text-center py-3 bg-emerald-500/5 rounded-lg border border-emerald-500/20">
                <p className="text-xs text-emerald-400/80 mb-2 uppercase tracking-wider">Time Remaining Until Fajr</p>
                <LiveTimer
                  targetTime={fajr.toISOString()}
                  size="lg"
                  showSeconds={false}
                  className="text-emerald-300"
                />
              </div>
            ) : nightPrayerInfo.timeUntilStartSeconds ? (
              <div className="text-center py-3 bg-indigo-500/5 rounded-lg border border-indigo-500/20">
                <p className="text-xs text-indigo-400/80 mb-2 uppercase tracking-wider">Last Third Starts In</p>
                <div className="text-2xl font-mono font-bold text-indigo-200">
                  {formatDuration(nightPrayerInfo.timeUntilStartSeconds)}
                </div>
              </div>
            ) : null}

            {/* Night duration info */}
            <div className="mt-4 p-3 bg-slate-800/30 rounded-lg">
              <div className="flex items-start gap-2">
                <Info className="w-4 h-4 text-indigo-400/50 flex-shrink-0 mt-0.5" />
                <p className="text-xs text-indigo-300/50 leading-relaxed">
                  The night is divided into three parts. The last third is when Allah descends 
                  to the lowest heaven and accepts supplications. Duration of last third: {' '}
                  <span className="text-indigo-300/70 font-medium">
                    {formatDuration(nightPrayerInfo.durationSeconds)}
                  </span>
                </p>
              </div>
            </div>

            {/* Progress bar for last third */}
            {isInLastThird && (
              <div className="mt-4">
                <div className="flex items-center justify-between text-xs text-emerald-400/70 mb-1">
                  <span>Progress through last third</span>
                  <span>{Math.round(nightPrayerInfo.progress * 100)}%</span>
                </div>
                <div className="h-2 bg-slate-700 rounded-full overflow-hidden">
                  <div 
                    className="h-full bg-gradient-to-r from-emerald-500 to-emerald-400 transition-all duration-1000"
                    style={{ width: `${nightPrayerInfo.progress * 100}%` }}
                  />
                </div>
              </div>
            )}
          </>
        )}
      </div>
    </div>
  );
};

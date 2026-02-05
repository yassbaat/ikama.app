import { useStore } from '../hooks/useStore';
import { useRakahEstimate } from '../hooks/usePrayerTimes';
import { formatTime, getPrayerIcon, getPrayerColor } from '../services/time';
import { LiveTimer, IqamaBadge } from './LiveTimer';
import { Moon, Sun, Navigation, MapPin, Clock } from 'lucide-react';

export const NextPrayerCard = () => {
  const { nextPrayer, countdowns, rakahEstimate, currentPrayerTimes, currentMosque, selectedDate } = useStore();

  // Get current active prayer for rakah estimation
  const activePrayer = countdowns.find((c) => c.is_active);
  useRakahEstimate(activePrayer?.prayer_name || null);

  // Check if viewing today's prayers
  const today = new Date().toISOString().split('T')[0];
  const isToday = selectedDate === today;
  const isPastDate = selectedDate < today;

  if (!currentPrayerTimes) {
    return (
      <div className="glass-card p-8 text-center">
        <p className="text-gray-400">Select a mosque to view prayer times</p>
      </div>
    );
  }

  // Get the mosque name from prayer times (mosque_name contains Arabic name from confData)
  // or fall back to the current mosque name
  const mosqueName = currentPrayerTimes.mosque_name || currentMosque?.name || currentPrayerTimes.fajr.name;

  const gradientClass = nextPrayer ? getPrayerColor(nextPrayer.prayer.name) : 'from-gray-400 to-gray-500';

  // Find the next prayer's adhan and iqama times for the timer
  const nextAdhanTime = nextPrayer?.prayer.adhan || null;
  const nextIqamaTime = nextPrayer?.prayer.iqama || null;
  
  // Determine which timer to show
  const showAdhanTimer = nextPrayer && nextPrayer.time_until_adhan_secs > 0;
  const showIqamaTimer = nextPrayer && nextPrayer.time_until_adhan_secs <= 0 && nextIqamaTime;

  return (
    <div className={`glass-card p-6 md:p-8 relative overflow-hidden`}>
      {/* Background gradient */}
      <div className={`absolute inset-0 bg-gradient-to-br ${gradientClass} opacity-10`} />
      
      <div className="relative z-10">
        {/* Mosque Name Header */}
        <div className="mb-6 pb-4 border-b border-gray-700/50">
          <div className="flex items-center gap-2 text-gray-400 mb-1">
            <MapPin className="w-4 h-4" />
            <span className="text-sm">Selected Mosque</span>
          </div>
          <h2 className="text-2xl font-bold text-white" dir="rtl">
            {mosqueName}
          </h2>
          {currentMosque?.city && (
            <p className="text-sm text-gray-400 mt-1">
              {currentMosque.city}{currentMosque.country && `, ${currentMosque.country}`}
            </p>
          )}
          {!isToday && (
            <div className="mt-2 inline-flex items-center gap-2 px-3 py-1 bg-yellow-500/20 border border-yellow-500/30 rounded-full">
              <Clock className="w-3 h-3 text-yellow-400" />
              <span className="text-xs text-yellow-400">
                Viewing {isPastDate ? 'past' : 'future'} date
              </span>
            </div>
          )}
        </div>

        {/* Next Prayer Header */}
        {nextPrayer && isToday && (
          <>
            <div className="flex items-center justify-between mb-6">
              <div className="flex items-center gap-3">
                <span className="text-3xl">{getPrayerIcon(nextPrayer.prayer.name)}</span>
                <div>
                  <h2 className="text-lg text-gray-400">Next Prayer</h2>
                  <p className="text-2xl font-bold">{nextPrayer.prayer.name}</p>
                </div>
              </div>
              {nextPrayer.is_tomorrow && (
                <span className="text-sm text-gray-400 bg-gray-800/50 px-3 py-1 rounded-full">
                  Tomorrow
                </span>
              )}
            </div>

            {/* Main countdown with LiveTimer */}
            <div className="text-center mb-8">
              {showAdhanTimer ? (
                <LiveTimer
                  targetTime={nextAdhanTime}
                  label="Time until Adhan"
                  size="xl"
                  showSeconds={true}
                  pulseWhenUrgent={true}
                  className="mb-2"
                />
              ) : showIqamaTimer ? (
                <>
                  <p className="text-emerald-400 mb-2 flex items-center justify-center gap-2 text-sm uppercase tracking-wide">
                    <span className="w-2 h-2 rounded-full bg-emerald-400 animate-pulse" />
                    Time until Iqama
                  </p>
                  <LiveTimer
                    targetTime={nextIqamaTime}
                    size="xl"
                    showSeconds={true}
                    pulseWhenUrgent={true}
                    className="text-emerald-400"
                  />
                </>
              ) : (
                <>
                  <p className="text-gray-400 mb-2 text-sm uppercase tracking-wide">Prayer in progress</p>
                  <div className="text-6xl font-bold text-white">Now</div>
                </>
              )}
            </div>

            {/* Prayer times grid */}
            <div className="grid grid-cols-2 gap-4 mb-6">
              <div className="bg-gray-800/50 rounded-lg p-4">
                <div className="flex items-center gap-2 text-gray-400 mb-1">
                  <Sun className="w-4 h-4" />
                  <span className="text-sm">Adhan</span>
                </div>
                <p className="text-xl font-semibold">{formatTime(nextPrayer.prayer.adhan)}</p>
              </div>
              <div className="bg-gray-800/50 rounded-lg p-4">
                <div className="flex items-center gap-2 text-gray-400 mb-1">
                  <Moon className="w-4 h-4" />
                  <span className="text-sm">Iqama</span>
                </div>
                <p className="text-xl font-semibold">
                  {nextPrayer.prayer.iqama ? formatTime(nextPrayer.prayer.iqama) : '—'}
                </p>
                {showIqamaTimer && nextIqamaTime && (
                  <div className="mt-2">
                    <IqamaBadge seconds={nextPrayer.time_until_iqama_secs || 0} />
                  </div>
                )}
              </div>
            </div>
          </>
        )}

        {/* Reference message for past/future dates */}
        {!isToday && (
          <div className="text-center py-8">
            <p className="text-gray-400 mb-4">
              {isPastDate 
                ? 'Viewing past prayer times for reference'
                : 'Viewing future prayer times'}
            </p>
            <div className="grid grid-cols-2 gap-4">
              <div className="bg-gray-800/50 rounded-lg p-4">
                <div className="flex items-center gap-2 text-gray-400 mb-1">
                  <Sun className="w-4 h-4" />
                  <span className="text-sm">Fajr</span>
                </div>
                <p className="text-xl font-semibold">{formatTime(currentPrayerTimes.fajr.adhan)}</p>
              </div>
              <div className="bg-gray-800/50 rounded-lg p-4">
                <div className="flex items-center gap-2 text-gray-400 mb-1">
                  <Moon className="w-4 h-4" />
                  <span className="text-sm">Isha</span>
                </div>
                <p className="text-xl font-semibold">{formatTime(currentPrayerTimes.isha.adhan)}</p>
              </div>
            </div>
          </div>
        )}

        {/* LIVE Rakah Estimation - Only for today */}
        {isToday && rakahEstimate && rakahEstimate.status !== 'not_available' && rakahEstimate.status !== 'likely_finished' && (
          <div className="bg-emerald-900/20 border border-emerald-500/30 rounded-lg p-4">
            <div className="flex items-center justify-between mb-3">
              <span className="live-badge">LIVE (estimated)</span>
              <span className="text-xs text-emerald-400/70">
                Based on {rakahEstimate.total_rakah} rak'ahs
              </span>
            </div>

            {rakahEstimate.status === 'not_started' && (
              <div className="text-center">
                <p className="text-gray-400 text-sm mb-2">Prayer starts in</p>
                <LiveTimer
                  targetTime={activePrayer?.iqama_time || null}
                  size="lg"
                  showSeconds={false}
                />
              </div>
            )}

            {rakahEstimate.status === 'in_progress' && (
              <>
                <div className="flex items-center justify-between mb-2">
                  <span className="text-gray-300">
                    Rak'ah {rakahEstimate.current_rakah} / {rakahEstimate.total_rakah}
                  </span>
                  <span className="text-emerald-400">
                    {Math.round(rakahEstimate.progress * 100)}%
                  </span>
                </div>
                <div className="h-2 bg-gray-700 rounded-full overflow-hidden">
                  <div
                    className="h-full bg-gradient-to-r from-emerald-500 to-emerald-400 transition-all duration-500"
                    style={{ width: `${rakahEstimate.progress * 100}%` }}
                  />
                </div>
                {rakahEstimate.elapsed_secs !== undefined && (
                  <p className="text-xs text-gray-400 mt-2">
                    Started {Math.floor(rakahEstimate.elapsed_secs / 60)} min ago (est.)
                  </p>
                )}
              </>
            )}

            {rakahEstimate.status === 'recently_finished' && (
              <div className="text-center">
                <div className="flex items-center justify-center gap-2 mb-2">
                  <span className="w-2 h-2 rounded-full bg-amber-400" />
                  <span className="text-amber-400 font-medium">
                    {rakahEstimate.ended_minutes_ago === 1 
                      ? 'Just ended' 
                      : `Ended ~${rakahEstimate.ended_minutes_ago} min ago`}
                  </span>
                </div>
                {rakahEstimate.can_still_catch ? (
                  <p className="text-sm text-emerald-400 animate-pulse">
                    You may still catch the prayer! ±3 min window
                  </p>
                ) : (
                  <p className="text-xs text-gray-400">
                    Next prayer countdown starting soon
                  </p>
                )}
              </div>
            )}
          </div>
        )}

        {/* Travel time hint */}
        {isToday && currentMosque && nextPrayer?.time_until_iqama_secs && nextPrayer.time_until_iqama_secs > 0 && (
          <div className="mt-4 flex items-center gap-2 text-sm text-gray-400 bg-gray-800/30 rounded-lg p-3">
            <Navigation className="w-4 h-4" />
            <span>Set your travel time to see when to leave</span>
          </div>
        )}
      </div>
    </div>
  );
};

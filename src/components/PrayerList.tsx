import { useState } from 'react';
import { useStore } from '../hooks/useStore';
import { formatTime, getPrayerIcon, getPrayerColor } from '../services/time';
import { CompactTimer, IqamaBadge } from './LiveTimer';
import { Clock, Sun, Sunrise, Calendar, ChevronLeft, ChevronRight, RotateCcw, ChevronDown, ChevronUp, Bell, BellOff, X, Info } from 'lucide-react';
import * as tauri from '../services/tauri';
import type { Prayer } from '../types';

// Simple calendar component
const MiniCalendar = ({ 
  selectedDate, 
  onSelectDate,
  onClose 
}: { 
  selectedDate: string; 
  onSelectDate: (date: string) => void;
  onClose: () => void;
}) => {
  const [currentMonth, setCurrentMonth] = useState(new Date(selectedDate));
  
  const monthNames = ['January', 'February', 'March', 'April', 'May', 'June', 
                      'July', 'August', 'September', 'October', 'November', 'December'];
  const dayNames = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'];
  
  const firstDayOfMonth = new Date(currentMonth.getFullYear(), currentMonth.getMonth(), 1);
  const lastDayOfMonth = new Date(currentMonth.getFullYear(), currentMonth.getMonth() + 1, 0);
  const daysInMonth = lastDayOfMonth.getDate();
  const startingDay = firstDayOfMonth.getDay();
  
  const today = new Date().toISOString().split('T')[0];
  const selected = new Date(selectedDate).toISOString().split('T')[0];
  
  const days: (number | null)[] = [];
  for (let i = 0; i < startingDay; i++) days.push(null);
  for (let i = 1; i <= daysInMonth; i++) days.push(i);
  
  const handlePrevMonth = () => {
    setCurrentMonth(new Date(currentMonth.getFullYear(), currentMonth.getMonth() - 1, 1));
  };
  
  const handleNextMonth = () => {
    setCurrentMonth(new Date(currentMonth.getFullYear(), currentMonth.getMonth() + 1, 1));
  };
  
  const handleDayClick = (day: number) => {
    const date = new Date(currentMonth.getFullYear(), currentMonth.getMonth(), day);
    onSelectDate(date.toISOString().split('T')[0]);
    onClose();
  };
  
  return (
    <div className="absolute top-full right-0 mt-2 p-4 glass-card z-50 w-72">
      <div className="flex items-center justify-between mb-4">
        <button onClick={handlePrevMonth} className="p-1 hover:bg-gray-700/50 rounded">
          <ChevronLeft className="w-4 h-4" />
        </button>
        <span className="font-semibold">
          {monthNames[currentMonth.getMonth()]} {currentMonth.getFullYear()}
        </span>
        <button onClick={handleNextMonth} className="p-1 hover:bg-gray-700/50 rounded">
          <ChevronRight className="w-4 h-4" />
        </button>
      </div>
      
      <div className="grid grid-cols-7 gap-1 text-center text-xs text-gray-400 mb-2">
        {dayNames.map(day => <span key={day}>{day}</span>)}
      </div>
      
      <div className="grid grid-cols-7 gap-1">
        {days.map((day, idx) => {
          if (!day) return <div key={idx} className="h-8" />;
          
          const dateStr = new Date(currentMonth.getFullYear(), currentMonth.getMonth(), day).toISOString().split('T')[0];
          const isToday = dateStr === today;
          const isSelected = dateStr === selected;
          
          return (
            <button
              key={idx}
              onClick={() => handleDayClick(day)}
              className={`h-8 w-8 rounded-full text-sm flex items-center justify-center transition-colors ${
                isSelected 
                  ? 'bg-primary-500 text-white' 
                  : isToday 
                    ? 'bg-primary-500/30 text-primary-300 border border-primary-500/50'
                    : 'hover:bg-gray-700/50'
              }`}
            >
              {day}
            </button>
          );
        })}
      </div>
    </div>
  );
};

// Prayer details modal with live timer
const PrayerDetailsModal = ({ 
  prayer, 
  isOpen, 
  onClose,
  selectedDate,
}: { 
  prayer: Prayer | null;
  isOpen: boolean;
  onClose: () => void;
  selectedDate: string;
}) => {
  if (!isOpen || !prayer) return null;
  
  const today = new Date().toISOString().split('T')[0];
  const isPastDate = selectedDate < today;
  
  return (
    <div className="fixed inset-0 bg-black/50 backdrop-blur-sm flex items-center justify-center z-50 p-4">
      <div className="glass-card p-6 max-w-md w-full">
        <div className="flex items-center justify-between mb-6">
          <h3 className="text-xl font-bold flex items-center gap-2">
            <span className="text-2xl">{getPrayerIcon(prayer.name)}</span>
            {prayer.name}
          </h3>
          <button onClick={onClose} className="p-2 hover:bg-gray-700/50 rounded-lg">
            <X className="w-5 h-5" />
          </button>
        </div>
        
        <div className="space-y-4">
          {/* Adhan time */}
          <div className="p-4 bg-gray-800/50 rounded-lg">
            <div className="flex items-center gap-2 text-gray-400 mb-1">
              <Sun className="w-4 h-4" />
              <span className="text-sm">Adhan</span>
            </div>
            <p className="text-2xl font-semibold">{formatTime(prayer.adhan)}</p>
          </div>
          
          {/* Iqama time */}
          {prayer.iqama && (
            <div className="p-4 bg-gray-800/50 rounded-lg">
              <div className="flex items-center gap-2 text-gray-400 mb-1">
                <Clock className="w-4 h-4" />
                <span className="text-sm">Iqama</span>
              </div>
              <p className="text-2xl font-semibold">{formatTime(prayer.iqama)}</p>
            </div>
          )}
          
          {/* Reference note for past dates */}
          {isPastDate && (
            <div className="p-4 bg-gray-700/30 rounded-lg flex items-start gap-3">
              <Info className="w-5 h-5 text-gray-400 flex-shrink-0 mt-0.5" />
              <div>
                <p className="text-sm text-gray-400">Reference</p>
                <p className="text-sm text-gray-300 mt-1">
                  This is a past date. Prayer times shown are for reference only.
                </p>
              </div>
            </div>
          )}
          
          {/* Rakah count */}
          <div className="p-4 bg-gray-800/50 rounded-lg">
            <p className="text-sm text-gray-400 mb-1">Rak'ahs</p>
            <p className="text-xl font-semibold">
              {prayer.custom_rakah_count || (prayer.name === 'Fajr' ? 2 : prayer.name === 'Maghrib' ? 3 : 4)}
            </p>
          </div>
        </div>
        
        <button 
          onClick={onClose}
          className="btn-primary w-full mt-6"
        >
          Close
        </button>
      </div>
    </div>
  );
};

export const PrayerList = () => {
  const { 
    countdowns, 
    nextPrayer, 
    currentPrayerTimes, 
    currentMosque, 
    selectedDate, 
    setSelectedDate, 
    setViewingDate, 
    setCurrentPrayerTimes, 
    setError,
    isCalendarExpanded,
    setIsCalendarExpanded,
    selectedPrayer,
    setSelectedPrayer,
    showPrayerDetails,
    setShowPrayerDetails,
    adhanNotifications,
    setAdhanNotifications,
    iqamahNotifications,
    setIqamahNotifications,
  } = useStore();
  
  const [isLoadingDate, setIsLoadingDate] = useState(false);
  const [showMiniCalendar, setShowMiniCalendar] = useState(false);

  if (!currentPrayerTimes) {
    return null;
  }

  // Create list of prayers with their data
  const allPrayers: { name: string; prayer: Prayer; isSunrise?: boolean }[] = [
    { name: 'Fajr', prayer: currentPrayerTimes.fajr },
    { name: 'Sunrise', prayer: { name: 'Sunrise', adhan: currentPrayerTimes.fajr.adhan }, isSunrise: true },
    { name: 'Dhuhr', prayer: currentPrayerTimes.dhuhr },
    { name: 'Asr', prayer: currentPrayerTimes.asr },
    { name: 'Maghrib', prayer: currentPrayerTimes.maghrib },
    { name: 'Isha', prayer: currentPrayerTimes.isha },
  ];

  // Find countdown for each prayer
  const getPrayerCountdown = (name: string) => {
    return countdowns.find(c => c.prayer_name === name);
  };

  // Check if viewing today's prayers
  const today = new Date().toISOString().split('T')[0];
  const isToday = selectedDate === today;
  const isPastDate = selectedDate < today;

  // Format the display date
  const displayDate = new Date(selectedDate).toLocaleDateString('en-US', {
    weekday: 'short',
    month: 'short',
    day: 'numeric',
  });

  const handleDateChange = async (newDate: string) => {
    if (!currentMosque || newDate === selectedDate) return;
    
    setIsLoadingDate(true);
    setError(null);
    
    try {
      const prayerTimes = await tauri.getPrayerTimesForMosque(currentMosque.id, undefined, newDate);
      
      setSelectedDate(newDate);
      setViewingDate(new Date(newDate));
      setCurrentPrayerTimes(prayerTimes);
    } catch (err) {
      console.error('Failed to load prayer times for date:', err);
      setError(`Failed to load prayer times for ${newDate}. The date may be out of range.`);
    } finally {
      setIsLoadingDate(false);
    }
  };

  const handlePrevDay = () => {
    const date = new Date(selectedDate);
    date.setDate(date.getDate() - 1);
    handleDateChange(date.toISOString().split('T')[0]);
  };

  const handleNextDay = () => {
    const date = new Date(selectedDate);
    date.setDate(date.getDate() + 1);
    handleDateChange(date.toISOString().split('T')[0]);
  };

  const handleToday = () => {
    handleDateChange(today);
  };

  const handlePrayerClick = (prayer: Prayer) => {
    setSelectedPrayer(prayer);
    setShowPrayerDetails(true);
  };



  return (
    <div className="glass-card p-6">
      {/* Header with date navigation */}
      <div className="flex items-center justify-between mb-4">
        <h3 className="text-lg font-semibold flex items-center gap-2">
          <Clock className="w-5 h-5 text-primary-500" />
          {isToday ? "Today's Prayers" : isPastDate ? "Past Prayers" : "Future Prayers"}
        </h3>

        <div className="flex items-center gap-2">
          <button
            onClick={handlePrevDay}
            disabled={isLoadingDate}
            className="p-1.5 rounded-lg hover:bg-gray-700/50 disabled:opacity-50 transition-colors"
            title="Previous day"
          >
            <ChevronLeft className="w-4 h-4" />
          </button>
          
          <div className="relative">
            <button
              onClick={() => setShowMiniCalendar(!showMiniCalendar)}
              className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-gray-800/50 hover:bg-gray-700/50 text-sm font-medium transition-colors"
              disabled={isLoadingDate}
            >
              <Calendar className="w-4 h-4 text-primary-400" />
              <span className="text-gray-300">{displayDate}</span>
            </button>
            
            {showMiniCalendar && (
              <MiniCalendar
                selectedDate={selectedDate}
                onSelectDate={handleDateChange}
                onClose={() => setShowMiniCalendar(false)}
              />
            )}
          </div>
          
          <button
            onClick={handleNextDay}
            disabled={isLoadingDate}
            className="p-1.5 rounded-lg hover:bg-gray-700/50 disabled:opacity-50 transition-colors"
            title="Next day"
          >
            <ChevronRight className="w-4 h-4" />
          </button>
          
          {!isToday && (
            <button
              onClick={handleToday}
              disabled={isLoadingDate}
              className="p-1.5 rounded-lg hover:bg-gray-700/50 text-primary-400 hover:text-primary-300 transition-colors"
              title="Go to today"
            >
              <RotateCcw className="w-4 h-4" />
            </button>
          )}
        </div>
      </div>

      {/* Expandable calendar */}
      <div className="mb-4">
        <button
          onClick={() => setIsCalendarExpanded(!isCalendarExpanded)}
          className="flex items-center gap-2 text-sm text-primary-400 hover:text-primary-300 transition-colors"
        >
          {isCalendarExpanded ? <ChevronUp className="w-4 h-4" /> : <ChevronDown className="w-4 h-4" />}
          {isCalendarExpanded ? 'Hide Calendar' : 'Show Calendar'}
        </button>
        
        {isCalendarExpanded && (
          <div className="mt-3 p-4 bg-gray-800/30 rounded-lg">
            <MiniCalendar
              selectedDate={selectedDate}
              onSelectDate={(date) => {
                handleDateChange(date);
                setIsCalendarExpanded(false);
              }}
              onClose={() => setIsCalendarExpanded(false)}
            />
          </div>
        )}
      </div>

      {/* Notification toggles */}
      {isToday && (
        <div className="flex items-center gap-4 mb-4 p-3 bg-gray-800/30 rounded-lg">
          <button
            onClick={() => setAdhanNotifications(!adhanNotifications)}
            className={`flex items-center gap-2 text-sm transition-colors ${
              adhanNotifications ? 'text-primary-400' : 'text-gray-500'
            }`}
          >
            {adhanNotifications ? <Bell className="w-4 h-4" /> : <BellOff className="w-4 h-4" />}
            Adhan
          </button>
          <button
            onClick={() => setIqamahNotifications(!iqamahNotifications)}
            className={`flex items-center gap-2 text-sm transition-colors ${
              iqamahNotifications ? 'text-primary-400' : 'text-gray-500'
            }`}
          >
            {iqamahNotifications ? <Bell className="w-4 h-4" /> : <BellOff className="w-4 h-4" />}
            Iqamah
          </button>
        </div>
      )}

      {/* Reference note for past dates */}
      {isPastDate && (
        <div className="mb-4 p-3 bg-gray-700/30 rounded-lg flex items-start gap-3">
          <Info className="w-5 h-5 text-gray-400 flex-shrink-0 mt-0.5" />
          <p className="text-sm text-gray-400">
            Viewing past prayer times for reference. Live countdowns and progress tracking are disabled.
          </p>
        </div>
      )}

      {isLoadingDate && (
        <div className="flex items-center justify-center py-8">
          <div className="w-6 h-6 border-2 border-primary-500 border-t-transparent rounded-full animate-spin" />
          <span className="ml-2 text-gray-400">Loading prayer times...</span>
        </div>
      )}

      {!isLoadingDate && (
        <div className="space-y-3">
          {allPrayers.map(({ name, prayer, isSunrise }) => {
            const isNext = isToday && nextPrayer?.prayer.name === name;
            const gradientClass = getPrayerColor(name);
            const countdown = getPrayerCountdown(name);
            
            const hasPassed = isToday && countdown && countdown.time_until_adhan_secs <= 0 && !countdown.is_active;
            const isActive = isToday && countdown?.is_active;
            
            // Get iqama countdown for this prayer
            const iqamaSeconds = countdown?.time_until_iqama_secs || 0;

            return (
              <div
                key={name}
                onClick={() => !isSunrise && handlePrayerClick(prayer)}
                className={`prayer-card flex items-center justify-between cursor-pointer transition-all ${
                  isNext ? 'active' : ''
                } ${hasPassed ? 'opacity-50' : ''} ${!isSunrise ? 'hover:bg-gray-800/70' : ''}`}
              >
                <div className="flex items-center gap-4">
                  <div
                    className={`w-10 h-10 rounded-lg bg-gradient-to-br ${isSunrise ? 'from-orange-400 to-yellow-500' : gradientClass} 
                      flex items-center justify-center text-lg`}
                  >
                    {isSunrise ? '🌅' : getPrayerIcon(name)}
                  </div>
                  <div>
                    <p className="font-semibold">{name}</p>
                    <div className="flex items-center gap-2 text-sm text-gray-400 flex-wrap">
                      <span className="flex items-center gap-1">
                        {isSunrise ? (
                          <>
                            <Sunrise className="w-3 h-3" />
                            {formatTime(prayer.adhan)}
                          </>
                        ) : (
                          <>
                            <Sun className="w-3 h-3" />
                            {formatTime(prayer.adhan)}
                          </>
                        )}
                      </span>
                      {!isSunrise && prayer.iqama && (
                        <span className="flex items-center gap-1">
                          <span className="text-gray-600">•</span>
                          <span>Iqama: {formatTime(prayer.iqama)}</span>
                          {isToday && iqamaSeconds > 0 && iqamaSeconds < 3600 && (
                            <IqamaBadge seconds={iqamaSeconds} />
                          )}
                        </span>
                      )}
                    </div>
                  </div>
                </div>

                <div className="text-right min-w-[60px]">
                  {isActive ? (
                    <span className="text-emerald-400 font-medium">Now</span>
                  ) : isToday && countdown && countdown.time_until_adhan_secs > 0 ? (
                    <CompactTimer seconds={countdown.time_until_adhan_secs} />
                  ) : hasPassed ? (
                    <span className="text-gray-500 text-sm">Passed</span>
                  ) : (
                    <span className="text-gray-500 text-sm">—</span>
                  )}
                </div>
              </div>
            );
          })}
        </div>
      )}
      
      {/* Jumuah time if available */}
      {currentPrayerTimes.jumuah && (
        <div className="mt-4 p-3 bg-emerald-900/10 border border-emerald-500/20 rounded-lg">
          <div className="flex items-center gap-2">
            <span className="text-lg">🕌</span>
            <div>
              <p className="text-sm text-emerald-400">Jumu'ah Prayer</p>
              <p className="font-semibold">{formatTime(currentPrayerTimes.jumuah.adhan)}</p>
            </div>
          </div>
        </div>
      )}

      {/* Prayer details modal */}
      <PrayerDetailsModal
        prayer={selectedPrayer}
        isOpen={showPrayerDetails}
        onClose={() => setShowPrayerDetails(false)}
        selectedDate={selectedDate}
      />
    </div>
  );
};

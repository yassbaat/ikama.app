import { useEffect, useState, useRef } from 'react';
import { formatLiveTimer, getUrgencyColor, getUrgencyBg } from '../services/time';

interface LiveTimerProps {
  targetTime: string | null;
  label?: string;
  showSeconds?: boolean;
  className?: string;
  onExpire?: () => void;
  size?: 'sm' | 'md' | 'lg' | 'xl';
  pulseWhenUrgent?: boolean;
}

export const LiveTimer = ({ 
  targetTime, 
  label,
  showSeconds = true,
  className = '',
  onExpire,
  size = 'md',
  pulseWhenUrgent = true
}: LiveTimerProps) => {
  const [timeLeft, setTimeLeft] = useState<number>(0);
  const [isExpired, setIsExpired] = useState(false);
  const animationFrameRef = useRef<number | null>(null);
  const lastSecondRef = useRef<number>(-1);

  useEffect(() => {
    if (!targetTime) {
      setTimeLeft(0);
      setIsExpired(false);
      return;
    }

    const updateTimer = () => {
      const target = new Date(targetTime).getTime();
      const now = Date.now();
      const diff = Math.max(0, Math.floor((target - now) / 1000));
      
      // Only update state if the second has changed
      if (diff !== lastSecondRef.current) {
        setTimeLeft(diff);
        lastSecondRef.current = diff;
        
        if (diff === 0 && !isExpired) {
          setIsExpired(true);
          onExpire?.();
        }
      }
      
      if (diff > 0) {
        animationFrameRef.current = requestAnimationFrame(updateTimer);
      }
    };

    // Initial call
    updateTimer();

    return () => {
      if (animationFrameRef.current) {
        cancelAnimationFrame(animationFrameRef.current);
      }
    };
  }, [targetTime, onExpire, isExpired]);

  const { hours, minutes, seconds } = formatLiveTimer(timeLeft);
  const urgencyColor = getUrgencyColor(timeLeft);
  getUrgencyBg(timeLeft); // Calculate for potential future use
  const isUrgent = timeLeft > 0 && timeLeft < 300; // Less than 5 minutes

  const sizeClasses = {
    sm: 'text-lg',
    md: 'text-2xl',
    lg: 'text-4xl',
    xl: 'text-6xl'
  };

  const labelClasses = {
    sm: 'text-xs',
    md: 'text-sm',
    lg: 'text-base',
    xl: 'text-lg'
  };

  if (isExpired) {
    return (
      <div className={`text-center ${className}`}>
        {label && <p className={`${labelClasses[size]} text-gray-400 mb-1`}>{label}</p>}
        <div className={`font-mono font-bold text-gray-500 ${sizeClasses[size]}`}>
          00:00
        </div>
      </div>
    );
  }

  return (
    <div className={`text-center ${className}`}>
      {label && (
        <p className={`${labelClasses[size]} text-gray-400 mb-1 ${isUrgent && pulseWhenUrgent ? 'animate-pulse' : ''}`}>
          {label}
        </p>
      )}
      
      <div className={`font-mono font-bold ${urgencyColor} ${sizeClasses[size]} ${isUrgent && pulseWhenUrgent ? 'animate-pulse' : ''}`}>
        {showSeconds ? (
          <span className="tabular-nums tracking-wider">
            {hours !== '00' && <span>{hours}:</span>}
            <span>{minutes}</span>
            <span className="text-opacity-80">:</span>
            <span>{seconds}</span>
          </span>
        ) : (
          <span className="tabular-nums">
            {hours !== '00' && <span>{parseInt(hours)}h </span>}
            <span>{minutes}m</span>
          </span>
        )}
      </div>
      
      {/* Progress bar for urgent timers */}
      {isUrgent && (
        <div className="mt-2 h-1 bg-gray-700 rounded-full overflow-hidden">
          <div 
            className={`h-full ${urgencyColor.replace('text-', 'bg-')} transition-all duration-1000`}
            style={{ width: `${(timeLeft / 300) * 100}%` }}
          />
        </div>
      )}
    </div>
  );
};

// Compact timer for prayer list items
interface CompactTimerProps {
  seconds: number;
  className?: string;
}

export const CompactTimer = ({ seconds, className = '' }: CompactTimerProps) => {
  const urgencyColor = getUrgencyColor(seconds);
  const hours = Math.floor(seconds / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  
  return (
    <div className={`text-right ${className}`}>
      <p className="text-xs text-gray-400">in</p>
      <p className={`font-mono text-sm tabular-nums ${urgencyColor}`}>
        {hours > 0 ? `${hours}h ${minutes.toString().padStart(2, '0')}m` : `${minutes}m`}
      </p>
    </div>
  );
};

// Iqama countdown badge
interface IqamaBadgeProps {
  seconds: number;
  className?: string;
}

export const IqamaBadge = ({ seconds, className = '' }: IqamaBadgeProps) => {
  if (seconds <= 0) {
    return (
      <span className={`inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-emerald-500/20 text-emerald-400 ${className}`}>
        Now
      </span>
    );
  }
  
  const hours = Math.floor(seconds / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  
  const urgencyClass = seconds < 300 
    ? 'bg-red-500/20 text-red-400 border border-red-500/30' 
    : seconds < 900 
      ? 'bg-orange-500/20 text-orange-400 border border-orange-500/30'
      : 'bg-emerald-500/20 text-emerald-400 border border-emerald-500/30';
  
  return (
    <span className={`inline-flex items-center px-2 py-0.5 rounded text-xs font-medium ${urgencyClass} ${className}`}>
      in {hours > 0 ? `${hours}h ` : ''}{minutes}m
    </span>
  );
};

// Timer hook for external use
export const usePreciseTimer = (targetTime: string | null) => {
  const [timeLeft, setTimeLeft] = useState<number>(0);
  const [isExpired, setIsExpired] = useState(false);
  const animationFrameRef = useRef<number | null>(null);

  useEffect(() => {
    if (!targetTime) {
      setTimeLeft(0);
      setIsExpired(false);
      return;
    }

    let lastSecond = -1;
    
    const updateTimer = () => {
      const target = new Date(targetTime).getTime();
      const now = Date.now();
      const diff = Math.max(0, Math.floor((target - now) / 1000));
      
      if (diff !== lastSecond) {
        setTimeLeft(diff);
        lastSecond = diff;
        
        if (diff === 0) {
          setIsExpired(true);
        }
      }
      
      if (diff > 0) {
        animationFrameRef.current = requestAnimationFrame(updateTimer);
      }
    };

    updateTimer();

    return () => {
      if (animationFrameRef.current) {
        cancelAnimationFrame(animationFrameRef.current);
      }
    };
  }, [targetTime]);

  return { timeLeft, isExpired, formatted: formatLiveTimer(timeLeft) };
};

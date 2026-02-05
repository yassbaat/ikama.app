import { useStore } from '../hooks/useStore';
import { AlertCircle, X } from 'lucide-react';

export const ErrorDisplay = () => {
  const { error, clearError } = useStore();

  if (!error) return null;

  return (
    <div className="fixed bottom-4 right-4 left-4 md:left-auto md:w-96 z-50 animate-slide-up">
      <div className="bg-red-900/90 border border-red-500/50 rounded-lg p-4 shadow-lg backdrop-blur-sm">
        <div className="flex items-start gap-3">
          <AlertCircle className="w-5 h-5 text-red-400 mt-0.5 flex-shrink-0" />
          <div className="flex-1">
            <p className="text-red-200 font-medium">Error</p>
            <p className="text-red-300 text-sm mt-1">{error}</p>
          </div>
          <button
            onClick={clearError}
            className="p-1 hover:bg-red-800 rounded transition-colors"
          >
            <X className="w-4 h-4 text-red-400" />
          </button>
        </div>
      </div>
    </div>
  );
};

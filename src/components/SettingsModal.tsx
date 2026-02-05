import { useState, useEffect } from 'react';
import * as tauri from '../services/tauri';
import { useStore } from '../hooks/useStore';
import { X, Check, AlertCircle, Moon } from 'lucide-react';
import type { ProviderInfo, ProviderTestResult } from '../types';

interface SettingsModalProps {
  isOpen: boolean;
  onClose: () => void;
}

export const SettingsModal = ({ isOpen, onClose }: SettingsModalProps) => {
  const { showNightPrayer, setShowNightPrayer } = useStore();
  const [providers, setProviders] = useState<ProviderInfo[]>([]);
  const [selectedProvider, setSelectedProvider] = useState<string>('');
  const [providerConfig, setProviderConfig] = useState<Record<string, string>>({});
  const [testResult, setTestResult] = useState<ProviderTestResult | null>(null);
  const [testing, setTesting] = useState(false);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    if (isOpen) {
      loadProviders();
    }
  }, [isOpen]);

  const loadProviders = async () => {
    try {
      const available = await tauri.getAvailableProviders();
      setProviders(available);
      if (available.length > 0 && !selectedProvider) {
        setSelectedProvider(available[0].id);
      }
    } catch (err) {
      console.error('Failed to load providers:', err);
    }
  };

  const handleTestConnection = async () => {
    if (!selectedProvider) return;

    setTesting(true);
    setTestResult(null);
    try {
      const config: Record<string, unknown> = {};
      Object.entries(providerConfig).forEach(([key, value]) => {
        // Try to parse numbers
        const numValue = Number(value);
        config[key] = !isNaN(numValue) && value !== '' ? numValue : value;
      });

      const result = await tauri.testProviderConnection(selectedProvider, config);
      setTestResult(result);
    } catch (err) {
      setTestResult({
        success: false,
        message: err instanceof Error ? err.message : 'Test failed',
      });
    } finally {
      setTesting(false);
    }
  };

  const handleSave = async () => {
    if (!selectedProvider) return;

    setSaving(true);
    try {
      const config: Record<string, unknown> = {};
      Object.entries(providerConfig).forEach(([key, value]) => {
        const numValue = Number(value);
        config[key] = !isNaN(numValue) && value !== '' ? numValue : value;
      });

      await tauri.saveProviderConfig({
        provider_id: selectedProvider,
        settings: config,
      });
      onClose();
    } catch (err) {
      console.error('Failed to save:', err);
    } finally {
      setSaving(false);
    }
  };

  const currentProvider = providers.find((p) => p.id === selectedProvider);

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50 backdrop-blur-sm">
      <div className="glass-card w-full max-w-lg max-h-[80vh] overflow-hidden flex flex-col">
        {/* Header */}
        <div className="flex items-center justify-between p-4 border-b border-gray-700/50">
          <h2 className="text-xl font-bold">Settings</h2>
          <button
            onClick={onClose}
            className="p-2 hover:bg-gray-700 rounded-lg transition-colors"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Content */}
        <div className="p-4 overflow-y-auto flex-1">
          {/* Prayer Preferences */}
          <div className="mb-6">
            <h3 className="text-sm font-semibold text-gray-300 mb-3 flex items-center gap-2">
              <Moon className="w-4 h-4" />
              Prayer Preferences
            </h3>
            
            {/* Night Prayer Toggle */}
            <div className="p-3 bg-indigo-900/10 border border-indigo-500/20 rounded-lg">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm font-medium text-indigo-200">Show Night Prayer Card</p>
                  <p className="text-xs text-indigo-300/60">
                    Display Tahajjud/Qiyam time after Isha
                  </p>
                </div>
                <button
                  onClick={() => setShowNightPrayer(!showNightPrayer)}
                  className={`relative inline-flex h-6 w-11 items-center rounded-full transition-colors ${
                    showNightPrayer ? 'bg-indigo-500' : 'bg-gray-600'
                  }`}
                >
                  <span
                    className={`inline-block h-4 w-4 transform rounded-full bg-white transition-transform ${
                      showNightPrayer ? 'translate-x-6' : 'translate-x-1'
                    }`}
                  />
                </button>
              </div>
            </div>
          </div>

          <div className="border-t border-gray-700/50 my-4" />

          {/* Provider selection */}
          <div className="mb-6">
            <label className="block text-sm font-medium text-gray-400 mb-2">
              Data Provider
            </label>
            <select
              value={selectedProvider}
              onChange={(e) => {
                setSelectedProvider(e.target.value);
                setProviderConfig({});
                setTestResult(null);
              }}
              className="input-field w-full"
            >
              {providers.map((provider) => (
                <option key={provider.id} value={provider.id}>
                  {provider.name}
                </option>
              ))}
            </select>
            {currentProvider && (
              <p className="text-sm text-gray-500 mt-1">
                {currentProvider.description}
              </p>
            )}
          </div>

          {/* Provider config fields */}
          {currentProvider?.config_schema.map((field) => (
            <div key={field.key} className="mb-4">
              <label className="block text-sm font-medium text-gray-400 mb-2">
                {field.label}
                {field.required && <span className="text-red-400 ml-1">*</span>}
              </label>
              {field.field_type === 'select' && field.options ? (
                <select
                  value={providerConfig[field.key] || field.default_value || ''}
                  onChange={(e) =>
                    setProviderConfig({ ...providerConfig, [field.key]: e.target.value })
                  }
                  className="input-field w-full"
                >
                  {field.options.map((opt) => (
                    <option key={opt} value={opt}>
                      {opt}
                    </option>
                  ))}
                </select>
              ) : (
                <input
                  type={field.field_type === 'password' ? 'password' : 'text'}
                  value={providerConfig[field.key] || ''}
                  onChange={(e) =>
                    setProviderConfig({ ...providerConfig, [field.key]: e.target.value })
                  }
                  placeholder={field.default_value || field.description}
                  className="input-field w-full"
                />
              )}
              {field.description && (
                <p className="text-xs text-gray-500 mt-1">{field.description}</p>
              )}
            </div>
          ))}

          {/* Test result */}
          {testResult && (
            <div
              className={`p-3 rounded-lg mb-4 ${
                testResult.success
                  ? 'bg-emerald-900/20 border border-emerald-500/30'
                  : 'bg-red-900/20 border border-red-500/30'
              }`}
            >
              <div className="flex items-start gap-2">
                {testResult.success ? (
                  <Check className="w-4 h-4 text-emerald-400 mt-0.5" />
                ) : (
                  <AlertCircle className="w-4 h-4 text-red-400 mt-0.5" />
                )}
                <div className="flex-1">
                  <p
                    className={`text-sm ${
                      testResult.success ? 'text-emerald-400' : 'text-red-400'
                    }`}
                  >
                    {testResult.success ? 'Connection successful' : 'Connection failed'}
                  </p>
                  <p className="text-xs text-gray-400 mt-1">{testResult.message}</p>
                  {testResult.latency_ms && (
                    <p className="text-xs text-gray-500 mt-1">
                      Latency: {testResult.latency_ms}ms
                    </p>
                  )}
                </div>
              </div>
            </div>
          )}
        </div>

        {/* Footer */}
        <div className="flex items-center justify-end gap-3 p-4 border-t border-gray-700/50">
          <button
            onClick={handleTestConnection}
            disabled={testing}
            className="btn-secondary"
          >
            {testing ? 'Testing...' : 'Test Connection'}
          </button>
          <button
            onClick={handleSave}
            disabled={saving}
            className="btn-primary"
          >
            {saving ? 'Saving...' : 'Save'}
          </button>
        </div>
      </div>
    </div>
  );
};

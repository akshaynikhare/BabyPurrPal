import React from 'react';
import { Volume2, VolumeX, X, Music } from 'lucide-react';
import { voiceEngine } from '../services/voiceMimic';

interface ParentalModalProps {
  isOpen: boolean;
  onClose: () => void;
  lullabyEnabled: boolean;
  onToggleLullaby: () => void;
  pitch: number;
  onChangePitch: (pitch: number) => void;
}

export const ParentalModal: React.FC<ParentalModalProps> = ({
  isOpen,
  onClose,
  lullabyEnabled,
  onToggleLullaby,
  pitch,
  onChangePitch,
}) => {
  if (!isOpen) return null;

  return (
    <div
      className="fixed inset-0 z-50 flex flex-col justify-end bg-slate-950/40 backdrop-blur-xs animate-in fade-in duration-150"
      onClick={onClose}
    >
      <div
        className="w-full max-w-lg mx-auto bg-white rounded-t-3xl p-6 shadow-2xl border-t border-slate-100 space-y-5 animate-in slide-in-from-bottom duration-200"
        onClick={(e) => e.stopPropagation()}
      >
        {/* Grab Handle */}
        <div className="w-10 h-1.5 bg-slate-300 rounded-full mx-auto" />

        {/* Header */}
        <div className="flex items-center justify-between">
          <h2 className="text-base font-bold text-slate-800">Sound Settings</h2>
          <button
            onClick={onClose}
            className="w-8 h-8 rounded-full bg-slate-100 hover:bg-slate-200 flex items-center justify-center text-slate-500 transition"
            aria-label="Close"
          >
            <X className="w-4 h-4" />
          </button>
        </div>

        {/* 1. Calming Lullaby Toggle */}
        <div className="flex items-center justify-between p-3.5 bg-amber-50/70 rounded-2xl border border-amber-100">
          <div className="flex items-center gap-3">
            <div className={`w-10 h-10 rounded-xl flex items-center justify-center ${
              lullabyEnabled ? 'bg-amber-500 text-white shadow-sm' : 'bg-slate-200 text-slate-500'
            }`}>
              {lullabyEnabled ? <Volume2 className="w-5 h-5" /> : <VolumeX className="w-5 h-5" />}
            </div>
            <div>
              <p className="text-sm font-semibold text-slate-800">Soothing Lullaby</p>
              <p className="text-xs text-slate-500">Gentle calming chords</p>
            </div>
          </div>

          <button
            onClick={onToggleLullaby}
            className={`px-4 py-2 text-xs font-bold rounded-xl transition ${
              lullabyEnabled
                ? 'bg-amber-500 text-white shadow-sm'
                : 'bg-slate-200 text-slate-700 hover:bg-slate-300'
            }`}
          >
            {lullabyEnabled ? 'ON' : 'OFF'}
          </button>
        </div>

        {/* 2. Voice Pitch Slider */}
        <div className="p-3.5 bg-slate-50 rounded-2xl border border-slate-100 space-y-2">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-1.5">
              <Music className="w-4 h-4 text-blue-500" />
              <span className="text-xs font-semibold text-slate-800">Talking Tom Voice Pitch</span>
            </div>
            <button
              onClick={() => voiceEngine.simulateTalkingTom()}
              className="text-[11px] font-bold text-blue-600 hover:underline"
            >
              Test Voice
            </button>
          </div>

          <input
            type="range"
            min="1.2"
            max="1.8"
            step="0.05"
            value={pitch}
            onChange={(e) => onChangePitch(parseFloat(e.target.value))}
            className="w-full h-2 bg-slate-200 rounded-lg appearance-none cursor-pointer accent-blue-600"
          />

          <div className="flex justify-between text-[11px] text-slate-500 font-medium">
            <span>Natural (1.2x)</span>
            <span className="font-bold text-blue-600">{pitch.toFixed(2)}x</span>
            <span>Cute High (1.8x)</span>
          </div>
        </div>

        {/* Done Button */}
        <button
          onClick={onClose}
          className="w-full py-3.5 bg-slate-900 text-white font-bold text-sm rounded-2xl shadow-md hover:bg-slate-800 transition active:scale-[0.99]"
        >
          Done
        </button>
      </div>
    </div>
  );
};

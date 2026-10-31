/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import React, { useState, useEffect, useRef, useCallback } from 'react';
import { motion, AnimatePresence } from 'motion/react';
import { CatCharacter, CatColorTheme } from './components/CatCharacter';
import { DogCharacter, DogColorTheme } from './components/DogCharacter';
import { RabbitCharacter, RabbitColorTheme } from './components/RabbitCharacter';
import { ParticleLayer } from './components/ParticleLayer';
import { ParentalModal } from './components/ParentalModal';
import { sound } from './services/soundEffects';
import { voiceEngine, VoiceState } from './services/voiceMimic';
import { haptics } from './services/haptics';
import {
  Mic,
  MicOff,
  Settings,
  Sparkles,
  Sun,
  Moon,
  Sunrise,
  Sunset,
  ZoomIn,
  ZoomOut,
} from 'lucide-react';

export type AnimalType = 'cat' | 'dog' | 'rabbit';
export type TimePhase = 'sunrise' | 'day' | 'sunset' | 'night';

const ANIMALS: AnimalType[] = ['cat', 'dog', 'rabbit'];

function getSystemTimePhase(): TimePhase {
  const hour = new Date().getHours();
  if (hour >= 5 && hour < 9) return 'sunrise';
  if (hour >= 9 && hour < 17) return 'day';
  if (hour >= 17 && hour < 20) return 'sunset';
  return 'night';
}

export default function App() {
  const [animalIndex, setAnimalIndex] = useState<number>(0);
  const [walkDirection, setWalkDirection] = useState<'next' | 'prev'>('next');
  const [isWalkingIn, setIsWalkingIn] = useState<boolean>(false);

  // Pinch-to-zoom face close-up state
  const [isFaceZoomed, setIsFaceZoomed] = useState<boolean>(false);
  const initialPinchDistRef = useRef<number | null>(null);

  // Time-aware ambient background phase
  const [timePhase, setTimePhase] = useState<TimePhase>(getSystemTimePhase);

  // Talking Tom states
  const [voiceState, setVoiceState] = useState<VoiceState>('IDLE');
  const [mouthAmplitude, setMouthAmplitude] = useState<number>(0);
  const [, setInputVolume] = useState<number>(0);

  // Animal emotional reaction states
  const [isPurring, setIsPurring] = useState<boolean>(false);
  const [isTickled, setIsTickled] = useState<boolean>(false);
  const [isHappy, setIsHappy] = useState<boolean>(false);

  // Themes
  const [catTheme] = useState<CatColorTheme>('midnight');
  const [dogTheme] = useState<DogColorTheme>('golden');
  const [rabbitTheme] = useState<RabbitColorTheme>('white');

  // Audio settings (Lullaby toggled via settings)
  const [lullabyEnabled, setLullabyEnabled] = useState<boolean>(false);
  const [voicePitch, setVoicePitch] = useState<number>(1.45);
  const [sensitivity] = useState<'low' | 'normal' | 'high'>('normal');

  // Particles
  const [lastTouch, setLastTouch] = useState<{
    x: number;
    y: number;
    type?: 'star' | 'heart' | 'bubble' | 'sparkle' | 'paw';
    count?: number;
  } | null>(null);

  // Audio activation state
  const [hasStartedAudio, setHasStartedAudio] = useState<boolean>(false);

  // Parental lock hold timer (3 seconds hold)
  const [isParentOpen, setIsParentOpen] = useState<boolean>(false);
  const [holdProgress, setHoldProgress] = useState<number>(0);
  const holdTimerRef = useRef<number | null>(null);
  const holdStartRef = useRef<number>(0);

  // Pentatonic chime index
  const chimeIndexRef = useRef<number>(0);

  // Touch swipe gesture refs
  const swipeStartRef = useRef<{ x: number; y: number; time: number } | null>(null);

  const activeAnimal = ANIMALS[animalIndex];

  // Auto-update time phase based on real clock
  useEffect(() => {
    const timer = setInterval(() => {
      setTimePhase(getSystemTimePhase());
    }, 60000);
    return () => clearInterval(timer);
  }, []);

  // Initialize voice callbacks
  useEffect(() => {
    voiceEngine.setCallbacks({
      onStateChange: (state) => setVoiceState(state),
      onVolumeChange: (vol) => setInputVolume(vol),
      onMouthAmplitude: (amp) => setMouthAmplitude(amp),
    });
  }, []);

  // Sync settings
  useEffect(() => {
    voiceEngine.setPitch(voicePitch);
  }, [voicePitch]);

  useEffect(() => {
    voiceEngine.setSensitivity(sensitivity);
  }, [sensitivity]);

  // Activate audio and microphone
  const handleStartAudio = async () => {
    sound.init();
    setHasStartedAudio(true);
    await voiceEngine.start();
    sound.playChime(3);
  };

  // Switch animal with slow walk-in animation
  const switchAnimal = useCallback((direction: 'next' | 'prev') => {
    sound.init();
    setWalkDirection(direction);
    setIsWalkingIn(true);
    setIsFaceZoomed(false); // Reset face zoom when switching animals

    // Play footstep sounds and subtle tactile vibration during walk
    sound.playFootstep();
    haptics.step();
    setTimeout(() => {
      sound.playFootstep();
      haptics.step();
    }, 300);
    setTimeout(() => {
      sound.playFootstep();
      haptics.step();
    }, 650);

    setAnimalIndex((prev) => {
      if (direction === 'next') {
        return (prev + 1) % ANIMALS.length;
      } else {
        return (prev - 1 + ANIMALS.length) % ANIMALS.length;
      }
    });

    // Walk duration ~1.1s, then animal stops in center and greets
    setTimeout(() => {
      setIsWalkingIn(false);
      const nextAnimal = direction === 'next' 
        ? ANIMALS[(animalIndex + 1) % ANIMALS.length]
        : ANIMALS[(animalIndex - 1 + ANIMALS.length) % ANIMALS.length];

      if (nextAnimal === 'cat') {
        sound.startPurr();
        haptics.purr();
        setIsPurring(true);
        setTimeout(() => {
          sound.stopPurr();
          setIsPurring(false);
        }, 1200);
      } else if (nextAnimal === 'dog') {
        sound.playPuppyWoof();
        haptics.bounce();
        setIsHappy(true);
        setTimeout(() => setIsHappy(false), 1200);
      } else {
        sound.playBunnySqueak();
        haptics.bounce();
        setIsHappy(true);
        setTimeout(() => setIsHappy(false), 1200);
      }
    }, 1100);
  }, [animalIndex]);

  // Cycle time phase manually if parent clicks ambient badge
  const cycleTimePhase = (e: React.MouseEvent) => {
    e.stopPropagation();
    const phases: TimePhase[] = ['sunrise', 'day', 'sunset', 'night'];
    const nextIdx = (phases.indexOf(timePhase) + 1) % phases.length;
    setTimePhase(phases[nextIdx]);
    sound.playTwinkle();
    haptics.twinkle();
  };

  // Toggle face zoom manually or via pinch
  const toggleFaceZoom = (e?: React.MouseEvent) => {
    if (e) e.stopPropagation();
    setIsFaceZoomed((prev) => {
      const next = !prev;
      if (next) {
        haptics.bounce();
        sound.playTwinkle();
      } else {
        haptics.tap();
      }
      return next;
    });
  };

  // Multi-touch pinch gesture detection for zooming in/out on the face
  const handleTouchStart = (e: React.TouchEvent) => {
    if (e.touches.length === 2) {
      const t1 = e.touches[0];
      const t2 = e.touches[1];
      initialPinchDistRef.current = Math.hypot(t1.clientX - t2.clientX, t1.clientY - t2.clientY);
    }
  };

  const handleTouchMove = (e: React.TouchEvent) => {
    if (e.touches.length === 2 && initialPinchDistRef.current !== null) {
      const t1 = e.touches[0];
      const t2 = e.touches[1];
      const currentDist = Math.hypot(t1.clientX - t2.clientX, t1.clientY - t2.clientY);
      const ratio = currentDist / initialPinchDistRef.current;

      // Pinch outward (> 1.22x) -> Zoom into face
      if (ratio > 1.22 && !isFaceZoomed) {
        setIsFaceZoomed(true);
        haptics.bounce();
        sound.playTwinkle();
        initialPinchDistRef.current = currentDist;
      }
      // Pinch inward (< 0.82x) -> Zoom out to full body
      else if (ratio < 0.82 && isFaceZoomed) {
        setIsFaceZoomed(false);
        haptics.tap();
        initialPinchDistRef.current = currentDist;
      }
    }
  };

  const handleTouchEnd = (e: React.TouchEvent) => {
    if (e.touches.length < 2) {
      initialPinchDistRef.current = null;
    }
  };

  // Global Pointer Events for Swipe Gesture & Touches
  const handlePointerDown = (e: React.PointerEvent) => {
    sound.init();
    if (!hasStartedAudio) {
      setHasStartedAudio(true);
      voiceEngine.start();
    }

    // Gentle micro-tactile tick on screen touch
    haptics.tap();

    swipeStartRef.current = {
      x: e.clientX,
      y: e.clientY,
      time: Date.now(),
    };

    // Soft chime on background touch
    const noteIdx = chimeIndexRef.current++;
    sound.playChime(noteIdx);
    setLastTouch({
      x: e.clientX,
      y: e.clientY,
      type: noteIdx % 2 === 0 ? 'bubble' : 'sparkle',
      count: 4,
    });
  };

  const handlePointerUp = (e: React.PointerEvent) => {
    if (!swipeStartRef.current) return;

    const dx = e.clientX - swipeStartRef.current.x;
    const dy = e.clientY - swipeStartRef.current.y;
    const dt = Date.now() - swipeStartRef.current.time;

    swipeStartRef.current = null;

    // Minimum swipe threshold: 45px and mostly horizontal
    if (Math.abs(dx) > 45 && Math.abs(dx) > Math.abs(dy) * 1.2 && dt < 800) {
      if (dx < 0) {
        switchAnimal('next');
      } else {
        switchAnimal('prev');
      }
    }
  };

  // Specific Animal Touch Zone Handlers
  const handleZoneTouch = useCallback((zone: 'ears' | 'cheeks' | 'mouth' | 'belly' | 'leftPaw' | 'rightPaw', e: React.PointerEvent) => {
    sound.init();
    const x = e.clientX;
    const y = e.clientY;

    if (activeAnimal === 'cat') {
      switch (zone) {
        case 'belly':
          setIsTickled(true);
          sound.playGiggle();
          haptics.tickle();
          setLastTouch({ x, y, type: 'bubble', count: 8 });
          setTimeout(() => setIsTickled(false), 600);
          break;
        case 'ears':
          setIsPurring(true);
          sound.startPurr();
          sound.playTwinkle();
          haptics.purr();
          setLastTouch({ x, y, type: 'heart', count: 7 });
          setTimeout(() => {
            sound.stopPurr();
            setIsPurring(false);
          }, 1600);
          break;
        case 'cheeks':
          sound.playTwinkle();
          haptics.twinkle();
          setLastTouch({ x, y, type: 'sparkle', count: 6 });
          break;
        case 'leftPaw':
        case 'rightPaw':
          sound.playPawTap();
          haptics.paw();
          setLastTouch({ x, y, type: 'paw', count: 5 });
          break;
        case 'mouth':
          haptics.bounce();
          if (voiceState === 'IDLE') {
            voiceEngine.simulateTalkingTom();
            setLastTouch({ x, y, type: 'star', count: 6 });
          }
          break;
      }
    } else if (activeAnimal === 'dog') {
      switch (zone) {
        case 'belly':
          setIsTickled(true);
          sound.playGiggle();
          sound.playPuppyPant();
          haptics.tickle();
          setLastTouch({ x, y, type: 'bubble', count: 8 });
          setTimeout(() => setIsTickled(false), 600);
          break;
        case 'ears':
          setIsHappy(true);
          sound.playPuppyPant();
          haptics.bounce();
          setLastTouch({ x, y, type: 'heart', count: 7 });
          setTimeout(() => setIsHappy(false), 1400);
          break;
        case 'cheeks':
        case 'mouth':
          sound.playPuppyWoof();
          haptics.bounce();
          if (voiceState === 'IDLE') {
            voiceEngine.simulateTalkingTom();
          }
          setLastTouch({ x, y, type: 'star', count: 6 });
          break;
        case 'leftPaw':
        case 'rightPaw':
          sound.playPawTap();
          haptics.paw();
          setLastTouch({ x, y, type: 'paw', count: 5 });
          break;
      }
    } else {
      // Rabbit
      switch (zone) {
        case 'belly':
          setIsTickled(true);
          sound.playGiggle();
          haptics.tickle();
          setLastTouch({ x, y, type: 'bubble', count: 8 });
          setTimeout(() => setIsTickled(false), 600);
          break;
        case 'ears':
          setIsHappy(true);
          sound.playBunnySqueak();
          haptics.bounce();
          setLastTouch({ x, y, type: 'heart', count: 7 });
          setTimeout(() => setIsHappy(false), 1200);
          break;
        case 'cheeks':
          sound.playTwinkle();
          haptics.twinkle();
          setLastTouch({ x, y, type: 'sparkle', count: 6 });
          break;
        case 'mouth':
          sound.playCarrotCrunch();
          haptics.feed();
          if (voiceState === 'IDLE') {
            voiceEngine.simulateTalkingTom();
          }
          setLastTouch({ x, y, type: 'star', count: 6 });
          break;
        case 'leftPaw':
        case 'rightPaw':
          sound.playPawTap();
          haptics.paw();
          setLastTouch({ x, y, type: 'paw', count: 5 });
          break;
      }
    }
  }, [activeAnimal, voiceState]);

  // Bottom interactive toys per animal
  const handleFeedToy = (toyName: string) => (e: React.PointerEvent) => {
    e.stopPropagation();
    sound.init();
    haptics.feed();
    const rect = (e.currentTarget as HTMLElement).getBoundingClientRect();
    const x = rect.left + rect.width / 2;
    const y = rect.top + rect.height / 2;

    if (activeAnimal === 'cat') {
      if (toyName === 'milk') {
        sound.startPurr();
        setIsPurring(true);
        setLastTouch({ x, y, type: 'heart', count: 8 });
        setTimeout(() => {
          sound.stopPurr();
          setIsPurring(false);
        }, 1500);
      } else if (toyName === 'fish') {
        sound.playPawTap();
        setIsTickled(true);
        setLastTouch({ x, y, type: 'star', count: 8 });
        setTimeout(() => setIsTickled(false), 500);
      } else {
        sound.playGiggle();
        setIsTickled(true);
        setLastTouch({ x, y, type: 'bubble', count: 10 });
        setTimeout(() => setIsTickled(false), 500);
      }
    } else if (activeAnimal === 'dog') {
      if (toyName === 'bone') {
        sound.playPawTap();
        sound.playPuppyWoof();
        setIsHappy(true);
        setLastTouch({ x, y, type: 'star', count: 8 });
        setTimeout(() => setIsHappy(false), 1000);
      } else if (toyName === 'ball') {
        sound.playGiggle();
        setIsTickled(true);
        setLastTouch({ x, y, type: 'bubble', count: 9 });
        setTimeout(() => setIsTickled(false), 500);
      } else {
        sound.playPuppyPant();
        setIsHappy(true);
        setLastTouch({ x, y, type: 'heart', count: 7 });
        setTimeout(() => setIsHappy(false), 1200);
      }
    } else {
      // Rabbit
      if (toyName === 'carrot') {
        sound.playCarrotCrunch();
        setIsHappy(true);
        setLastTouch({ x, y, type: 'star', count: 8 });
        setTimeout(() => setIsHappy(false), 1000);
      } else if (toyName === 'clover') {
        sound.playBunnySqueak();
        setIsHappy(true);
        setLastTouch({ x, y, type: 'heart', count: 8 });
        setTimeout(() => setIsHappy(false), 1000);
      } else {
        sound.playTwinkle();
        setIsTickled(true);
        setLastTouch({ x, y, type: 'bubble', count: 9 });
        setTimeout(() => setIsTickled(false), 500);
      }
    }
  };

  // Parental lock hold (3s)
  const handleParentPointerDown = (e: React.PointerEvent) => {
    e.stopPropagation();
    holdStartRef.current = Date.now();
    setHoldProgress(0);

    const updateHold = () => {
      const elapsed = Date.now() - holdStartRef.current;
      const progress = Math.min(100, (elapsed / 2500) * 100);
      setHoldProgress(progress);

      if (progress >= 100) {
        setIsParentOpen(true);
        setHoldProgress(0);
        sound.playTwinkle();
        haptics.twinkle();
      } else {
        holdTimerRef.current = window.requestAnimationFrame(updateHold);
      }
    };

    holdTimerRef.current = window.requestAnimationFrame(updateHold);
  };

  const handleParentPointerUp = (e: React.PointerEvent) => {
    e.stopPropagation();
    if (holdTimerRef.current) {
      window.cancelAnimationFrame(holdTimerRef.current);
      holdTimerRef.current = null;
    }
    if (holdProgress < 90) {
      sound.playChime(4);
      haptics.tap();
    }
    setHoldProgress(0);
  };

  const toggleLullabyState = () => {
    const next = sound.toggleLullaby();
    setLullabyEnabled(next);
  };

  // Time Phase visual configurations
  const themeConfig = {
    sunrise: {
      gradient: 'from-[#FFF0E6] via-[#FFF8EE] to-[#FFE5D9]',
      glow: 'bg-orange-300/30',
      pillBg: 'bg-white/90 text-slate-800 border-orange-200/60 shadow-sm',
      btnBg: 'bg-white/90 text-slate-600 border-orange-100/80 hover:bg-orange-50',
      sideArrowBg: 'bg-white/80 text-slate-600 border-orange-100/80',
      toyBg: 'bg-white/90 text-slate-800 border-orange-100/80 shadow-md',
      toyText: 'text-slate-700',
      tag: 'Sunrise',
      isDark: false,
    },
    day: {
      gradient: 'from-[#EDF6FF] via-[#FFFDF7] to-[#F1F5F9]',
      glow: 'bg-amber-200/25',
      pillBg: 'bg-white/90 text-slate-800 border-amber-100/80 shadow-sm',
      btnBg: 'bg-white/90 text-slate-600 border-slate-200/80 hover:bg-slate-50',
      sideArrowBg: 'bg-white/80 text-slate-500 border-amber-100/80',
      toyBg: 'bg-white/90 text-slate-800 border-amber-100/80 shadow-md',
      toyText: 'text-slate-700',
      tag: 'Daylight',
      isDark: false,
    },
    sunset: {
      gradient: 'from-[#FFE8D6] via-[#F3E8EE] to-[#E3D5EE]',
      glow: 'bg-rose-300/30',
      pillBg: 'bg-white/90 text-slate-800 border-pink-200/60 shadow-sm',
      btnBg: 'bg-white/90 text-slate-600 border-pink-100/80 hover:bg-pink-50',
      sideArrowBg: 'bg-white/80 text-slate-600 border-pink-100/80',
      toyBg: 'bg-white/90 text-slate-800 border-pink-100/80 shadow-md',
      toyText: 'text-slate-700',
      tag: 'Sunset',
      isDark: false,
    },
    night: {
      gradient: 'from-[#0B132B] via-[#1C2541] to-[#0A0E21]',
      glow: 'bg-indigo-600/30',
      pillBg: 'bg-slate-900/85 text-slate-100 border-slate-700/80 shadow-lg',
      btnBg: 'bg-slate-900/85 text-slate-200 border-slate-700/80 hover:bg-slate-800',
      sideArrowBg: 'bg-slate-900/80 text-slate-300 border-slate-800',
      toyBg: 'bg-slate-900/85 text-slate-100 border-slate-700/80 shadow-lg',
      toyText: 'text-slate-200',
      tag: 'Night',
      isDark: true,
    },
  }[timePhase];

  return (
    <main
      className={`relative w-screen h-screen overflow-hidden bg-gradient-to-b ${themeConfig.gradient} transition-colors duration-1000 select-none flex flex-col items-center justify-between`}
      onPointerDown={handlePointerDown}
      onPointerUp={handlePointerUp}
      onTouchStart={handleTouchStart}
      onTouchMove={handleTouchMove}
      onTouchEnd={handleTouchEnd}
      style={{ touchAction: 'none' }}
    >
      {/* Night Sky Gentle Stars */}
      {timePhase === 'night' && (
        <div className="absolute inset-0 pointer-events-none overflow-hidden z-10 opacity-75">
          <div className="absolute top-12 left-16 w-1.5 h-1.5 bg-white rounded-full animate-pulse" />
          <div className="absolute top-24 right-20 w-1 h-1 bg-white rounded-full animate-pulse" style={{ animationDelay: '1s' }} />
          <div className="absolute top-36 left-1/3 w-1.5 h-1.5 bg-amber-200 rounded-full animate-pulse" style={{ animationDelay: '2s' }} />
          <div className="absolute top-48 right-1/4 w-1 h-1 bg-white rounded-full animate-pulse" style={{ animationDelay: '1.5s' }} />
          <div className="absolute top-20 right-1/2 w-1.5 h-1.5 bg-blue-200 rounded-full animate-pulse" style={{ animationDelay: '0.5s' }} />
          <div className="absolute top-64 left-12 w-1 h-1 bg-white rounded-full animate-pulse" style={{ animationDelay: '2.5s' }} />
          <div className="absolute top-72 right-12 w-1 h-1 bg-amber-100 rounded-full animate-pulse" style={{ animationDelay: '3s' }} />
        </div>
      )}

      {/* Particle Reinforcement Layer */}
      <ParticleLayer lastTouch={lastTouch} />

      {/* TOP BAR / PARENTAL CONTROLS */}
      <header className="relative z-40 w-full max-w-lg px-6 pt-5 pb-2 flex items-center justify-between select-none pointer-events-none">
        {/* Animal Indicator & Voice State */}
        <div className={`pointer-events-auto flex items-center gap-2 px-3.5 py-1.5 rounded-full backdrop-blur-md transition-colors duration-500 ${themeConfig.pillBg}`}>
          {voiceState === 'LISTENING' ? (
            <span className="flex items-center gap-1.5 text-xs font-bold text-amber-500">
              <span className="w-2.5 h-2.5 rounded-full bg-amber-500 animate-ping" />
              Listening! 👂
            </span>
          ) : voiceState === 'MIMICKING' ? (
            <span className="flex items-center gap-1.5 text-xs font-bold text-blue-400">
              <span className="w-2.5 h-2.5 rounded-full bg-blue-400 animate-bounce" />
              Repeating! 🗣️
            </span>
          ) : (
            <div className="flex items-center gap-1.5 text-xs font-bold">
              <Sparkles className="w-4 h-4 text-amber-400" />
              <span>
                {activeAnimal === 'cat' ? 'Kitty Cat 🐱' : activeAnimal === 'dog' ? 'Puppy Dog 🐶' : 'Bunny Rabbit 🐰'}
              </span>
            </div>
          )}
        </div>

        {/* Ambient Time Atmosphere, Face Zoom Toggle & Settings */}
        <div className="pointer-events-auto flex items-center gap-2">
          {/* Time-of-Day Ambient Atmosphere Button */}
          <button
            onClick={cycleTimePhase}
            className={`px-2.5 py-2 rounded-2xl flex items-center gap-1.5 text-xs font-bold transition shadow-sm ${themeConfig.btnBg}`}
            title="Ambient Atmosphere (Sunrise / Day / Sunset / Night)"
            aria-label="Toggle ambient atmosphere"
          >
            {timePhase === 'sunrise' && <Sunrise className="w-4 h-4 text-orange-500" />}
            {timePhase === 'day' && <Sun className="w-4 h-4 text-amber-500" />}
            {timePhase === 'sunset' && <Sunset className="w-4 h-4 text-pink-500" />}
            {timePhase === 'night' && <Moon className="w-4 h-4 text-indigo-300" />}
            <span className="text-[11px] font-semibold">{themeConfig.tag}</span>
          </button>

          {/* Face Zoom Button (Supports both touch pinch and 1-tap zoom) */}
          <button
            onClick={toggleFaceZoom}
            className={`w-11 h-11 rounded-2xl flex items-center justify-center transition shadow-sm ${
              isFaceZoomed
                ? 'bg-blue-600 text-white shadow-blue-200'
                : `${themeConfig.btnBg}`
            }`}
            title="Zoom on Pet Face (Pinch gesture or Tap)"
            aria-label="Zoom on Face"
          >
            {isFaceZoomed ? <ZoomOut className="w-5 h-5" /> : <ZoomIn className="w-5 h-5" />}
          </button>

          {/* Parental 3s Hold */}
          <button
            onPointerDown={handleParentPointerDown}
            onPointerUp={handleParentPointerUp}
            onPointerLeave={handleParentPointerUp}
            className={`relative w-11 h-11 rounded-2xl ${themeConfig.btnBg} flex items-center justify-center shadow-sm active:scale-95 transition`}
            title="Hold 3s for Settings"
            aria-label="Hold 3 seconds for Settings"
          >
            <Settings className="w-5 h-5" />
            {holdProgress > 0 && (
              <svg className="absolute inset-0 w-full h-full -rotate-90 pointer-events-none">
                <circle
                  cx="22"
                  cy="22"
                  r="19"
                  fill="none"
                  stroke="#3B82F6"
                  strokeWidth="3.5"
                  strokeDasharray="120"
                  strokeDashoffset={120 - (holdProgress / 100) * 120}
                  strokeLinecap="round"
                />
              </svg>
            )}
          </button>
        </div>
      </header>


      {/* CENTRAL STAGE (WITH PINCH-TO-ZOOM ON FACE) */}
      <section className="relative flex-1 w-full flex flex-col items-center justify-center px-4 z-20 overflow-visible">
        {/* Ambient Stage Glow */}
        <div className={`absolute w-[360px] h-[360px] rounded-full ${themeConfig.glow} blur-2xl pointer-events-none -z-10 transition-colors duration-1000`} />

        <div className="relative w-full max-w-[420px] aspect-[4/5] flex items-center justify-center overflow-visible">
          {/* Animated Zoom Wrapper focused directly on the Pet's Face */}
          <motion.div
            animate={{
              scale: isFaceZoomed ? 1.85 : 1,
              y: isFaceZoomed ? 52 : 0,
            }}
            transition={{
              type: 'spring',
              stiffness: 240,
              damping: 24,
            }}
            style={{
              transformOrigin: '50% 36%',
            }}
            className="w-full h-full flex items-center justify-center overflow-visible"
          >
            <AnimatePresence mode="wait">
              <motion.div
                key={activeAnimal}
                initial={{
                  x: walkDirection === 'next' ? 260 : -260,
                  opacity: 0.1,
                }}
                animate={{
                  x: 0,
                  opacity: 1,
                }}
                exit={{
                  x: walkDirection === 'next' ? -260 : 260,
                  opacity: 0,
                }}
                transition={{
                  duration: 1.1,
                  ease: [0.25, 0.1, 0.25, 1],
                }}
                className="w-full h-full flex items-center justify-center"
              >
                {activeAnimal === 'cat' && (
                  <CatCharacter
                    voiceState={voiceState}
                    mouthAmplitude={mouthAmplitude}
                    isPurring={isPurring}
                    isTickled={isTickled}
                    isWalking={isWalkingIn}
                    theme={catTheme}
                    onTouchZone={handleZoneTouch}
                  />
                )}

                {activeAnimal === 'dog' && (
                  <DogCharacter
                    voiceState={voiceState}
                    mouthAmplitude={mouthAmplitude}
                    isHappy={isHappy}
                    isTickled={isTickled}
                    isWalking={isWalkingIn}
                    theme={dogTheme}
                    onTouchZone={handleZoneTouch}
                  />
                )}

                {activeAnimal === 'rabbit' && (
                  <RabbitCharacter
                    voiceState={voiceState}
                    mouthAmplitude={mouthAmplitude}
                    isHappy={isHappy}
                    isTickled={isTickled}
                    isWalking={isWalkingIn}
                    theme={rabbitTheme}
                    onTouchZone={handleZoneTouch}
                  />
                )}
              </motion.div>
            </AnimatePresence>
          </motion.div>
        </div>

        {/* When zoomed in on face, provide friendly reset indicator */}
        {isFaceZoomed && (
          <button
            onClick={toggleFaceZoom}
            className={`mt-2 pointer-events-auto px-4 py-1.5 rounded-full text-xs font-bold shadow-md transition active:scale-95 flex items-center gap-1.5 animate-in fade-in ${themeConfig.pillBg}`}
          >
            <ZoomOut className="w-3.5 h-3.5 text-blue-500" />
            <span>Face Close-Up (Pinch or Tap to Reset)</span>
          </button>
        )}

        {/* Audio Start Button */}
        {!hasStartedAudio && (
          <div className="mt-2 pointer-events-auto">
            <button
              onClick={(e) => {
                e.stopPropagation();
                handleStartAudio();
              }}
              className="px-6 py-3.5 rounded-full bg-slate-900 text-white font-bold text-sm shadow-xl hover:bg-slate-800 transition active:scale-95 flex items-center gap-2.5 animate-pulse"
            >
              <Mic className="w-5 h-5 text-amber-400" />
              Tap to Enable Sound & Talking Pet
            </button>
          </div>
        )}

        {/* Fallback info when mic is blocked */}
        {voiceState === 'PERMISSION_REQUIRED' && (
          <div className={`mt-2 pointer-events-auto flex items-center gap-2 backdrop-blur-md px-4 py-2 rounded-full border shadow-sm text-xs ${themeConfig.pillBg}`}>
            <MicOff className="w-4 h-4 text-rose-500" />
            <span>Tap pet's mouth or toys below to hear speech!</span>
          </div>
        )}
      </section>

      {/* BOTTOM TOY TRAY */}
      <footer className="relative z-40 w-full max-w-md px-6 pb-6 pt-2 flex items-center justify-around pointer-events-auto select-none">
        {activeAnimal === 'cat' && (
          <>
            <button
              onPointerDown={handleFeedToy('milk')}
              className={`flex flex-col items-center gap-1.5 p-3 rounded-2xl ${themeConfig.toyBg} active:scale-90 transition`}
              aria-label="Feed warm milk"
            >
              <span className="text-2xl">🥛</span>
              <span className={`text-[11px] font-bold ${themeConfig.toyText}`}>Warm Milk</span>
            </button>
            <button
              onPointerDown={handleFeedToy('fish')}
              className={`flex flex-col items-center gap-1.5 p-3 rounded-2xl ${themeConfig.toyBg} active:scale-90 transition`}
              aria-label="Give fish snack"
            >
              <span className="text-2xl">🐟</span>
              <span className={`text-[11px] font-bold ${themeConfig.toyText}`}>Fish Snack</span>
            </button>
            <button
              onPointerDown={handleFeedToy('yarn')}
              className={`flex flex-col items-center gap-1.5 p-3 rounded-2xl ${themeConfig.toyBg} active:scale-90 transition`}
              aria-label="Play with yarn"
            >
              <span className="text-2xl">🧶</span>
              <span className={`text-[11px] font-bold ${themeConfig.toyText}`}>Yarn Ball</span>
            </button>
          </>
        )}

        {activeAnimal === 'dog' && (
          <>
            <button
              onPointerDown={handleFeedToy('bone')}
              className={`flex flex-col items-center gap-1.5 p-3 rounded-2xl ${themeConfig.toyBg} active:scale-90 transition`}
              aria-label="Give juicy bone"
            >
              <span className="text-2xl">🦴</span>
              <span className={`text-[11px] font-bold ${themeConfig.toyText}`}>Juicy Bone</span>
            </button>
            <button
              onPointerDown={handleFeedToy('ball')}
              className={`flex flex-col items-center gap-1.5 p-3 rounded-2xl ${themeConfig.toyBg} active:scale-90 transition`}
              aria-label="Throw tennis ball"
            >
              <span className="text-2xl">🎾</span>
              <span className={`text-[11px] font-bold ${themeConfig.toyText}`}>Tennis Ball</span>
            </button>
            <button
              onPointerDown={handleFeedToy('water')}
              className={`flex flex-col items-center gap-1.5 p-3 rounded-2xl ${themeConfig.toyBg} active:scale-90 transition`}
              aria-label="Fresh water bowl"
            >
              <span className="text-2xl">💧</span>
              <span className={`text-[11px] font-bold ${themeConfig.toyText}`}>Fresh Water</span>
            </button>
          </>
        )}

        {activeAnimal === 'rabbit' && (
          <>
            <button
              onPointerDown={handleFeedToy('carrot')}
              className={`flex flex-col items-center gap-1.5 p-3 rounded-2xl ${themeConfig.toyBg} active:scale-90 transition`}
              aria-label="Crunchy carrot"
            >
              <span className="text-2xl">🥕</span>
              <span className={`text-[11px] font-bold ${themeConfig.toyText}`}>Crunchy Carrot</span>
            </button>
            <button
              onPointerDown={handleFeedToy('clover')}
              className={`flex flex-col items-center gap-1.5 p-3 rounded-2xl ${themeConfig.toyBg} active:scale-90 transition`}
              aria-label="Lucky clover"
            >
              <span className="text-2xl">🍀</span>
              <span className={`text-[11px] font-bold ${themeConfig.toyText}`}>Sweet Clover</span>
            </button>
            <button
              onPointerDown={handleFeedToy('bell')}
              className={`flex flex-col items-center gap-1.5 p-3 rounded-2xl ${themeConfig.toyBg} active:scale-90 transition`}
              aria-label="Silver bell"
            >
              <span className="text-2xl">🔔</span>
              <span className={`text-[11px] font-bold ${themeConfig.toyText}`}>Silver Bell</span>
            </button>
          </>
        )}
      </footer>

      {/* PARENTAL SETTINGS MODAL */}
      <ParentalModal
        isOpen={isParentOpen}
        onClose={() => setIsParentOpen(false)}
        lullabyEnabled={lullabyEnabled}
        onToggleLullaby={toggleLullabyState}
        pitch={voicePitch}
        onChangePitch={setVoicePitch}
      />
    </main>
  );
}

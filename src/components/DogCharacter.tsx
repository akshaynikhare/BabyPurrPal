import React, { useState, useEffect } from 'react';
import { motion } from 'motion/react';
import { VoiceState } from '../services/voiceMimic';

export type DogColorTheme = 'golden' | 'chocolate' | 'spotted';

interface DogCharacterProps {
  voiceState: VoiceState;
  mouthAmplitude: number;
  isHappy: boolean;
  isTickled: boolean;
  isWalking?: boolean;
  theme: DogColorTheme;
  onTouchZone: (zone: 'ears' | 'cheeks' | 'mouth' | 'belly' | 'leftPaw' | 'rightPaw', e: React.PointerEvent) => void;
}

export const DogCharacter: React.FC<DogCharacterProps> = ({
  voiceState,
  mouthAmplitude,
  isHappy,
  isTickled,
  isWalking = false,
  theme,
  onTouchZone,
}) => {
  const [blink, setBlink] = useState(false);
  const [pawLeftRaised, setPawLeftRaised] = useState(false);
  const [pawRightRaised, setPawRightRaised] = useState(false);

  useEffect(() => {
    const blinkInterval = setInterval(() => {
      setBlink(true);
      setTimeout(() => setBlink(false), 200);
    }, 3600);
    return () => clearInterval(blinkInterval);
  }, []);

  const themeData = {
    golden: {
      bodyPrimary: '#F59E0B',
      bodyHighlight: '#FCD34D',
      bodyShadow: '#B45309',
      bodyStroke: '#78350F',
      ears: '#D97706',
      earsHighlight: '#FBBF24',
      bellyTop: '#FEF3C7',
      bellyBottom: '#FDE68A',
      snoutTop: '#FFFBEB',
      snoutBottom: '#FEF3C7',
      nose: '#1E202B',
      irisOuter: '#78350F',
      irisInner: '#B45309',
      irisGlow: '#FDE68A',
      pupil: '#11131E',
      pawPad: '#F87171',
      pawPadHighlight: '#FECACA',
      collar: '#EF4444',
      medallion: '#FBBF24',
      shadow: 'rgba(180, 83, 9, 0.28)',
    },
    chocolate: {
      bodyPrimary: '#78350F',
      bodyHighlight: '#92400E',
      bodyShadow: '#451A03',
      bodyStroke: '#2D1302',
      ears: '#582405',
      earsHighlight: '#78350F',
      bellyTop: '#EDE0D4',
      bellyBottom: '#DDB892',
      snoutTop: '#F5EBE0',
      snoutBottom: '#E6CCB2',
      nose: '#181A24',
      irisOuter: '#065F46',
      irisInner: '#059669',
      irisGlow: '#A7F3D0',
      pupil: '#0F1A17',
      pawPad: '#FF8FA3',
      pawPadHighlight: '#FFCCD5',
      collar: '#3B82F6',
      medallion: '#FBBF24',
      shadow: 'rgba(69, 26, 3, 0.3)',
    },
    spotted: {
      bodyPrimary: '#FFFFFF',
      bodyHighlight: '#FFFFFF',
      bodyShadow: '#CBD5E1',
      bodyStroke: '#1E293B',
      ears: '#334155',
      earsHighlight: '#475569',
      bellyTop: '#F8FAFC',
      bellyBottom: '#E2E8F0',
      snoutTop: '#FFFFFF',
      snoutBottom: '#F1F5F9',
      nose: '#0F172A',
      irisOuter: '#1D4ED8',
      irisInner: '#3B82F6',
      irisGlow: '#BFDBFE',
      pupil: '#0F172A',
      pawPad: '#F472B6',
      pawPadHighlight: '#FBCFE8',
      collar: '#10B981',
      medallion: '#FBBF24',
      shadow: 'rgba(30, 41, 59, 0.2)',
    },
  }[theme];

  const mouthOpenY = Math.min(38, mouthAmplitude * 40);
  const isTalking = voiceState === 'MIMICKING' && mouthAmplitude > 0.05;
  const isListening = voiceState === 'LISTENING';

  const handleZoneTouch = (zone: 'ears' | 'cheeks' | 'mouth' | 'belly' | 'leftPaw' | 'rightPaw') => (e: React.PointerEvent) => {
    e.stopPropagation();
    if (zone === 'leftPaw') {
      setPawLeftRaised(true);
      setTimeout(() => setPawLeftRaised(false), 500);
    } else if (zone === 'rightPaw') {
      setPawRightRaised(true);
      setTimeout(() => setPawRightRaised(false), 500);
    }
    onTouchZone(zone, e);
  };

  return (
    <motion.div
      className="relative w-full max-w-[380px] sm:max-w-[420px] aspect-[4/5] flex items-center justify-center select-none pointer-events-auto"
      animate={!isWalking ? {
        y: [0, -9, 0],
        scaleX: [1, 0.985, 1],
        scaleY: [1, 1.02, 1],
      } : {}}
      transition={!isWalking ? {
        repeat: Infinity,
        duration: 1.9,
        ease: 'easeInOut',
      } : undefined}
    >
      {/* Ground Soft Oval Shadow with synced breath-bounce */}
      <motion.div
        className="absolute bottom-6 w-3/4 h-8 rounded-full blur-md"
        style={{ backgroundColor: themeData.shadow }}
        animate={!isWalking ? {
          scale: [1, 0.92, 1],
          opacity: [0.85, 0.58, 0.85],
        } : {}}
        transition={!isWalking ? {
          repeat: Infinity,
          duration: 1.9,
          ease: 'easeInOut',
        } : undefined}
      />

      <svg
        viewBox="0 0 400 500"
        className="w-full h-full drop-shadow-sm overflow-visible"
        style={{ touchAction: 'none' }}
      >
        <defs>
          {/* Puppy Body 3D Gradient */}
          <radialGradient id="dogBodyGrad" cx="40%" cy="30%" r="70%">
            <stop offset="0%" stopColor={themeData.bodyHighlight} />
            <stop offset="60%" stopColor={themeData.bodyPrimary} />
            <stop offset="100%" stopColor={themeData.bodyShadow} />
          </radialGradient>

          {/* Puppy Head 3D Gradient */}
          <radialGradient id="dogHeadGrad" cx="45%" cy="35%" r="65%">
            <stop offset="0%" stopColor={themeData.bodyHighlight} />
            <stop offset="60%" stopColor={themeData.bodyPrimary} />
            <stop offset="100%" stopColor={themeData.bodyShadow} />
          </radialGradient>

          {/* Puppy Ear Gradient */}
          <linearGradient id="dogEarGrad" x1="0%" y1="0%" x2="0%" y2="100%">
            <stop offset="0%" stopColor={themeData.earsHighlight} />
            <stop offset="100%" stopColor={themeData.ears} />
          </linearGradient>

          {/* Puppy Snout Gradient */}
          <linearGradient id="dogSnoutGrad" x1="0%" y1="0%" x2="0%" y2="100%">
            <stop offset="0%" stopColor={themeData.snoutTop} />
            <stop offset="100%" stopColor={themeData.snoutBottom} />
          </linearGradient>

          {/* Puppy Chest & Belly Gradient */}
          <linearGradient id="dogBellyGrad" x1="0%" y1="0%" x2="0%" y2="100%">
            <stop offset="0%" stopColor={themeData.bellyTop} />
            <stop offset="100%" stopColor={themeData.bellyBottom} />
          </linearGradient>

          {/* Detailed Puppy Iris Radial Gradient */}
          <radialGradient id="dogIrisGrad" cx="45%" cy="40%" r="55%">
            <stop offset="0%" stopColor={themeData.irisGlow} />
            <stop offset="55%" stopColor={themeData.irisInner} />
            <stop offset="95%" stopColor={themeData.irisOuter} />
            <stop offset="100%" stopColor="#0F111A" />
          </radialGradient>

          {/* Paw Pad Gradient */}
          <linearGradient id="dogPawPadGrad" x1="0%" y1="0%" x2="0%" y2="100%">
            <stop offset="0%" stopColor={themeData.pawPadHighlight} />
            <stop offset="100%" stopColor={themeData.pawPad} />
          </linearGradient>

          {/* Soft Shadow Under Head */}
          <filter id="dogHeadShadow" x="-10%" y="-10%" width="120%" height="130%">
            <feDropShadow dx="0" dy="5" stdDeviation="4" floodColor="#000000" floodOpacity="0.2" />
          </filter>
        </defs>

        {/* 1. ENERGETIC PUPPY TAIL (Wags excitedly!) */}
        <motion.g
          animate={{
            rotate: isHappy || isTickled ? [-25, 25, -25] : isListening ? [-14, 14, -14] : [-8, 8, -8],
          }}
          transition={{
            repeat: Infinity,
            duration: isHappy || isTickled ? 0.2 : isListening ? 0.5 : 1.2,
            ease: 'easeInOut',
          }}
          style={{ originX: '260px', originY: '375px' }}
        >
          {/* Base Tail */}
          <path
            d="M255,385 C320,388 375,345 372,285 C370,262 342,268 344,290 C346,325 312,358 248,372 Z"
            fill="url(#dogEarGrad)"
            stroke={themeData.bodyStroke}
            strokeWidth="6"
            strokeLinecap="round"
            strokeLinejoin="round"
          />
          {/* Fluffy Tail Tip */}
          <path
            d="M372,285 C370,262 342,268 344,290 C349,300 360,296 372,285 Z"
            fill={themeData.bellyTop}
            opacity="0.9"
          />
        </motion.g>

        {/* 2. PUPPY BODY & BELLY */}
        <motion.g
          animate={{
            scale: isTickled ? [1, 1.05, 0.96, 1] : isListening ? [1, 1.02, 1] : [1, 1.015, 1],
            y: isWalking ? [0, -8, 0, -8, 0] : isTickled ? [0, -6, 2, -4, 0] : [0, -3, 0],
            rotate: isWalking ? [-3, 3, -3] : 0,
          }}
          transition={{
            repeat: isTickled ? 0 : Infinity,
            duration: isWalking ? 0.45 : isTickled ? 0.35 : 2.4,
            ease: 'easeInOut',
          }}
        >
          {/* Main Torso */}
          <path
            d="M130,300 C105,340 100,420 135,445 C165,465 235,465 265,445 C300,420 295,340 270,300 C250,285 150,285 130,300 Z"
            fill="url(#dogBodyGrad)"
            stroke={themeData.bodyStroke}
            strokeWidth="7"
            strokeLinejoin="round"
          />

          {/* Spots if Dalmatian theme */}
          {theme === 'spotted' && (
            <g fill={themeData.bodyStroke} opacity="0.85">
              <path d="M120,345 C125,335 140,338 138,352 C135,362 120,358 120,345 Z" />
              <path d="M265,340 C275,332 285,342 280,355 C275,365 260,355 265,340 Z" />
              <circle cx="160" cy="425" r="9" />
              <circle cx="245" cy="415" r="11" />
              <circle cx="270" cy="385" r="8" />
            </g>
          )}

          {/* Touch Zone: BELLY & CHEST RUFF */}
          <g
            className="cursor-pointer"
            onPointerDown={handleZoneTouch('belly')}
          >
            {/* Scalloped Puppy Chest & Belly Patch */}
            <motion.path
              d="M165,295 C175,305 185,298 200,302 C215,298 225,305 235,295 C255,320 264,365 260,410 C252,442 225,452 200,452 C175,452 148,442 140,410 C136,365 145,320 165,295 Z"
              fill="url(#dogBellyGrad)"
              stroke={themeData.bodyStroke}
              strokeWidth="4"
              whileTap={{ scale: 0.95 }}
            />

            {/* Puppy Collar & Golden Medallion */}
            <path
              d="M160,296 Q200,314 240,296"
              fill="none"
              stroke={themeData.collar}
              strokeWidth="7"
              strokeLinecap="round"
            />
            {/* Golden Bone / Star Medallion */}
            <motion.g
              animate={{ rotate: isHappy ? [-10, 10, -10] : 0 }}
              transition={{ repeat: Infinity, duration: 0.5 }}
              style={{ originX: '200px', originY: '308px' }}
            >
              <circle cx="200" cy="310" r="8.5" fill={themeData.medallion} stroke={themeData.bodyStroke} strokeWidth="2.5" />
              {/* Star symbol inside medallion */}
              <polygon
                points="200,305 202,309 206,309 203,312 204,316 200,313 196,316 197,312 194,309 198,309"
                fill="#FFFFFF"
              />
            </motion.g>

            {/* Belly Button tickle spot */}
            <ellipse cx="200" cy="380" rx="3.5" ry="3.5" fill={themeData.bodyShadow} opacity="0.5" />
          </g>

          {/* Feet with walking animations */}
          <motion.g
            animate={{ y: isWalking ? [0, -14, 0] : 0 }}
            transition={{ repeat: Infinity, duration: 0.45, ease: 'easeInOut' }}
          >
            <ellipse cx="140" cy="445" rx="33" ry="20" fill="url(#dogBodyGrad)" stroke={themeData.bodyStroke} strokeWidth="6" />
            <ellipse cx="140" cy="445" rx="18" ry="10" fill={themeData.bellyTop} />
            {/* Puppy toe indentations */}
            <line x1="130" y1="440" x2="130" y2="453" stroke={themeData.bodyStroke} strokeWidth="3" strokeLinecap="round" />
            <line x1="150" y1="440" x2="150" y2="453" stroke={themeData.bodyStroke} strokeWidth="3" strokeLinecap="round" />
          </motion.g>

          <motion.g
            animate={{ y: isWalking ? [-14, 0, -14] : 0 }}
            transition={{ repeat: Infinity, duration: 0.45, ease: 'easeInOut' }}
          >
            <ellipse cx="260" cy="445" rx="33" ry="20" fill="url(#dogBodyGrad)" stroke={themeData.bodyStroke} strokeWidth="6" />
            <ellipse cx="260" cy="445" rx="18" ry="10" fill={themeData.bellyTop} />
            <line x1="250" y1="440" x2="250" y2="453" stroke={themeData.bodyStroke} strokeWidth="3" strokeLinecap="round" />
            <line x1="270" y1="440" x2="270" y2="453" stroke={themeData.bodyStroke} strokeWidth="3" strokeLinecap="round" />
          </motion.g>
        </motion.g>

        {/* 3. PUPPY HEAD GROUP */}
        <motion.g
          filter="url(#dogHeadShadow)"
          animate={{
            rotate: isListening ? [-4, 5, -4] : isTickled ? [-6, 6, -6] : [0, 2, -2, 0],
            y: isTalking ? [0, -4, 0] : [0, -2, 0],
          }}
          transition={{
            repeat: Infinity,
            duration: isTalking ? 0.25 : isTickled ? 0.3 : isListening ? 1.0 : 3.0,
            ease: 'easeInOut',
          }}
          style={{ originX: '200px', originY: '240px' }}
        >
          {/* FLOPPY PUPPY EARS (Bounce when touched or listening) */}
          <g
            className="cursor-pointer"
            onPointerDown={handleZoneTouch('ears')}
          >
            {/* Left Floppy Ear with 3D Fold Crease */}
            <motion.g
              animate={{
                rotate: isListening ? [0, -14, 0] : isTickled ? [-16, 16, -16] : [0, -4, 0],
              }}
              transition={{ repeat: Infinity, duration: isListening ? 0.5 : 2.5 }}
              style={{ originX: '135px', originY: '175px' }}
            >
              {/* Outer Flap */}
              <path
                d="M130,165 C85,165 62,220 68,272 C74,310 115,320 128,275 C136,242 144,205 146,180 Z"
                fill="url(#dogEarGrad)"
                stroke={themeData.bodyStroke}
                strokeWidth="7"
                strokeLinejoin="round"
              />
              {/* Ear Crease Fold */}
              <path
                d="M130,165 C115,190 108,225 106,255"
                fill="none"
                stroke={themeData.bodyStroke}
                strokeWidth="4"
                strokeLinecap="round"
                opacity="0.4"
              />
            </motion.g>

            {/* Right Floppy Ear */}
            <motion.g
              animate={{
                rotate: isListening ? [0, 16, 0] : isTickled ? [16, -16, 16] : [0, 4, 0],
              }}
              transition={{ repeat: Infinity, duration: isListening ? 0.5 : 2.5 }}
              style={{ originX: '265px', originY: '175px' }}
            >
              <path
                d="M270,165 C315,165 338,220 332,272 C326,310 285,320 272,275 C264,242 256,205 254,180 Z"
                fill="url(#dogEarGrad)"
                stroke={themeData.bodyStroke}
                strokeWidth="7"
                strokeLinejoin="round"
              />
              <path
                d="M270,165 C285,190 292,225 294,255"
                fill="none"
                stroke={themeData.bodyStroke}
                strokeWidth="4"
                strokeLinecap="round"
                opacity="0.4"
              />
            </motion.g>
          </g>

          {/* Listening sound ripple glow */}
          {isListening && (
            <motion.g
              initial={{ opacity: 0, scale: 0.8 }}
              animate={{ opacity: [0.3, 1, 0.3], scale: [0.9, 1.15, 0.9] }}
              transition={{ repeat: Infinity, duration: 0.8 }}
            >
              <path
                d="M325,150 Q355,130 370,160"
                fill="none"
                stroke={themeData.irisInner}
                strokeWidth="5"
                strokeLinecap="round"
              />
              <path
                d="M340,130 Q375,110 390,145"
                fill="none"
                stroke={themeData.irisInner}
                strokeWidth="4"
                strokeLinecap="round"
              />
            </motion.g>
          )}

          {/* SCULPTED PUPPY HEAD with Fluffy Cheeks */}
          <path
            d="M135,145 C165,130 235,130 265,145 C295,160 305,190 302,215 C315,220 326,228 322,238 C314,244 322,252 316,260 C308,266 314,274 304,280 C278,312 240,318 200,318 C160,318 122,312 96,280 C86,274 92,266 84,260 C78,252 86,244 78,238 C74,228 85,220 98,215 C95,190 105,160 135,145 Z"
            fill="url(#dogHeadGrad)"
            stroke={themeData.bodyStroke}
            strokeWidth="7"
            strokeLinejoin="round"
          />

          {/* Patch Over One Eye for Spotted Theme or Cute Forehead Fur Tuft */}
          {theme === 'spotted' ? (
            <path
              d="M135,158 C155,145 185,155 188,180 C190,205 170,225 145,220 C125,215 120,185 135,158 Z"
              fill={themeData.ears}
              opacity="0.9"
            />
          ) : (
            /* Fluffy Forehead Cowlick Tuft */
            <path
              d="M192,136 C196,126 204,126 208,136 C204,142 196,142 192,136 Z"
              fill={themeData.bodyHighlight}
              stroke={themeData.bodyStroke}
              strokeWidth="2.5"
            />
          )}

          {/* Expressive Arched Puppy Eyebrows */}
          <g stroke={themeData.bodyStroke} strokeWidth="4.5" strokeLinecap="round" fill="none">
            <path d={isHappy ? "M144,152 Q158,142 174,154" : isListening ? "M144,148 Q158,140 174,152" : "M144,152 Q158,146 174,152"} />
            <path d={isHappy ? "M226,154 Q242,142 256,152" : isListening ? "M226,152 Q242,140 256,148" : "M226,152 Q242,146 256,152"} />
          </g>

          {/* CHEEKS (Touch Zone) */}
          <g
            className="cursor-pointer"
            onPointerDown={handleZoneTouch('cheeks')}
          >
            {/* Rosy Cheeks */}
            <motion.ellipse
              cx="124"
              cy="242"
              rx="23"
              ry="15"
              fill="#FF8FA3"
              animate={{ opacity: isHappy ? [0.75, 1, 0.75] : 0.6 }}
              transition={{ repeat: Infinity, duration: 1.0 }}
            />
            <motion.ellipse
              cx="276"
              cy="242"
              rx="23"
              ry="15"
              fill="#FF8FA3"
              animate={{ opacity: isHappy ? [0.75, 1, 0.75] : 0.6 }}
              transition={{ repeat: Infinity, duration: 1.0 }}
            />
          </g>

          {/* PUPPY EYES - Big Soulful Puppy Eyes with Starburst Glints */}
          <g>
            {blink || isHappy || isTickled ? (
              <g stroke={themeData.bodyStroke} strokeWidth="8" strokeLinecap="round" fill="none">
                <path d="M136,188 Q158,164 180,188" />
                <path d="M220,188 Q242,164 264,188" />
              </g>
            ) : (
              <>
                {/* Left Eye */}
                <ellipse cx="158" cy="184" rx="30" ry="38" fill="#FFFFFF" stroke={themeData.bodyStroke} strokeWidth="5.5" />
                <ellipse cx="160" cy="185" rx="21" ry="29" fill="url(#dogIrisGrad)" />
                <ellipse cx="160" cy="185" rx="14" ry="22" fill={themeData.pupil} />
                
                {/* Ambient Lower Iris Glow */}
                <path
                  d="M148,196 C153,205 167,205 172,196 C167,199 153,199 148,196 Z"
                  fill={themeData.irisGlow}
                  opacity="0.85"
                />

                {/* Starburst Diamond Catchlight */}
                <path
                  d="M152,166 C152,170 148,172 144,172 C148,172 152,174 152,178 C152,174 156,172 160,172 C156,172 152,170 152,166 Z"
                  fill="#FFFFFF"
                />
                <circle cx="152" cy="172" r="5" fill="#FFFFFF" />
                <circle cx="168" cy="192" r="3.5" fill="#FFFFFF" />

                {/* Right Eye */}
                <ellipse cx="242" cy="184" rx="30" ry="38" fill="#FFFFFF" stroke={themeData.bodyStroke} strokeWidth="5.5" />
                <ellipse cx="240" cy="185" rx="21" ry="29" fill="url(#dogIrisGrad)" />
                <ellipse cx="240" cy="185" rx="14" ry="22" fill={themeData.pupil} />

                {/* Ambient Lower Iris Glow */}
                <path
                  d="M228,196 C233,205 247,205 252,196 C247,199 233,199 228,196 Z"
                  fill={themeData.irisGlow}
                  opacity="0.85"
                />

                {/* Starburst Diamond Catchlight */}
                <path
                  d="M232,166 C232,170 228,172 224,172 C228,172 232,174 232,178 C232,174 236,172 240,172 C236,172 232,170 232,166 Z"
                  fill="#FFFFFF"
                />
                <circle cx="232" cy="172" r="5" fill="#FFFFFF" />
                <circle cx="248" cy="192" r="3.5" fill="#FFFFFF" />
              </>
            )}
          </g>

          {/* SNOUT & BIG SHINY PUPPY NOSE */}
          {/* Muzzle bulb */}
          <ellipse cx="200" cy="245" rx="48" ry="36" fill="url(#dogSnoutGrad)" stroke={themeData.bodyStroke} strokeWidth="4.5" />
          
          {/* Whiskers Freckle Dots */}
          <circle cx="172" cy="242" r="2.2" fill={themeData.bodyStroke} opacity="0.6" />
          <circle cx="166" cy="248" r="2.2" fill={themeData.bodyStroke} opacity="0.6" />
          <circle cx="174" cy="253" r="2.2" fill={themeData.bodyStroke} opacity="0.6" />
          <circle cx="228" cy="242" r="2.2" fill={themeData.bodyStroke} opacity="0.6" />
          <circle cx="234" cy="248" r="2.2" fill={themeData.bodyStroke} opacity="0.6" />
          <circle cx="226" cy="253" r="2.2" fill={themeData.bodyStroke} opacity="0.6" />

          {/* Big Shiny Black Dog Nose with Twin Specular Highlights */}
          <motion.g whileTap={{ scale: 1.1 }}>
            <path
              d="M184,226 C184,216 216,216 216,226 C216,238 200,244 200,244 C200,244 184,238 184,226 Z"
              fill={themeData.nose}
              stroke={themeData.bodyStroke}
              strokeWidth="3.5"
            />
            {/* Twin Specular Highlights */}
            <ellipse cx="193" cy="223" rx="4.5" ry="2.5" fill="#FFFFFF" opacity="0.85" />
            <ellipse cx="204" cy="225" rx="2.5" ry="1.5" fill="#FFFFFF" opacity="0.6" />
          </motion.g>

          {/* MOUTH & TONGUE (Talking Tom Mimic) */}
          <g
            className="cursor-pointer"
            onPointerDown={handleZoneTouch('mouth')}
          >
            {isTalking ? (
              <motion.g
                animate={{ scaleY: [1, 1.15, 0.95] }}
                transition={{ duration: 0.1 }}
              >
                <path
                  d={`M186,246 Q200,${254 + mouthOpenY} 214,246 Z`}
                  fill="#6B0515"
                  stroke={themeData.bodyStroke}
                  strokeWidth="5"
                  strokeLinejoin="round"
                />
                {/* Panting Puppy Tongue */}
                <path
                  d={`M189,${246 + mouthOpenY * 0.45} Q200,${256 + mouthOpenY} 211,${246 + mouthOpenY * 0.45} Z`}
                  fill="#FF4D6D"
                />
              </motion.g>
            ) : isHappy ? (
              /* Happy puppy panting tongue */
              <g>
                <path
                  d="M186,246 Q200,254 214,246"
                  fill="none"
                  stroke={themeData.bodyStroke}
                  strokeWidth="5"
                  strokeLinecap="round"
                />
                <motion.path
                  d="M192,248 C190,268 210,268 208,248 Z"
                  fill="#FF4D6D"
                  stroke={themeData.bodyStroke}
                  strokeWidth="3.5"
                  animate={{ y: [0, 4, 0] }}
                  transition={{ repeat: Infinity, duration: 0.4 }}
                />
              </g>
            ) : (
              /* Puppy Smile */
              <path
                d="M184,246 Q200,256 200,240 Q200,256 216,246"
                fill="none"
                stroke={themeData.bodyStroke}
                strokeWidth="5"
                strokeLinecap="round"
              />
            )}
          </g>
        </motion.g>

        {/* 4. FRONT PAWS with Chunky Toe Beans (High-Five Zones!) */}
        <motion.g
          className="cursor-pointer"
          onPointerDown={handleZoneTouch('leftPaw')}
          animate={{
            y: pawLeftRaised ? -40 : [0, -3, 0],
            rotate: pawLeftRaised ? 18 : 0,
            scale: pawLeftRaised ? 1.15 : 1,
          }}
          transition={{ duration: pawLeftRaised ? 0.2 : 2.5, repeat: pawLeftRaised ? 0 : Infinity }}
          style={{ originX: '120px', originY: '330px' }}
        >
          <path
            d="M90,340 C85,320 105,305 125,308 C145,310 152,328 145,348 C140,360 95,358 90,340 Z"
            fill="url(#dogBodyGrad)"
            stroke={themeData.bodyStroke}
            strokeWidth="7"
            strokeLinejoin="round"
          />
          <ellipse cx="118" cy="336" rx="14" ry="10" fill="url(#dogPawPadGrad)" stroke={themeData.bodyStroke} strokeWidth="2" />
          <circle cx="102" cy="322" r="5" fill="url(#dogPawPadGrad)" stroke={themeData.bodyStroke} strokeWidth="1.5" />
          <circle cx="117" cy="317" r="5.5" fill="url(#dogPawPadGrad)" stroke={themeData.bodyStroke} strokeWidth="1.5" />
          <circle cx="132" cy="322" r="5" fill="url(#dogPawPadGrad)" stroke={themeData.bodyStroke} strokeWidth="1.5" />
        </motion.g>

        <motion.g
          className="cursor-pointer"
          onPointerDown={handleZoneTouch('rightPaw')}
          animate={{
            y: pawRightRaised ? -40 : [0, -3, 0],
            rotate: pawRightRaised ? -18 : 0,
            scale: pawRightRaised ? 1.15 : 1,
          }}
          transition={{ duration: pawRightRaised ? 0.2 : 2.5, repeat: pawRightRaised ? 0 : Infinity }}
          style={{ originX: '280px', originY: '330px' }}
        >
          <path
            d="M310,340 C315,320 295,305 275,308 C255,310 248,328 255,348 C260,360 305,358 310,340 Z"
            fill="url(#dogBodyGrad)"
            stroke={themeData.bodyStroke}
            strokeWidth="7"
            strokeLinejoin="round"
          />
          <ellipse cx="282" cy="336" rx="14" ry="10" fill="url(#dogPawPadGrad)" stroke={themeData.bodyStroke} strokeWidth="2" />
          <circle cx="268" cy="322" r="5" fill="url(#dogPawPadGrad)" stroke={themeData.bodyStroke} strokeWidth="1.5" />
          <circle cx="283" cy="317" r="5.5" fill="url(#dogPawPadGrad)" stroke={themeData.bodyStroke} strokeWidth="1.5" />
          <circle cx="298" cy="322" r="5" fill="url(#dogPawPadGrad)" stroke={themeData.bodyStroke} strokeWidth="1.5" />
        </motion.g>
      </svg>
    </motion.div>
  );
};

import React, { useState, useEffect } from 'react';
import { motion } from 'motion/react';
import { VoiceState } from '../services/voiceMimic';

export type CatColorTheme = 'midnight' | 'ginger' | 'cloud';

interface CatCharacterProps {
  voiceState: VoiceState;
  mouthAmplitude: number; // 0 to 1
  isPurring: boolean;
  isTickled: boolean;
  isWalking?: boolean;
  theme: CatColorTheme;
  onTouchZone: (zone: 'ears' | 'cheeks' | 'mouth' | 'belly' | 'leftPaw' | 'rightPaw', e: React.PointerEvent) => void;
}

export const CatCharacter: React.FC<CatCharacterProps> = ({
  voiceState,
  mouthAmplitude,
  isPurring,
  isTickled,
  isWalking = false,
  theme,
  onTouchZone,
}) => {
  const [blink, setBlink] = useState(false);
  const [pawLeftRaised, setPawLeftRaised] = useState(false);
  const [pawRightRaised, setPawRightRaised] = useState(false);

  // Natural idle blinking
  useEffect(() => {
    const blinkInterval = setInterval(() => {
      setBlink(true);
      setTimeout(() => setBlink(false), 200);
    }, 3800);
    return () => clearInterval(blinkInterval);
  }, []);

  // Theme palettes with rich shading, highlights, and gradients
  const themeData = {
    midnight: {
      bodyPrimary: '#2B2D46',
      bodyHighlight: '#3F4365',
      bodyShadow: '#1B1C2E',
      bodyStroke: '#141524',
      stripe: '#1B1C2E',
      bellyTop: '#FFF8F0',
      bellyBottom: '#F2E3D0',
      innerEarStart: '#FFA8BA',
      innerEarEnd: '#FF6B8B',
      earFluff: '#FFF5EB',
      muzzle: '#FFFFFF',
      nose: '#FF4D6D',
      noseHighlight: '#FFA8BA',
      irisOuter: '#D97706',
      irisInner: '#FBBF24',
      irisGlow: '#FEF08A',
      pupil: '#0F101A',
      pawPad: '#FF8FA3',
      pawPadHighlight: '#FFCCD5',
      whiskers: '#222438',
      shadow: 'rgba(27, 28, 46, 0.28)',
    },
    ginger: {
      bodyPrimary: '#EE734C',
      bodyHighlight: '#FA9371',
      bodyShadow: '#C85330',
      bodyStroke: '#913115',
      stripe: '#BC4321',
      bellyTop: '#FFF4EB',
      bellyBottom: '#FCE0CE',
      innerEarStart: '#FFCCD5',
      innerEarEnd: '#FF85A1',
      earFluff: '#FFF8F2',
      muzzle: '#FFFFFF',
      nose: '#E63946',
      noseHighlight: '#FF758F',
      irisOuter: '#0D9488',
      irisInner: '#2DD4BF',
      irisGlow: '#99F6E4',
      pupil: '#132A27',
      pawPad: '#FF8FA3',
      pawPadHighlight: '#FFCCD5',
      whiskers: '#913115',
      shadow: 'rgba(238, 115, 76, 0.28)',
    },
    cloud: {
      bodyPrimary: '#F8FAFC',
      bodyHighlight: '#FFFFFF',
      bodyShadow: '#E2E8F0',
      bodyStroke: '#334155',
      stripe: '#CBD5E1',
      bellyTop: '#FFFFFF',
      bellyBottom: '#F1F5F9',
      innerEarStart: '#FFB3C1',
      innerEarEnd: '#FF758F',
      earFluff: '#FFFFFF',
      muzzle: '#FFFFFF',
      nose: '#FF4D6D',
      noseHighlight: '#FFA8BA',
      irisOuter: '#0284C7',
      irisInner: '#38BDF8',
      irisGlow: '#BAE6FD',
      pupil: '#0F172A',
      pawPad: '#FF8FA3',
      pawPadHighlight: '#FFCCD5',
      whiskers: '#475569',
      shadow: 'rgba(51, 65, 85, 0.2)',
    },
  }[theme];

  // Dynamic mouth height based on talking amplitude
  const mouthOpenY = Math.min(36, mouthAmplitude * 38);
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
        y: [0, -8, 0],
        scaleX: [1, 0.99, 1],
        scaleY: [1, 1.015, 1],
      } : {}}
      transition={!isWalking ? {
        repeat: Infinity,
        duration: 2.2,
        ease: 'easeInOut',
      } : undefined}
    >
      {/* Ground Soft Oval Shadow with synced breath-bounce */}
      <motion.div
        className="absolute bottom-6 w-3/4 h-8 rounded-full blur-md"
        style={{ backgroundColor: themeData.shadow }}
        animate={!isWalking ? {
          scale: [1, 0.93, 1],
          opacity: [0.85, 0.6, 0.85],
        } : {}}
        transition={!isWalking ? {
          repeat: Infinity,
          duration: 2.2,
          ease: 'easeInOut',
        } : undefined}
      />

      <svg
        viewBox="0 0 400 500"
        className="w-full h-full drop-shadow-sm overflow-visible"
        style={{ touchAction: 'none' }}
      >
        <defs>
          {/* Dimensional Body Gradient */}
          <radialGradient id="catBodyGrad" cx="40%" cy="30%" r="70%">
            <stop offset="0%" stopColor={themeData.bodyHighlight} />
            <stop offset="65%" stopColor={themeData.bodyPrimary} />
            <stop offset="100%" stopColor={themeData.bodyShadow} />
          </radialGradient>

          {/* Head 3D Sphere Gradient */}
          <radialGradient id="catHeadGrad" cx="45%" cy="35%" r="65%">
            <stop offset="0%" stopColor={themeData.bodyHighlight} />
            <stop offset="60%" stopColor={themeData.bodyPrimary} />
            <stop offset="100%" stopColor={themeData.bodyShadow} />
          </radialGradient>

          {/* Velvet Inner Ear Gradient */}
          <linearGradient id="catInnerEarGrad" x1="0%" y1="0%" x2="0%" y2="100%">
            <stop offset="0%" stopColor={themeData.innerEarStart} />
            <stop offset="100%" stopColor={themeData.innerEarEnd} />
          </linearGradient>

          {/* Fluffy Chest & Belly Gradient */}
          <linearGradient id="catBellyGrad" x1="0%" y1="0%" x2="0%" y2="100%">
            <stop offset="0%" stopColor={themeData.bellyTop} />
            <stop offset="100%" stopColor={themeData.bellyBottom} />
          </linearGradient>

          {/* Detailed Eye Iris Radial Gradient */}
          <radialGradient id="catIrisGrad" cx="45%" cy="40%" r="55%">
            <stop offset="0%" stopColor={themeData.irisGlow} />
            <stop offset="55%" stopColor={themeData.irisInner} />
            <stop offset="95%" stopColor={themeData.irisOuter} />
            <stop offset="100%" stopColor="#0B132B" />
          </radialGradient>

          {/* Muzzle Pill Gradient */}
          <linearGradient id="catMuzzleGrad" x1="0%" y1="0%" x2="0%" y2="100%">
            <stop offset="0%" stopColor="#FFFFFF" />
            <stop offset="100%" stopColor="#F1F5F9" />
          </linearGradient>

          {/* Paw Pad Gradient */}
          <linearGradient id="catPawPadGrad" x1="0%" y1="0%" x2="0%" y2="100%">
            <stop offset="0%" stopColor={themeData.pawPadHighlight} />
            <stop offset="100%" stopColor={themeData.pawPad} />
          </linearGradient>

          {/* Soft Shadow Filter for subtle under-head depth */}
          <filter id="softUnderHeadShadow" x="-10%" y="-10%" width="120%" height="130%">
            <feDropShadow dx="0" dy="5" stdDeviation="4" floodColor="#000000" floodOpacity="0.22" />
          </filter>
        </defs>

        {/* 1. TAIL with playful wagging and multi-tone fur tip */}
        <motion.g
          animate={{
            rotate: isListening ? [0, 9, -9, 0] : isTickled ? [-16, 16, -16] : [0, 6, -5, 0],
          }}
          transition={{
            repeat: Infinity,
            duration: isTickled ? 0.38 : isListening ? 0.9 : 2.8,
            ease: 'easeInOut',
          }}
          style={{ originX: '270px', originY: '380px' }}
        >
          {/* Base Tail */}
          <path
            d="M265,390 C345,395 378,335 356,275 C345,245 315,265 324,285 C334,308 322,355 258,368 Z"
            fill="url(#catBodyGrad)"
            stroke={themeData.bodyStroke}
            strokeWidth="6"
            strokeLinecap="round"
            strokeLinejoin="round"
          />
          {/* Tail Fur Tip Accent */}
          <path
            d="M356,275 C345,245 315,265 324,285 C330,298 338,290 356,275 Z"
            fill={themeData.bellyTop}
            opacity="0.9"
          />
        </motion.g>

        {/* 2. BODY & BELLY (Jiggle when tickled / waddle when walking) */}
        <motion.g
          animate={{
            scale: isTickled ? [1, 1.04, 0.97, 1.03, 1] : isListening ? [1, 1.02, 1] : [1, 1.015, 1],
            y: isWalking ? [0, -8, 0, -8, 0] : isTickled ? [0, -6, 2, -4, 0] : [0, -3, 0],
            rotate: isWalking ? [-3, 3, -3] : 0,
          }}
          transition={{
            repeat: isTickled ? 0 : Infinity,
            duration: isWalking ? 0.45 : isTickled ? 0.35 : 2.5,
            ease: 'easeInOut',
          }}
        >
          {/* Main Body Torso with 3D gradient */}
          <path
            d="M130,300 C105,340 100,420 135,445 C165,465 235,465 265,445 C300,420 295,340 270,300 C250,285 150,285 130,300 Z"
            fill="url(#catBodyGrad)"
            stroke={themeData.bodyStroke}
            strokeWidth="7"
            strokeLinejoin="round"
          />

          {/* Subtle Tabby Side Body Stripes */}
          <path
            d="M116,360 Q135,365 145,368"
            stroke={themeData.stripe}
            strokeWidth="5"
            strokeLinecap="round"
            fill="none"
            opacity="0.75"
          />
          <path
            d="M118,385 Q138,388 148,390"
            stroke={themeData.stripe}
            strokeWidth="5"
            strokeLinecap="round"
            fill="none"
            opacity="0.75"
          />
          <path
            d="M284,360 Q265,365 255,368"
            stroke={themeData.stripe}
            strokeWidth="5"
            strokeLinecap="round"
            fill="none"
            opacity="0.75"
          />
          <path
            d="M282,385 Q262,388 252,390"
            stroke={themeData.stripe}
            strokeWidth="5"
            strokeLinecap="round"
            fill="none"
            opacity="0.75"
          />

          {/* Touch Zone: BELLY & CHEST FLUFF */}
          <g
            className="cursor-pointer"
            onPointerDown={handleZoneTouch('belly')}
          >
            {/* Scalloped Fluffy Chest Bib & Belly Patch */}
            <motion.path
              d="M165,295 C175,305 185,298 200,302 C215,298 225,305 235,295 C255,320 262,365 258,410 C250,442 225,452 200,452 C175,452 150,442 142,410 C138,365 145,320 165,295 Z"
              fill="url(#catBellyGrad)"
              stroke={themeData.bodyStroke}
              strokeWidth="4"
              whileTap={{ scale: 0.96 }}
            />
            {/* Soft inner belly fur tufts */}
            <path
              d="M185,325 Q200,336 215,325 M188,342 Q200,352 212,342"
              fill="none"
              stroke={themeData.bodyShadow}
              strokeWidth="2.5"
              strokeLinecap="round"
              opacity="0.4"
            />
            {/* Belly Button Heart */}
            <path
              d="M200,380 C198,375 192,375 192,379 C192,383 200,388 200,388 C200,388 208,383 208,379 C208,375 202,375 200,380 Z"
              fill={themeData.nose}
              opacity="0.85"
            />
          </g>

          {/* Left Foot Paw - Steps when walking */}
          <motion.g
            animate={{
              y: isWalking ? [0, -14, 0] : 0,
            }}
            transition={{ repeat: Infinity, duration: 0.45, ease: 'easeInOut' }}
          >
            <ellipse cx="140" cy="445" rx="32" ry="20" fill="url(#catBodyGrad)" stroke={themeData.bodyStroke} strokeWidth="6" />
            <ellipse cx="140" cy="445" rx="18" ry="10" fill={themeData.bellyTop} />
            {/* Toe dividers */}
            <line x1="131" y1="440" x2="131" y2="453" stroke={themeData.bodyStroke} strokeWidth="3" strokeLinecap="round" />
            <line x1="149" y1="440" x2="149" y2="453" stroke={themeData.bodyStroke} strokeWidth="3" strokeLinecap="round" />
          </motion.g>

          {/* Right Foot Paw - Steps opposite phase when walking */}
          <motion.g
            animate={{
              y: isWalking ? [-14, 0, -14] : 0,
            }}
            transition={{ repeat: Infinity, duration: 0.45, ease: 'easeInOut' }}
          >
            <ellipse cx="260" cy="445" rx="32" ry="20" fill="url(#catBodyGrad)" stroke={themeData.bodyStroke} strokeWidth="6" />
            <ellipse cx="260" cy="445" rx="18" ry="10" fill={themeData.bellyTop} />
            {/* Toe dividers */}
            <line x1="251" y1="440" x2="251" y2="453" stroke={themeData.bodyStroke} strokeWidth="3" strokeLinecap="round" />
            <line x1="269" y1="440" x2="269" y2="453" stroke={themeData.bodyStroke} strokeWidth="3" strokeLinecap="round" />
          </motion.g>
        </motion.g>

        {/* 3. CAT HEAD GROUP with Head Shadow */}
        <motion.g
          filter="url(#softUnderHeadShadow)"
          animate={{
            rotate: isListening ? [-3, 4, -3] : isTickled ? [-5, 5, -5] : [0, 1.5, -1.5, 0],
            y: isTalking ? [0, -4, 0] : [0, -2, 0],
          }}
          transition={{
            repeat: Infinity,
            duration: isTalking ? 0.25 : isTickled ? 0.3 : isListening ? 1.2 : 3.2,
            ease: 'easeInOut',
          }}
          style={{ originX: '200px', originY: '240px' }}
        >
          {/* EARS (Touch Zone) */}
          <g
            className="cursor-pointer"
            onPointerDown={handleZoneTouch('ears')}
          >
            {/* Left Ear with 3D depth and fluffy ear-canal tufts */}
            <motion.g
              animate={{
                rotate: isListening ? [0, -9, 0] : [0, -3, 0],
              }}
              transition={{ repeat: Infinity, duration: isListening ? 0.6 : 3.0 }}
              style={{ originX: '120px', originY: '170px' }}
            >
              {/* Outer Ear Shape */}
              <path
                d="M92,192 C88,145 105,80 122,62 C132,52 142,60 156,95 C170,128 184,152 192,160 Z"
                fill="url(#catBodyGrad)"
                stroke={themeData.bodyStroke}
                strokeWidth="7"
                strokeLinejoin="round"
              />
              {/* Velvet Inner Ear Pink */}
              <path
                d="M106,180 C104,142 118,92 124,76 C130,86 148,124 168,155 Z"
                fill="url(#catInnerEarGrad)"
              />
              {/* Fluffy Ear Fur Tufts peeking from base */}
              <path
                d="M108,185 C118,172 132,175 142,160 C146,170 158,168 172,174 C158,182 142,180 134,188 Z"
                fill={themeData.earFluff}
                stroke={themeData.bodyStroke}
                strokeWidth="2.5"
                strokeLinejoin="round"
              />
            </motion.g>

            {/* Right Ear (Perks/cups forward when listening) */}
            <motion.g
              animate={{
                rotate: isListening ? [0, 11, 0] : [0, 3, 0],
                scale: isListening ? [1, 1.08, 1] : 1,
              }}
              transition={{ repeat: Infinity, duration: isListening ? 0.6 : 3.0 }}
              style={{ originX: '280px', originY: '170px' }}
            >
              {/* Outer Ear Shape */}
              <path
                d="M308,192 C312,145 295,80 278,62 C268,52 258,60 244,95 C230,128 216,152 208,160 Z"
                fill="url(#catBodyGrad)"
                stroke={themeData.bodyStroke}
                strokeWidth="7"
                strokeLinejoin="round"
              />
              {/* Velvet Inner Ear Pink */}
              <path
                d="M294,180 C296,142 282,92 276,76 C270,86 252,124 232,155 Z"
                fill="url(#catInnerEarGrad)"
              />
              {/* Fluffy Ear Fur Tufts peeking from base */}
              <path
                d="M292,185 C282,172 268,175 258,160 C254,170 242,168 228,174 C242,182 258,180 266,188 Z"
                fill={themeData.earFluff}
                stroke={themeData.bodyStroke}
                strokeWidth="2.5"
                strokeLinejoin="round"
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
                d="M315,70 Q345,50 365,80"
                fill="none"
                stroke={themeData.irisInner}
                strokeWidth="5"
                strokeLinecap="round"
              />
              <path
                d="M330,50 Q365,30 385,70"
                fill="none"
                stroke={themeData.irisInner}
                strokeWidth="4"
                strokeLinecap="round"
              />
            </motion.g>
          )}

          {/* SCULPTED HEAD with Triple Fluffy Cheek Tufts! */}
          <path
            d="M135,145 C165,130 235,130 265,145 C295,160 305,190 302,215 C316,218 328,226 322,236 C314,242 324,250 318,258 C310,265 316,273 306,278 C280,312 240,318 200,318 C160,318 120,312 94,278 C84,273 90,265 82,258 C76,250 86,242 78,236 C72,226 84,218 98,215 C95,190 105,160 135,145 Z"
            fill="url(#catHeadGrad)"
            stroke={themeData.bodyStroke}
            strokeWidth="7"
            strokeLinejoin="round"
          />

          {/* Tabby Forehead Stripes / Crown Marking */}
          <g opacity="0.8">
            {/* Center stripe */}
            <path
              d="M197,138 L203,138 L202,168 L198,168 Z"
              fill={themeData.stripe}
            />
            {/* Left stripe */}
            <path
              d="M182,143 Q187,156 189,166 L185,167 Q182,156 177,144 Z"
              fill={themeData.stripe}
            />
            {/* Right stripe */}
            <path
              d="M218,143 Q213,156 211,166 L215,167 Q218,156 223,144 Z"
              fill={themeData.stripe}
            />
          </g>

          {/* Cute Expressive Eyebrows */}
          <g stroke={themeData.bodyStroke} strokeWidth="4" strokeLinecap="round" fill="none">
            <path d={isListening ? "M145,155 Q160,147 175,157" : isTickled ? "M145,152 Q160,158 175,152" : "M145,154 Q160,149 175,154"} />
            <path d={isListening ? "M225,157 Q240,147 255,155" : isTickled ? "M225,152 Q240,158 255,152" : "M225,154 Q240,149 255,154"} />
          </g>

          {/* CHEEKS & WHISKERS (Touch Zone) */}
          <g
            className="cursor-pointer"
            onPointerDown={handleZoneTouch('cheeks')}
          >
            {/* Soft Rosy Blushing Cheeks */}
            <motion.ellipse
              cx="124"
              cy="242"
              rx="24"
              ry="16"
              fill="#FF8FA3"
              animate={{
                opacity: isPurring ? [0.8, 1, 0.8] : 0.65,
                scale: isPurring ? [1, 1.15, 1] : 1,
              }}
              transition={{ repeat: Infinity, duration: 1.2 }}
            />
            <motion.ellipse
              cx="276"
              cy="242"
              rx="24"
              ry="16"
              fill="#FF8FA3"
              animate={{
                opacity: isPurring ? [0.8, 1, 0.8] : 0.65,
                scale: isPurring ? [1, 1.15, 1] : 1,
              }}
              transition={{ repeat: Infinity, duration: 1.2 }}
            />

            {/* Whiskers Left (Multi-point curved whiskers) */}
            <motion.g
              animate={{
                rotate: isTickled ? [-5, 5, -5] : 0,
              }}
              transition={{ repeat: Infinity, duration: 0.3 }}
              style={{ originX: '110px', originY: '240px' }}
            >
              <path d="M115,228 Q75,220 40,212" stroke={themeData.whiskers} strokeWidth="5.5" strokeLinecap="round" fill="none" />
              <path d="M110,244 Q68,244 32,246" stroke={themeData.whiskers} strokeWidth="5.5" strokeLinecap="round" fill="none" />
              <path d="M114,260 Q72,268 45,280" stroke={themeData.whiskers} strokeWidth="5.5" strokeLinecap="round" fill="none" />
            </motion.g>

            {/* Whiskers Right */}
            <motion.g
              animate={{
                rotate: isTickled ? [5, -5, 5] : 0,
              }}
              transition={{ repeat: Infinity, duration: 0.3 }}
              style={{ originX: '290px', originY: '240px' }}
            >
              <path d="M285,228 Q325,220 360,212" stroke={themeData.whiskers} strokeWidth="5.5" strokeLinecap="round" fill="none" />
              <path d="M290,244 Q332,244 368,246" stroke={themeData.whiskers} strokeWidth="5.5" strokeLinecap="round" fill="none" />
              <path d="M286,260 Q328,268 355,280" stroke={themeData.whiskers} strokeWidth="5.5" strokeLinecap="round" fill="none" />
            </motion.g>
          </g>

          {/* DETAILED GLOSSY CARTOON EYES */}
          <g>
            {blink || isPurring || isTickled ? (
              /* Joyful Closed Crescent Eyes ( ^ . ^ ) with cute eyelashes */
              <g stroke={themeData.bodyStroke} strokeWidth="8" strokeLinecap="round" fill="none">
                <path d="M135,190 Q158,164 181,190" />
                <path d="M140,186 L134,178" strokeWidth="5" />
                <path d="M176,186 L182,178" strokeWidth="5" />
                <path d="M219,190 Q242,164 265,190" />
                <path d="M224,186 L218,178" strokeWidth="5" />
                <path d="M260,186 L266,178" strokeWidth="5" />
              </g>
            ) : (
              /* Open Enormous Glossy Cartoon Eyes */
              <>
                {/* --- Left Eye --- */}
                {/* Eye Sclera (White base with subtle top rim shadow) */}
                <ellipse cx="158" cy="184" rx="31" ry="38" fill="#FFFFFF" stroke={themeData.bodyStroke} strokeWidth="5.5" />
                
                {/* Iris with Radial Depth Gradient */}
                <ellipse cx="160" cy="185" rx="22" ry="29" fill="url(#catIrisGrad)" />
                
                {/* Limbal ring highlight */}
                <ellipse cx="160" cy="185" rx="21" ry="28" fill="none" stroke={themeData.irisOuter} strokeWidth="2" opacity="0.6" />

                {/* Big Deep Pupil */}
                <ellipse cx="160" cy="185" rx="14" ry="22" fill={themeData.pupil} />
                
                {/* Lower Iris Ambient Glow Reflection */}
                <path
                  d="M148,196 C153,205 167,205 172,196 C167,199 153,199 148,196 Z"
                  fill={themeData.irisGlow}
                  opacity="0.85"
                />

                {/* Starburst Diamond Catchlight Sparkle (Main) */}
                <path
                  d="M152,166 C152,170 148,172 144,172 C148,172 152,174 152,178 C152,174 156,172 160,172 C156,172 152,170 152,166 Z"
                  fill="#FFFFFF"
                />
                <circle cx="152" cy="172" r="5" fill="#FFFFFF" />

                {/* Secondary Micro Circular Catchlight */}
                <circle cx="169" cy="192" r="3.5" fill="#FFFFFF" />
                <circle cx="163" cy="165" r="2" fill="#FFFFFF" opacity="0.8" />

                {/* --- Right Eye --- */}
                {/* Eye Sclera */}
                <ellipse cx="242" cy="184" rx="31" ry="38" fill="#FFFFFF" stroke={themeData.bodyStroke} strokeWidth="5.5" />
                
                {/* Iris */}
                <ellipse cx="240" cy="185" rx="22" ry="29" fill="url(#catIrisGrad)" />
                
                {/* Limbal ring */}
                <ellipse cx="240" cy="185" rx="21" ry="28" fill="none" stroke={themeData.irisOuter} strokeWidth="2" opacity="0.6" />

                {/* Big Deep Pupil */}
                <ellipse cx="240" cy="185" rx="14" ry="22" fill={themeData.pupil} />
                
                {/* Lower Iris Reflection */}
                <path
                  d="M228,196 C233,205 247,205 252,196 C247,199 233,199 228,196 Z"
                  fill={themeData.irisGlow}
                  opacity="0.85"
                />

                {/* Starburst Catchlight (Main) */}
                <path
                  d="M232,166 C232,170 228,172 224,172 C228,172 232,174 232,178 C232,174 236,172 240,172 C236,172 232,170 232,166 Z"
                  fill="#FFFFFF"
                />
                <circle cx="232" cy="172" r="5" fill="#FFFFFF" />

                {/* Secondary Micro Catchlight */}
                <circle cx="249" cy="192" r="3.5" fill="#FFFFFF" />
                <circle cx="243" cy="165" r="2" fill="#FFFFFF" opacity="0.8" />
              </>
            )}
          </g>

          {/* PLUMP 3D MUZZLE & NOSE */}
          {/* Left & Right Muzzle Cheeks */}
          <path
            d="M172,246 C162,246 156,234 165,224 C174,215 190,218 196,232 C198,242 188,246 172,246 Z"
            fill="url(#catMuzzleGrad)"
            stroke={themeData.bodyStroke}
            strokeWidth="3.5"
          />
          <path
            d="M228,246 C238,246 244,234 235,224 C226,215 210,218 204,232 C202,242 212,246 228,246 Z"
            fill="url(#catMuzzleGrad)"
            stroke={themeData.bodyStroke}
            strokeWidth="3.5"
          />

          {/* Whiskers Freckle Dots on Muzzle */}
          <circle cx="178" cy="232" r="1.8" fill={themeData.bodyStroke} opacity="0.6" />
          <circle cx="173" cy="237" r="1.8" fill={themeData.bodyStroke} opacity="0.6" />
          <circle cx="182" cy="239" r="1.8" fill={themeData.bodyStroke} opacity="0.6" />
          <circle cx="222" cy="232" r="1.8" fill={themeData.bodyStroke} opacity="0.6" />
          <circle cx="227" cy="237" r="1.8" fill={themeData.bodyStroke} opacity="0.6" />
          <circle cx="218" cy="239" r="1.8" fill={themeData.bodyStroke} opacity="0.6" />

          {/* Dimensional Heart/Triangle Cat Nose with Specular Highlight */}
          <path
            d="M200,234 C193,234 186,220 190,216 C194,213 206,213 210,216 C214,220 207,234 200,234 Z"
            fill={themeData.nose}
            stroke={themeData.bodyStroke}
            strokeWidth="3.5"
            strokeLinejoin="round"
          />
          {/* Specular Glint on Nose */}
          <ellipse cx="196" cy="217" rx="3.5" ry="2" fill={themeData.noseHighlight} />

          {/* MOUTH (Talking Tom Speech-Sync & Touch Zone) */}
          <g
            className="cursor-pointer"
            onPointerDown={handleZoneTouch('mouth')}
          >
            {isTalking ? (
              /* Talking Tom Open Mouth synced to amplitude */
              <motion.g
                animate={{ scaleY: [1, 1.15, 0.95] }}
                transition={{ duration: 0.1 }}
              >
                {/* Deep burgundy interior */}
                <path
                  d={`M186,238 Q200,${246 + mouthOpenY} 214,238 Z`}
                  fill="#6B0515"
                  stroke={themeData.bodyStroke}
                  strokeWidth="5"
                  strokeLinejoin="round"
                />
                {/* Rosy Tongue with depth */}
                <path
                  d={`M190,${238 + mouthOpenY * 0.45} Q200,${244 + mouthOpenY} 210,${238 + mouthOpenY * 0.45} Z`}
                  fill="#FF6584"
                />
                {/* Pearly White Kitten Fangs */}
                <polygon points="189,238 193,244 195,238" fill="#FFFFFF" stroke={themeData.bodyStroke} strokeWidth="1" />
                <polygon points="205,238 207,244 211,238" fill="#FFFFFF" stroke={themeData.bodyStroke} strokeWidth="1" />
              </motion.g>
            ) : (
              /* Closed Cute Kitten Smile :3 with dimensional curve */
              <path
                d="M182,238 Q198,252 200,235 Q202,252 218,238"
                fill="none"
                stroke={themeData.bodyStroke}
                strokeWidth="5"
                strokeLinecap="round"
                strokeLinejoin="round"
              />
            )}
          </g>
        </motion.g>

        {/* 4. FRONT PAWS with Chunky Toe Beans (High-Five Touch Zones!) */}
        {/* Left Front Paw */}
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
          {/* Main Paw */}
          <path
            d="M90,340 C85,320 105,305 125,308 C145,310 152,328 145,348 C140,360 95,358 90,340 Z"
            fill="url(#catBodyGrad)"
            stroke={themeData.bodyStroke}
            strokeWidth="7"
            strokeLinejoin="round"
          />
          {/* Big Center Paw Pad */}
          <ellipse cx="118" cy="336" rx="14" ry="10" fill="url(#catPawPadGrad)" stroke={themeData.bodyStroke} strokeWidth="2" />
          {/* Toe Bean 1 */}
          <circle cx="102" cy="322" r="5" fill="url(#catPawPadGrad)" stroke={themeData.bodyStroke} strokeWidth="1.5" />
          {/* Toe Bean 2 */}
          <circle cx="117" cy="317" r="5.5" fill="url(#catPawPadGrad)" stroke={themeData.bodyStroke} strokeWidth="1.5" />
          {/* Toe Bean 3 */}
          <circle cx="132" cy="322" r="5" fill="url(#catPawPadGrad)" stroke={themeData.bodyStroke} strokeWidth="1.5" />
        </motion.g>

        {/* Right Front Paw */}
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
          {/* Main Paw */}
          <path
            d="M310,340 C315,320 295,305 275,308 C255,310 248,328 255,348 C260,360 305,358 310,340 Z"
            fill="url(#catBodyGrad)"
            stroke={themeData.bodyStroke}
            strokeWidth="7"
            strokeLinejoin="round"
          />
          {/* Big Center Paw Pad */}
          <ellipse cx="282" cy="336" rx="14" ry="10" fill="url(#catPawPadGrad)" stroke={themeData.bodyStroke} strokeWidth="2" />
          {/* Toe Bean 1 */}
          <circle cx="268" cy="322" r="5" fill="url(#catPawPadGrad)" stroke={themeData.bodyStroke} strokeWidth="1.5" />
          {/* Toe Bean 2 */}
          <circle cx="283" cy="317" r="5.5" fill="url(#catPawPadGrad)" stroke={themeData.bodyStroke} strokeWidth="1.5" />
          {/* Toe Bean 3 */}
          <circle cx="298" cy="322" r="5" fill="url(#catPawPadGrad)" stroke={themeData.bodyStroke} strokeWidth="1.5" />
        </motion.g>
      </svg>
    </motion.div>
  );
};

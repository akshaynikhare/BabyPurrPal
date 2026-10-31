import React, { useState, useEffect } from 'react';
import { motion } from 'motion/react';
import { VoiceState } from '../services/voiceMimic';

export type RabbitColorTheme = 'white' | 'honey' | 'smokey';

interface RabbitCharacterProps {
  voiceState: VoiceState;
  mouthAmplitude: number;
  isHappy: boolean;
  isTickled: boolean;
  isWalking?: boolean;
  theme: RabbitColorTheme;
  onTouchZone: (zone: 'ears' | 'cheeks' | 'mouth' | 'belly' | 'leftPaw' | 'rightPaw', e: React.PointerEvent) => void;
}

export const RabbitCharacter: React.FC<RabbitCharacterProps> = ({
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
    }, 3400);
    return () => clearInterval(blinkInterval);
  }, []);

  const themeData = {
    white: {
      bodyPrimary: '#FFFFFF',
      bodyHighlight: '#FFFFFF',
      bodyShadow: '#E2E8F0',
      bodyStroke: '#334155',
      bellyTop: '#FFF5F5',
      bellyBottom: '#FFE3E8',
      innerEarStart: '#FFA8BA',
      innerEarEnd: '#FF758F',
      earFluff: '#FFFFFF',
      nose: '#FF4D6D',
      noseHighlight: '#FFA8BA',
      irisOuter: '#E11D48',
      irisInner: '#FB7185',
      irisGlow: '#FECDD3',
      pupil: '#1E293B',
      pawPad: '#FFB3C1',
      pawPadHighlight: '#FFE4E8',
      whiskers: '#475569',
      shadow: 'rgba(51, 65, 85, 0.2)',
    },
    honey: {
      bodyPrimary: '#FBBF24',
      bodyHighlight: '#FDE68A',
      bodyShadow: '#D97706',
      bodyStroke: '#78350F',
      bellyTop: '#FEF9C3',
      bellyBottom: '#FEF08A',
      innerEarStart: '#FFCCD5',
      innerEarEnd: '#FF85A1',
      earFluff: '#FFFBEB',
      nose: '#E11D48',
      noseHighlight: '#FF758F',
      irisOuter: '#0369A1',
      irisInner: '#38BDF8',
      irisGlow: '#BAE6FD',
      pupil: '#082F49',
      pawPad: '#FFCCD5',
      pawPadHighlight: '#FFE4E8',
      whiskers: '#78350F',
      shadow: 'rgba(217, 119, 6, 0.28)',
    },
    smokey: {
      bodyPrimary: '#94A3B8',
      bodyHighlight: '#CBD5E1',
      bodyShadow: '#64748B',
      bodyStroke: '#1E293B',
      bellyTop: '#F8FAFC',
      bellyBottom: '#E2E8F0',
      innerEarStart: '#FFB3C1',
      innerEarEnd: '#FF85A1',
      earFluff: '#F8FAFC',
      nose: '#E11D48',
      noseHighlight: '#FF8FA3',
      irisOuter: '#0284C7',
      irisInner: '#38BDF8',
      irisGlow: '#BAE6FD',
      pupil: '#0F172A',
      pawPad: '#FF8FA3',
      pawPadHighlight: '#FFCCD5',
      whiskers: '#1E293B',
      shadow: 'rgba(30, 41, 59, 0.25)',
    },
  }[theme];

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
        y: [0, -10, 0],
        scaleX: [1, 0.985, 1],
        scaleY: [1, 1.025, 1],
      } : {}}
      transition={!isWalking ? {
        repeat: Infinity,
        duration: 2.0,
        ease: 'easeInOut',
      } : undefined}
    >
      {/* Ground Soft Oval Shadow with synced breath-bounce */}
      <motion.div
        className="absolute bottom-6 w-3/4 h-8 rounded-full blur-md"
        style={{ backgroundColor: themeData.shadow }}
        animate={!isWalking ? {
          scale: [1, 0.91, 1],
          opacity: [0.85, 0.55, 0.85],
        } : {}}
        transition={!isWalking ? {
          repeat: Infinity,
          duration: 2.0,
          ease: 'easeInOut',
        } : undefined}
      />

      <svg
        viewBox="0 0 400 500"
        className="w-full h-full drop-shadow-sm overflow-visible"
        style={{ touchAction: 'none' }}
      >
        <defs>
          {/* Bunny Body 3D Gradient */}
          <radialGradient id="rabbitBodyGrad" cx="40%" cy="30%" r="70%">
            <stop offset="0%" stopColor={themeData.bodyHighlight} />
            <stop offset="60%" stopColor={themeData.bodyPrimary} />
            <stop offset="100%" stopColor={themeData.bodyShadow} />
          </radialGradient>

          {/* Bunny Head 3D Gradient */}
          <radialGradient id="rabbitHeadGrad" cx="45%" cy="35%" r="65%">
            <stop offset="0%" stopColor={themeData.bodyHighlight} />
            <stop offset="60%" stopColor={themeData.bodyPrimary} />
            <stop offset="100%" stopColor={themeData.bodyShadow} />
          </radialGradient>

          {/* Velvet Inner Ear Gradient */}
          <linearGradient id="rabbitInnerEarGrad" x1="0%" y1="0%" x2="0%" y2="100%">
            <stop offset="0%" stopColor={themeData.innerEarStart} />
            <stop offset="100%" stopColor={themeData.innerEarEnd} />
          </linearGradient>

          {/* Belly Fluff Gradient */}
          <linearGradient id="rabbitBellyGrad" x1="0%" y1="0%" x2="0%" y2="100%">
            <stop offset="0%" stopColor={themeData.bellyTop} />
            <stop offset="100%" stopColor={themeData.bellyBottom} />
          </linearGradient>

          {/* Detailed Bunny Iris Radial Gradient */}
          <radialGradient id="rabbitIrisGrad" cx="45%" cy="40%" r="55%">
            <stop offset="0%" stopColor={themeData.irisGlow} />
            <stop offset="55%" stopColor={themeData.irisInner} />
            <stop offset="95%" stopColor={themeData.irisOuter} />
            <stop offset="100%" stopColor="#1E1B4B" />
          </radialGradient>

          {/* Paw Pad Gradient */}
          <linearGradient id="rabbitPawPadGrad" x1="0%" y1="0%" x2="0%" y2="100%">
            <stop offset="0%" stopColor={themeData.pawPadHighlight} />
            <stop offset="100%" stopColor={themeData.pawPad} />
          </linearGradient>

          {/* Soft Shadow Under Head */}
          <filter id="rabbitHeadShadow" x="-10%" y="-10%" width="120%" height="130%">
            <feDropShadow dx="0" dy="5" stdDeviation="4" floodColor="#000000" floodOpacity="0.2" />
          </filter>
        </defs>

        {/* 1. FLUFFY MULTI-LAYER POM-POM COTTON TAIL (Bounces gently) */}
        <motion.g
          animate={{
            scale: isHappy || isTickled ? [1, 1.25, 0.9, 1] : [1, 1.05, 1],
            rotate: isHappy ? [-8, 8, -8] : 0,
          }}
          transition={{ repeat: Infinity, duration: isHappy ? 0.3 : 1.5 }}
          style={{ originX: '310px', originY: '380px' }}
        >
          {/* Cloud pom-pom puffs */}
          <circle cx="310" cy="380" r="22" fill="#E2E8F0" stroke={themeData.bodyStroke} strokeWidth="5" />
          <circle cx="302" cy="372" r="16" fill="#FFFFFF" />
          <circle cx="318" cy="374" r="14" fill="#FFFFFF" />
          <circle cx="312" cy="386" r="16" fill="#FFFFFF" />
        </motion.g>

        {/* 2. BUNNY BODY & BELLY */}
        <motion.g
          animate={{
            scale: isTickled ? [1, 1.04, 0.97, 1] : isListening ? [1, 1.02, 1] : [1, 1.015, 1],
            y: isWalking ? [0, -9, 0, -9, 0] : isTickled ? [0, -6, 2, -4, 0] : [0, -3, 0],
            rotate: isWalking ? [-3, 3, -3] : 0,
          }}
          transition={{
            repeat: isTickled ? 0 : Infinity,
            duration: isWalking ? 0.45 : isTickled ? 0.35 : 2.5,
            ease: 'easeInOut',
          }}
        >
          {/* Main Torso */}
          <path
            d="M130,300 C105,340 100,420 135,445 C165,465 235,465 265,445 C300,420 295,340 270,300 C250,285 150,285 130,300 Z"
            fill="url(#rabbitBodyGrad)"
            stroke={themeData.bodyStroke}
            strokeWidth="7"
            strokeLinejoin="round"
          />

          {/* Touch Zone: BELLY & CHEST FLUFF */}
          <g
            className="cursor-pointer"
            onPointerDown={handleZoneTouch('belly')}
          >
            {/* Scalloped Bunny Chest & Belly Patch */}
            <motion.path
              d="M165,295 C175,305 185,298 200,302 C215,298 225,305 235,295 C255,320 264,365 260,410 C252,442 225,452 200,452 C175,452 148,442 140,410 C136,365 145,320 165,295 Z"
              fill="url(#rabbitBellyGrad)"
              stroke={themeData.bodyStroke}
              strokeWidth="4"
              whileTap={{ scale: 0.95 }}
            />
            {/* Cute Little Carrot Emblem on Belly */}
            <g transform="translate(192, 365) scale(0.9)">
              {/* Carrot Green Leaves */}
              <path d="M8,0 C4,-6 0,-4 3,-1 C-2,-3 -4,-1 1,2 C-2,4 2,4 5,2 Z" fill="#10B981" />
              {/* Carrot Orange Body */}
              <path d="M4,2 C10,2 14,2 10,16 C9,19 7,19 6,16 C2,2 4,2 4,2 Z" fill="#F97316" />
              <line x1="5" y1="5" x2="8" y2="5" stroke="#EA580C" strokeWidth="1" strokeLinecap="round" />
              <line x1="6" y1="9" x2="9" y2="9" stroke="#EA580C" strokeWidth="1" strokeLinecap="round" />
            </g>
          </g>

          {/* Left Foot Paw - Steps when walking */}
          <motion.g
            animate={{ y: isWalking ? [0, -14, 0] : 0 }}
            transition={{ repeat: Infinity, duration: 0.45, ease: 'easeInOut' }}
          >
            <ellipse cx="140" cy="445" rx="34" ry="20" fill="url(#rabbitBodyGrad)" stroke={themeData.bodyStroke} strokeWidth="6" />
            <ellipse cx="140" cy="445" rx="18" ry="10" fill={themeData.bellyTop} />
            {/* Bunny toe separators */}
            <line x1="130" y1="440" x2="130" y2="453" stroke={themeData.bodyStroke} strokeWidth="3" strokeLinecap="round" />
            <line x1="150" y1="440" x2="150" y2="453" stroke={themeData.bodyStroke} strokeWidth="3" strokeLinecap="round" />
          </motion.g>

          {/* Right Foot Paw - Steps opposite phase when walking */}
          <motion.g
            animate={{ y: isWalking ? [-14, 0, -14] : 0 }}
            transition={{ repeat: Infinity, duration: 0.45, ease: 'easeInOut' }}
          >
            <ellipse cx="260" cy="445" rx="34" ry="20" fill="url(#rabbitBodyGrad)" stroke={themeData.bodyStroke} strokeWidth="6" />
            <ellipse cx="260" cy="445" rx="18" ry="10" fill={themeData.bellyTop} />
            <line x1="250" y1="440" x2="250" y2="453" stroke={themeData.bodyStroke} strokeWidth="3" strokeLinecap="round" />
            <line x1="270" y1="440" x2="270" y2="453" stroke={themeData.bodyStroke} strokeWidth="3" strokeLinecap="round" />
          </motion.g>
        </motion.g>

        {/* 3. BUNNY HEAD & LONG EARS */}
        <motion.g
          filter="url(#rabbitHeadShadow)"
          animate={{
            rotate: isListening ? [-3, 4, -3] : isTickled ? [-5, 5, -5] : [0, 1.5, -1.5, 0],
            y: isTalking ? [0, -4, 0] : [0, -2, 0],
          }}
          transition={{
            repeat: Infinity,
            duration: isTalking ? 0.25 : isTickled ? 0.3 : isListening ? 1.0 : 3.0,
            ease: 'easeInOut',
          }}
          style={{ originX: '200px', originY: '240px' }}
        >
          {/* LONG BUNNY EARS (Touch Zone) with Soft Curvature & Fluffy Base Tufts */}
          <g
            className="cursor-pointer"
            onPointerDown={handleZoneTouch('ears')}
          >
            {/* Left Ear */}
            <motion.g
              animate={{
                rotate: isListening ? [0, -10, 0] : isTickled ? [-14, 14, -14] : [0, -3, 0],
              }}
              transition={{ repeat: Infinity, duration: isListening ? 0.6 : 3.0 }}
              style={{ originX: '150px', originY: '160px' }}
            >
              {/* Ear Shape with gentle curve */}
              <path
                d="M135,160 C115,120 110,65 130,25 C142,4 158,15 162,55 C166,95 160,135 155,160 Z"
                fill="url(#rabbitBodyGrad)"
                stroke={themeData.bodyStroke}
                strokeWidth="7"
                strokeLinejoin="round"
              />
              {/* Velvet Inner Ear */}
              <path
                d="M138,150 C124,115 120,68 134,35 C142,20 152,28 155,60 C158,95 154,130 150,150 Z"
                fill="url(#rabbitInnerEarGrad)"
              />
              {/* Fluffy Ear Base Tufts */}
              <path
                d="M125,162 C132,150 144,152 150,140 C154,152 165,148 168,160 Z"
                fill={themeData.earFluff}
                stroke={themeData.bodyStroke}
                strokeWidth="2.5"
              />
            </motion.g>

            {/* Right Ear (Perks up when listening) */}
            <motion.g
              animate={{
                rotate: isListening ? [0, 12, 0] : isTickled ? [14, -14, 14] : [0, 3, 0],
                scale: isListening ? [1, 1.08, 1] : 1,
              }}
              transition={{ repeat: Infinity, duration: isListening ? 0.6 : 3.0 }}
              style={{ originX: '250px', originY: '160px' }}
            >
              <path
                d="M265,160 C285,120 290,65 270,25 C258,4 242,15 238,55 C234,95 240,135 245,160 Z"
                fill="url(#rabbitBodyGrad)"
                stroke={themeData.bodyStroke}
                strokeWidth="7"
                strokeLinejoin="round"
              />
              {/* Velvet Inner Ear */}
              <path
                d="M262,150 C276,115 280,68 266,35 C258,20 248,28 245,60 C242,95 246,130 250,150 Z"
                fill="url(#rabbitInnerEarGrad)"
              />
              {/* Fluffy Ear Base Tufts */}
              <path
                d="M275,162 C268,150 256,152 250,140 C246,152 235,148 232,160 Z"
                fill={themeData.earFluff}
                stroke={themeData.bodyStroke}
                strokeWidth="2.5"
              />
            </motion.g>
          </g>

          {/* Listening ear audio waves */}
          {isListening && (
            <motion.g
              initial={{ opacity: 0, scale: 0.8 }}
              animate={{ opacity: [0.3, 1, 0.3], scale: [0.9, 1.15, 0.9] }}
              transition={{ repeat: Infinity, duration: 0.8 }}
            >
              <path
                d="M295,45 Q325,25 345,55"
                fill="none"
                stroke={themeData.irisInner}
                strokeWidth="5"
                strokeLinecap="round"
              />
              <path
                d="M310,25 Q345,5 365,45"
                fill="none"
                stroke={themeData.irisInner}
                strokeWidth="4"
                strokeLinecap="round"
              />
            </motion.g>
          )}

          {/* SCULPTED BUNNY HEAD with Fluffy Chubby Cheek Tufts */}
          <path
            d="M135,145 C165,130 235,130 265,145 C295,160 305,190 302,215 C316,218 328,226 322,236 C314,242 324,250 318,258 C310,265 316,273 306,278 C280,312 240,318 200,318 C160,318 120,312 94,278 C84,273 90,265 82,258 C76,250 86,242 78,236 C72,226 84,218 98,215 C95,190 105,160 135,145 Z"
            fill="url(#rabbitHeadGrad)"
            stroke={themeData.bodyStroke}
            strokeWidth="7"
            strokeLinejoin="round"
          />

          {/* Cute Forehead Fluff Curl */}
          <path
            d="M194,136 C198,124 204,124 206,136 C202,142 196,142 194,136 Z"
            fill={themeData.bodyHighlight}
            stroke={themeData.bodyStroke}
            strokeWidth="2.5"
          />

          {/* Arched Cute Eyebrows */}
          <g stroke={themeData.bodyStroke} strokeWidth="4" strokeLinecap="round" fill="none">
            <path d={isListening ? "M145,153 Q160,145 175,155" : isTickled ? "M145,150 Q160,156 175,150" : "M145,152 Q160,147 175,152"} />
            <path d={isListening ? "M225,155 Q240,145 255,153" : isTickled ? "M225,150 Q240,156 255,150" : "M225,152 Q240,147 255,152"} />
          </g>

          {/* CHEEKS & WHISKERS (Touch Zone) */}
          <g
            className="cursor-pointer"
            onPointerDown={handleZoneTouch('cheeks')}
          >
            {/* Rosy Cheeks */}
            <motion.ellipse
              cx="124"
              cy="242"
              rx="24"
              ry="16"
              fill="#FF8FA3"
              animate={{ opacity: isHappy ? [0.8, 1, 0.8] : 0.65 }}
              transition={{ repeat: Infinity, duration: 1.0 }}
            />
            <motion.ellipse
              cx="276"
              cy="242"
              rx="24"
              ry="16"
              fill="#FF8FA3"
              animate={{ opacity: isHappy ? [0.8, 1, 0.8] : 0.65 }}
              transition={{ repeat: Infinity, duration: 1.0 }}
            />

            {/* Whiskers Left */}
            <path d="M115,228 Q75,220 40,212" stroke={themeData.whiskers} strokeWidth="5" strokeLinecap="round" fill="none" />
            <path d="M110,244 Q68,244 32,246" stroke={themeData.whiskers} strokeWidth="5" strokeLinecap="round" fill="none" />
            <path d="M114,260 Q72,268 45,280" stroke={themeData.whiskers} strokeWidth="5" strokeLinecap="round" fill="none" />

            {/* Whiskers Right */}
            <path d="M285,228 Q325,220 360,212" stroke={themeData.whiskers} strokeWidth="5" strokeLinecap="round" fill="none" />
            <path d="M290,244 Q332,244 368,246" stroke={themeData.whiskers} strokeWidth="5" strokeLinecap="round" fill="none" />
            <path d="M286,260 Q328,268 355,280" stroke={themeData.whiskers} strokeWidth="5" strokeLinecap="round" fill="none" />
          </g>

          {/* DETAILED GLOSSY BUNNY EYES with Starburst Catchlights */}
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
                <ellipse cx="160" cy="185" rx="21" ry="29" fill="url(#rabbitIrisGrad)" />
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
                <ellipse cx="240" cy="185" rx="21" ry="29" fill="url(#rabbitIrisGrad)" />
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

          {/* SNOUT & HEART NOSE (Twitches playfully) */}
          <motion.g
            animate={{ scaleY: [1, 0.88, 1], y: [0, -2, 0] }}
            transition={{ repeat: Infinity, duration: 0.6 }}
          >
            <path
              d="M200,234 C193,234 186,220 190,216 C194,213 206,213 210,216 C214,220 207,234 200,234 Z"
              fill={themeData.nose}
              stroke={themeData.bodyStroke}
              strokeWidth="3.5"
              strokeLinejoin="round"
            />
            <ellipse cx="196" cy="217" rx="3.5" ry="2" fill={themeData.noseHighlight} />
          </motion.g>

          {/* MOUTH & BUCK TEETH (Talking Tom Mimic) */}
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
                  d={`M186,238 Q200,${246 + mouthOpenY} 214,238 Z`}
                  fill="#6B0515"
                  stroke={themeData.bodyStroke}
                  strokeWidth="5"
                  strokeLinejoin="round"
                />
                {/* Cute Bunny Front Buck Teeth */}
                <rect x="193" y="238" width="6.5" height="9" rx="1.5" fill="#FFFFFF" stroke={themeData.bodyStroke} strokeWidth="2" />
                <rect x="200.5" y="238" width="6.5" height="9" rx="1.5" fill="#FFFFFF" stroke={themeData.bodyStroke} strokeWidth="2" />
              </motion.g>
            ) : (
              <g>
                <path
                  d="M184,238 Q200,248 200,235 Q200,248 216,238"
                  fill="none"
                  stroke={themeData.bodyStroke}
                  strokeWidth="5"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                />
                {/* Cute Tiny Buck Teeth peeking out */}
                <rect x="193.5" y="244" width="6" height="7" rx="1.5" fill="#FFFFFF" stroke={themeData.bodyStroke} strokeWidth="2" />
                <rect x="200.5" y="244" width="6" height="7" rx="1.5" fill="#FFFFFF" stroke={themeData.bodyStroke} strokeWidth="2" />
              </g>
            )}
          </g>
        </motion.g>

        {/* 4. BUNNY PAWS with Chunky Toe Beans (High-Five Zones!) */}
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
            fill="url(#rabbitBodyGrad)"
            stroke={themeData.bodyStroke}
            strokeWidth="7"
            strokeLinejoin="round"
          />
          <ellipse cx="118" cy="336" rx="14" ry="10" fill="url(#rabbitPawPadGrad)" stroke={themeData.bodyStroke} strokeWidth="2" />
          <circle cx="102" cy="322" r="5" fill="url(#rabbitPawPadGrad)" stroke={themeData.bodyStroke} strokeWidth="1.5" />
          <circle cx="117" cy="317" r="5.5" fill="url(#rabbitPawPadGrad)" stroke={themeData.bodyStroke} strokeWidth="1.5" />
          <circle cx="132" cy="322" r="5" fill="url(#rabbitPawPadGrad)" stroke={themeData.bodyStroke} strokeWidth="1.5" />
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
            fill="url(#rabbitBodyGrad)"
            stroke={themeData.bodyStroke}
            strokeWidth="7"
            strokeLinejoin="round"
          />
          <ellipse cx="282" cy="336" rx="14" ry="10" fill="url(#rabbitPawPadGrad)" stroke={themeData.bodyStroke} strokeWidth="2" />
          <circle cx="268" cy="322" r="5" fill="url(#rabbitPawPadGrad)" stroke={themeData.bodyStroke} strokeWidth="1.5" />
          <circle cx="283" cy="317" r="5.5" fill="url(#rabbitPawPadGrad)" stroke={themeData.bodyStroke} strokeWidth="1.5" />
          <circle cx="298" cy="322" r="5" fill="url(#rabbitPawPadGrad)" stroke={themeData.bodyStroke} strokeWidth="1.5" />
        </motion.g>
      </svg>
    </motion.div>
  );
};

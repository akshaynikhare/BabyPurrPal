import React, { useEffect, useState, useCallback } from 'react';

export interface ParticleItem {
  id: string;
  x: number;
  y: number;
  type: 'star' | 'heart' | 'bubble' | 'sparkle' | 'paw';
  color: string;
  size: number;
  vx: number;
  vy: number;
  rotation: number;
  scale: number;
  opacity: number;
}

interface ParticleLayerProps {
  lastTouch: { x: number; y: number; type?: 'star' | 'heart' | 'bubble' | 'sparkle' | 'paw'; count?: number } | null;
}

const COLORS = [
  '#FF758F', // Soft Strawberry
  '#FFB703', // Warm Sunshine
  '#06D6A0', // Gentle Mint
  '#118AB2', // Sky Blue
  '#9D4EDD', // Lavender
  '#FFB3C1', // Rosy Pink
];

export const ParticleLayer: React.FC<ParticleLayerProps> = ({ lastTouch }) => {
  const [particles, setParticles] = useState<ParticleItem[]>([]);

  const spawnParticles = useCallback((x: number, y: number, preferredType?: 'star' | 'heart' | 'bubble' | 'sparkle' | 'paw', count = 7) => {
    const types: ('star' | 'heart' | 'bubble' | 'sparkle' | 'paw')[] = ['star', 'heart', 'bubble', 'sparkle'];
    const newItems: ParticleItem[] = [];

    for (let i = 0; i < count; i++) {
      const angle = Math.random() * Math.PI * 2;
      const speed = Math.random() * 80 + 40;
      const chosenType = preferredType || types[Math.floor(Math.random() * types.length)];
      const color = COLORS[Math.floor(Math.random() * COLORS.length)];

      newItems.push({
        id: `${Date.now()}-${Math.random()}`,
        x,
        y,
        type: chosenType,
        color,
        size: Math.random() * 24 + 18,
        vx: Math.cos(angle) * speed,
        vy: Math.sin(angle) * speed - 60, // slight upward float
        rotation: Math.random() * 360,
        scale: 0.2,
        opacity: 1,
      });
    }

    setParticles((prev) => [...prev.slice(-35), ...newItems]);
  }, []);

  useEffect(() => {
    if (lastTouch) {
      spawnParticles(lastTouch.x, lastTouch.y, lastTouch.type, lastTouch.count || 6);
    }
  }, [lastTouch, spawnParticles]);

  // Animation loop
  useEffect(() => {
    if (particles.length === 0) return;

    let animId: number;
    let lastTime = performance.now();

    const loop = (now: number) => {
      const dt = Math.min((now - lastTime) / 1000, 0.1);
      lastTime = now;

      setParticles((prev) => {
        return prev
          .map((p) => ({
            ...p,
            x: p.x + p.vx * dt,
            y: p.y + p.vy * dt,
            vy: p.vy + 40 * dt, // soft gravity
            scale: Math.min(1.2, p.scale + dt * 3),
            opacity: p.opacity - dt * 1.1,
            rotation: p.rotation + p.vx * dt * 2,
          }))
          .filter((p) => p.opacity > 0.05);
      });

      animId = requestAnimationFrame(loop);
    };

    animId = requestAnimationFrame(loop);
    return () => cancelAnimationFrame(animId);
  }, [particles.length]);

  return (
    <div className="absolute inset-0 pointer-events-none z-30 overflow-hidden">
      {particles.map((p) => (
        <div
          key={p.id}
          className="absolute transition-transform duration-75 ease-out select-none"
          style={{
            transform: `translate3d(${p.x - p.size / 2}px, ${p.y - p.size / 2}px, 0) scale(${p.scale}) rotate(${p.rotation}deg)`,
            opacity: p.opacity,
            width: p.size,
            height: p.size,
          }}
        >
          {p.type === 'heart' && (
            <svg viewBox="0 0 24 24" width="100%" height="100%" fill={p.color}>
              <path d="M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z" />
            </svg>
          )}

          {p.type === 'star' && (
            <svg viewBox="0 0 24 24" width="100%" height="100%" fill={p.color}>
              <path d="M12 17.27L18.18 21l-1.64-7.03L22 9.24l-7.19-.61L12 2 9.19 8.63 2 9.24l5.46 4.73L5.82 21z" />
            </svg>
          )}

          {p.type === 'sparkle' && (
            <svg viewBox="0 0 24 24" width="100%" height="100%" fill={p.color}>
              <path d="M12 0L14.5 9.5L24 12L14.5 14.5L12 24L9.5 14.5L0 12L9.5 9.5z" />
            </svg>
          )}

          {p.type === 'bubble' && (
            <div
              className="w-full h-full rounded-full border-3 shadow-inner"
              style={{
                borderColor: p.color,
                backgroundColor: `${p.color}33`,
              }}
            >
              <div className="w-1.5 h-1.5 bg-white/90 rounded-full mt-1 ml-1" />
            </div>
          )}

          {p.type === 'paw' && (
            <svg viewBox="0 0 24 24" width="100%" height="100%" fill={p.color}>
              <ellipse cx="12" cy="15" rx="5" ry="4" />
              <ellipse cx="6" cy="10" rx="2.5" ry="3" />
              <ellipse cx="10" cy="7" rx="2.5" ry="3.5" />
              <ellipse cx="14" cy="7" rx="2.5" ry="3.5" />
              <ellipse cx="18" cy="10" rx="2.5" ry="3" />
            </svg>
          )}
        </div>
      ))}
    </div>
  );
};

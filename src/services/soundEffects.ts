/**
 * High-quality Web Audio API procedural sound engine for infant reinforcement learning.
 * Synthesizes gentle pentatonic chimes, warm cat purrs, and soothing background lullabies.
 * 100% offline, zero external audio asset dependencies.
 */

class SoundEngine {
  private ctx: AudioContext | null = null;
  private masterGain: GainNode | null = null;
  private lullabyGain: GainNode | null = null;
  private purrGain: GainNode | null = null;
  private purrOsc1: OscillatorNode | null = null;
  private purrOsc2: OscillatorNode | null = null;
  private isPurring = false;
  private isLullabyPlaying = false;
  private lullabyTimer: number | null = null;
  private lullabyIndex = 0;

  // Soothing Pentatonic Frequencies (C Major Pentatonic across 2 octaves)
  // Always sounds harmonious, no dissonant chords, gentle for baby ears
  private pentatonicScale = [
    261.63, // C4
    293.66, // D4
    329.63, // E4
    392.00, // G4
    440.00, // A4
    523.25, // C5
    587.33, // D5
    659.25, // E5
    783.99, // G5
    880.00, // A5
  ];

  // Gentle lullaby chord progressions
  private lullabyChords = [
    [261.63, 329.63, 392.00], // C maj
    [220.00, 261.63, 329.63], // A min
    [174.61, 261.63, 329.63], // F maj
    [196.00, 246.94, 293.66], // G maj
  ];

  public init() {
    if (!this.ctx) {
      const AudioContextClass = window.AudioContext || (window as unknown as { webkitAudioContext: typeof AudioContext }).webkitAudioContext;
      this.ctx = new AudioContextClass();
      this.masterGain = this.ctx.createGain();
      this.masterGain.gain.setValueAtTime(0.8, this.ctx.currentTime);
      this.masterGain.connect(this.ctx.destination);

      this.lullabyGain = this.ctx.createGain();
      this.lullabyGain.gain.setValueAtTime(0.25, this.ctx.currentTime);
      this.lullabyGain.connect(this.masterGain);
    }

    if (this.ctx.state === 'suspended') {
      this.ctx.resume();
    }
  }

  public getAudioContext(): AudioContext {
    if (!this.ctx) {
      this.init();
    }
    return this.ctx!;
  }

  /**
   * Plays a harmonious pentatonic bell/chime on touch.
   * Perfect reinforcement feedback for infants.
   */
  public playChime(pitchIndex?: number) {
    this.init();
    if (!this.ctx || !this.masterGain) return;

    const idx = pitchIndex !== undefined 
      ? pitchIndex % this.pentatonicScale.length 
      : Math.floor(Math.random() * this.pentatonicScale.length);
    const freq = this.pentatonicScale[idx];

    const now = this.ctx.currentTime;
    const osc = this.ctx.createOscillator();
    const gain = this.ctx.createGain();
    const filter = this.ctx.createBiquadFilter();

    // Warm rounded bell tone
    osc.type = 'sine';
    osc.frequency.setValueAtTime(freq, now);

    // Warm low-pass filter to keep sound soft and gentle
    filter.type = 'lowpass';
    filter.frequency.setValueAtTime(1600, now);

    // Gentle strike & exponential decay envelope
    gain.gain.setValueAtTime(0.0001, now);
    gain.gain.linearRampToValueAtTime(0.35, now + 0.015);
    gain.gain.exponentialRampToValueAtTime(0.0001, now + 0.7);

    // Harmonic overtone for glassy bell sparkle
    const overtone = this.ctx.createOscillator();
    const overGain = this.ctx.createGain();
    overtone.type = 'sine';
    overtone.frequency.setValueAtTime(freq * 2, now);
    overGain.gain.setValueAtTime(0.08, now);
    overGain.gain.exponentialRampToValueAtTime(0.0001, now + 0.35);

    osc.connect(filter);
    filter.connect(gain);
    gain.connect(this.masterGain);

    overtone.connect(overGain);
    overGain.connect(this.masterGain);

    osc.start(now);
    overtone.start(now);
    osc.stop(now + 0.8);
    overtone.stop(now + 0.4);
  }

  /**
   * Playful giggle wobble for tummy tickle.
   */
  public playGiggle() {
    this.init();
    if (!this.ctx || !this.masterGain) return;

    const now = this.ctx.currentTime;
    const steps = [400, 560, 480, 640, 520, 700];

    steps.forEach((freq, i) => {
      if (!this.ctx || !this.masterGain) return;
      const t = now + i * 0.07;
      const osc = this.ctx.createOscillator();
      const gain = this.ctx.createGain();

      osc.type = 'triangle';
      osc.frequency.setValueAtTime(freq, t);
      osc.frequency.exponentialRampToValueAtTime(freq * 1.2, t + 0.06);

      gain.gain.setValueAtTime(0.0001, t);
      gain.gain.linearRampToValueAtTime(0.2, t + 0.01);
      gain.gain.exponentialRampToValueAtTime(0.0001, t + 0.06);

      osc.connect(gain);
      gain.connect(this.masterGain);

      osc.start(t);
      osc.stop(t + 0.07);
    });
  }

  /**
   * Warm high-five paw sound: marimba/woodblock resonance.
   */
  public playPawTap() {
    this.init();
    if (!this.ctx || !this.masterGain) return;

    const now = this.ctx.currentTime;
    const osc = this.ctx.createOscillator();
    const gain = this.ctx.createGain();

    osc.type = 'triangle';
    osc.frequency.setValueAtTime(320, now);
    osc.frequency.exponentialRampToValueAtTime(140, now + 0.15);

    gain.gain.setValueAtTime(0.0001, now);
    gain.gain.linearRampToValueAtTime(0.3, now + 0.01);
    gain.gain.exponentialRampToValueAtTime(0.0001, now + 0.2);

    osc.connect(gain);
    gain.connect(this.masterGain);

    osc.start(now);
    osc.stop(now + 0.25);
  }

  /**
   * Rosy cheek twinkle sound.
   */
  public playTwinkle() {
    this.init();
    if (!this.ctx || !this.masterGain) return;

    const now = this.ctx.currentTime;
    const notes = [659.25, 783.99, 987.77, 1318.51];

    notes.forEach((freq, i) => {
      if (!this.ctx || !this.masterGain) return;
      const t = now + i * 0.05;
      const osc = this.ctx.createOscillator();
      const gain = this.ctx.createGain();

      osc.type = 'sine';
      osc.frequency.setValueAtTime(freq, t);

      gain.gain.setValueAtTime(0.0001, t);
      gain.gain.linearRampToValueAtTime(0.18, t + 0.01);
      gain.gain.exponentialRampToValueAtTime(0.0001, t + 0.2);

      osc.connect(gain);
      gain.connect(this.masterGain);

      osc.start(t);
      osc.stop(t + 0.25);
    });
  }

  /**
   * Realistic soothing cat purr using low frequency oscillators.
   */
  public startPurr() {
    this.init();
    if (!this.ctx || !this.masterGain || this.isPurring) return;

    this.isPurring = true;
    const now = this.ctx.currentTime;

    this.purrGain = this.ctx.createGain();
    this.purrGain.gain.setValueAtTime(0.0001, now);
    this.purrGain.gain.linearRampToValueAtTime(0.35, now + 0.3);

    const filter = this.ctx.createBiquadFilter();
    filter.type = 'bandpass';
    filter.frequency.setValueAtTime(80, now);
    filter.Q.setValueAtTime(1.5, now);

    // Primary purr rumble oscillator (26Hz)
    this.purrOsc1 = this.ctx.createOscillator();
    this.purrOsc1.type = 'sawtooth';
    this.purrOsc1.frequency.setValueAtTime(26, now);

    // Purr rhythm modulation (motor breath effect at 3.5Hz)
    const lfo = this.ctx.createOscillator();
    const lfoGain = this.ctx.createGain();
    lfo.type = 'sine';
    lfo.frequency.setValueAtTime(3.6, now);
    lfoGain.gain.setValueAtTime(12, now);
    lfo.connect(this.purrOsc1.frequency);
    lfo.start(now);

    this.purrOsc1.connect(filter);
    filter.connect(this.purrGain);
    this.purrGain.connect(this.masterGain);

    this.purrOsc1.start(now);
  }

  /**
   * Gentle, cute puppy woof / playful bark.
   */
  public playPuppyWoof() {
    this.init();
    if (!this.ctx || !this.masterGain) return;

    const now = this.ctx.currentTime;
    const osc = this.ctx.createOscillator();
    const gain = this.ctx.createGain();
    const filter = this.ctx.createBiquadFilter();

    // Cute puppy yip: 280Hz -> 420Hz -> 220Hz
    osc.type = 'triangle';
    osc.frequency.setValueAtTime(260, now);
    osc.frequency.linearRampToValueAtTime(460, now + 0.06);
    osc.frequency.exponentialRampToValueAtTime(220, now + 0.22);

    filter.type = 'bandpass';
    filter.frequency.setValueAtTime(500, now);
    filter.Q.setValueAtTime(1.2, now);

    gain.gain.setValueAtTime(0.0001, now);
    gain.gain.linearRampToValueAtTime(0.38, now + 0.03);
    gain.gain.exponentialRampToValueAtTime(0.0001, now + 0.24);

    osc.connect(filter);
    filter.connect(gain);
    gain.connect(this.masterGain);

    osc.start(now);
    osc.stop(now + 0.26);
  }

  /**
   * Playful puppy panting / tail wag hum.
   */
  public playPuppyPant() {
    this.init();
    if (!this.ctx || !this.masterGain) return;

    const now = this.ctx.currentTime;
    for (let i = 0; i < 3; i++) {
      const t = now + i * 0.12;
      const osc = this.ctx.createOscillator();
      const gain = this.ctx.createGain();

      osc.type = 'sine';
      osc.frequency.setValueAtTime(180, t);
      osc.frequency.exponentialRampToValueAtTime(120, t + 0.08);

      gain.gain.setValueAtTime(0.0001, t);
      gain.gain.linearRampToValueAtTime(0.12, t + 0.02);
      gain.gain.exponentialRampToValueAtTime(0.0001, t + 0.09);

      osc.connect(gain);
      gain.connect(this.masterGain);

      osc.start(t);
      osc.stop(t + 0.1);
    }
  }

  /**
   * Sweet bunny squeak / chirp.
   */
  public playBunnySqueak() {
    this.init();
    if (!this.ctx || !this.masterGain) return;

    const now = this.ctx.currentTime;
    const osc = this.ctx.createOscillator();
    const gain = this.ctx.createGain();

    // High sweet upward chirp: 880Hz -> 1320Hz
    osc.type = 'sine';
    osc.frequency.setValueAtTime(880, now);
    osc.frequency.exponentialRampToValueAtTime(1380, now + 0.12);

    gain.gain.setValueAtTime(0.0001, now);
    gain.gain.linearRampToValueAtTime(0.24, now + 0.02);
    gain.gain.exponentialRampToValueAtTime(0.0001, now + 0.22);

    osc.connect(gain);
    gain.connect(this.masterGain);

    osc.start(now);
    osc.stop(now + 0.24);
  }

  /**
   * Bunny carrot munch / crunch sound.
   */
  public playCarrotCrunch() {
    this.init();
    if (!this.ctx || !this.masterGain) return;

    const now = this.ctx.currentTime;
    const clicks = [740, 920, 680, 840];
    clicks.forEach((freq, i) => {
      if (!this.ctx || !this.masterGain) return;
      const t = now + i * 0.06;
      const osc = this.ctx.createOscillator();
      const gain = this.ctx.createGain();

      osc.type = 'triangle';
      osc.frequency.setValueAtTime(freq, t);
      osc.frequency.exponentialRampToValueAtTime(freq * 0.5, t + 0.04);

      gain.gain.setValueAtTime(0.0001, t);
      gain.gain.linearRampToValueAtTime(0.2, t + 0.01);
      gain.gain.exponentialRampToValueAtTime(0.0001, t + 0.045);

      osc.connect(gain);
      gain.connect(this.masterGain);

      osc.start(t);
      osc.stop(t + 0.05);
    });
  }

  /**
   * Soft walking footstep pitter-patter sound when animal enters.
   */
  public playFootstep() {
    this.init();
    if (!this.ctx || !this.masterGain) return;

    const now = this.ctx.currentTime;
    const osc = this.ctx.createOscillator();
    const gain = this.ctx.createGain();

    osc.type = 'triangle';
    osc.frequency.setValueAtTime(180, now);
    osc.frequency.exponentialRampToValueAtTime(80, now + 0.06);

    gain.gain.setValueAtTime(0.0001, now);
    gain.gain.linearRampToValueAtTime(0.15, now + 0.01);
    gain.gain.exponentialRampToValueAtTime(0.0001, now + 0.07);

    osc.connect(gain);
    gain.connect(this.masterGain);

    osc.start(now);
    osc.stop(now + 0.08);
  }

  public stopPurr() {
    if (!this.isPurring || !this.purrGain || !this.ctx) return;
    const now = this.ctx.currentTime;
    this.purrGain.gain.linearRampToValueAtTime(0.0001, now + 0.25);

    setTimeout(() => {
      try {
        this.purrOsc1?.stop();
        this.purrOsc1?.disconnect();
        this.purrOsc2?.stop();
        this.purrOsc2?.disconnect();
      } catch {
        // Safe disconnect
      }
      this.isPurring = false;
      this.purrOsc1 = null;
      this.purrOsc2 = null;
    }, 280);
  }

  /**
   * Gentle, soothing ambient lullaby background loop for 1-year olds.
   */
  public toggleLullaby(enable?: boolean): boolean {
    this.init();
    const target = enable !== undefined ? enable : !this.isLullabyPlaying;

    if (target && !this.isLullabyPlaying) {
      this.isLullabyPlaying = true;
      this.playNextLullabyChord();
      return true;
    } else if (!target && this.isLullabyPlaying) {
      this.isLullabyPlaying = false;
      if (this.lullabyTimer) {
        window.clearTimeout(this.lullabyTimer);
        this.lullabyTimer = null;
      }
      return false;
    }
    return this.isLullabyPlaying;
  }

  public isLullabyActive(): boolean {
    return this.isLullabyPlaying;
  }

  public setLullabyVolume(vol: number) {
    if (this.lullabyGain && this.ctx) {
      const v = Math.max(0, Math.min(1, vol));
      this.lullabyGain.gain.setTargetAtTime(v * 0.35, this.ctx.currentTime, 0.05);
    }
  }

  private playNextLullabyChord() {
    if (!this.isLullabyPlaying || !this.ctx || !this.lullabyGain) return;

    const chord = this.lullabyChords[this.lullabyIndex % this.lullabyChords.length];
    this.lullabyIndex++;
    const now = this.ctx.currentTime;

    // Arpeggiate the soothing notes
    chord.forEach((freq, i) => {
      if (!this.ctx || !this.lullabyGain) return;
      const t = now + i * 0.45;
      const osc = this.ctx.createOscillator();
      const gain = this.ctx.createGain();
      const filter = this.ctx.createBiquadFilter();

      osc.type = 'sine';
      osc.frequency.setValueAtTime(freq, t);

      filter.type = 'lowpass';
      filter.frequency.setValueAtTime(900, t);

      gain.gain.setValueAtTime(0.0001, t);
      gain.gain.linearRampToValueAtTime(0.18, t + 0.1);
      gain.gain.exponentialRampToValueAtTime(0.0001, t + 2.8);

      osc.connect(filter);
      filter.connect(gain);
      gain.connect(this.lullabyGain);

      osc.start(t);
      osc.stop(t + 3.0);
    });

    this.lullabyTimer = window.setTimeout(() => {
      this.playNextLullabyChord();
    }, 3200);
  }
}

export const sound = new SoundEngine();

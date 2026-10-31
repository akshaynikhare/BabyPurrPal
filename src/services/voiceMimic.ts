/**
 * Talking Tom Voice Mimic Engine.
 * 100% client-side, offline voice activity detection and pitch-shifted playback
 * with real-time mouth opening amplitude dispatch.
 */

import { sound } from './soundEffects';

export type VoiceState = 'IDLE' | 'LISTENING' | 'MIMICKING' | 'PERMISSION_REQUIRED' | 'UNSUPPORTED';

export interface VoiceMimicCallbacks {
  onStateChange: (state: VoiceState) => void;
  onVolumeChange: (volume: number) => void; // 0 to 1 input volume
  onMouthAmplitude: (amplitude: number) => void; // 0 to 1 playback mouth sync
}

export class VoiceMimicEngine {
  private state: VoiceState = 'IDLE';
  private stream: MediaStream | null = null;
  private audioCtx: AudioContext | null = null;
  private sourceNode: MediaStreamAudioSourceNode | null = null;
  private inputAnalyser: AnalyserNode | null = null;
  private processorNode: ScriptProcessorNode | null = null;

  // Recording buffers
  private recordedChunks: Float32Array[] = [];
  private recordingSampleRate = 44100;
  private isSpeechActive = false;
  private silenceTimer: number | null = null;
  private minSpeechDuration = 400; // ms
  private silenceThresholdMs = 700; // ms of silence before replay
  private speechStartTime = 0;

  // Sensitivity threshold (RMS energy)
  private speechThreshold = 0.035;
  // Playback pitch multiplier (Talking Tom cute high-pitch)
  private pitchMultiplier = 1.45;

  private callbacks: VoiceMimicCallbacks | null = null;
  private playbackSource: AudioBufferSourceNode | null = null;
  private playbackAnalyser: AnalyserNode | null = null;
  private playbackAnimFrame: number | null = null;

  public setCallbacks(cbs: VoiceMimicCallbacks) {
    this.callbacks = cbs;
  }

  public setSensitivity(level: 'low' | 'normal' | 'high') {
    switch (level) {
      case 'low':
        this.speechThreshold = 0.06; // Needs louder sound
        break;
      case 'high':
        this.speechThreshold = 0.02; // Very sensitive to soft infant coos
        break;
      case 'normal':
      default:
        this.speechThreshold = 0.035;
        break;
    }
  }

  public setPitch(pitch: number) {
    this.pitchMultiplier = Math.max(1.1, Math.min(2.0, pitch));
  }

  public getPitch(): number {
    return this.pitchMultiplier;
  }

  public getState(): VoiceState {
    return this.state;
  }

  /**
   * Initializes microphone capture for Talking Tom loop.
   */
  public async start(): Promise<boolean> {
    if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
      this.setState('UNSUPPORTED');
      return false;
    }

    try {
      this.audioCtx = sound.getAudioContext();
      if (this.audioCtx.state === 'suspended') {
        await this.audioCtx.resume();
      }

      this.recordingSampleRate = this.audioCtx.sampleRate;

      this.stream = await navigator.mediaDevices.getUserMedia({
        audio: {
          echoCancellation: true,
          noiseSuppression: true,
          autoGainControl: true,
        },
      });

      this.sourceNode = this.audioCtx.createMediaStreamSource(this.stream);
      this.inputAnalyser = this.audioCtx.createAnalyser();
      this.inputAnalyser.fftSize = 512;
      this.inputAnalyser.smoothingTimeConstant = 0.3;

      // Use ScriptProcessorNode to buffer samples in pure PCM
      this.processorNode = this.audioCtx.createScriptProcessor(2048, 1, 1);

      this.processorNode.onaudioprocess = (e) => {
        if (this.state === 'MIMICKING') return;

        const inputData = e.inputBuffer.getChannelData(0);
        this.processAudioInput(inputData);
      };

      this.sourceNode.connect(this.inputAnalyser);
      this.sourceNode.connect(this.processorNode);
      // Connect to destination via zero-gain to keep script processor alive
      const silentGain = this.audioCtx.createGain();
      silentGain.gain.setValueAtTime(0, this.audioCtx.currentTime);
      this.processorNode.connect(silentGain);
      silentGain.connect(this.audioCtx.destination);

      this.setState('IDLE');
      return true;
    } catch {
      this.setState('PERMISSION_REQUIRED');
      return false;
    }
  }

  public stop() {
    if (this.silenceTimer) {
      window.clearTimeout(this.silenceTimer);
      this.silenceTimer = null;
    }
    if (this.playbackAnimFrame) {
      window.cancelAnimationFrame(this.playbackAnimFrame);
      this.playbackAnimFrame = null;
    }
    if (this.playbackSource) {
      try {
        this.playbackSource.stop();
        this.playbackSource.disconnect();
      } catch {
        // Safe disconnect
      }
      this.playbackSource = null;
    }

    this.processorNode?.disconnect();
    this.sourceNode?.disconnect();
    this.inputAnalyser?.disconnect();

    if (this.stream) {
      this.stream.getTracks().forEach((track) => track.stop());
      this.stream = null;
    }

    this.recordedChunks = [];
    this.isSpeechActive = false;
    this.setState('IDLE');
  }

  private processAudioInput(inputData: Float32Array) {
    // Calculate RMS volume level
    let sum = 0;
    for (let i = 0; i < inputData.length; i++) {
      sum += inputData[i] * inputData[i];
    }
    const rms = Math.sqrt(sum / inputData.length);
    const normalizedVol = Math.min(1, rms * 8);

    this.callbacks?.onVolumeChange(normalizedVol);

    const isLoudEnough = rms > this.speechThreshold;

    if (isLoudEnough) {
      if (!this.isSpeechActive) {
        // Baby started babbling!
        this.isSpeechActive = true;
        this.speechStartTime = performance.now();
        this.recordedChunks = [];
        this.setState('LISTENING');
      }

      // Collect audio frame
      this.recordedChunks.push(new Float32Array(inputData));

      // Reset any pending silence trigger
      if (this.silenceTimer) {
        window.clearTimeout(this.silenceTimer);
        this.silenceTimer = null;
      }
    } else if (this.isSpeechActive) {
      // Continue recording slightly into silence so audio doesn't cut abruptly
      this.recordedChunks.push(new Float32Array(inputData));

      if (!this.silenceTimer) {
        this.silenceTimer = window.setTimeout(() => {
          this.finishRecordingAndReplay();
        }, this.silenceThresholdMs);
      }
    }
  }

  private finishRecordingAndReplay() {
    this.silenceTimer = null;
    const duration = performance.now() - this.speechStartTime;

    if (!this.isSpeechActive || duration < this.minSpeechDuration || this.recordedChunks.length === 0) {
      // Too short / accidental tap click
      this.isSpeechActive = false;
      this.recordedChunks = [];
      this.setState('IDLE');
      return;
    }

    this.isSpeechActive = false;
    this.replayVoice();
  }

  /**
   * Replays recorded speech pitch-shifted like Talking Tom with mouth-sync!
   */
  public replayVoice(customBuffer?: AudioBuffer) {
    if (!this.audioCtx) return;
    this.setState('MIMICKING');

    let audioBuffer = customBuffer;
    if (!audioBuffer) {
      // Calculate total sample length
      const totalLength = this.recordedChunks.reduce((acc, chunk) => acc + chunk.length, 0);
      if (totalLength === 0) {
        this.setState('IDLE');
        return;
      }

      // Merge chunks into single AudioBuffer
      audioBuffer = this.audioCtx.createBuffer(1, totalLength, this.recordingSampleRate);
      const channel = audioBuffer.getChannelData(0);
      let offset = 0;
      for (const chunk of this.recordedChunks) {
        channel.set(chunk, offset);
        offset += chunk.length;
      }
      this.recordedChunks = [];
    }

    // Playback with pitch multiplier
    const source = this.audioCtx.createBufferSource();
    source.buffer = audioBuffer;
    source.playbackRate.setValueAtTime(this.pitchMultiplier, this.audioCtx.currentTime);

    const analyser = this.audioCtx.createAnalyser();
    analyser.fftSize = 256;
    analyser.smoothingTimeConstant = 0.2;

    const gainNode = this.audioCtx.createGain();
    gainNode.gain.setValueAtTime(1.1, this.audioCtx.currentTime);

    source.connect(analyser);
    analyser.connect(gainNode);
    gainNode.connect(this.audioCtx.destination);

    this.playbackSource = source;
    this.playbackAnalyser = analyser;

    // Monitor playback amplitude to drive the cat's mouth open and close!
    const timeData = new Uint8Array(analyser.frequencyBinCount);
    const monitorMouth = () => {
      if (this.state !== 'MIMICKING' || !this.playbackAnalyser) {
        this.callbacks?.onMouthAmplitude(0);
        return;
      }

      analyser.getByteTimeDomainData(timeData);
      let sum = 0;
      for (let i = 0; i < timeData.length; i++) {
        const v = (timeData[i] - 128) / 128;
        sum += v * v;
      }
      const amp = Math.min(1, Math.sqrt(sum / timeData.length) * 3.5);
      this.callbacks?.onMouthAmplitude(amp);

      this.playbackAnimFrame = window.requestAnimationFrame(monitorMouth);
    };

    source.onended = () => {
      if (this.playbackAnimFrame) {
        window.cancelAnimationFrame(this.playbackAnimFrame);
        this.playbackAnimFrame = null;
      }
      this.callbacks?.onMouthAmplitude(0);
      this.playbackSource = null;
      this.playbackAnalyser = null;
      this.setState('IDLE');
    };

    source.start(0);
    this.playbackAnimFrame = window.requestAnimationFrame(monitorMouth);
  }

  /**
   * Simulated cute baby babble / kitten meow for testing or if mic is denied.
   */
  public simulateTalkingTom() {
    this.audioCtx = sound.getAudioContext();
    if (!this.audioCtx) return;

    // Generate a cute playful babble sound programmatically
    const sampleRate = this.audioCtx.sampleRate;
    const duration = 1.4;
    const buffer = this.audioCtx.createBuffer(1, sampleRate * duration, sampleRate);
    const data = buffer.getChannelData(0);

    // Cute pitch melody: "Ba-ba-boo-meow!"
    const pitchMap = [
      { t: 0.0, f: 520 },
      { t: 0.3, f: 650 },
      { t: 0.6, f: 440 },
      { t: 0.9, f: 720 },
    ];

    for (let i = 0; i < data.length; i++) {
      const time = i / sampleRate;
      let targetFreq = 520;
      for (const p of pitchMap) {
        if (time >= p.t) targetFreq = p.f;
      }

      // Vocal formant modulation (mouth open/close envelope)
      const syllable = Math.sin(time * 24) * 0.5 + 0.5;
      const carrier = Math.sin(2 * Math.PI * targetFreq * time);
      const overtone = Math.sin(2 * Math.PI * targetFreq * 2 * time) * 0.3;
      data[i] = (carrier + overtone) * syllable * 0.45;
    }

    this.replayVoice(buffer);
  }

  private setState(newState: VoiceState) {
    this.state = newState;
    this.callbacks?.onStateChange(newState);
  }
}

export const voiceEngine = new VoiceMimicEngine();

/**
 * Tactile Haptic Feedback Service using Web Vibration API.
 * Provides subtle, sensory vibration patterns for toddler motor reinforcement on Android.
 * Safe fallback for non-supporting browsers and desktop.
 */

class HapticsService {
  private hasVibration(): boolean {
    return typeof navigator !== 'undefined' && 'vibrate' in navigator && typeof navigator.vibrate === 'function';
  }

  private trigger(pattern: number | number[]) {
    try {
      if (this.hasVibration()) {
        navigator.vibrate(pattern);
      }
    } catch {
      // Safe catch if device or policy blocks vibration
    }
  }

  /**
   * Subtle micro-tick for standard screen and background touches (8ms)
   */
  public tap() {
    this.trigger(8);
  }

  /**
   * Playful gentle rhythmic flutter for tummy tickles and giggles
   */
  public tickle() {
    this.trigger([14, 30, 14, 30, 18]);
  }

  /**
   * Warm rumbling pulse that simulates a cat's purr motor in the baby's hands
   */
  public purr() {
    this.trigger([24, 40, 24, 40, 24]);
  }

  /**
   * Round tactile bump for high-five paw claps and paws taps (22ms)
   */
  public paw() {
    this.trigger(22);
  }

  /**
   * Crisp double-tick for cheek blushes and bell sparkles
   */
  public twinkle() {
    this.trigger([10, 25, 10]);
  }

  /**
   * Playful bounce pulse for puppy woofs and bunny squeaks
   */
  public bounce() {
    this.trigger([16, 32, 16]);
  }

  /**
   * Rich double-pulse reward when feeding treats (milk, fish, bone, carrot)
   */
  public feed() {
    this.trigger([20, 40, 28]);
  }

  /**
   * Soft subtle step tick synced to footsteps during animal walk-in
   */
  public step() {
    this.trigger(10);
  }
}

export const haptics = new HapticsService();

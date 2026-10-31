# PurrPal Design System & Visual Specification

A complete guide to color tokens, SVG character anatomy, typography, motion curves, and tactile feedback for PurrPal.

---

## 1. Design Philosophy

- **Zero-Pill Discipline**: Informational controls and status tags use clean unboxed text or soft circular buttons.
- **Dimensional 2D Cartoon Style**: Handcrafted SVG vector art with multi-stop radial and linear gradients, soft ambient occlusion shadows, fluffy fur tuft silhouettes, and multi-catchlight glossy cartoon eyes.
- **Anti-Overstimulation**: Warm pastel daytime surfaces and deep navy nocturnal gradients respecting infant circadian rhythms.

---

## 2. Character Palette Tokens

### Kitty Cat (`CatCharacter.tsx`)
| Token Name | Midnight Theme | Ginger Theme | Cloud Theme | Purpose |
|---|---|---|---|---|
| `bodyPrimary` | `#2B2D46` | `#EE734C` | `#F8FAFC` | Core torso & head fill |
| `bodyHighlight` | `#3F4365` | `#FA9371` | `#FFFFFF` | Upper specular volume |
| `bodyShadow` | `#1B1C2E` | `#C85330` | `#E2E8F0` | Underside ambient depth |
| `bodyStroke` | `#141524` | `#913115` | `#334155` | 7px rounded vector contour |
| `bellyTop` | `#FFF8F0` | `#FFF4EB` | `#FFFFFF` | Chest fur bib highlight |
| `bellyBottom` | `#F2E3D0` | `#FCE0CE` | `#F1F5F9` | Lower belly shadow |
| `innerEarStart`| `#FFA8BA` | `#FFCCD5` | `#FFB3C1` | Ear canal velvet gradient start |
| `innerEarEnd` | `#FF6B8B` | `#FF85A1` | `#FF758F` | Ear canal shadow base |
| `irisOuter` | `#D97706` | `#0D9488` | `#0284C7` | Limbal ring border |
| `irisInner` | `#FBBF24` | `#2DD4BF` | `#38BDF8` | Radial iris glow |
| `pupil` | `#0F101A` | `#132A27` | `#0F172A` | Deep cartoon pupil |
| `nose` | `#FF4D6D` | `#E63946` | `#FF4D6D` | Triangular nose heart |
| `pawPad` | `#FF8FA3` | `#FF8FA3` | `#FF8FA3` | Toe beans & paw center |

### Puppy Dog (`DogCharacter.tsx`)
| Token Name | Golden Theme | Chocolate Theme | Spotted Dalmatian | Purpose |
|---|---|---|---|---|
| `bodyPrimary` | `#F59E0B` | `#78350F` | `#FFFFFF` | Puppy coat primary |
| `bodyHighlight` | `#FCD34D` | `#92400E` | `#FFFFFF` | Specular head highlight |
| `bodyShadow` | `#B45309` | `#451A03` | `#CBD5E1` | Underbelly shadow |
| `bodyStroke` | `#78350F` | `#2D1302` | `#1E293B` | 7px soft contour line |
| `ears` | `#D97706` | `#582405` | `#334155` | Floppy ear flap tone |
| `snoutTop` | `#FFFBEB` | `#F5EBE0` | `#FFFFFF` | Muzzle top |
| `snoutBottom` | `#FEF3C7` | `#E6CCB2` | `#F1F5F9` | Muzzle bottom depth |
| `nose` | `#1E202B` | `#181A24` | `#0F172A` | Wet shiny dog nose |
| `irisOuter` | `#78350F` | `#065F46` | `#1D4ED8` | Limbal ring |
| `irisInner` | `#B45309` | `#059669` | `#3B82F6` | Iris center |
| `collar` | `#EF4444` | `#3B82F6` | `#10B981` | Puppy neck band |
| `medallion` | `#FBBF24` | `#FBBF24` | `#FBBF24` | Golden star medal |

### Bunny Rabbit (`RabbitCharacter.tsx`)
| Token Name | White Theme | Honey Theme | Smokey Theme | Purpose |
|---|---|---|---|---|
| `bodyPrimary` | `#FFFFFF` | `#FBBF24` | `#94A3B8` | Bunny coat primary |
| `bodyHighlight` | `#FFFFFF` | `#FDE68A` | `#CBD5E1` | Ear & forehead highlight |
| `bodyShadow` | `#E2E8F0` | `#D97706` | `#64748B` | Torso underside |
| `bodyStroke` | `#334155` | `#78350F` | `#1E293B` | 7px outline stroke |
| `innerEarStart`| `#FFA8BA` | `#FFCCD5` | `#FFB3C1` | Long ear velvet gradient |
| `innerEarEnd` | `#FF758F` | `#FF85A1` | `#FF85A1` | Base ear depth |
| `irisOuter` | `#E11D48` | `#0369A1` | `#0284C7` | Ruby/sapphire outer rim |
| `irisInner` | `#FB7185` | `#38BDF8` | `#38BDF8` | Iris radiant center |
| `nose` | `#FF4D6D` | `#E11D48` | `#E11D48` | Twitching heart nose |
| `pawPad` | `#FFB3C1` | `#FFCCD5` | `#FF8FA3` | Soft bunny paw pads |

---

## 3. SVG Character Anatomy & Geometry

All characters are authored in a standardized `0 0 400 500` SVG viewBox coordinate frame:

```
0,0 ────────────────────────────────────────── 400,0
 │                                               │
 │    Ears: y: 25 - 190 (Touch Zone 'ears')      │
 │                                               │
 │    Eyes & Cheeks: y: 150 - 260                │
 │    ('cheeks' & 'mouth' Touch Zones)           │
 │                                               │
 │    Front Paws: x: 90 - 150, x: 250 - 310      │
 │    ('leftPaw', 'rightPaw' Touch Zones)        │
 │                                               │
 │    Torso & Belly: y: 290 - 460                │
 │    ('belly' Touch Zone)                       │
 │                                               │
0,500 ──────────────────────────────────────── 400,500
```

### The 3-Tiered Cheek Fur Tuft Formula
Instead of primitive ovals, the head outlines use compound cubic Bézier curves defining 3 distinct soft fur tufts extending from the jawline:
```svg
<path d="M135,145 C165,130 235,130 265,145 C295,160 305,190 302,215
         C316,218 328,226 322,236 C314,242 324,250 318,258
         C310,265 316,273 306,278 C280,312 240,318 200,318
         C160,318 120,312 94,278 C84,273 90,265 82,258
         C76,250 86,242 78,236 C72,226 84,218 98,215
         C95,190 105,160 135,145 Z" />
```

### Eye Specular Catchlight Geometry
Every open eye incorporates a multi-tier light-reflection system to create cartoon life and soul:
1. **Sclera**: `ellipse rx="30" ry="38" fill="#FFFFFF"` with 5.5px dark contour.
2. **Iris Radial Gradient**: `radialGradient cx="45%" cy="40%" r="55%"`.
3. **Limbal Ring**: `strokeWidth="2" opacity="0.6"` outer iris border.
4. **Pupil**: Midnight oval `rx="14" ry="22"`.
5. **Lower Iris Ambient Crescent**: Light crescent path reflecting ambient bounce light from cheeks.
6. **Diamond Starburst Sparkle**: 4-point star catchlight centered at top-left (`cx=152, cy=172`).
7. **Secondary Micro Circle**: 3.5px pure white glint at bottom-right (`cx=168, cy=192`).

---

## 4. Motion & Animation Timing Tokens

| Movement | Duration | Easing | Transform Animated |
|---|---|---|---|
| Idle Bouncing (Pet) | 2.0s – 2.2s | `easeInOut` loop | `y: [0, -8, 0]`, `scaleY: [1, 1.015, 1]` |
| Ground Shadow Scale | 2.0s – 2.2s | `easeInOut` loop | `scale: [1, 0.92, 1]`, `opacity: [0.85, 0.6, 0.85]` |
| Walk-in Waddle | 1.1s | `cubic-bezier(0.25, 0.1, 0.25, 1)` | `x: [-260 -> 0]`, waddle `rotate: [-3, 3, -3]` |
| Tail Wagging | 0.2s (happy) / 1.2s (idle) | `easeInOut` loop | `rotate: [-16, 16, -16]` |
| Blinking Cycle | Every 3.4s – 3.8s | 200ms duration | Eye crescent swap |
| Face Zoom (Pinch/Tap)| Spring (`stiffness: 240, damping: 24`) | Natural settle | `scale: 1.85`, `origin: 50% 36%` |
| High-Five Paw Raise | 200ms up, 500ms hold | Snappy spring | `y: -40px`, `rotate: 18deg`, `scale: 1.15` |

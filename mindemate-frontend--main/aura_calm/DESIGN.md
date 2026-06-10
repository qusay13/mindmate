# Design System: Mindful Sanctuary

## 1. Overview & Creative North Star
**Creative North Star: "The Digital Sanctuary"**
Mindful Sanctuary is a high-end editorial experience designed to facilitate introspection and calm. It moves away from the rigid, utilitarian "app" feel by embracing the flow of a lifestyle magazine. The system prioritizes breathing room, tonal depth, and tactile softness.

The design breaks the standard grid through **Intentional Asymmetry**: large-scale hero sections bleed into gradients, while bento-style grids use varying card heights and internal padding to create a rhythm that feels curated rather than computer-generated. Elements overlap slightly—such as floating navigation bars and decorative blurred orbs—to suggest a space that exists in layers.

## 2. Colors
The palette is built on "Expressive" logic, utilizing soft indigos, teals, and sage greens to evoke emotional balance.

*   **Primary (#4C55B6):** Used for brand identity and active states.
*   **Secondary & Tertiary:** Used for categorical differentiation (e.g., Tasks vs. Journaling) to provide visual cues without over-reliance on text labels.
*   **The "No-Line" Rule:** Sectioning is achieved through color blocks and background shifts. 1px borders are strictly prohibited for layout containment. Use `surface-container-low` against `surface` to define areas.
*   **Surface Hierarchy:** 
    *   `surface_container_lowest` (#ffffff) for high-elevation floating cards.
    *   `surface_container_low` (#f1f3fa) for inset UI elements like mood buttons.
*   **Glass & Gradient Rule:** Navigation and headers must use `rgba(255, 255, 255, 0.7)` with a `20px` backdrop blur. Use linear and radial gradients (e.g., `primary-fixed` to `secondary-fixed-dim`) for high-impact hero moments.

## 3. Typography
The system uses a dual-font strategy: **Plus Jakarta Sans** for high-energy headers and **Manrope** for legible, sophisticated body content.

**Typography Scale (Ground Truth):**
*   **Display/Hero:** 2.25rem (36px) — Extra bold, tight tracking (-0.02em).
*   **Headline 1:** 1.875rem (30px) — Bold, used for section titles.
*   **Headline 2:** 1.5rem (24px) — Semi-bold.
*   **Body Large:** 1.125rem (18px) — For editorial quotes or lead-ins.
*   **Body Standard:** 0.875rem (14px) — Primary interface text.
*   **Labels/Captions:** 0.75rem (12px), 11px, or 10px — Always uppercase with wide tracking (0.1em) for a premium, utilitarian feel.

The hierarchy communicates a "voice" that is both authoritative (Bold Headlines) and approachable (Medium-weight Body).

## 4. Elevation & Depth
Elevation is expressed through **Tonal Layering** and ambient light rather than harsh shadows.

*   **The Layering Principle:** Build depth by stacking `surface_container_lowest` cards on `surface` backgrounds.
*   **Ambient Shadows:** Use the "Custom Shadow" profile: `0 10px 40px rgba(45, 51, 59, 0.06)`. This creates a soft, lifted effect that feels like paper on a desk.
*   **The "Ghost Border" Fallback:** If differentiation is required on light backgrounds, use `outline-variant` at 10% opacity.
*   **Glassmorphism:** All "floating" containers (top and bottom navigation) utilize `backdrop-blur-xl` to maintain a sense of context with the content beneath them.

## 5. Components
*   **Buttons:** 
    *   Primary: Pill-shaped (rounded-full), bold text, no border.
    *   Tertiary/Action: High-contrast color with icons (e.g., Indigo text on white glass).
*   **Mood Chips:** Large, squircle-shaped buttons (`rounded-lg`) using `surface-container-low`. They should feel like physical "pads" to press.
*   **Progress Bars:** Segmented into logical phases. Completed segments use `primary` color with a `white/20` overlay for a crystalline texture.
*   **Input Fields:** Ghost-style textareas with `surface-container-high` backgrounds, avoiding borders unless focused.
*   **Cards (Bento):** Defined by `custom-shadow` and `2rem` (lg) or `1rem` (default) corner radii.

## 6. Do's and Don'ts
### Do:
*   Use wide internal padding (at least 2rem/32px for large cards).
*   Use emojis as large visual anchors (text-4xl).
*   Utilize italics for editorial prompts to create a "hand-written" emotional connection.
*   Embrace whitespace as a functional element of the user's "sanctuary."

### Don't:
*   Don't use sharp 90-degree corners; the minimum radius is 1rem.
*   Don't use solid black (#000) for text; use `on-surface` (#2d333b) to maintain softness.
*   Don't use standard Material "Shadow-2"; only use the custom diffused ambient shadow.
*   Don't crowd more than 3 distinct color roles into a single viewport.
---
name: improve-leafmark-ui
description: >-
  Design, implement, review, or audit Leafmark SwiftUI screens.
  Use for UI/UX changes, new screens, layout or navigation changes, and visual polish.
  Also use for accessibility, Dynamic Type, dark mode, UI states, and screenshot review.
---

# Improve Leafmark UI

Translate subjective requests into explicit design constraints.
Implement the smallest coherent change.
Verify the result in the states users will encounter.

## 1. Frame the change

Before editing code:

1. Inspect the current screen, its source, and a recent screenshot or simulator rendering.
2. State the user goal, the primary action, and the information that must remain visible.
3. Question whether the current screen structure or interaction is necessary.
   Propose an information-architecture change when it would remove steps or choices.
4. Define acceptance criteria. Avoid unmeasurable directions such as "make it feel modern."

For a new or substantially reworked flow, describe each screen's role before implementation.
Name its primary action.
Prefer one primary action per state.

## 2. Follow Leafmark's design language

Keep the reading experience content-first and native to iOS:

- Let book covers and book content provide visual character. Keep app chrome restrained.
- Prefer standard SwiftUI controls, materials, navigation, and system behaviors.
- Use semantic colors such as `.primary`, `.secondary`, `.tint`, and system backgrounds.
  Avoid separate hard-coded colors when semantic colors support both appearances.
- Use Dynamic Type text styles such as `.body`, `.headline`, and `.caption`. Reserve fixed point
  sizes for non-text symbols or artwork.
- Use the established 8-point radius for small elements and 12-point radius for cards.
  Do not introduce a token or component until a decision recurs.
- Keep accent color usage sparse and functional.

Treat the existing app and its approved screenshots as the primary reference.
When proposing another product, name the exact quality to borrow.
Examples include spacing, hierarchy, and navigation behavior.
Do not copy its branding.

## 3. Implement all relevant states

Account for normal, empty, loading, and error states where the feature can produce them. Exercise
long titles, missing metadata, zero items, and large collections when they affect layout.

For interactive elements:

- Provide at least a 44 by 44 point hit area.
- Add a meaningful accessibility label when the visible content or symbol is not self-explanatory.
- Add hints only when the resulting action is not clear from the label.
- Expose state through accessibility values or labels for toggles and selected items.
- Combine or contain children so VoiceOver reads a useful unit rather than visual fragments.
- Do not rely on color alone to communicate state.

Avoid decoration that does not clarify hierarchy, state, or interaction.
This includes containers, gradients, shadows, and animation.

## 4. Verify before handoff

Run the relevant unit tests and build the app. Then inspect the changed flow in the simulator.
Use XcodeBuildMCP for simulator builds and UI inspection when available.

Check every applicable item:

- Light and dark appearance
- Default and largest accessibility text size
- A small iPhone and the supported iPad layout
- Portrait and landscape when the screen supports both
- Normal, empty, and loading states
- Error and extreme-data states
- VoiceOver labels and values
- VoiceOver reading order and grouped content
- 44 by 44 point minimum hit areas
- No clipped or truncated essential content
- No overlapping or off-screen essential content

Record what was actually verified. Do not claim manual, VoiceOver, device, or state coverage that
was not exercised.

## 5. Separate implementation from review

After implementation, give the diff and verification evidence to an independent reviewer.
Use a fresh context.
Ask the reviewer to find defects in:

- Information hierarchy and unnecessary actions
- Accessibility and touch targets
- Dynamic Type, appearance, device-size, and orientation behavior
- Missing states and extreme data
- Inconsistency with the design language above

Keep review read-only. Apply only concrete findings, then rerun affected checks.

## Source

This workflow adapts the constraint-first UI process from the following article:
[「いい感じにして」で終わらせない](https://qiita.com/kotaro_ai_lab/items/159438982341578a8a81).

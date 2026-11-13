# Design System

Two surfaces share one look: the **Roblox game UI** (ScreenGui, Luau) and the **web dashboard** (React). Status: Proposal - needs approval (all values below are first proposals; contrast to be measured in Phase 5).

## Design direction
- Brand attributes: warm market bazaar (parchment, ink, stamped prices); lively but readable; merchants have personality, numbers are always honest.
- Supported devices: Roblox on desktop (primary, demo device) and mobile Roblox (must not break); web dashboard on desktop 1280+ (primary) and 390 px phone (readable).
- References (borrow, do not copy): a hand-written market price board (chalk numbers that change), a trading terminal's tape of recent deals, speech bubbles from classic RPG shopkeepers.

## UI tokens
| Token | Value | Usage |
| --- | --- | --- |
| color.background | #F4ECDD (parchment) | Main canvas (web), panel fill (Roblox) |
| color.surface | #FFF9EE | Cards, chat bubbles |
| color.border | #D9C7A6 | Card and panel borders |
| color.text | #2B2118 (ink) | Primary copy |
| color.muted | #6E5D4A | Secondary copy, captions |
| color.primary | #B4471F (stamp red) | Main actions: Accept, Fast-forward |
| color.accent.wood | #A8661C | Wood series, icons |
| color.accent.fish | #1E7A78 | Fish series, icons |
| color.accent.iron | #4F5D6B | Iron series, icons |
| color.success | #2F7A3B | Deal done, price down for buyer |
| color.warning | #B07A12 | Pending deal, low patience |
| color.tier.common / rare / epic / legendary | #5B626C / #2A5FB4 / #8A3FC2 / #8A5E00 | Item rarity text (boards, bag, chips); each >= 4.86:1 on background and surface |
| color.error | #A12C2C | Failed deal, refused (always with text label) |
| color.focus | #1F5FBF | Focus ring (web) |
| font.display | Fraunces 600 (web); Fondamento (Roblox, `Font.fromName`) | Titles, merchant names. Reason: hand-lettered market-sign voice, readable from 20 px |
| font.body | IBM Plex Sans 400, 16/24 (web); Merriweather 18 px min (Roblox) | Body copy, chat. Reason: screen-reading serif that matches the parchment look |
| font.numeric | IBM Plex Mono 500 (web); Merriweather Bold (Roblox) | Prices, balances. Reason: a mono face reads as terminal, not market board (changed 2026-11-13, v4) |
| space.unit | 4 px (web); 4 px scale in Offset (Roblox) | Spacing scale 4/8/12/16/24/32/48 |
| radius.control | 8 px (web); UICorner 8 px (Roblox) | Inputs, buttons, bubbles |

Dark mode: not planned (single light theme on both surfaces; decision logged below).

## Layout rules
- Web: container max 1200 px, gutter 16 px (mobile) / 24 px (desktop); breakpoints 390, 768, 1280. Dashboard grid: 12 columns desktop, 1 column mobile.
- Roblox: ScreenGui with `IgnoreGuiInset = false`; HUD top-left; haggle panel bottom-center, max width 560 px, scales down via UIScale on small screens; nothing covers the center of the screen except the haggle panel.
- Alignment: numbers right-aligned in tables; prices always with "C" suffix (e.g. `12 C`).

## Components
Every interactive component defines default, hover, focus, disabled, loading, success and error states.
- **Primary button (Accept, Fast-forward):** fill color.primary, text #FFF9EE, 44 px min height. Hover: 8% darker. Focus: 2 px color.focus ring (web) / SelectionImageObject (Roblox gamepad). Disabled: 40% opacity + reason text next to it. Loading: label becomes "Settling..." with spinner. Success: brief color.success flash + "Deal done". Error: color.error label with what to do next.
- **Chat input (haggle):** TextBox, placeholder "Make an offer, e.g. 40 for 5 wood". Enter sends. Disabled while waiting for the merchant (shows "Woodcutter is thinking...").
- **Merchant bubble:** surface card with merchant name in font.display, line in font.body, counter price in font.numeric big, mood tag (e.g. "pleased", "annoyed"), reasoning row with an info icon (tooltip text from rules).
- **Patience meter:** 3 pips; empty pips color.warning; at 0 the panel shows "Come back tomorrow" (color.error label + countdown).
- **Price board (Roblox world sign + web card):** good icon, ask, bid, arrow up/down vs last day, stock bar.
- **HUD:** Coin, Wood, Fish, Iron counters with icons; pending deltas shown as "+1" ghost until confirmed.
- **Deal feed (web):** rows: time, player (short name), merchant, good x qty @ price, explorer link icon.
- **Form field (web stretch):** label above, helper below, error below in color.error with icon.

## Accessibility
- Web: full keyboard navigation, visible focus ring, semantic headings, chart has a data table alternative, `prefers-reduced-motion` stops chart animation (shows final state + step buttons). Contrast checked with a contrast checker in Phase 5.
- Roblox: text min 18 px, no information by color alone (arrows + labels), chat works with keyboard Enter; gamepad selection for Accept/Leave.

## Screen states
| Screen | Empty | Loading | Error | Populated |
| --- | --- | --- | --- | --- |
| Roblox HUD | "0" counters | Counters show "..." until first balance | "Market offline - your goods are safe" banner | Live counters |
| Roblox haggle panel | Greeting line + suggested offer | "<Merchant> is thinking..." | Fallback rule-based reply (never empty) | Bubble + counter + Accept |
| Roblox price board | "Opening soon" | Last known prices greyed | Last known prices + "stale" tag | Live prices |
| Web dashboard | "No deals yet - be the first in Haggle Town" | Skeleton cards | "Can't reach the market. Retrying in 5 s." | Charts, purses, feed, leaderboard |
| Web fast-forward | Button only | "Simulating a week..." progress | "Simulation file missing" + retry | Animated chart |

## Approval
Design owner: nabil. Source of truth: this file + docs/superpowers/specs/2026-11-10-haggle-town-design.md.

---

## Hackathon UI addendum

### 1. Screen inventory
| Screen | PRD journey / feature | Purpose | Key components | States | Wireframe |
| --- | --- | --- | --- | --- | --- |
| Roblox town (world) | J1 / F-02, F-09 | Gather, walk to merchants, see board | Gather nodes, merchant stalls, price board, leaderboard board | see above | W1 |
| Roblox HUD | J1 / F-01, F-02 | Balances | HUD counters | see above | W2 |
| Roblox haggle panel | J1-J4 / F-03, F-04, F-06 | Haggle and accept | Merchant bubble, chat input, patience, Accept, Leave | see above | W3 |
| Web dashboard | J5 / F-07, F-09 | Show economy + chain | Price chart, purse cards, deal feed, leaderboard | see above | W4 |
| Web fast-forward | J5 / F-08 | Week in 60 s | Button, animated chart, day counter | see above | W4 |
| Web game (stretch) | J6 / F-12 | Play without Roblox | Gather buttons, haggle panel (same as W3), HUD | same as Roblox | W5 |

### 2. Flow
Golden path: join -> HUD shows 1000 C -> walk to forest -> ProximityPrompt "Chop" x3 -> walk to Woodcutter -> ProximityPrompt "Haggle" -> panel opens -> type offer -> bubble with counter -> Accept -> "Settling..." -> "Deal done" -> HUD updates -> price board arrow moves.
Main failure branch: Accept -> settle rejected (price moved) -> bubble "Prices just moved, now it's X" -> Accept again or Leave.

### 3. Wireframes (ASCII; to be redrawn in Roblox Studio and the web build)
W1 Roblox town (top view)
```
 [Forest: Chop]        [Mine: Dig]
        \                 /
   [Woodcutter]  PRICE BOARD  [Smith]
            \    LEADERBOARD   /
              [ Market square ]
                    |
             [Pier: Fish] [Fishmonger]
```
W2 HUD (top-left)
```
+-------------------------------------+
| Coin 112 C  Wood 3  Fish 0  Iron 1  |
+-------------------------------------+
```
W3 Haggle panel (bottom-center)
```
+------------------------------------------------+
| WOODCUTTER  (pleased)            patience o o o |
| "Too much wood, friend. 4 C each, take it."     |
| Counter: 4 C x 5 = 20 C      (i) stock 140/100  |
| [ Make an offer...                     ] [Send] |
| [ Accept 20 C ]                        [ Leave ] |
+------------------------------------------------+
```
W4 Web dashboard (desktop)
```
+-- Haggle Town market -------------------- [Fast-forward a week] --+
| Price chart (Wood / Fish / Iron, ask lines)          | Leaderboard |
|------------------------------------------------------|  1. ...     |
| Woodcutter purse 980 C stock 140 | Fishmonger ... | Smith ...      |
|--------------------------------------------------------------------|
| Deal feed: 12:01 Rina bought 5 Wood @4 from Woodcutter  [tx]       |
| Chat/reasoning feed: Smith: "Ten? I have 3 iron left" (i) stock 3  |
+--------------------------------------------------------------------+
```
W5 Web game (stretch): HUD row, three gather buttons, merchant picker, haggle panel identical to W3.

### 4. Type scale
Web: h1 40/48 Fraunces 600, h2 28/36, h3 22/28, h4 18/24, body 16/24 Plex Sans, small 14/20, caption 12/16; numbers Plex Mono 500; max line length 70ch. Fallbacks: Georgia, system-ui, ui-monospace. Fonts from Google Fonts (OFL).
Roblox: titles FredokaOne 28 px, body BuilderSans 18-20 px, numbers RobotoMono 20 px; TextScaled off, sizes fixed with UIScale for small screens.

### 5. Color roles
Background #F4ECDD, surface #FFF9EE, border #D9C7A6, text #2B2118, muted #6E5D4A, primary #B4471F, accents wood #A8661C / fish #1E7A78 / iron #4F5D6B, success #2F7A3B, warning #B07A12, error #A12C2C, focus #1F5FBF. Light theme only. Contrast ratios: Not run (check in Phase 5; text on background target >= 4.5:1).

### 6. Spacing and grid
4 px base, scale 4/8/12/16/24/32/48; container 1200 px; breakpoints 390/768/1280; mobile-first CSS.

### 7. Icons and imagery
Web: Lucide icons (ISC license). Roblox: simple flat decals for Coin/Wood/Fish/Iron drawn as basic shapes in Studio or free Creator Store models with attribution in README. Logo: wordmark "Haggle Town" in Fraunces with a stamped coin.

### 8. Motion
Durations 120 ms (hover), 200 ms (panel open), 400 ms (price board tick); easing ease-out. Animate: panel open/close, price arrow change, "+1" ghost counters, fast-forward chart. `prefers-reduced-motion`: no chart animation, step buttons instead. Wow moment: fast-forward week chart drawing itself while the day counter ticks 1 -> 7.

### 9. Voice and copy
Merchants: short, warm, a bit cheeky, in character, max 2 sentences. UI labels: verbs ("Accept 20 C", "Leave", "Chop"). Errors: what happened + what to do ("Prices just moved. New price 5 C - accept or leave."). Empty states invite action. **Inside Roblox never use: crypto, blockchain, NFT, token, wallet, NEAR, gas, transaction.** Web dashboard may name NEAR and show explorer links.

### 10. Demo conditions
Demo device: Windows laptop, Roblox client 1920x1080 for recording; dashboard in a browser at 1280 px; network: home wifi, backend on Railway; legibility: 1080p recording, text >= 18 px.

### 11. Component inventory
Web: no UI library; plain React components + CSS variables in `web/src/theme.css`; chart library chosen once in ARCHITECTURE. Roblox: custom ScreenGui modules in `roblox/src/client/ui/` (Hud, HagglePanel, PriceBoard).

### 12. Do / Don't
- Do use tokens only; no inline hex outside `web/src/theme.css` / `roblox/src/shared/Theme.luau`.
- Do ship every state (empty, loading, error, populated) per screen before the next screen.
- Do show prices with the "C" suffix and right-aligned.
- Do keep merchant reasoning text rule-based and true.
- Don't show any chain words or account names inside Roblox.
- Don't add a UI library or new fonts.
- Don't block the Roblox screen with modals other than the haggle panel.
- Don't rely on color alone; arrows + labels.
- Don't animate when reduced motion is set.
- Don't leave dead buttons on the golden path.

### 13. Design decisions log
| Date | Decision | Reason |
| --- | --- | --- |
| 2026-11-10 | One light "parchment market" theme for both surfaces | Consistent identity; less work than dark+light |
| 2026-11-10 | No chain words inside Roblox | Track bonus + Roblox policy |
| 2026-11-10 | Reasoning tooltip from rules, not LLM | Always true, cheap, explainable |

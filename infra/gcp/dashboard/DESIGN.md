# hapai Design System

hapai's visual identity is built on the same philosophy as the software itself:
deterministic, explicit, and without decoration that obscures function.
Inspired by BMW's design language — precision engineering made visible.

## Core Principle

> "Remove everything that does not contribute information. What remains must be perfect."

No shadows. No gradients. No border-radius. Contrast comes from color mass,
not decoration. Every pixel earns its place.

---

## Color

| Token                | Hex       | Usage                                              |
|----------------------|-----------|----------------------------------------------------|
| `--color-blue`       | `#1c69d4` | Interactive only: buttons, links, focus rings      |
| `--color-black`      | `#000000` | Navigation bar, logo, dark section backgrounds     |
| `--color-near-black` | `#262626` | Primary body text, headings                        |
| `--color-meta-gray`  | `#757575` | Secondary text, chart tick labels, captions        |
| `--color-light-gray` | `#f0f0f0` | Card borders, table dividers, subtle backgrounds   |
| `--color-white`      | `#ffffff` | Page background, card surfaces                     |
| `--color-deny`       | `#c0392b` | Deny events: badges, chart series                  |
| `--color-warn`       | `#e67e22` | Warn events: badges, chart series                  |
| `--color-allow`      | `#27ae60` | Allow events: badges only                          |

**Rule:** `--color-blue` is used **only** on interactive elements. Never for text,
backgrounds, or decoration.

---

## Typography

Font stack: `'Helvetica Neue', Arial, sans-serif`
System stack — no web font download. hapai loads instantly.

| Weight | Value | Usage                                          |
|--------|-------|------------------------------------------------|
| Light  | 300   | Hero stat numbers, chart values                |
| Normal | 400   | Table data, body text                          |
| Bold   | 700   | Labels, table headers, button text             |
| Black  | 900   | Logo/wordmark, navigation items                |

Type scale (8px base unit):

| Size  | Weight | Usage                                      |
|-------|--------|--------------------------------------------|
| 11px  | 700    | Uppercase labels, badges (letter-spacing: 0.08em) |
| 14px  | 400    | Table data, body                           |
| 16px  | 700    | Card titles, section headers               |
| 32px  | 300    | Medium stat values                         |
| 56px  | 300    | Hero stat numbers                          |

---

## Spacing

Base unit: **8px**

| Token       | Value |
|-------------|-------|
| `--space-1` |  8px  |
| `--space-2` | 16px  |
| `--space-3` | 24px  |
| `--space-4` | 32px  |
| `--space-6` | 48px  |
| `--space-8` | 64px  |

All padding, margin, and gap values must be multiples of 8px.

---

## Shape

- **Border-radius: 0** everywhere. Zero exceptions.
- **No box-shadows.** Depth comes from color blocks and borders.
- Card border: `1px solid #f0f0f0`
- Active/selected accent: `border-left: 4px solid #1c69d4`

---

## Layout

Dashboard grid:

```
[ denials ] [ warnings ] [ timeline chart ──────────── ]
[ recent events table ─────────────────────────────── ]
[ hooks doughnut ] [ tools h-bar ] [ projects v-bar ]
[ deny rate trend line ────────────────────────────── ]
```

Max content width: 1400px, centered. Gutter: 24px. Margin: 24px.

---

## Components

### Button — Primary
```css
background: #1c69d4;
color: #ffffff;
border: none;
border-radius: 0;
padding: 12px 24px;
font-weight: 700;
font-size: 14px;
text-transform: uppercase;
letter-spacing: 0.05em;
```
Hover: `background: #1557b0`

### Card
```css
background: #ffffff;
border: 1px solid #f0f0f0;
border-radius: 0;
padding: 24px;
```

### Badge
```css
padding: 2px 8px;
border-radius: 0;
font-size: 11px;
font-weight: 700;
text-transform: uppercase;
letter-spacing: 0.06em;
```
DENY: `background: #c0392b; color: #fff`
WARN: `background: #e67e22; color: #fff`
ALLOW: `background: #27ae60; color: #fff`

### Table
```css
/* Header */
background: #262626; color: #ffffff;
font-weight: 700; font-size: 11px;
text-transform: uppercase; letter-spacing: 0.08em;
padding: 12px 16px;

/* Cell */
border-bottom: 1px solid #f0f0f0;
padding: 12px 16px;
```

### Navigation Bar
```css
background: #000000;
height: 56px;
padding: 0 24px;
```

---

## Chart Configuration (Chart.js)

```javascript
{
  plugins: {
    legend: { labels: { color: '#262626', font: { weight: '700', size: 12 } } }
  },
  scales: {
    x: { ticks: { color: '#757575', font: { size: 11 } }, grid: { color: '#f0f0f0' } },
    y: { ticks: { color: '#757575', font: { size: 11 } }, grid: { color: '#f0f0f0' } }
  }
}
```

Bar datasets: `borderRadius: 0`, `borderWidth: 0`

---

## Logo / Wordmark

`hapai` — Helvetica Neue Black (900), lowercase.
Lowercase: quiet and unobtrusive, always running.
Black weight: absolute, non-negotiable.

White on black background (nav). Black on white (splash screen).
Never use `--color-blue` for the wordmark.

---

## Motion

Functional transitions only:
- Content fade-in: `opacity 0→1, 200ms ease`
- No parallax, hover lift, or bounce effects

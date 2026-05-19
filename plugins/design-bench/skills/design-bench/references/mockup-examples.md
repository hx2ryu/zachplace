# Mockup HTML Examples (LLM Reference)

Examples of well-formed mockup HTML for `design-bench`. Use these as
**structural** references only — do NOT copy verbatim. Adapt to the
recommendation's specific content.

## Rules (must follow)

1. Top-level wrapper: `<div class="mockup-frame" data-platform="mobile|desktop">`
2. Width is fixed by platform: mobile = 375px, desktop = 1280px.
3. **`box-sizing: border-box`** on the wrapper — so `padding` is included
   inside the fixed width and the mockup never exceeds the viewport. Apply
   `box-sizing: border-box` globally via `*, *::before, *::after`.
4. All colors, spacing, radii, fonts go through CSS variables:
   `var(--color-primary)`, `var(--space-4)`, etc.
5. No raw hex (`#fff`), no external assets (`<img src="https://...">`),
   no external CSS/JS.
6. Inline `<style>` block at top is OK. `design-tokens.css` is loaded
   automatically by the wrapper context.

---

## Example 1: Pricing tier card (desktop)

```html
<!doctype html>
<html><head><meta charset="utf-8">
<style>
  *, *::before, *::after { box-sizing: border-box; }
  body { margin: 0; font-family: var(--font-sans); color: var(--color-fg); background: var(--color-bg); }
  .mockup-frame { width: 1280px; padding: var(--space-8); }
  .tier-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: var(--space-4); }
  .tier { border: 1px solid var(--color-border); border-radius: var(--radius-md); padding: var(--space-4); }
  .tier.featured { border-color: var(--color-primary); border-width: 2px; }
  .tier h3 { margin: 0 0 var(--space-2) 0; font-size: var(--text-lg); }
  .tier .price { font-size: 32px; font-weight: 600; margin: var(--space-4) 0; }
  .tier button { width: 100%; padding: var(--space-2); background: var(--color-primary); color: white; border: none; border-radius: var(--radius-sm); }
</style>
</head><body>
<div class="mockup-frame" data-platform="desktop">
  <div class="tier-grid">
    <div class="tier"><h3>Free</h3><div class="price">$0</div><button>Get Started</button></div>
    <div class="tier featured"><h3>Pro</h3><div class="price">$12</div><button>Get Started</button></div>
    <div class="tier"><h3>Team</h3><div class="price">$99</div><button>Get Started</button></div>
  </div>
</div>
</body></html>
```

## Example 2: Onboarding step (mobile)

```html
<!doctype html>
<html><head><meta charset="utf-8">
<style>
  *, *::before, *::after { box-sizing: border-box; }
  body { margin: 0; font-family: var(--font-sans); color: var(--color-fg); background: var(--color-bg); }
  .mockup-frame { width: 375px; padding: var(--space-4); }
  .progress { display: flex; gap: var(--space-1); margin-bottom: var(--space-8); }
  .dot { flex: 1; height: 4px; border-radius: 2px; background: var(--color-border); }
  .dot.active { background: var(--color-primary); }
  h1 { font-size: var(--text-lg); margin: 0 0 var(--space-2) 0; }
  p { color: var(--color-muted); font-size: var(--text-sm); margin: 0 0 var(--space-8) 0; }
  button { width: 100%; padding: var(--space-4); background: var(--color-primary); color: white; border: none; border-radius: var(--radius-md); }
</style>
</head><body>
<div class="mockup-frame" data-platform="mobile">
  <div class="progress">
    <div class="dot active"></div>
    <div class="dot active"></div>
    <div class="dot"></div>
  </div>
  <h1>What's your goal?</h1>
  <p>Pick one — you can always change it later.</p>
  <button>Continue</button>
</div>
</body></html>
```

## Example 3: Empty-state list (mobile)

```html
<!doctype html>
<html><head><meta charset="utf-8">
<style>
  *, *::before, *::after { box-sizing: border-box; }
  body { margin: 0; font-family: var(--font-sans); color: var(--color-fg); background: var(--color-bg); }
  .mockup-frame { width: 375px; padding: var(--space-4); }
  .empty { text-align: center; padding: var(--space-8) 0; }
  .icon { width: 48px; height: 48px; border-radius: var(--radius-lg); background: var(--color-border); margin: 0 auto var(--space-4); }
  h2 { font-size: var(--text-md); margin: 0 0 var(--space-1) 0; }
  p { color: var(--color-muted); font-size: var(--text-sm); margin: 0 0 var(--space-4) 0; }
  button { padding: var(--space-2) var(--space-4); background: var(--color-primary); color: white; border: none; border-radius: var(--radius-sm); }
</style>
</head><body>
<div class="mockup-frame" data-platform="mobile">
  <div class="empty">
    <div class="icon"></div>
    <h2>No projects yet</h2>
    <p>Start by creating your first project.</p>
    <button>+ New Project</button>
  </div>
</div>
</body></html>
```

## Example 4: Dashboard widget (desktop)

```html
<!doctype html>
<html><head><meta charset="utf-8">
<style>
  *, *::before, *::after { box-sizing: border-box; }
  body { margin: 0; font-family: var(--font-sans); color: var(--color-fg); background: var(--color-bg); }
  .mockup-frame { width: 1280px; padding: var(--space-4); }
  .card { border: 1px solid var(--color-border); border-radius: var(--radius-md); padding: var(--space-4); max-width: 320px; }
  .label { color: var(--color-muted); font-size: var(--text-sm); margin: 0; }
  .value { font-size: 28px; font-weight: 600; margin: var(--space-1) 0 0 0; }
  .delta { color: var(--color-primary); font-size: var(--text-sm); margin-top: var(--space-2); }
</style>
</head><body>
<div class="mockup-frame" data-platform="desktop">
  <div class="card">
    <p class="label">Active users</p>
    <p class="value">12,408</p>
    <p class="delta">+8.2% this week</p>
  </div>
</div>
</body></html>
```

## Anti-Examples (do NOT do this)

```html
<!-- NOT raw hex -->
<div style="background: #2563eb">...</div>

<!-- NOT external image -->
<img src="https://example.com/logo.png">

<!-- NOT external CSS -->
<link rel="stylesheet" href="https://cdn.example.com/styles.css">

<!-- NOT no data-platform attribute -->
<div class="mockup-frame">...</div>
```

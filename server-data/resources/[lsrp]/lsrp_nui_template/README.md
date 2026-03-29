# lsrp_nui_template

Reusable transparent NUI shell/template for future LSRP interfaces.

This resource is meant to be copied as a starting point when building a new UI. It captures the startup and transparency rules that were easy to get wrong when building ad-hoc NUIs.

## What This Template Standardizes

- Transparent `html` and `body` from first paint.
- Hidden startup state so a resource restart does not show a fullscreen black page.
- One root app container that is shown and hidden instead of mutating `html` state.
- Cache-busted CSS and JS asset references.
- A centered shell with status cards, content cards, and primary/secondary actions.

## Files

- `fxmanifest.lua`: minimal manifest with `ui_page` and NUI asset files.
- `client/client.lua`: preview commands plus a minimal `open` and `close` flow.
- `html/index.html`: startup-safe document shell.
- `html/style.css`: transparent-root styling and centered panel layout.
- `html/script.js`: open/close handlers and payload-driven rendering.

## Preview Commands

If you temporarily `ensure lsrp_nui_template`, you can preview it in-game with:

- `/nui_template_preview`
- `/nui_template_close`

## Recommended Pattern For New UIs

1. Copy this folder into a new `lsrp_*` resource.
2. Rename the resource and update the manifest metadata.
3. Replace the sample content in `client/client.lua` with your real open/close flow.
4. Keep the transparent startup shell in `index.html`.
5. Keep the root app hidden by default and only show it from JavaScript when the UI opens.
6. Do not toggle `html` visibility classes unless there is a strong reason.
7. If FiveM serves stale assets during iteration, bump the query string in `index.html`.

## Payload Shape

The shell accepts this message shape:

```js
{
  action: 'open',
  payload: {
    eyebrow: 'LSRP Template',
    title: 'Reusable NUI Shell',
    subtitle: 'Short description',
    statusItems: [
      { label: 'Mode', value: 'Preview' },
      { label: 'Focus', value: 'Mouse + Keyboard' }
    ],
    sections: [
      { title: 'Section title', body: 'Section content' }
    ],
    primary: { label: 'Confirm', event: 'confirm' },
    secondary: { label: 'Cancel', event: 'cancel' },
    footer: 'Footer copy'
  }
}
```

## Notes

- The template favors the ATM/hacking-safe pattern: transparent root plus a single hidden app container.
- If a specific UI needs a dimmed or stylized fullscreen layer, add it inside the root app instead of styling `body` or `html` directly.
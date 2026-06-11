# End-to-end verification recipes

Concrete Layer 2 recipes for driving the **running** app and observing real behavior. Tool-agnostic: use whichever capability the environment has, in this preference order.

**UI driving / video:** Playwright MCP → chrome-devtools MCP → mobile-mcp (native) → raw `playwright` / `npx playwright` in the repo → (last resort) the project's own e2e command.

Record artifacts under a temp dir (`$CLAUDE_JOB_DIR/tmp` if set, else `.claude/tmp/`), not in the repo tree. Clean up after, or tell the user where they are.

---

## Backend / service

1. **Boot** the service with the recorded start command. Wait for the ready signal (log line / health endpoint), don't assume it's up.
2. **Exercise** the changed path — hit it directly:
   - Happy path: expected input → assert status code + response body shape + key fields.
   - Error path: bad/missing input → assert the correct 4xx and error body (not a 500).
   - Auth path (if relevant): without creds → 401/403; with creds → 200.
   ```bash
   curl -sS -i -X POST http://localhost:<port>/<route> \
     -H 'content-type: application/json' -d '{...}'
   ```
3. **Watch the logs** during the requests — a 200 with a stack trace in the logs is still a bug. Grep the service output for `error|exception|traceback`.
4. **Tear down** the server.
5. Pass = expected responses AND clean logs.

## Web UI (Playwright)

1. Start the dev server; wait for the URL to respond.
2. Drive the user flow that the change affects — navigate, fill forms, click, wait for results. Use accessible roles/text selectors, not brittle CSS where possible.
3. **Capture state**: screenshot each key step (and at mobile + desktop widths if layout changed).
4. **Assert health, not just pixels**:
   - Console: zero unexpected errors/warnings.
   - Network: no failed (4xx/5xx) requests for the flow.
   - The expected element/text is actually present and visible.
5. **Diff** against a baseline screenshot if one exists; flag meaningful visual deltas.

Minimal raw-Playwright fallback (when no MCP is available):
```js
// npx playwright — saves screenshots + video for review
const { chromium } = require('playwright');
(async () => {
  const browser = await chromium.launch();
  const ctx = await browser.newContext({
    recordVideo: { dir: process.env.CLAUDE_JOB_DIR ? process.env.CLAUDE_JOB_DIR + '/tmp/video' : '.claude/tmp/video' },
    viewport: { width: 1280, height: 800 },
  });
  const page = await ctx.newPage();
  const errors = [];
  page.on('console', m => m.type() === 'error' && errors.push(m.text()));
  page.on('requestfailed', r => errors.push('REQ FAIL ' + r.url()));
  await page.goto('http://localhost:<port>');
  // ...drive the flow, await visible results...
  await page.screenshot({ path: '.claude/tmp/after.png', fullPage: true });
  await ctx.close();           // finalizes the video file
  await browser.close();
  console.log(errors.length ? 'ISSUES:\n' + errors.join('\n') : 'clean');
})();
```

## Video / glitch capture (motion bugs a screenshot misses)

Record the flow as video/trace, then **review the recording** for issues a static shot can't show: animation jank/stutter, flicker, flash-of-unstyled-content, layout shift (CLS), elements popping in late, broken transitions, scroll judder.

Pick the available recorder:
- **Playwright** — `recordVideo` on the browser context (see snippet above); or `page.video()`. Also `--trace on` for a step-by-step trace viewer.
- **chrome-devtools MCP** — `performance_start_trace` / `performance_stop_trace` over the interaction, then read the insights for long tasks, layout shifts, dropped frames.
- **mobile-mcp** (native iOS/Android) — `mobile_start_screen_recording` / `mobile_stop_screen_recording` around the flow.

Review checklist for the recording:
- [ ] Transitions/animations run smoothly (no stutter or dropped frames).
- [ ] No flicker or flash of unstyled/placeholder content.
- [ ] No layout shift after first paint (content doesn't jump).
- [ ] Interactions feel responsive (no visible lag between action and feedback).
- [ ] Nothing renders broken mid-transition.

If you can't programmatically analyze the video, save it and tell the user the exact path so they can scrub it. Don't claim "no glitches" off a recording you didn't actually inspect.

## Reporting Layer 2
For each leg run, report: what you drove, what you observed (paste the key response / attach the screenshot path / name the video file), and pass/fail against the success criteria. State explicitly any leg you couldn't run in this environment.

# Programmatic AEO runs — handoff guide

> Goal: given a **company + competitors**, generate the prompts, run them against
> the real answer engines, score them, and **see the results in the dashboard UI** —
> all from a terminal/Claude Code session, no clicking through the app.
>
> This is a self-contained brief. Another Claude Code session should be able to
> follow it top to bottom. It does **not** require anything deployed — it runs
> against the local Next.js dev server.

---

## 0. What this app is (orientation)

`sovereign-aeo-tracker` is a Next.js 16 app that measures how visible a brand is
inside AI answer engines (ChatGPT, Perplexity, Copilot, Gemini, Google AI, Grok).

- A **run** = one prompt sent to one engine. The engine's answer + citations come
  back, and the app computes a 0–100 **visibility score** for your brand plus
  sentiment and brand/competitor mentions.
- All scraping is one HTTP call: **`POST /api/scrape`** → `{ provider, prompt }` →
  returns `{ answer, sources }`. The heavy lifting (driving a real engine session)
  is done by **Bright Data** behind that route.
- The scoring is **plain string-matching** (not an LLM). It currently lives inside
  `components/sovereign-dashboard.tsx` (~lines 677–758). `scripts/run-company.mjs`
  mirrors it. See **§6** for the clean-up that removes this duplication.

### Where data lives (this is the crux of the "show in UI" part)

- The entire app state for a workspace is **one JSON blob** under the key
  **`sovereign-aeo-tracker-v1`** (the default workspace; other workspaces use
  `sovereign-aeo-tracker-<id>`).
- Storage layer (`lib/client/sovereign-store.ts`):
  - **Local mode (default):** IndexedDB (via `idb-keyval`: DB `keyval-store`,
    object store `keyval`) is the source of truth; `localStorage` is a mirror.
    Reads hit **IndexedDB first**.
  - **Cloud mode (optional):** if Supabase is configured, `/api/state`
    (a key→JSONB table) becomes the source of truth.
- The dashboard reads that blob on mount and renders `state.runs` (a `ScrapeRun[]`).
  So **"show it in the UI" = merge new `ScrapeRun`s into that blob's `runs` array.**

---

## 1. Prerequisites

1. `.env` is populated (it already is locally). Needed keys:
   `BRIGHT_DATA_KEY`, the six `BRIGHT_DATA_DATASET_*` ids, `GEMINI_API_KEY`,
   `OPENROUTER_KEY`.
2. Dev server running:
   ```bash
   npm run dev          # serves http://localhost:3000, auto-loads .env
   ```
   Wait for `✓ Ready`. Confirm: `curl -s -o /dev/null -w '%{http_code}' localhost:3000` → `200`.

> **Known broken provider:** `google_ai` currently 404s — its `.env` dataset id
> `BRIGHT_DATA_DATASET_GOOGLE_AI` (`d_…`) looks malformed vs the others (`gd_…`).
> Leave `google_ai` out of `providers` until that id is fixed, or its scrapes
> silently fail and get dropped from results.

> **Cost note:** every scrape spends real Bright Data credits and takes ~30–60s
> (it drives a live engine session). Keep prompt × provider counts modest. A run
> of 3 prompts × 3 providers ≈ 9 scrapes ≈ 2–3 min wall-clock (they run in parallel).

---

## 2. Define the company (config file)

Create a JSON config (see `scripts/example-company.json` for a working sample):

```json
{
  "brand": {
    "name": "BrightBridge Credit Union",
    "aliases": ["BrightBridge"],
    "websites": ["brightbridgecu.org"]
  },
  "competitors": [
    { "name": "Jeanne D'Arc Credit Union", "aliases": ["Jeanne D'Arc", "JDCU"], "websites": ["jdcu.org"] }
  ],
  "industry": "Credit Union / retail banking",
  "providers": ["chatgpt", "perplexity", "google_ai"],
  "baseUrl": "http://localhost:3000",
  "prompts": [
    "What are the best credit unions for a home mortgage?",
    "Alternatives to Jeanne D'Arc Credit Union (JDCU)",
    "Best credit union for small business banking and loans"
  ]
}
```

### Working out the prompts

The `prompts` array is the one judgement call. Write the questions a **buyer would
actually type into an answer engine** where the brand would hope to appear. Good
patterns:

- Category / "best X for Y": *"best credit union for a home mortgage"*
- Competitor displacement: *"alternatives to <competitor>"*
- Head-to-head: *"<brand> vs <competitor>"*
- Product-specific (use the `industry`/products): *"best credit union for small
  business banking"*

> **Geography matters.** Credit unions (and most local businesses) are regional. If
> the brand serves a specific area, include geo prompts like *"best credit union in
> <city/state>"* — national prompts will under-represent a regional brand.

> **Scoring is literal string matching.** If the brand is discussed but the exact
> name/alias never appears, it scores 0. Put every real alias in `aliases`.

---

## 3. Run it

```bash
node scripts/run-company.mjs scripts/example-company.json
```

What it does (`scripts/run-company.mjs`):
1. builds `prompts × providers` jobs and POSTs each to `/api/scrape` in parallel,
2. scores each answer with the dashboard's exact logic → builds `ScrapeRun[]`,
3. prints a summary table + headline (e.g. *"appeared in 0/9 answers, avg 0/100"*),
4. writes **`public/aeo-inject.json`** (the patch used to load results into the UI).

Example output (the BrightBridge baseline run):

```
BrightBridge Credit Union: appeared in 0/9 answers | avg visibility 0.0/100
```

The `ScrapeRun` objects it produces match the app's type exactly
(`components/dashboard/types.ts`):

```ts
type ScrapeRun = {
  provider: Provider;            // "chatgpt" | "perplexity" | ...
  prompt: string;
  answer: string;
  sources: string[];
  createdAt: string;             // ISO timestamp
  visibilityScore: number;       // 0-100
  sentiment: "positive" | "neutral" | "negative" | "not-mentioned";
  brandMentions: string[];
  competitorMentions: string[];
};
```

---

## 4. Show it in the UI

Pick **one** path. Path A needs zero setup but a one-time human paste. Path B is
fully automatable end-to-end (good for the future "rerun weekly" job) but needs a
one-time Supabase setup.

### Path A — browser console (no setup, local-only)  ← default

The run already wrote `public/aeo-inject.json`, which the dev server serves at
`/aeo-inject.json`. In the browser, with the app open at `http://localhost:3000`,
open DevTools console and paste this snippet **once**:

```js
(async () => {
  const KEY = 'sovereign-aeo-tracker-v1';                 // default workspace
  const patch = await (await fetch('/aeo-inject.json')).json();

  // minimal idb-keyval-compatible access (DB 'keyval-store', store 'keyval')
  const idb = (mode, fn) => new Promise((res, rej) => {
    const o = indexedDB.open('keyval-store');
    o.onupgradeneeded = () => o.result.createObjectStore('keyval');
    o.onsuccess = () => {
      const tx = o.result.transaction('keyval', mode);
      const rq = fn(tx.objectStore('keyval'));
      tx.oncomplete = () => res(rq && rq.result);
      tx.onerror = () => rej(tx.error);
    };
    o.onerror = () => rej(o.error);
  });

  const cur = (await idb('readonly', s => s.get(KEY))) || {};
  const merged = {
    ...cur,
    brand:         { ...(cur.brand || {}), ...patch.brand },
    competitors:   patch.competitors,
    customPrompts: patch.customPrompts,
    runs:          [ ...(cur.runs || []), ...patch.runs ],   // append, don't clobber
  };
  await idb('readwrite', s => s.put(merged, KEY));
  try { localStorage.setItem(KEY, JSON.stringify(merged)); } catch {}
  location.reload();
})();
```

After reload: the **Responses** tab shows the answers (brand/competitor mentions
highlighted), **Visibility Analytics** shows the scores, **Citations** shows cited
domains, and the brand/competitor config is populated.

> Notes:
> - `runs` are **appended**, so re-running adds more without wiping prior data.
> - Open the app at least once before pasting, so IndexedDB is initialised.
> - `competitors` / `customPrompts` are **replaced** with the config's — edit the
>   snippet to merge instead if you don't want that.

### Path B — Supabase cloud (fully automatable, one-time setup)

This makes `/api/state` live, so the script can push results directly (no browser
paste) via `node scripts/run-company.mjs <config> --push`. It's also the foundation
for cloud/scheduled reruns.

1. Create a Supabase project. Run the migration in
   `supabase/migrations/001_kv_store.sql` (creates `public.kv_store`).
2. Add to `.env`:
   ```
   SUPABASE_URL=https://<ref>.supabase.co
   SUPABASE_SERVICE_ROLE_KEY=<service-role-key>     # server-only, never NEXT_PUBLIC
   NEXT_PUBLIC_SUPABASE_URL=https://<ref>.supabase.co
   NEXT_PUBLIC_CLOUD_STORAGE_ENABLED=true           # flips the client to cloud mode
   ```
   - Server gate: `isCloudStorageConfigured()` needs `SUPABASE_URL` +
     `SUPABASE_SERVICE_ROLE_KEY` (`lib/server/supabase.ts`).
   - Client gate: `isCloudActive()` needs `NEXT_PUBLIC_CLOUD_STORAGE_ENABLED=true`
     and the user not having opted out (`lib/client/cloud-mode.ts`).
3. Restart `npm run dev`, then:
   ```bash
   node scripts/run-company.mjs scripts/example-company.json --push
   ```
   The script does GET `/api/state?key=sovereign-aeo-tracker-v1` → merge runs →
   PUT back. Reload the app to see them.

> ⚠️ `/api/state` currently has **no authentication**. Fine for local. Do **not**
> expose a Supabase-backed deployment publicly without adding a shared-secret
> check to `app/api/state/route.ts` (and the scrape routes) first.

---

## 5. Quick recipe (TL;DR for the next session)

```bash
# 1. start the app
npm run dev                                   # wait for ✓ Ready

# 2. edit scripts/example-company.json (brand, competitors, prompts)

# 3. run
node scripts/run-company.mjs scripts/example-company.json

# 4. show in UI: open http://localhost:3000, paste the Path A console snippet
#    (or set up Supabase once and use --push for Path B)
```

---

## 6. Recommended clean-up (when moving past one-offs)

The scoring math is duplicated between `components/sovereign-dashboard.tsx` and
`scripts/run-company.mjs`. Before this becomes a recurring job, extract
`findMentions` / `detectSentiment` / `calcVisibilityScore` into a shared
`lib/scoring.ts` (pure functions, no React/`state` dependency — pass
`brand.websites` in as an argument) and have both the dashboard and the script
import it. That removes the drift risk and is the natural seed for:

- a **one-shot** "add a company and run it" command (this script), and
- a **weekly rerun** job: the same script on a schedule, writing to the cloud
  workspace (Path B). On a Next.js host this is a server route + cron hitting it;
  no second platform needed for the volumes discussed.
```

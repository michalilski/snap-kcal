# Snap Kcal — iOS Build Plan

Oct 12, 2026 · @Michał

## Overview

Snap Kcal is a single-user iPhone app: take a photo of a meal, get an estimated kcal number, a one-line description and a health score in a few seconds, and the meal lands on today's log. No account, no backend, no ads, no subscription. The user brings their own OpenAI and/or Anthropic API key and picks the model.

**Goals**

- Photo to logged meal in 2 taps and under \~10 seconds.
- Kcal is the hero number everywhere; everything else is secondary.
- Per-day log browsable through a calendar; add or edit meals on any day.
- Week and month summary: average, max, min daily kcal.
- Personal daily targets for lose / maintain / gain from weight, height, age, sex and activity level (0–3).

**Non-goals (v1)**

- No user accounts, sync, server, analytics or third-party SDKs.
- No barcode scanning, food database or manual gram weighing.
- No macros tracking beyond what the model optionally returns (protein/carbs/fat shown as small extras, not targets).
- No Apple Health integration (possible v2).

**Product principles**

1. Camera first: the main screen's biggest control is the shutter.
2. Never block on typing: an optional note field exists, but a meal can be saved with zero keystrokes.
3. Estimates are editable: the user can tap the kcal number and correct it; corrections are saved.
4. Everything stays on device, except the photo sent to the chosen AI provider at analysis time.

**Note on the brief:** the target calculation needs height as well as weight, age, sex and activity; the plan adds a height field to onboarding.

## Tech stack and architecture

Native SwiftUI app, zero third-party dependencies, all data on device. The phone talks directly to `api.openai.com` and `api.anthropic.com` with the user's own keys.

| Concern | Choice | Why |
| --- | --- | --- |
| UI | SwiftUI, iOS 18.0+, Swift 6 strict concurrency | Modern, small codebase |
| State | `@Observable` view models, `@MainActor` | No Combine boilerplate |
| Persistence | SwiftData (`@Model`), photos via `@Attribute(.externalStorage)` | Built in, queryable by day |
| Secrets | Keychain (`kSecClassGenericPassword`, `AfterFirstUnlockThisDeviceOnly`) | API keys never in UserDefaults or the DB |
| Settings | `@AppStorage` for non-secret prefs | Simple |
| Networking | `URLSession` async/await, hand-written `Codable` DTOs | No SDKs needed |
| Camera | `UIImagePickerController` (camera) wrapped in `UIViewControllerRepresentable`; `PhotosPicker` for library | Fastest reliable capture; system UI |
| Charts | Swift Charts | Week/month bars |
| Tests | Swift Testing (`@Test`) for logic, XCUITest smoke test |  |

**Layers**

- **Views** — `TodayView`, `CaptureFlow`, `MealResultSheet`, `MealDetailView`, `CalendarView`, `DayView`, `StatsView`, `SettingsView`, `OnboardingFlow`.
- **View models** — one per screen; no networking or SwiftData code inside views.
- **Services**
  - `AIProvider` protocol with `OpenAIProvider` and `AnthropicProvider`: `analyzeMeal(image:context:) async throws -> MealAnalysis` and `listModels() async throws -> [AIModel]`.
  - `MealAnalyzer`: picks the provider/model from settings, prepares the image, calls the provider, maps errors.
  - `ImageProcessor`: downscale, JPEG encode, strip metadata, make thumbnail.
  - `ModelCatalog`: fetches and caches model lists per provider.
  - `KeychainStore`: get/set/delete keys.
  - `NutritionCalculator`: BMR, TDEE, targets (pure functions).
  - `StatsCalculator`: week/month aggregates (pure functions).
- **Persistence** — SwiftData container with `Meal`, `UserProfile`, `WeightEntry`.

**Concurrency rule:** a meal is inserted into SwiftData with `status = .analyzing` the moment the photo is taken, so it is never lost. Analysis runs in a `Task` wrapped in `UIApplication.beginBackgroundTask` so a quick app switch does not kill the request; on finish the meal is updated to `.done` or `.failed` (with a Retry button).

## Screens and user flows

Four tabs on a carbon command bar: **TODAY · CALENDAR · STATS · SETUP**. The app always launches on TODAY with the shutter one tap away.

### 1. Onboarding (first launch only, 4 short steps, skippable back-navigation)

1. **Body** — sex (male / female), birth date (date picker, age derived), height in cm, current weight in kg (one decimal).
2. **Activity** — four big selectable plates, 0–3:
   - 0 Sedentary — desk job, little exercise
   - 1 Light — exercise 1–3 days/week or 7k+ steps
   - 2 Moderate — exercise 3–5 days/week
   - 3 Very active — hard exercise 6–7 days/week or physical job
3. **Goal** — shows three computed numbers side by side (LOSE / MAINTAIN / GAIN, see Calorie target math); tap one to make it the daily target.
4. **AI setup** — provider toggle (OpenAI / Anthropic), API key field (paste button, secure entry), "Load models" fetches the list, pick a model, "Test" runs a tiny vision call. Both providers can be configured; one is active.

### 2. TODAY (home)

- Top plate: date with ‹ › arrows, big outlined kcal eaten, "/ 2,150 target", remaining kcal, amber progress bar (turns red when over).
- Meal list: platinum rows, each with thumbnail, meal name, time, score badge, kcal right-aligned. Rows in `.analyzing` show a spinner; `.failed` rows show RETRY.
- Bottom-center: the **SNAP** button (large orange disc). Long-press or a small gallery icon beside it opens the photo library.
- Swipe a row left to delete (with undo toast).

### 3. Capture → result (the core loop)

1. Tap SNAP → system camera opens immediately.
2. Take photo, tap Use Photo → meal saved as `.analyzing` on the currently viewed day, result sheet slides up showing the photo and a "READING YOUR PLATE…" state.
3. Response arrives → sheet shows: kcal (hero, with range e.g. 520–680), meal name, 1–2 sentence description, health score badge with a one-line reason, one tip, small P/C/F grams, confidence.
4. Meal is **auto-saved** (setting, default on). Sheet actions: DONE (dismiss), ADJUST (kcal stepper ±50 and tap-to-type, portion chips ½× / 1× / 1½× / 2×), ADD NOTE + RE-ESTIMATE (e.g. "cooked in 2 tbsp oil"), DELETE.
5. If the model says it is not food (`is_food = false`) the meal is not saved and the sheet says NO FOOD DETECTED with RETAKE.
6. On error: the meal stays in the list as `.failed` with the photo kept; the sheet shows a human message (invalid key, rate limit, no connection) and RETRY / SWITCH MODEL.

Photos picked from the library use the EXIF capture date to pre-select the day and time; the user can change it.

### 4. Meal detail

Full photo, all fields, edit name / kcal / time / day, list of detected items with per-item kcal, "Re-analyze with…" (pick another model), provider + model used, delete. Edited kcal is stored alongside the original estimate.

### 5. CALENDAR

Month grid (week starts per locale, Monday for Poland). Each cell shows the day number and total kcal in micro type, tinted by status: no data (platinum), under target (pale sky), on target ±10% (amber), over (red). Tap a day → `DayView` (same layout as TODAY for that date, including SNAP to add a meal to that day). Month header has ‹ › arrows and a TODAY jump.

### 6. STATS

Segmented WEEK / MONTH with ‹ › to step back in time. Shows average, max (with date), min (with date), days logged, average vs target, and a bar chart with a target line. Details in Weekly/monthly summary stats.

### 7. SETUP

- Profile: edit body data, activity, goal; updating weight appends a `WeightEntry`.
- AI: provider, keys (masked, show last 4), model pickers with refresh, Test button, "Analysis detail" (Fast / Accurate, maps to image size and effort).
- Behaviour: auto-save on/off, haptics on/off.
- Data: export JSON + CSV via share sheet, delete all data (double confirm).
- About: version, privacy note ("Photos are sent only to the AI provider you choose.").

## Data model

Three SwiftData models plus Keychain entries. Every meal carries a `dayKey` string (`yyyy-MM-dd` in the user's calendar at the time of eating) so per-day queries and stats never drift across time zones or DST.

```swift
@Model final class Meal {
    @Attribute(.unique) var id: UUID
    var dayKey: String              // "2026-10-12", indexed
    var eatenAt: Date
    var createdAt: Date
    var status: MealStatus          // .analyzing | .done | .failed
    var errorMessage: String?

    // AI result
    var name: String                // "Chicken burrito bowl"
    var summary: String             // 1-2 sentences
    var kcal: Int                   // value shown & summed (user-editable)
    var kcalEstimated: Int          // original model estimate
    var kcalLow: Int
    var kcalHigh: Int
    var proteinG: Double
    var carbsG: Double
    var fatG: Double
    var healthScore: Int            // 1-10
    var scoreReason: String
    var tip: String
    var confidence: Confidence      // .low | .medium | .high
    var itemsJSON: Data             // [DetectedItem] encoded
    var userNote: String?
    var portionMultiplier: Double   // 1.0 default

    // provenance
    var provider: Provider          // .openai | .anthropic
    var modelId: String
    var inputTokens: Int?
    var outputTokens: Int?

    @Attribute(.externalStorage) var photo: Data?      // JPEG ~1024px
    @Attribute(.externalStorage) var thumbnail: Data?  // JPEG ~200px
}

struct DetectedItem: Codable { var name: String; var portion: String; var kcal: Int }

@Model final class UserProfile {      // single row
    var sex: Sex                     // .male | .female
    var birthDate: Date
    var heightCm: Double
    var weightKg: Double
    var activityLevel: Int           // 0...3
    var goal: Goal                   // .lose | .maintain | .gain
    var updatedAt: Date
}

@Model final class WeightEntry { var date: Date; var kg: Double }
```

**Keychain:** `openai_api_key`, `anthropic_api_key`.

**AppStorage:** `activeProvider`, `openAIModelId`, `anthropicModelId`, `autoSave` (true), `analysisDetail` (fast/accurate), `haptics` (true), `onboardingDone`, plus the cached model lists as JSON with a `fetchedAt` timestamp.

**Rules**

- Day total = sum of `kcal` for meals with `status == .done` and that `dayKey`.
- Changing `portionMultiplier` recomputes `kcal = round(kcalEstimated × multiplier)` unless the user typed a value manually.
- Moving a meal to another day updates both `eatenAt` and `dayKey`.

## AI integration

One prompt, one JSON schema, two thin provider adapters. Model lists are fetched live from each provider's Models endpoint with the user's key, never hard-coded, so new models appear automatically. Both providers support image input and JSON-schema-constrained output as of this writing.

### Model list fetching

|  | OpenAI | Anthropic |
| --- | --- | --- |
| Endpoint | `GET https://api.openai.com/v1/models` | `GET https://api.anthropic.com/v1/models?limit=1000` |
| Auth headers | `Authorization: Bearer <key>` | `x-api-key: <key>`, `anthropic-version: 2023-06-01` |
| Fields used | `id`, `created`, `shutdown_date` | `id`, `display_name`, `created_at`, `lifecycle`, `capabilities.image_input.supported`, `capabilities.structured_outputs.supported`, `capabilities.effort.supported` |
| Pagination | none | follow `has_more` / `last_id` → `after_id` |
| Vision filter | not exposed by the API: filter by id (see below) and verify with Test | keep `lifecycle == "active"` and `image_input.supported == true` |
| Sort | `created` desc | `created_at` desc (API already returns newest first) |

**OpenAI id filter** (the list contains every model type): keep ids starting with `gpt-`, `o` followed by a digit, or `chatgpt-`; drop any id containing `audio`, `realtime`, `tts`, `transcribe`, `whisper`, `embedding`, `image`, `dall-e`, `moderation`, `search`, `codex`, `instruct`; drop ids whose `shutdown_date` is in the past. Keep the logic in one function with unit tests so it is easy to adjust.

**UX:** cache each list for 24 h in AppStorage; pull-to-refresh in the picker; show a "Fast" hint next to ids/names containing `mini`, `nano`, `haiku`, `flash`; always offer "Enter model ID manually" as a fallback. The **Test** button sends a 64×64 solid-color JPEG and expects valid JSON back; on success the model is marked ✓ in the picker.

### Image preparation (`ImageProcessor`)

- Normalize orientation, convert HEIC → JPEG.
- Resize long edge to 1024 px (Fast) or 1568 px (Accurate); JPEG quality 0.7 → typically 150–400 KB, well under provider limits (Anthropic: 5 MB per image).
- Re-encode from pixels so EXIF/GPS metadata is stripped before upload.
- Also produce a 200 px thumbnail for list rows.
- Send as base64; never upload to any file store.

### Anthropic request

`POST https://api.anthropic.com/v1/messages` with headers `x-api-key`, `anthropic-version: 2023-06-01`, `content-type: application/json`.

```json
{
  "model": "<selected id>",
  "max_tokens": 1024,
  "system": "<SYSTEM PROMPT>",
  "messages": [{
    "role": "user",
    "content": [
      {"type": "image", "source": {"type": "base64", "media_type": "image/jpeg", "data": "<base64>"}},
      {"type": "text", "text": "<USER CONTEXT>"}
    ]
  }],
  "output_config": {
    "format": {"type": "json_schema", "schema": <MEAL SCHEMA>},
    "effort": "low"
  }
}
```

- Include `output_config.format` only if the model's `structured_outputs.supported` is true; include `effort: "low"` only if `effort.supported` is true (lower latency). Do not enable extended thinking.
- Read the answer from `content[]` items with `type == "text"`, then decode JSON. Check `stop_reason` (`max_tokens` → treat as error, `refusal` → show "Model declined this image").
- Store `usage.input_tokens` / `usage.output_tokens`.

### OpenAI request

`POST https://api.openai.com/v1/responses` with `Authorization: Bearer <key>`.

```json
{
  "model": "<selected id>",
  "instructions": "<SYSTEM PROMPT>",
  "input": [{
    "role": "user",
    "content": [
      {"type": "input_image", "image_url": "data:image/jpeg;base64,<base64>", "detail": "auto"},
      {"type": "input_text", "text": "<USER CONTEXT>"}
    ]
  }],
  "text": {
    "format": {"type": "json_schema", "name": "meal_analysis", "strict": true, "schema": <MEAL SCHEMA>}
  },
  "max_output_tokens": 2000,
  "store": false
}
```

- Use `detail: "low"` in Fast mode, `"auto"` in Accurate.
- For reasoning-capable models add `"reasoning": {"effort": "low"}`; if the API returns 400 mentioning `reasoning`, retry once without it and remember that for this model id.
- Parse: walk `output[]` → item `type == "message"` → `content[]` → `type == "output_text"` → `text`. A `type == "refusal"` part → show "Model declined this image". (`output_text` is an SDK convenience, not in the raw JSON.)
- Store `usage.input_tokens` / `usage.output_tokens`.

### System prompt

```text
You are a nutrition estimator inside a calorie-tracking app. You see one photo of food.
Estimate what was eaten and its energy content as accurately as possible from the photo.

Rules:
- Identify each distinct food/drink item, estimate its portion (grams or common units) using visual cues: plate (~26 cm), cutlery, hands, packaging, glass size.
- Account for hidden calories typical for the dish: cooking oil, butter, dressings, sauces, sugar in drinks.
- kcal_total must equal the sum of item kcal (rounded). kcal_low/kcal_high give a realistic range.
- If the user note says something about portion or ingredients, trust it over the photo.
- If several people's portions are visible, estimate only one portion unless the note says otherwise.
- If the image does not show food or drink, set is_food=false, all numbers 0, and explain in description.
- health_score: 1-10 for nutritional quality of this meal (protein, fiber, vegetables, processing, added sugar, portion size relative to the user's goal).
- tip: one short, practical, non-judgmental suggestion (max 120 characters), considering the user's goal and remaining kcal today.
- Write meal_name, description, score_reason and tip in {LANGUAGE}.
- Respond only with JSON matching the schema.
```

**User context text** (built per request):

```text
Goal: lose weight. Daily target: 1950 kcal. Already eaten today: 1120 kcal. Remaining: 830 kcal.
Local time: 13:42.
User note: "half portion, no sauce"   <- omitted when empty
```

`{LANGUAGE}` = the device's preferred language (`Locale.preferredLanguages.first`), so Polish users get Polish text.

### Meal JSON schema

All properties required and `additionalProperties: false` on every object (OpenAI strict mode requires this). Avoid `minimum`/`maximum` and other numeric constraints; describe ranges in `description` and clamp in code instead, which keeps the schema portable across both providers.

```json
{
  "type": "object",
  "additionalProperties": false,
  "required": ["is_food","meal_name","description","items","kcal_total","kcal_low","kcal_high","protein_g","carbs_g","fat_g","health_score","score_reason","tip","confidence"],
  "properties": {
    "is_food":      {"type": "boolean"},
    "meal_name":    {"type": "string", "description": "Short name, max 40 chars"},
    "description":  {"type": "string", "description": "1-2 sentences on what is on the plate"},
    "items": {
      "type": "array",
      "items": {
        "type": "object",
        "additionalProperties": false,
        "required": ["name","portion","kcal"],
        "properties": {
          "name":    {"type": "string"},
          "portion": {"type": "string", "description": "e.g. '150 g', '1 cup', '2 slices'"},
          "kcal":    {"type": "integer"}
        }
      }
    },
    "kcal_total":   {"type": "integer"},
    "kcal_low":     {"type": "integer"},
    "kcal_high":    {"type": "integer"},
    "protein_g":    {"type": "number"},
    "carbs_g":      {"type": "number"},
    "fat_g":        {"type": "number"},
    "health_score": {"type": "integer", "description": "1 (poor) to 10 (excellent)"},
    "score_reason": {"type": "string", "description": "Max 80 chars"},
    "tip":          {"type": "string", "description": "Max 120 chars"},
    "confidence":   {"type": "string", "enum": ["low","medium","high"]}
  }
}
```

**Post-processing:** clamp `health_score` to 1–10 and kcal values to 0–5000; if `kcal_low > kcal_total` or `kcal_high < kcal_total`, widen the range to include the total; if items sum differs from `kcal_total` by >10%, keep `kcal_total` (it is the model's considered answer).

**Fallback when a model does not support structured output:** send the same request without the format parameter, append "Return only a JSON object matching this schema:" + the schema to the system prompt, then extract the first `{` … last `}` and decode. One retry on decode failure.

### Errors, timeouts, retries

| Condition | Behaviour |
| --- | --- |
| No key for active provider | Block SNAP; banner "Add an API key in SETUP" |
| 401 / 403 | "API key rejected" → link to SETUP |
| 404 or model-not-found | "Model unavailable" → open model picker, refresh list |
| 429, 500, 502, 503, 529 | Retry once after 2 s (respect `retry-after` header if present), then fail |
| 400 mentioning image or format | Retry once with fallback mode, then fail with the API's message |
| Timeout | 45 s request timeout; fail with RETRY |
| Offline | Detect via `URLError.notConnectedToInternet`; keep meal as `.failed`, retry when user taps |

Never log the API key or the base64 image. Use one shared `URLSession` with `waitsForConnectivity = false`.

## Calorie target math

Use the Mifflin–St Jeor equation for resting energy (BMR), multiply by an activity factor for daily expenditure (TDEE), then offset for the goal. All in `NutritionCalculator` as pure functions with unit tests.

```latex
\text{BMR} = 10\,w + 6.25\,h - 5\,a + s \qquad s = +5 \text{ (male)},\; -161 \text{ (female)}
```

w = weight in kg, h = height in cm, a = age in whole years (from birth date, recomputed daily).

| Activity level | Label | Multiplier |
| --- | --- | --- |
| 0 | Sedentary | 1.2 |
| 1 | Light | 1.375 |
| 2 | Moderate | 1.55 |
| 3 | Very active | 1.725 |

| Goal | Daily target | Approx. pace |
| --- | --- | --- |
| Lose | TDEE − 500 | −0.5 kg/week |
| Maintain | TDEE | — |
| Gain | TDEE + 300 | +0.3 kg/week (lean gain) |

**Rules**

- Round all displayed targets to the nearest 10 kcal.
- Safety floor for LOSE: never below 1,500 kcal (male) / 1,200 kcal (female), and never below BMR; if the floor applies, show a small note "Target raised to a safe minimum".
- Recompute whenever weight, height, birth date, sex, activity or goal changes; past days keep the target that was active on that day only if cheap to do (optional: store `targetKcal` per day in a tiny `DayTarget` model); otherwise use the current target for history.

**Worked example (use as a unit test):** male, 30 years, 180 cm, 80 kg, level 1. BMR = 800 + 1,125 − 150 + 5 = 1,780. TDEE = 1,780 × 1.375 = 2,447.5 → **maintain 2,450**, **lose 1,950**, **gain 2,750**.

Show a one-line disclaimer in SETUP: "Estimates only, not medical advice."

## Weekly/monthly summary stats

Stats are computed over **completed, logged days** only: days with at least one `.done` meal, excluding today (still in progress). Empty days are skipped so a forgotten day does not drag the average down; the screen states how many days were counted.

| Metric | Definition |
| --- | --- |
| Average | mean of daily totals over counted days, rounded to whole kcal |
| Max | highest daily total + its date (tap → that day) |
| Min | lowest daily total + its date (tap → that day) |
| Days logged | counted days / days elapsed in the period, e.g. "5 / 7" |
| vs target | average − current target, shown as "+120 over" or "−340 under" |
| On-target days | days within ±10% of target |

- **Week** = calendar week per locale (Monday–Sunday in Poland); **Month** = calendar month. ‹ › step to previous/next period; › disabled for the current period.
- Today's running total is shown separately at the top ("Today so far: 1,120") but not mixed into the numbers.
- Chart (Swift Charts): one bar per day (7 or 28–31), bars tinted with the same status colors as the calendar, a dashed `RuleMark` at the target, empty days drawn as a faint stub.
- `StatsCalculator.summary(for range: DateInterval, meals: [Meal], today: Date) -> PeriodSummary` is a pure function with tests for: empty period, single day, today excluded, month with 31 days, DST week.

## Design system: Nintendo 2001 on iOS

The app looks like a Y2K console faceplate: brushed-periwinkle metal plates with bevels, a carbon command bar with amber labels, and outlined box-art type for the kcal number. Warm colors are rationed as signals only. Pull the full spec into the repo with `npx getdesign@latest add nintendo-2001` (creates `DESIGN.md`) and treat it as the source of truth; this section maps it to SwiftUI. Spec: [getdesign.md — Nintendo 2001](https://getdesign.md/nintendo-2001/design-md), [live preview](https://getdesign.md/design-md/nintendo-2001/preview).

### Color tokens (`Theme.Color`)

| Token | Hex | Use in Snap Kcal |
| --- | --- | --- |
| canvas | #7A8ABA | App background (periwinkle metal) |
| periwinkle | #8BA1D4 | Raised plates: today header, result sheet |
| canvasSoft | #9FBEE7 | Light panels, "under target" calendar cells |
| ice | #C0D5E6 | Onboarding background field |
| lavender | #ACACE7 | Empty-state hero field |
| chromeIndigo | #3D4F97 | Bevel borders, selected outlines |
| mutedIndigo | #60619C | Inactive segments, secondary chrome |
| hairline | #5A5F8C | Dividers |
| platinum | #DEDEDE | Meal rows, inset surfaces, empty calendar cells |
| surface | #FFFFFF | Text fields, score badge, row highlight |
| carbon | #21242E | Command (tab) bar, primary ink, dark buttons |
| navGold | #E48600 | Tab labels on the carbon bar |
| amber | #ECAB37 | Utility buttons, progress fill, "on target" cells |
| signal | #F68D1F | SNAP button, primary commit actions, chevron chips |
| red | #E60012 | Over target, errors, destructive |

Lock the app to this palette (`.preferredColorScheme(.light)`) in v1; the mid-tone metal works in a dark room and a dark variant is out of scope.

### Typography (`Theme.Font`)

The spec is Arial-only with character from treatment (uppercase, tracking, outlines). iOS ships Arial, Arial Bold, Arial Italic and Arial Bold Italic, but not Arial Black, so the display style uses SF Pro Black Italic with an outline. Sizes are scaled up from the 2001 web values for phone legibility and all styles use `relativeTo:` for Dynamic Type.

| Style | Font | Size / weight | Treatment | Used for |
| --- | --- | --- | --- | --- |
| display | `.system(size:weight:.black).italic()` | 56 | carbon 2pt outline + 2pt drop shadow, white fill | kcal hero number |
| title | Arial Bold Italic | 20 | — | Meal name on result sheet |
| navLink | Arial Bold | 13 | UPPERCASE, tracking 0.5 | Tab labels |
| uiLabel | Arial Bold | 13 | UPPERCASE, tracking 0.5 | Panel titles, button text |
| link | Arial Bold | 15 | — | Row titles |
| body | Arial | 15, line spacing 1.4 | — | Description, tip |
| micro | Arial | 11 | — | Calendar cells, captions, model id |

Outline effect: render the text 4–8 times offset by ±1–2 pt in carbon underneath the white text (or use a small `TextOutline` view modifier).

### Spacing, radius, depth

- Spacing scale (pt): 2, 4, 8, 12, 16, 24, 32, 48. Panels pad 12; large modules 16; section gaps 24.
- Radius: 0 for plates and the tab bar, 2 for buttons, 4 for rows; full circle only for physical-looking controls (SNAP disc, chevron chips, radio dots).
- **Plate (raised):** fill periwinkle, 1 pt top inner highlight white @ 45%, 1 pt bottom edge chromeIndigo, optional subtle vertical brushed gradient (±4% lightness).
- **Inset (recessed):** platinum fill, 1 pt chromeIndigo top edge, 1 pt white @ 60% bottom edge. Used for rows and text fields.
- **Command slab:** carbon fill with a halftone dot texture (draw with `Canvas`: 1 pt dots on a 4 pt grid, white @ 6%).

### Components

- **Tab bar** — custom carbon slab at the bottom, four uppercase navGold labels with small icons; selected tab gets an amber underline bar and white label.
- **SNAP button** — 84 pt signal-orange disc, 2 pt chromeIndigo ring, white camera glyph, sits half over the tab bar; press state darkens 8% and fires a medium haptic.
- **Kcal plate** — raised plate with the display-style number, "/ 1,950" in uiLabel, inset progress track (carbon) with amber fill; fill turns red over target.
- **Meal row** — inset platinum row, 56 pt thumbnail with 1 pt carbon frame (like the spec's featured tile), link-style name, micro time, score badge, bold kcal right, trailing 20 pt orange chevron chip.
- **Score badge** — white square with 1.5 pt carbon border (the spec's rating-square), a letter grade: 9–10 A, 7–8 B, 5–6 C, 3–4 D, 1–2 E; full number in detail view.
- **Buttons** — primary: amber fill, carbon label, 2 pt radius, top highlight; commit: signal fill, carbon label (white on #F68D1F is too low-contrast for small text); dark: carbon slab, white label, square corners; destructive: red text on platinum.
- **Result sheet** — raised plate sheet, photo framed in carbon at top, kcal hero, range in micro, then description, score row, tip in an amber-tabbed info box (the spec's info-box tab), P/C/F as three small inset chips.
- **Calendar cell** — square, 0 radius, micro day number top-left, kcal centered; status fill colors from the token table.
- **Dotted divider** — 1 pt dotted hairline between form sub-sections in SETUP.
- **Loading state** — "READING YOUR PLATE…" in uiLabel with a 3-dot blinking amber indicator (no generic spinner on the result sheet).

### Accessibility

- Minimum touch target 44 × 44 pt.
- Never put white text on amber or signal orange below 18 pt bold; use carbon.
- Every icon-only button has an `accessibilityLabel`; the kcal hero reads as "520 kilocalories, range 450 to 600".
- Reduce Motion disables the blinking indicator and sheet bounce.

## Project structure, milestones, testing

Build in six milestones; each ends with a runnable app and passing tests before the next starts.

```text
SnapKcal/
  App/            SnapKcalApp.swift, RootTabView.swift
  Design/         Theme.swift (colors, fonts, spacing), Plate.swift, Inset.swift,
                  CommandSlab.swift, TextOutline.swift, SnapButton.swift, ScoreBadge.swift
  Models/         Meal.swift, UserProfile.swift, WeightEntry.swift, Enums.swift
  Services/
    AI/           AIProvider.swift, OpenAIProvider.swift, AnthropicProvider.swift,
                  MealAnalyzer.swift, MealSchema.swift, Prompt.swift, AIError.swift
    ModelCatalog.swift, ImageProcessor.swift, KeychainStore.swift,
    NutritionCalculator.swift, StatsCalculator.swift, ExportService.swift
  Features/
    Onboarding/   Today/   Capture/   MealDetail/   Calendar/   Stats/   Settings/
  Resources/      Assets.xcassets, Localizable.xcstrings (en, pl)
SnapKcalTests/    NutritionCalculatorTests, StatsCalculatorTests, ModelFilterTests,
                  ResponseParsingTests (fixture JSON from both providers), ImageProcessorTests
SnapKcalUITests/  SmokeTest (onboarding → mock analysis → meal in list)
DESIGN.md         from getdesign (nintendo-2001)
```

**Info.plist:** `NSCameraUsageDescription` ("Take a photo of your meal to estimate calories."), `NSPhotoLibraryUsageDescription` (for picking existing photos). No other permissions.

### Milestones

1. **Skeleton + design system** — Theme tokens, Plate/Inset/CommandSlab/TextOutline, custom tab bar with 4 empty tabs, SNAP button. *Done when:* a SwiftUI preview gallery shows every component matching the spec.
2. **Data + profile + targets** — SwiftData models, onboarding steps 1–3, `NutritionCalculator`, SETUP profile editing. *Done when:* the worked example test passes and targets update live in SETUP.
3. **AI layer** — Keychain, both providers, model list fetch + filter + cache, Test button, `ImageProcessor`, schema, prompt, parsing, error mapping, a `MockProvider` for previews/tests. *Done when:* parsing tests pass with recorded fixtures from both APIs and a real Test call succeeds on each provider.
4. **Capture loop** — camera + library, `.analyzing` insert, result sheet, auto-save, adjust/portion/note + re-estimate, not-food path, failed + retry, TODAY list and totals. *Done when:* photo → kcal on screen in under 10 s on Wi‑Fi with a fast model, and killing the network mid-request leaves a retryable meal.
5. **Calendar + day view + meal detail** — month grid with status colors, DayView with SNAP for past days, move meal to another day, re-analyze with another model. *Done when:* adding a meal to last Tuesday updates that cell and stats.
6. **Stats + export + polish** — `StatsCalculator`, STATS screen with chart, JSON/CSV export, delete all, haptics, accessibility pass, Polish localization. *Done when:* stats tests pass and VoiceOver can complete the capture loop.

### Testing checklist

- Unit: calculator (worked example, safety floors, age on birthday), stats (empty, single day, today excluded, 31-day month, DST week), OpenAI model filter, both response parsers (success, refusal, max-tokens, fallback JSON extraction), clamping rules.
- Manual on device: 10 real meals of varying difficulty (plated dinner, sandwich, soup, packaged snack, drink, mixed buffet plate), compared across two models; note latency and kcal spread.
- Edge cases: no key, wrong key, deleted model id, airplane mode, app backgrounded during analysis, photo of a non-food object, very dark photo, midnight boundary (meal at 23:59 lands on correct day).

### Out of scope for v1 (ideas for later)

Apple Health export of dietary energy, Control Center / Lock Screen control that opens straight to the camera (App Intents), home-screen widget with today's kcal, weight trend chart, iCloud sync.

## Decision log

Every choice the agent might otherwise stop to ask about is settled here. The agent follows this table and does not re-decide.

| Topic | Decision | Why |
| --- | --- | --- |
| Platform | iOS 18.0+, iPhone only, portrait only, light appearance locked | SwiftData `#Index`, `@Observable`, Swift Testing all stable; one layout to get right |
| Bundle | Display name "Snap Kcal", bundle id `com.USER.snapkcal` (user fills in) |  |
| Camera | `UIImagePickerController` (`.camera`), not AVFoundation | 30 lines, system permission UI, orientation handled; custom viewfinder is v2 |
| Simulator | If `isSourceTypeAvailable(.camera)` is false, SNAP opens `PhotosPicker` instead | Lets the agent test the whole loop in the simulator |
| Photo storage | 1024/1568 px JPEG + 200 px thumbnail in SwiftData external storage; never written to the Photos library | No write permission needed, no leftover photos |
| Day assignment | `dayKey = yyyy-MM-dd` of `eatenAt` in `Calendar.autoupdatingCurrent`; adding from DayView for a past day sets `eatenAt` = that day at the current time of day | Stable per-day grouping across time zones and DST |
| Library photos | `eatenAt` = EXIF capture date if present and within the last 30 days, else now; user can change it in detail | Lets you log yesterday's dinner from the camera roll |
| Target history | The current target applies to all history; no per-day target snapshot in v1 | Simplicity; targets rarely change |
| Stats scope | Completed days only (today excluded), empty days excluded, counted-days shown | A forgotten day should not drag the average |
| Week start | `Calendar.autoupdatingCurrent.firstWeekday` (Monday in PL) | Locale-correct |
| Reading data in views | `@Query` is allowed in views for reading lists; **all writes** go through view models or services | Live-updating lists with the least code; one write path |
| kcal editing | `kcalSource` is `.model` / `.portion` / `.manual`; portion chips recompute from `kcalEstimated`; typing sets `.manual`; "Reset to estimate" returns to `.model` | Original estimate is never lost |
| Auto-save | Default on. When off: DONE saves, swipe-down asks "Discard this meal?" |  |
| Dismiss during analysis | Allowed; analysis continues, the row updates when done | Never block the user |
| Re-estimate | Same `Meal` id, same photo, new note; fields overwritten, `kcalSource` reset to `.model` | Keeps the row in place |
| Delete | Swipe → removed immediately, 5 s UNDO toast (meal held in memory, re-inserted on undo) | Standard iOS feel, no confirm dialog |
| Providers | Both keys can be stored; exactly one `activeProvider` + its model id is used for analysis | Simple mental model |
| Model lists | Fetched per provider with that key; cached as JSON file in Application Support, 24 h TTL, pull-to-refresh; "Enter model ID manually" always available | New models appear without an app update |
| Structured output | Anthropic: use `output_config.format` when `structured_outputs.supported`. OpenAI: always send `text.format` json\_schema; on HTTP 400 mentioning `format`/`schema`, retry in fallback mode and remember the model id in `modelsWithoutSchema` |  |
| Effort / reasoning | Anthropic `output_config.effort = "low"` when supported; OpenAI `reasoning.effort = "low"`; on 400 mentioning `reasoning`, retry without it and remember the id in `modelsWithoutReasoning` | Lowest latency; no extended thinking |
| Timeouts | 45 s per request, one retry on 429/5xx/529 after 2 s (or `retry-after`) |  |
| Language | Model text in the device language; UI localized en + pl via `Localizable.xcstrings` |  |
| Units | Metric only (kg, cm, kcal) | PL user; imperial is v2 |
| Score display | Letter badge A–E in rows, number 1–10 + reason in result sheet and detail | Glanceable |
| Haptics | `.success` on result, `.error` on failure, `.medium` impact on SNAP; toggle in SETUP |  |
| Debug aid | SETUP › Advanced › "Save last raw response" writes the last provider JSON (no key) to Documents | For capturing real fixtures |
| Not included | Analytics, crash reporting, iCloud, Apple Health, widgets, iPad | v1 scope |

## Implementation guide

This section is the contract the code must satisfy: types, signatures, state machines and wire formats. Names here are the names in the code.

### Architecture at a glance

&#91;embedded content: app layers · 4 bands, calls flow downward\]

Calls only go downward. A view never imports Foundation networking or `ModelContext`; a service never imports SwiftUI.

### Core types and protocols

```swift
// Enums.swift
enum Provider: String, Codable, CaseIterable, Identifiable { case openai, anthropic; var id: String { rawValue } }
enum MealStatus: String, Codable { case analyzing, done, failed }
enum Confidence: String, Codable { case low, medium, high }
enum KcalSource: String, Codable { case model, portion, manual }
enum Sex: String, Codable, CaseIterable { case male, female }
enum Goal: String, Codable, CaseIterable { case lose, maintain, gain }
enum AnalysisDetail: String, CaseIterable { case fast, accurate }

// AIModel.swift — one row of a model picker, provider-agnostic
struct AIModel: Codable, Identifiable, Hashable, Sendable {
    let id: String                        // API model id, e.g. "claude-sonnet-4-5"
    let displayName: String               // Anthropic display_name, or the id for OpenAI
    let provider: Provider
    let createdAt: Date?
    let supportsStructuredOutput: Bool?   // nil = unknown (OpenAI list has no capabilities)
    let supportsEffort: Bool?
    var isFastHint: Bool { ["mini","nano","haiku","flash"].contains { id.lowercased().contains($0) } }
}

// AnalysisContext.swift — everything the prompt needs besides the image
struct AnalysisContext: Sendable {
    let goal: Goal
    let targetKcal: Int
    let eatenTodayKcal: Int
    let localTime: String        // "13:42"
    let languageName: String     // "Polish" (Locale.current.localizedString(forLanguageCode:) in English)
    let userNote: String?
    let detail: AnalysisDetail
}

// MealAnalysis.swift — mirrors the JSON schema exactly; decoded with .convertFromSnakeCase
struct DetectedItem: Codable, Equatable, Sendable { let name: String; let portion: String; let kcal: Int }
struct MealAnalysis: Codable, Equatable, Sendable {
    let isFood: Bool
    let mealName: String
    let description: String
    let items: [DetectedItem]
    let kcalTotal: Int
    let kcalLow: Int
    let kcalHigh: Int
    let proteinG: Double
    let carbsG: Double
    let fatG: Double
    let healthScore: Int
    let scoreReason: String
    let tip: String
    let confidence: Confidence
    func sanitized() -> MealAnalysis   // clamps + range widening from "Post-processing"
}

struct AnalysisResult: Sendable {
    let analysis: MealAnalysis
    let provider: Provider
    let modelId: String
    let inputTokens: Int?
    let outputTokens: Int?
    let latency: TimeInterval
    let rawResponse: Data            // for the debug "save last raw response" toggle
}

// AIProvider.swift — the only abstraction over the two vendors
protocol AIProvider: Sendable {
    var provider: Provider { get }
    func listModels(apiKey: String) async throws -> [AIModel]
    func analyze(imageJPEG: Data, context: AnalysisContext, model: AIModel, apiKey: String) async throws -> AnalysisResult
    func test(model: AIModel, apiKey: String) async throws          // 64×64 jpeg, expects decodable MealAnalysis
}

// AIError.swift — every failure the UI can show
enum AIError: Error, Equatable {
    case missingKey(Provider)
    case invalidKey                       // 401 / 403
    case modelUnavailable(String)         // 404 or model-not-found message
    case rateLimited(retryAfter: TimeInterval?)   // 429
    case overloaded                       // 500, 502, 503, 529
    case badRequest(String)               // 400 with API message, after fallbacks tried
    case refused                          // model refusal
    case truncated                        // stop_reason max_tokens / status incomplete
    case decoding(String)                 // JSON did not match schema
    case offline
    case timeout
    var userMessage: String { ... }       // localized, one sentence
    var isRetryable: Bool { switch self { case .rateLimited, .overloaded, .offline, .timeout, .truncated, .decoding: true; default: false } }
}

// MealAnalyzer.swift — orchestrates one analysis; the only place that updates Meal from AI output
@MainActor final class MealAnalyzer {
    init(providers: [Provider: any AIProvider], keychain: KeychainStore, settings: AppSettings, modelContext: ModelContext)
    /// Runs analysis for a meal already inserted with status .analyzing. Never throws: writes .done or .failed to the meal.
    func run(meal: Meal, image: UIImage, note: String?) async
}
```

`MealAnalyzer.run` in order: (1) resolve active provider, model and key, else set `.failed` with `missingKey`; (2) `ImageProcessor.prepare` → store photo + thumbnail on the meal if not yet stored; (3) build `AnalysisContext` from `UserProfile` and today's total; (4) begin a background task; (5) `await provider.analyze(...)`; (6) `sanitized()`; (7) if `!isFood` → set `meal.status = .failed`, `meal.errorMessage = "NOT_FOOD"`; `CaptureViewModel` recognises that marker, deletes the meal and shows the NO FOOD state; (8) else copy fields into the meal, set `kcal = kcalTotal`, `kcalSource = .model`, `status = .done`, save; (9) on `AIError` set `.failed` + `errorMessage = error.userMessage`; (10) end the background task.

### Capture state machine

&#91;embedded content: capture loop · 6 states, 2 retry paths\]

Analyzing is the only state that writes a new row; Failed and Saved are the same row with a different `status`, and Not food is the one case where the row is removed.

```swift
// CaptureViewModel.swift
@Observable @MainActor final class CaptureViewModel {
    enum Phase: Equatable {
        case idle
        case picking(PhotoSource)            // .camera | .library
        case analyzing(mealID: PersistentIdentifier)
        case result(mealID: PersistentIdentifier)
        case notFood
        case failed(mealID: PersistentIdentifier, message: String)
    }
    private(set) var phase: Phase = .idle
    var note: String = ""
    var isSheetPresented: Bool              // derived: phase != .idle && phase != .picking

    func snap(for day: Date, source: PhotoSource)          // idle → picking
    func photoPicked(_ image: UIImage, captureDate: Date?)  // picking → analyzing: inserts Meal(.analyzing), saves, starts MealAnalyzer.run
    func cancelPicking()                                     // picking → idle
    func retry()                                             // failed → analyzing (same meal, same photo)
    func reEstimate()                                        // result → analyzing with `note`
    func setPortion(_ multiplier: Double)                    // result: kcal = round(kcalEstimated * m), source .portion
    func setManualKcal(_ kcal: Int)                          // result: source .manual
    func resetToEstimate()                                   // result: kcal = kcalEstimated, source .model
    func finish()                                            // result → idle (saves if autoSave off)
    func discard()                                           // result/failed/notFood → idle, deletes the meal
    func dismissWhileAnalyzing()                             // analyzing → idle; the Task keeps running
}
```

The `Meal` row is the source of truth; the sheet observes the meal's `status` and the phase follows it. `photoPicked` decodes the image once into memory, passes it to `MealAnalyzer.run` and drops it; everything later (retry, re-estimate) re-reads `meal.photo` from the store.

### Dates and calendar rules

```swift
// DayKey.swift
enum DayKey {
    static var calendar: Calendar { .autoupdatingCurrent }
    private static let formatter: DateFormatter = {
        let f = DateFormatter(); f.calendar = calendar; f.timeZone = calendar.timeZone
        f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"; return f
    }()
    static func key(for date: Date) -> String { formatter.string(from: date) }
    static func startOfDay(_ key: String) -> Date { formatter.date(from: key)! }
    static func keys(in interval: DateInterval) -> [String]   // one per day, inclusive of start, exclusive of end
}
```

- Today = `DayKey.key(for: .now)`, re-evaluated on `scenePhase == .active` so the app rolls over at midnight.
- Week interval: `calendar.dateInterval(of: .weekOfYear, for: anchor)`; month: `.month`. Stepping ‹ › moves `anchor` by ±1 week / month with `calendar.date(byAdding:)`.
- Month grid: leading blanks = `(weekday(firstOfMonth) - calendar.firstWeekday + 7) % 7`; always render 6 rows so the grid height is stable.
- Age: `calendar.dateComponents([.year], from: birthDate, to: .now).year!`.
- Past-day add: `eatenAt = calendar.date(bySettingHour:minute:second:of: dayStart)` using the current clock time.
- Keys are ISO strings, so SwiftData range predicates compare correctly: `$0.dayKey >= startKey && $0.dayKey <= endKey`.

### Persistence

```swift
// Meal.swift (additions to the earlier model)
#Index<Meal>([\.dayKey], [\.eatenAt])
var kcalSource: KcalSource = .model

// Container
let container = try ModelContainer(for: Meal.self, UserProfile.self, WeightEntry.self,
                                   configurations: ModelConfiguration(isStoredInMemoryOnly: isPreviewOrTest))

// Reading in views
@Query private var meals: [Meal]
init(dayKey: String) {
    let key = dayKey   // #Predicate needs a captured constant
    _meals = Query(filter: #Predicate<Meal> { $0.dayKey == key }, sort: \Meal.eatenAt)
}

// Day totals for a range (calendar, stats): fetch once, group in memory
func dayTotals(from startKey: String, to endKey: String) -> [String: Int]   // only status == .done
```

**Writes** go through `MealStore` (a thin `@MainActor` wrapper around `ModelContext`): `insert(_:)`, `delete(_:)`, `save()`, `fetchMeals(dayKey:)`, `dayTotals(from:to:)`, `profile()` (creates the single `UserProfile` if missing), `appendWeight(_:)`. Views and view models never hold a `ModelContext` directly except through `MealStore`.

**AppSettings** (`@Observable`, backed by `UserDefaults`):

| Key | Type | Default |
| --- | --- | --- |
| `onboardingDone` | Bool | false |
| `activeProvider` | Provider | `.openai` |
| `openAIModelId` | String? | nil |
| `anthropicModelId` | String? | nil |
| `analysisDetail` | AnalysisDetail | `.fast` |
| `autoSave` | Bool | true |
| `haptics` | Bool | true |
| `modelsWithoutSchema` | Set\<String> | \[\] |
| `modelsWithoutReasoning` | Set\<String> | \[\] |
| `saveRawResponse` | Bool | false |

Model lists are **not** in UserDefaults: `ModelCatalog` writes `Application Support/models-openai.json` and `models-anthropic.json` as `{ fetchedAt, models: [AIModel] }`.

### Keychain

```swift
// KeychainStore.swift — generic password items, service "SnapKcal", account = provider.rawValue
struct KeychainStore: Sendable {
    func key(for provider: Provider) -> String?            // SecItemCopyMatching
    func setKey(_ value: String?, for provider: Provider)  // nil deletes; SecItemAdd, on errSecDuplicateItem → SecItemUpdate
}
// Attributes: kSecClass = kSecClassGenericPassword, kSecAttrAccessible = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
```

Trim whitespace on save; show only the last 4 characters in SETUP; the field is `SecureField` with a PASTE button that reads `UIPasteboard.general.string`.

### Camera and photo picking

```swift
// CameraPicker.swift
struct CameraPicker: UIViewControllerRepresentable {
    let onImage: (UIImage) -> Void
    let onCancel: () -> Void
    // UIImagePickerController: sourceType = .camera, cameraCaptureMode = .photo, allowsEditing = false
    // Coordinator: didFinishPickingMediaWithInfo → info[.originalImage] as? UIImage
}
// Library: PhotosPicker(selection:matching: .images) → loadTransferable(type: Data.self) → UIImage(data:)
// EXIF date for library photos: CGImageSourceCopyPropertiesAtIndex → kCGImagePropertyExifDictionary[kCGImagePropertyExifDateTimeOriginal], format "yyyy:MM:dd HH:mm:ss"
```

SNAP tap: if `UIImagePickerController.isSourceTypeAvailable(.camera)` → `.picking(.camera)` full-screen cover; else `.picking(.library)`. The gallery icon next to SNAP always opens the library. Camera permission denied → alert with "Open Settings" (`UIApplication.openSettingsURLString`).

### Image processing

```swift
// ImageProcessor.swift
struct PreparedImage { let upload: Data; let thumbnail: Data; let pixelSize: CGSize }
enum ImageProcessor {
    static func prepare(_ image: UIImage, detail: AnalysisDetail) -> PreparedImage
    // 1. maxEdge = detail == .fast ? 1024 : 1568; scale = min(1, maxEdge / max(w, h))
    // 2. UIGraphicsImageRenderer(size: scaled, format: scale 1, opaque true) draws image.draw(in:) → normalizes orientation, drops alpha
    // 3. .jpegData(compressionQuality: 0.7) → no EXIF/GPS carried over
    // 4. thumbnail: same path with maxEdge 200, quality 0.6
    // 5. if upload.count > 4_000_000 (safety for 5 MB limits incl. base64) re-encode at 0.5
}
```

Run `prepare` off the main actor (`Task.detached(priority: .userInitiated)`); it takes \~50–150 ms on a 12 MP photo.

### Background continuation

```swift
let taskID = UIApplication.shared.beginBackgroundTask(withName: "meal-analysis") { /* expiration: nothing to cancel; the meal stays .analyzing and becomes .failed(timeout) via the 45 s URLSession timeout */ }
defer { UIApplication.shared.endBackgroundTask(taskID) }
```

On launch, any meal still in `.analyzing` older than 2 minutes is flipped to `.failed` with message "Interrupted — tap to retry" (`MealStore.recoverStuckMeals()` called from the root view's `.task`).

### Provider wire formats (DTOs)

Decode with `JSONDecoder` using `keyDecodingStrategy = .convertFromSnakeCase`; DTO properties are camelCase. Unknown fields are ignored. Every DTO field below is optional unless the parser cannot proceed without it.

```swift
// --- OpenAI ---
struct OAIModelList: Decodable { let data: [OAIModel] }
struct OAIModel: Decodable { let id: String; let created: Int?; let ownedBy: String?; let shutdownDate: String? }

struct OAIResponse: Decodable {
    let id: String?
    let status: String?                 // "completed" | "incomplete" | "failed"
    let output: [OAIOutputItem]
    let usage: OAIUsage?
    let incompleteDetails: OAIIncomplete?
}
struct OAIOutputItem: Decodable { let type: String; let content: [OAIContentPart]? }   // "message" | "reasoning" (skip)
struct OAIContentPart: Decodable { let type: String; let text: String?; let refusal: String? } // "output_text" | "refusal"
struct OAIUsage: Decodable { let inputTokens: Int?; let outputTokens: Int? }
struct OAIIncomplete: Decodable { let reason: String? }                                    // "max_output_tokens"
struct OAIErrorEnvelope: Decodable { let error: OAIErrorBody }
struct OAIErrorBody: Decodable { let message: String; let type: String?; let code: String? }

// --- Anthropic ---
struct AnthModelList: Decodable { let data: [AnthModel]; let hasMore: Bool?; let lastId: String? }
struct AnthModel: Decodable {
    let id: String; let displayName: String?; let createdAt: String?; let lifecycle: String?
    let capabilities: AnthCapabilities?
}
struct AnthCapabilities: Decodable { let imageInput: AnthCap?; let structuredOutputs: AnthCap?; let effort: AnthCap? }
struct AnthCap: Decodable { let supported: Bool? }

struct AnthResponse: Decodable {
    let content: [AnthContent]
    let stopReason: String?             // "end_turn" | "max_tokens" | "refusal" | ...
    let usage: AnthUsage?
}
struct AnthContent: Decodable { let type: String; let text: String? }                       // use type == "text"
struct AnthUsage: Decodable { let inputTokens: Int?; let outputTokens: Int? }
struct AnthErrorEnvelope: Decodable { let error: AnthErrorBody }
struct AnthErrorBody: Decodable { let type: String; let message: String }                 // "authentication_error", "not_found_error", "rate_limit_error", "overloaded_error", "invalid_request_error"
```

**Parsing to `MealAnalysis`**

- OpenAI: if `status == "incomplete"` → `.truncated`. Take the first `output` item with `type == "message"`; if any content part is `refusal` → `.refused`; join `output_text` parts; decode. If the response contains no message item → `.decoding("no message output")`.
- Anthropic: if `stopReason == "max_tokens"` → `.truncated`; `"refusal"` → `.refused`. Join all `text` parts; decode.
- Fallback mode (no schema): take substring from first `{` to last `}`; decode; on failure retry the request once; then `.decoding`.

**HTTP status → `AIError`** (both providers): 400 → `.badRequest(message)` after fallbacks; 401/403 → `.invalidKey`; 404 → `.modelUnavailable(id)` (also 400 whose message contains "model" and "not found" / "does not exist"); 429 → `.rateLimited(retryAfter)`; 500/502/503/529 → `.overloaded`; `URLError.timedOut` → `.timeout`; `.notConnectedToInternet` / `.networkConnectionLost` → `.offline`. The API's own `message` is shown under the user message in small type when present.

**Request builders** are pure functions returning `URLRequest`, so they are unit-testable without the network:

```swift
enum OpenAIRequests {
    static func models(apiKey: String) -> URLRequest
    static func analyze(image: Data, context: AnalysisContext, modelId: String, apiKey: String, useSchema: Bool, useReasoning: Bool) -> URLRequest
}
enum AnthropicRequests {
    static func models(apiKey: String, afterId: String?) -> URLRequest
    static func analyze(image: Data, context: AnalysisContext, modelId: String, apiKey: String, useSchema: Bool, useEffort: Bool) -> URLRequest
}
```

The JSON schema lives once in `MealSchema.swift` as a `[String: Any]` built by code (not a string) and is serialized into both request bodies.

### Model list filtering (`ModelCatalog`)

```swift
enum ModelFilter {
    static func openAI(_ raw: [OAIModel], now: Date) -> [AIModel]
    // keep: id hasPrefix "gpt-" || id matches ^o[0-9] || hasPrefix "chatgpt-"
    // drop if id contains any of: audio realtime tts transcribe whisper embedding image dall-e moderation search codex instruct
    // drop if shutdownDate parses (yyyy-MM-dd) and < now
    // sort by created desc; displayName = id
    static func anthropic(_ raw: [AnthModel]) -> [AIModel]
    // keep: lifecycle == nil || lifecycle == "active"; capabilities.imageInput.supported != false
    // supportsStructuredOutput = capabilities.structuredOutputs.supported; supportsEffort = capabilities.effort.supported
    // sort by createdAt desc (ISO 8601)
}
```

Test cases to include: an `o1-mini` passes, `gpt-4o-mini-tts` drops, `gpt-image-1` drops, a model with yesterday's `shutdown_date` drops, an Anthropic `deprecated` model drops, one with `image_input.supported == false` drops, one with no `capabilities` object is kept with `nil` flags.

### Mock provider and fixtures

`MockProvider: AIProvider` lives in the app target (not just tests) and is selected when the process has launch argument `-mockAI` or when running in SwiftUI previews. It sleeps 1.2 s, then returns `Fixtures.burrito` (or `Fixtures.notFood` if the note contains "notfood", `throws AIError.overloaded` if the note contains "fail"). `listModels` returns two fake models. The UI test scheme passes `-mockAI`.

Fixture files under `SnapKcalTests/Fixtures/`: `openai_models.json`, `anthropic_models.json`, `openai_response.json`, `anthropic_response.json`, `openai_error_401.json`, `anthropic_error_429.json`, `analysis_burrito.json`. Write them by hand from the shapes above; once the user runs the app with real keys and the "Save last raw response" toggle, replace the response fixtures with real captures.

### View model contracts

```swift
@Observable @MainActor final class OnboardingViewModel {
    var step: Int                            // 0...3
    var draft: ProfileDraft                  // sex, birthDate, heightCm, weightKg, activityLevel, goal
    var targets: (lose: Int, maintain: Int, gain: Int)   // recomputed on every draft change
    var canContinue: Bool                    // step-specific validation (height 120...250, weight 30...300, age 13...100)
    func next(); func back(); func finish()  // finish: saves UserProfile + WeightEntry, settings.onboardingDone = true
}

@Observable @MainActor final class TodayViewModel {
    var anchor: Date                         // the day being viewed; TODAY tab starts at .now, DayView at its day
    var dayKey: String { DayKey.key(for: anchor) }
    var isToday: Bool
    var targetKcal: Int                      // from NutritionCalculator + profile
    var undoCandidate: Meal?; var undoDeadline: Date?
    func step(days: Int)                     // disabled forward past today on the TODAY tab
    func total(for meals: [Meal]) -> Int     // sum of .done
    func delete(_ meal: Meal); func undoDelete()
}

@Observable @MainActor final class CalendarViewModel {
    var month: Date                          // first of month
    var cells: [CalendarCell]                // 42 cells: dayKey?, dayNumber, totalKcal?, status (.empty/.under/.onTarget/.over/.future)
    func load(); func step(months: Int); func jumpToToday()
}

@Observable @MainActor final class StatsViewModel {
    enum Period { case week, month }
    var period: Period; var anchor: Date
    var summary: PeriodSummary?              // average, max(kcal,date), min(kcal,date), daysLogged, daysElapsed, vsTarget, onTargetDays
    var bars: [DayBar]                       // dayKey, kcal?, status
    var todaySoFar: Int
    func load(); func step(_ delta: Int); var canStepForward: Bool
}

@Observable @MainActor final class SettingsViewModel {
    var keys: [Provider: String]             // masked for display; raw only passes to KeychainStore
    var models: [Provider: [AIModel]]; var loading: [Provider: Bool]; var loadError: [Provider: String?]
    var testState: TestState                 // .idle | .running | .ok(latency) | .failed(message)
    func setKey(_ raw: String, for: Provider); func refreshModels(_: Provider) async; func selectModel(_: AIModel)
    func testActiveModel() async
    func updateProfile(_ draft: ProfileDraft); func exportJSON() -> URL; func exportCSV() -> URL; func deleteAllData()
}
```

Status thresholds (shared by calendar and stats): `under` = total < 0.9 × target, `onTarget` = within ±10%, `over` = > 1.1 × target, `empty` = no `.done` meals, `future` = after today.

### Export formats

- JSON: `{ "exportedAt": ISO8601, "profile": {...}, "meals": [ { id, dayKey, eatenAt, name, kcal, kcalEstimated, kcalLow, kcalHigh, kcalSource, proteinG, carbsG, fatG, healthScore, confidence, provider, modelId, userNote } ] }` — no photos.
- CSV: header `date,time,name,kcal,kcal_estimated,kcal_low,kcal_high,protein_g,carbs_g,fat_g,health_score,provider,model,note`; RFC 4180 quoting; UTF-8 with BOM so Excel opens Polish characters correctly.
- Both written to a temp file and shared with `ShareLink`.

### Localization

- One `Localizable.xcstrings` with `en` (source) and `pl`; every user-facing string via `String(localized:)` or `Text("...")` literals.
- Uppercase chrome labels are stored in normal case and rendered with `.textCase(.uppercase)` so Polish diacritics uppercase correctly.
- Numbers through `Int.formatted()` / `Measurement` so thousands separators follow the locale (`1 950` in pl, `1,950` in en).
- Tab names in pl: Dzisiaj, Kalendarz, Statystyki, Ustawienia; SNAP stays SNAP.

### Build order (file level)

Within each milestone, create files in this order so every step compiles and is previewable:

1. `Theme.swift` → `Plate`, `Inset`, `CommandSlab`, `TextOutline`, `SnapButton`, `ScoreBadge` → `ComponentGallery` preview → `RootTabView` with placeholder tabs.
2. `Enums.swift` → models → `DayKey` → `MealStore` → `AppSettings` → `NutritionCalculator` + tests → `OnboardingViewModel` + views → SETUP profile section.
3. `AIError` → `AIModel`, `AnalysisContext`, `MealAnalysis` (+ `sanitized` tests) → `MealSchema` → `Prompt` → DTOs → `ModelFilter` + tests → request builders + tests → `OpenAIProvider`, `AnthropicProvider` → parsing tests with fixtures → `KeychainStore` → `ModelCatalog` → `MockProvider` → SETUP AI section with Test button.
4. `ImageProcessor` + tests → `CameraPicker` → `MealAnalyzer` → `CaptureViewModel` → `MealResultSheet` → `TodayViewModel` + `TodayView` + `MealRow` → undo toast → `recoverStuckMeals`.
5. `CalendarViewModel` + `CalendarView` → `DayView` (reuses `TodayView` with an anchor) → `MealDetailView` (edit, move day, re-analyze).
6. `StatsCalculator` + tests → `StatsViewModel` + `StatsView` + chart → `ExportService` → delete all → haptics → accessibility pass → `pl` strings → UI smoke test with `-mockAI`.

## Prompt for the coding agent

Export this doc as Markdown, save it as `PLAN.md` in an empty repo, and paste this:

```text
Build the iOS app described in PLAN.md ("Snap Kcal").

1. Read PLAN.md fully. The "Decision log" and "Implementation guide" sections are binding: use those type names, signatures, state machine, wire formats, settings keys and file names as written. Do not re-decide anything listed in the Decision log; if something is truly unspecified, pick the simplest option and note it in your summary.
2. Run `npx getdesign@latest add nintendo-2001` and read the generated DESIGN.md; PLAN.md's "Design system" section maps it to SwiftUI tokens and components.
3. Create an Xcode project: SwiftUI, iOS 18.0 minimum, Swift 6 strict concurrency, SwiftData, Swift Testing, no third-party packages. Add the launch argument `-mockAI` to a second scheme for simulator work.
4. Work milestone by milestone in the "Build order (file level)" sequence. After each milestone: build, run the tests, fix failures, and give a short summary of what was done and any deviation.
5. Before writing the provider request builders, open the current OpenAI Responses API and Anthropic Messages API docs for image input and JSON-schema output; if a field name differs from PLAN.md, follow the live docs and note the change.
6. Never hard-code model IDs; lists come from the providers' /v1/models endpoints at runtime through ModelCatalog.
7. API keys live only in the Keychain. Never log keys or image data.
8. Views never contain networking or ModelContext code; writes go through MealStore from view models and services.
9. Ask me before adding dependencies, a backend, analytics, or any permission beyond camera and photo library.
```

## Sources

- [Nintendo 2001 DESIGN.md — getdesign.md](https://getdesign.md/nintendo-2001/design-md) and its [live preview with tokens](https://getdesign.md/design-md/nintendo-2001/preview)
- [Anthropic — List Models](https://platform.claude.com/docs/en/api/models/list)
- [Anthropic — Structured outputs](https://platform.claude.com/docs/en/build-with-claude/structured-outputs)
- [OpenAI — List models](https://developers.openai.com/api/reference/resources/models/methods/list)
- [OpenAI — Structured model outputs](https://developers.openai.com/api/docs/guides/structured-outputs)

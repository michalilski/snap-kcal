# Changelog

Progress against `docs/build-plan.md`. Newest entries first.

## 2026-10-13 — Workout calories (Apple Health) + meal conversations

### What's implemented

- **Workout calories:** reads HealthKit workouts (read-only) and adds only each workout's **active** calories to that day's kcal goal, summed across workouts; passive calories are ignored.
  - Shown on TODAY ("2340 goal + 320 from workouts"); it also affects calendar colours, stats (on-target days, vs target) and the "remaining" kcal sent to the AI.
  - Setup → Apple Health has a toggle (default on) and a "Connect Apple Health" button; access is also requested the first time TODAY opens.
  - Code: `WorkoutCalories` + `HealthKitActivitySource` (`MockActivitySource` gives 320 kcal in `-mockAI`). Added `NSHealthShareUsageDescription` and the HealthKit entitlement.
- **Meal conversations:** each meal is now a chat (`MealTurn` model: optional photo, optional text, stored estimate).
  - The first message can be a photo, text, or both: SNAP / library open a compose step with an optional text field, and a new "describe" button (left of SNAP) starts a text-only meal.
  - Refinements are unlimited: add text and/or a photo (camera or library, e.g. the ham packaging) in the result sheet or on the meal detail screen. Every turn returns a full updated kcal estimate and description for the whole meal; the meal row and totals follow the latest answer.
  - Both providers get the whole conversation, with earlier answers as assistant messages. Follow-up failures keep the previous estimate, with Retry / Discard message.
  - Undo delete restores the conversation. Meals logged before this change get their photo and note turned into turn one when you refine them.
- **Any input language:** you can write in any language (e.g. Polish: "grahamka z Żabki"), including local products and shops; answers always come back in English.
- **Tests:** 87 unit tests (new: multi-turn request building, text-only turn, follow-up refinement, failed follow-up, undo with conversation, workout bonus in stats, workouts toggle) and 2 UI tests (photo + follow-up, text-only), all passing on the simulator. The phone build is signed with the HealthKit entitlement under the free Personal Team.

### What's next

1. Install on the phone and check the HealthKit permission prompt plus real workout totals.
2. Run a real Anthropic call through a multi-turn refinement.

## 2026-10-12 — Redesign: Nike style

### What changed

- Replaced the monochrome tactical UI with a Nike-inspired style:
  - Layout: white background, soft grey (`#F5F5F5`) rounded cards, no borders.
  - Type: big heavy condensed uppercase headlines and numbers (SF Pro Black Condensed).
  - Controls: pill buttons (black primary, outlined secondary), size-picker style selection (black 2pt outline), a thick black progress bar, a round black SNAP button, and an icon tab bar with labels.
  - Colour: Nike red (`#D30005`) for "over target" and errors, green for good health scores. Calendar and chart status colours: grey (under), black (on target), red (over).
  - Light appearance locked; app icon regenerated (black with white condensed "KCAL").
- The chart axes are now formatted with the English app locale. Swift Charts doesn't follow the app-wide locale, so they were still showing Polish.

## 2026-10-12 — Redesign: monochrome tactical UI (superseded), English-only

### What changed

- **Design:** replaced the Nintendo 2001 look (the build plan's "Design system" section is superseded) with a black/white/grey technical UI in the style of Palantir:
  - Typography: monospace everywhere, square corners, HUD corner brackets on panels, `// SECTION` titles.
  - Controls: `[ BRACKETED ]` buttons, numbered tab bar, segmented ASCII-style progress bar, `[■□□□]` loader.
  - Colour: red is the only colour, used just for "over target" and errors.
  - Tokens and components are semantic now (`background`, `surface`, `border`, `textPrimary`, `accent`, `danger`; `panel()`, `tile()`, `MetricText`, `TabBar`, `SegmentBar`).
  - App icon regenerated in monochrome.
- **Language:** English only. Polish strings were removed so the UI and the AI output never mix languages. `AppLocale` pins English while keeping the user's region (Monday week start, 24h clock), and the AI prompt asks for answers in the app's language (English).

### What's next

Same as below (real-key Test call, real fixtures, device pass).

## 2026-10-12 — v1 build: Milestones 1–6

### Status

| Milestone | State |
| --- | --- |
| 1. Skeleton + design system | ✅ Done |
| 2. Data + profile + targets | ✅ Done |
| 3. AI layer | ✅ Done in code + tests; ⏳ real-key Test call not run yet (no keys in `.env`) |
| 4. Capture loop | ✅ Done (verified in simulator with `-mockAI`) |
| 5. Calendar + day view + meal detail | ✅ Done |
| 6. Stats + export + polish | ✅ Done (haptics, a11y labels, UI smoke test; English-only, see redesign entry above) |

**Tests:** 76 unit tests (Swift Testing) + 2 UI tests (XCUITest), all passing on the iPhone 17 simulator (iOS 26).

### What's implemented

- **Project:** generated by XcodeGen from `project.yml` (`xcodegen generate`). Targets: `SnapKcal`, `SnapKcalTests`, `SnapKcalUITests`. Schemes: `SnapKcal`, `SnapKcal-Mock` (runs with `-mockAI`). iOS 18+, Swift 6 with complete strict concurrency, no third-party dependencies.
- **Design system (Nintendo 2001):** `Theme` tokens, plates, insets, carbon command bar with halftone, outlined kcal hero, SNAP disc, score badge, button styles, blinking amber loader, `ComponentGallery` preview. `DESIGN.md` was pulled from getdesign.
- **Data:** SwiftData `Meal` / `UserProfile` / `WeightEntry`, `DayKey`, `MealStore` (the single write path), `AppSettings` (UserDefaults), and recovery of stuck `.analyzing` meals on launch.
- **Targets:** `NutritionCalculator` (Mifflin–St Jeor, activity factors, lose/maintain/gain, safety floors, rounding to 10).
- **Onboarding:** 4 steps: body, activity, goal, AI setup.
- **AI:**
  - Providers: `OpenAIProvider` (Responses API) and `AnthropicProvider` (Messages API), each with pure request builders and parsers.
  - Model handling: model lists are filtered and cached for 24 h by `ModelCatalog`, and a model ID can also be entered manually.
  - Retries and fallbacks (`AnalysisPipeline`): one retry on 429/5xx/529, a fallback without schema or reasoning on a 400 (remembered per model), and one retry when JSON decoding fails.
  - Shared logic: one `MealSchema`, the plan's prompt, `sanitized()` clamping, and `AIError` mapped to user messages.
  - Mock and Test: `MockProvider` and fixtures, plus a Test button.
- **Capture loop:** camera (`UIImagePickerController`), or `PhotosPicker` with the EXIF date when no camera is available. The meal is inserted as `.analyzing` immediately and analysed under a background task. The result sheet has adjust (±50, typed value, ½×/1×/1½×/2×), note + re-estimate, a NOT FOOD path, a failed state with RETRY / SWITCH MODEL, auto-save, and swipe-to-delete with a 5 s UNDO.
- **Calendar:** month grid (locale week start, 6 rows, status colours) → `DayLogView` for any past day, with SNAP adding to that day.
- **Meal detail:** rename, edit kcal (original estimate kept, reset available), move to another day/time, detected items, provider/model/tokens, re-analyze with another model, delete.
- **Stats:** week/month summary with completed days only and today excluded (avg, max/min with tap-through, days logged, vs target, on-target days), and a Swift Charts bar chart with a dashed target line.
- **Setup:** profile editing (a weight change adds a `WeightEntry`), AI keys (masked, last 4 shown), provider/model picker, Fast/Accurate, raw-response debug toggle, auto-save and haptics toggles, JSON + CSV export (UTF-8 BOM, RFC 4180), delete all data (double confirm).
- **API keys:**
  1. In the app: SETUP → AI (or onboarding step 4) → paste → Save. Keys are stored in the Keychain only.
  2. From `.env`: copy `.env.example` to `.env` and fill in `OPENAI_API_KEY` / `ANTHROPIC_API_KEY` (optionally `OPENAI_MODEL` / `ANTHROPIC_MODEL`). The build phase `Scripts/embed-env.sh` writes them into the app bundle (`DevKeys.plist`), and on launch `EnvKeySeeder` copies them into the Keychain. It re-seeds only when the `.env` value changes, so a key typed in the app is not overwritten on every launch. If the active provider has no key but the other one does, the app switches to it.

### Deviations from the plan (simplest option chosen)

- `AIProvider.analyze` takes an extra `AnalysisOptions` (useSchema / useEffort). The retry and fallback memory lives in `AnalysisPipeline`, which uses it for both analysis and the Test button.
- If no model is selected, the analyzer fetches the model list and auto-picks the first "fast" model (mini/nano/haiku/flash). This means a key alone in `.env` is enough to start.
- `AIError.missingModel` was added for that case.
- Undo delete keeps a detached copy of the `Meal` and re-inserts it.
- `-uiTesting` (in-memory store, isolated defaults) and `-mockPhoto` (SNAP uses a generated plate image) launch arguments make UI tests run without a camera or photo library.
- The status filter (`.done`) is applied in memory after a `dayKey` predicate, because SwiftData predicates on enums are unreliable.
- The app icon is generated by `Scripts/make-icon.swift`.

### What's next

1. Put real keys in `.env` (or paste them in SETUP) and run Test on both providers. If either API rejects a field name, check the request against the current OpenAI Responses and Anthropic Messages API docs.
2. Turn on "Save last raw response", analyse a few real meals, and replace `SnapKcalTests/Fixtures/*_response.json` with real captures.
3. Manual device pass from the testing checklist: 10 real meals across two models; edge cases: wrong key, deleted model id, airplane mode, backgrounding during analysis, non-food photo, dark photo, 23:59 meal.
4. Run on a physical iPhone: set `DEVELOPMENT_TEAM` in `project.yml` and regenerate.
5. VoiceOver pass through the capture loop.
6. Later (v2 per plan): Apple Health, widget, Lock Screen control, weight trend chart.

### How to run

```sh
xcodegen generate                       # after changing project.yml or adding files
open SnapKcal.xcodeproj                 # scheme SnapKcal (real AI) or SnapKcal-Mock (no keys needed)
xcodebuild test -project SnapKcal.xcodeproj -scheme SnapKcal \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

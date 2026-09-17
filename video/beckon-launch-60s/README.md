# Beckon Launch Film

T-393. A 60-second silent product film built from genuine iOS Simulator footage, with Chinese titles and native English UI. No app behavior or security rules were changed for filming.

## Deliverables

- Final film: `renders/beckon-launch-60s-v2.mp4`.
- Ten-second look-development sample: `renders/beckon-sample-10s-v2.mp4`.
- Editable source: `index.html`, `compositions/`, `styles.css`, `motion.js`, `timeline.json`.
- Local source media: `assets/raw/`, `assets/stills/`, `assets/edited/`, `assets/generated/`.
- Source-media archive: `renders/Beckon-60s-editable-project.zip`.

The v2 filename is the first delivered full-length version after internal QA. The v1 render is retained locally as an intermediate. Media, account recovery files and QA outputs are intentionally excluded from Git. A Git-only checkout needs the media from the local archive; the source does not fetch private data or log in to Beckon.

## Reproduce

Verified on Apple Silicon macOS with Node 26.3.0, FFmpeg/ffprobe 8.1.2, Hyperframes 0.8.41, GSAP 3.14.2 and the system PingFang SC font. Dependencies are pinned. Use Node 22 or later; other platforms need an appropriate Chinese font and new layout verification. System fonts are not redistributed.

```bash
cd video/beckon-launch-60s
npm ci
npm run check
npm run dev
node_modules/.bin/hyperframes preview --status
npm run render
npm run render:sample
```

Studio: <http://localhost:3002/#project/beckon-launch-60s>. The CLI reports another port if 3002 is occupied. `index.html` is composition source, not a standalone browser player. Stop the persistent preview with `node_modules/.bin/hyperframes preview --stop`.

Output is 1920 x 1080, 30 fps, 1800 frames, 60.000 seconds, H.264/yuv420p/Rec.709, faststart, with no audio stream. The sample is 300 frames and 10.000 seconds. The renderer first extracts native video frames; it does not rely on real-time browser seeking for final encoding.

## Timeline

| Seconds | Scene | Main message |
|---|---|---|
| 0-4 | S01 | Beckon, start with your needs |
| 4-9 | S02 | Meet Coco and its care profile |
| 9-20 | S03 | Five native request steps and real publication |
| 20-27 | S04 | Groomer reads needs and prepares a quote |
| 27-39 | S05 | Compare two prices, times and groomer details |
| 39-47 | S06 | Review, confirm and see the booked appointment |
| 47-55 | S07 | Chat, then review a separately completed service |
| 55-60 | S08 | One request, multiple choices |

`timeline.json` owns logical frame ranges. Outgoing scenes remain for nine extra frames for a 0.3-second dissolve; the final scene ends at frame1800. The final title holds from57 to60 seconds. Quoted prices and times are magnifications of native screenshots, not replacement UI.

## Provenance

All app UI was captured at1206 x2622 from an isolated iPhone17Pro Simulator, iOS26.5. Coco's fictional photo was generated, uploaded to the demo pet and photographed through the actual app. Existing synthetic test profiles were used; no account was created or deleted.

S04 is a pickup shot from an identical, separately published demo request. Its native quote form is an unsubmitted draft. The two offers in S05 belong to the main request; the $75 offer at10:00 was genuinely accepted. S07's review belongs to a separate completed demo appointment, explicitly labeled as historical in the film. Service start/completion used real elapsed time and normal public operations. No clock manipulation or simulated success state was used.

Native recordings are variable-frame-rate. The edit converts to30fps before trimming, removes waiting periods, and converts the source sRGB transfer to Rec.709 before encoding. `assets/raw/` remains untouched. Source hashes, exact edit segments, build identities and events are retained in the private local `capture/manifest.json`.

## Validation And Restoration

The local `qa/` directory contains technical reports, representative frames, boundary comparisons and the review record. Lint's two nonzero-media-start warnings refer to intentionally composition-local timestamps; the five-step caption-track warning is intentional. Short crossfade overlap findings are informational, not persistent text collisions.

Scoped cleanup restored14 baseline tables' business fields and the three original profile time zones. Legitimate update timestamps and eligibility revisions were not forged backward. All owned requests, bookings, reviews, conversations, added services, pet and its Storage image were removed. Owned private contexts, projections, candidate rows, request addresses and refresh queue were verified empty. The dedicated Simulator was shut down without erasure; other work was preserved.

This is a first creative version, not a claim of user aesthetic approval. The native interface is best inspected full-screen in landscape; the main Chinese headlines also remain readable in a390px-wide player. No cloud upload or public publication was performed.

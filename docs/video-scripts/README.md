# Four-presenter video handoff

Make four short recordings, then edit them into **one submission video**. Each
student presents one section: two explain what the app does and two explain how
it works. These are presentation assignments, not claims about who wrote code.
Assign the technical sections to students who can explain the implementation.

Replace `[Name]` and each contribution placeholder before recording. A contribution
must describe something that student actually did. Aim for 8–12 words; do not
invent coding work. Review `../AI-USAGE.md` together and finish its student
contributions and AI disclosure before using the closing narration.

| Presenter | Role | Responsibility | Final video slot | Handoff |
|---|---|---|---|---|
| 1 | Functional: purpose and scanning | Introduce the problem, audience, profile and label check | 0:04–0:44 | [Script 1](01-functional-purpose-and-scanning.md) |
| 2 | Functional: travel and emergency | Demonstrate preparation, crew communication and emergency support | 0:44–1:24 | [Script 2](02-functional-travel-and-emergency.md) |
| 3 | Technical: matching and label reading | Explain rules, OCR, uncertainty and the translation limit | 1:24–2:04 | [Script 3](03-technical-matching-and-ocr.md) |
| 4 | Technical: architecture and reliability | Explain Flutter/Swift, local storage, tests and AI assistance | 2:04–2:44 | [Script 4](04-technical-architecture-and-testing.md) |

Use a four-second opening card with the app name and all four students' names.
End with a six-second credits card. The target runtime is **2:50**, leaving ten
seconds of margin. Each spoken section is roughly 80–90 words after filling the
placeholders; rehearse it at a natural pace. If a section exceeds 40 seconds,
shorten it rather than speeding up the recording. Do not add separate long intros.

## Shared demo setup

Use one iPhone and the same fictional traveler throughout all four sections.

- Traveler: **Alex Demo**, peanut allergy, **Strict** setting.
- Label: a real ingredient panel that visibly lists peanuts. Presenter 1 should
  photograph it and review the recognized text, rather than depend on a live
  barcode lookup. Do not eat or handle an allergen for the demonstration; a
  photograph of a package label is enough.
- Trip: **Demo Trip**, with dates including the recording day, a destination,
  one flight, a fictional seat number and a sample accommodation request.
- Keep personal contacts, booking references and actual medical records off screen.
- Prepare the crew card. Use only fictional demo information in emergency mode;
  turn its microphone off while recording so narration does not become commands.
- Use the same installed release build. Download any language packs before
  showing offline translation; this short script does not require that feature.

Record real app behavior. Check the exact screens before rehearsing; cut waits
between taps, but leave enough time for viewers to read the result. If a feature
fails, fix it or omit that shot and its matching narration. Do not insert a
successful result that did not come from the demonstrated input.

## What each student delivers

1. A clean voice or camera recording of their full script, under 40 seconds.
2. The matching iPhone screen recording, with two seconds of extra footage at
   each end for editing. Screen capture can be recorded separately from narration.
3. Their real name and finalized contribution sentence in a text file.

Use filenames such as `01-name-narration.mp4` and `01-name-screen.mp4`. If someone
cannot access the phone, they record their narration and send their shot list to
the teammate with the device. All four voices should appear in the final edit.

## Editor instructions

- Assemble in the numbered order above. Show each student's name and role while
  they introduce themselves, then place their narration over their app footage.
- Keep phone text large enough to read. A landscape canvas with the portrait
  phone capture in the center works; avoid showing tiny code editors.
- Use short captions: “Personal allergy profile”, “Matched label evidence”,
  “Trip journal”, “Crew card”, “Confirm current country”, “Rules decide”,
  “Local storage” and “237 automated tests passed”.
- Presenter 3's optional diagram is: **Label text → keyword and warning checks →
  verdict + evidence**. It explains the implementation; keep real app footage
  as the main visual.
- The test count describes the latest verified development run, not a guarantee
  of medical accuracy or the absence of bugs. Update it if the code or results change.
- Opening card: **Fly Allergy Aware — [all four participant names]**.
- Closing card: **Flutter/Dart · Swift · ML Kit · SQLite**; **AI assistance:
  Claude Code and Codex; details in submission**; **Food data: Open Food Facts
  and USDA FoodData Central**. Keep the full disclosure in the submission; this
  short credit is not a replacement.
- Check the finished runtime, sound, captions and link from start to finish.
  Upload the final combined video publicly to YouTube or Vimeo and test the link
  while signed out.

## Submission requirements checked

The official 2026 rulebook specifies a 1–3 minute public demonstration video
covering participant names, app name, purpose, target audience, tools/languages
and functionality. It also requires disclosure of AI assistance and significant
student contributions and understanding. Follow any additional district
instructions. Source: [official 2026 rulebook](https://www.congressionalappchallenge.us/wp-content/uploads/2026/05/2026-CAC-Rules.pdf).

The deadline stated there is October 26, 2026, noon Eastern / 9 a.m. Pacific.

## Final check

- [ ] All four names and actual contribution sentences are filled in.
- [ ] Each student understands and can answer questions about their section.
- [ ] The filmed build matches the narrated behavior.
- [ ] No actual call or text was sent during the demo.
- [ ] AI disclosure and student contributions are complete and accurate.
- [ ] Video is 1–3 minutes, public, and accessible while signed out.
- [ ] Written answers and the video link are submitted before the deadline.

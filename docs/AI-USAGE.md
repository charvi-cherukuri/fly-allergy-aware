# AI usage in Fly Allergy Aware

The Congressional App Challenge rules allow AI tools if all use is fully
disclosed, AI supports specific parts of the project rather than the whole, and
the students show significant individual contribution and understanding.

This file records what the git history shows. **The team should review it, add
what each student wrote and decided themselves, and use it for the AI-usage
disclosure in the submission.**

## Tools

- **Claude Code** (Anthropic; models Claude Opus 5 and Claude Opus 5.5). Commits
  it wrote carry a `Co-Authored-By: Claude …` line.
- **Codex** (OpenAI). Commits authored as "Codex".

## What the history shows

### Branch `main` and its base (Sept 27 – Oct 4, 2026)

| Commits | Author | AI |
|---|---|---|
| Initial app ("Fly Allergy Safe — offline-first allergy platform"), simulator notes, device unlock | Shray Bagga | Claude Opus 5 co-authored |
| Offline translator, privacy declaration fixes, README fixes | Shray Bagga | Claude Opus 5.5 co-authored |
| App lock on by default; TestFlight notes | Shray Bagga | Claude Opus 5.5 co-authored |
| Rename to "Fly Allergy Aware" | Ashok Cherukuri | no AI line |
| Namespace and TestFlight config | Ashok Cherukuri | no AI line |

### Branch `travel-redesign` (Oct 17–18, 2026)

Written by Claude Code (Claude Opus 5.5) from instructions given by Ashok
Cherukuri, committed under his name:

- Trip journal data, database upgrades v5–v7, travel screens, removal of the
  airline risk score
- Exposure, reaction and incident logging; trip timeline and report; crew card
- Emergency mode; local emergency numbers
- Voice input (on-device speech, rules parser, Apple Intelligence extraction,
  Siri shortcut)
- Home country and domestic/international trip names
- "At the airport and on board" guide
- The October 18 feedback round: readability, wording, medical note, prevention
  tips, medical kit facts and sources, child food card, flight experience
  record, full-resolution label photos

Claude Code also installed the toolchain, configured signing, and uploaded
TestFlight builds.

### Other branches

| Branch | Author | AI |
|---|---|---|
| `vihaan_2` — preparation guidance and emergency incident routing | Vihaan Tirumala | no AI line in the commit |
| `vihaan's-work` — airline directory, booking import, OCR key, Stitch UI refresh | Codex | AI-authored |

## To complete before submitting

- [ ] Each student: what you designed, wrote or changed yourself
- [ ] Which ideas and decisions came from the team (for example the feature
      list and the feedback review)
- [ ] How AI was used for each part (generated code, explained code, reviewed
      code, wrote text)
- [ ] Confirm every student can explain how their parts of the code work

## October 24 submission-readiness review and fixes

Codex reviewed the scanning, emergency, storage and lock paths and generated
fixes and regression tests for ingredient-language handling, USDA barcode
verification, confirmation of the caller's current country, visible storage
failures with ordered retries, and suspending emergency voice while locked.
Codex also updated the demo preparation instructions. Students must review and
understand these changes and accurately describe their own contributions in the
submission. This entry does not establish student authorship or eligibility.

Codex also drafted the four-presenter narration scripts and recording plan in
`docs/video-scripts/`. Students must replace the contribution placeholders with
their actual work and review the scripts for accuracy before recording.

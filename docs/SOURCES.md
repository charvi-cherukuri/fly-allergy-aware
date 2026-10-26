# Sources for medical and airline statements

Every factual claim the app makes about medicine, airlines or emergency numbers,
and where it comes from. Checked October 2026. Review before each release.

## Epinephrine on planes (`lib/data/safety_copy.dart`, Medical kits screen)

| Statement | Source |
|---|---|
| US airlines must carry epinephrine in their emergency medical kit, but not as an auto-injector (usually a vial and syringe). | CBS News, "In-flight emergencies raise concerns about airlines' medical kit requirements," Dec 9 2022 — https://www.cbsnews.com/news/in-flight-emergencies-airlines-medical-kit-requirements/ |
| The FAA proposed new medical kit rules in 2026 but does not require auto-injectors. | SnackSafely, Aug 2026 — https://snacksafely.com/2026/08/outrage-as-faa-again-declines-to-mandate-epinephrine-auto-injectors/ ; Paddle Your Own Kanoo, Aug 4 2026 — https://www.paddleyourownkanoo.com/2026/08/04/the-faa-still-wont-mandate-epipens-on-airplanes-under-controversial-new-rule/ |
| American Airlines carries auto-injectors (adult and child doses, since late 2019). | Allergic Living, Sep 28 2026 — https://www.allergicliving.com/2026/09/28/delta-allegiant-add-epi-injectors-to-medical-kits-to-step-up-safety/ |
| JetBlue carries an auto-injector in addition to FAA requirements. | CBS News, Dec 2022 (above); Allergic Living (above) |
| Southwest added auto-injectors fleet-wide in 2024, alongside vials. | Allergic Living, 2025–2026 (above) |
| Alaska Airlines carries auto-injectors (reported 2022 — older, labelled as such in the app). | CBS News, Dec 2022 (above) |
| Delta is adding auto-injectors to all aircraft, continuing through 2027. | Allergic Living, Sep 28 2026 (above); AllEars, Oct 15 2026 — https://allears.net/2026/10/15/people-with-allergies-will-feel-safer-flying-on-these-two-airlines/ |
| Allegiant is adding auto-injectors alongside vials; no schedule announced. | Allergic Living, Sep 28 2026 (above) |

**Not confirmed on airline websites.** None of these could be found on the
airlines' own pages during research. The app says the information comes from
news reports, gives the date checked, and tells the traveler to ask the crew.

## General safety statements

| Statement | Basis |
|---|---|
| Reactions can change fast; a mild one can become life-threatening. Work with your doctor on an individual plan. | General guidance, as stated in the feedback review; consistent with the FARE / AAP Food Allergy & Anaphylaxis Emergency Care Plan the app already mirrors (`kSymptomOptions`). |
| A serious reaction may lead to an emergency landing. | Airline medical diversions are standard practice; stated without numbers. |
| Second dose after 5–15 minutes with no improvement. | Already in the app's clinical guidance (`clinical_guidance_screen.dart`) and auto-injector labelling. |

## Emergency numbers (`lib/data/countries.dart`)

Ambulance numbers for 56 countries; unlisted countries fall back to 112 and say
so. Needs a human review against each country's official source before release.

## Airline request procedures (`lib/data/request_guides.dart`)

Researched August 2026 from carrier pages; every record carries `lastReviewed`.
Not re-verified in this round.

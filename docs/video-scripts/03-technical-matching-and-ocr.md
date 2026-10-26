# Presenter 3 — Technical: matching and label reading

**Your job:** explain how the app reaches a result and handles uncertainty.
**Your slot:** 1:24–2:04, maximum 40 seconds.

## Read aloud

> Hi, I'm [Name]. The allergy verdict comes from rules, not a generative AI
> answer. The matcher checks ingredient keywords and warnings such as “may
> contain,” then shows the evidence it found.
>
> Google's ML Kit reads text from a label photo on the phone. Users review that
> text before checking it. Unverified ingredient languages cannot receive a
> clear result. Translations can raise an allergy warning, but they cannot
> clear a label, because translation can miss words.
>
> My contribution was [your actual contribution in 8–12 words].

## Match the screen to your words

| Approximate time within your clip | Show |
|---|---|
| 0–5 seconds | Your face/name and the label result from Presenter 1 |
| 5–15 seconds | The highlighted peanut evidence; optional short diagram: Label text → Rules → Verdict + evidence |
| 15–25 seconds | The original label photo beside recognized text, followed by the English-confirmation checkbox |
| 25–35 seconds | In a separate real test, type `Ingredientes: leche, azúcar` without confirming English; tap Check this list and show Ingredient language not verified |
| 35–40 seconds | Hold the result while delivering your contribution sentence |

For the separate language example, use a **milk-allergy demo profile** with no
other allergens and no custom keywords. A hit on another word can legitimately
raise a warning instead. Prepare this shot separately so switching profiles does
not consume narration time. Label it “Unverified-language example” in editing.

## Prepare to explain

- **OCR** means turning the words in a picture into editable text. It can misread
  or omit words, which is why the review step matters.
- **Deterministic rules** means the same input and profile give the same result.
  Consistency does not prove that the text or database is complete.
- Matching checks word boundaries so `egg` does not match inside `eggplant`.
- Keyword hits and structured allergen tags both contribute to barcode results.
- Machine translation is a separate path with a limit: it cannot establish the
  absence of an allergen.

Code to understand before presenting: `lib/services/matcher.dart`,
`lib/models/product.dart`, and `lib/screens/ocr_screen.dart`.

**Deliver:** `03-name-narration.mp4`, `03-name-screen.mp4`, and your name/contribution text.

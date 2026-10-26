# Prompts — Fly Allergy Safe

**Prompt 1:**

"Build a food allergy app in Flutter under `apps/` in this project.

Do not start with code. Start by researching the existing market: pull live App Store data on the real competitors, read their reviews — especially the one-star ones — and work out what users actually complain about. I want the gaps, not a feature list. Write that research and the design decisions that follow from it into a plan file I can read.

Then build at least five features, chosen because they close gaps you found rather than because they are table stakes. Justify each one against the research.

Deliver it as an Xcode project and install it on my iPhone. Parallelise with subagents wherever the work is genuinely independent, and give them strict file ownership so they cannot collide."

**Prompt 2:**

"Here is the FRD this project is being graded against.

Before you build any of it, assess it critically. For each requirement, tell me whether it is buildable as written. Where it is not, say why and propose the closest thing that is — I would rather ship an honest substitute than a feature that looks finished and does nothing.

Pay particular attention to anything touching clinical content. If the document specifies something that conflicts with current medical guidance, tell me, because I will be handing this to judges and possibly to people with allergies.

Then build it. Flag which requirements depend on partnerships, data sources, or hardware that do not exist yet, so I know what is real and what is a demo."

**Prompt 3:**

"Design an app icon.

The constraint that matters is that it has to be legible at 60 pixels on a home screen next to my other apps — so one idea, executed boldly, not an illustration. It should say something about what the app is rather than being decorative.

Generate the complete iOS icon set at every required size. Draw it as vectors and rasterise each size natively rather than downscaling one export, so the small sizes stay sharp. No alpha channel on the 1024 marketing icon — that is a silent App Store rejection.

Show it to me before you install it anywhere, and check it at a small size yourself first."

**Prompt 4:**

"Knowing an airline offers a buffer zone is useless if you do not know how to ask for it, and every carrier routes it differently. Emirates and American are nothing alike.

Research the actual request procedure for every airline already in the app. For each one, record: the channel that genuinely works, the channels that look like they should work and do not, how far in advance to ask, where it lives inside the airline's own app, a verified phone number or form link, and the carrier-specific traps.

Never invent a phone number. If you cannot verify one on the carrier's own site, leave it out and link the contact page instead — a wrong number in a safety context is worse than no number.

Store all of it in the app, and add a short carrier-agnostic tutorial for someone who has never done this: what to say, when, and what to write down."

**Prompt 5:**

"Get this app to the point where I can hand a working build to other people through TestFlight.

Do everything that does not require my Apple ID: bundle identifier, signing configuration, export options, export compliance, and a one-command build and upload script. Actually run the archive to prove it builds rather than just writing the config.

Audit the app for anything that will fail App Store validation before I find out at upload time — icon alpha channel, missing usage strings, privacy manifest.

Then give me an exact, ordered checklist of the steps only I can do, and tell me which of them have lead times so I can start those first. Explain the difference between internal and external testing and recommend one."

**Prompt 6:**

"Use my existing signed-in browser session to do the App Store Connect setup: register the bundle identifier, create the app record, and fill in whatever can be filled in accurately.

Stop at anything that is a legal agreement or an attestation in my name. I will click those myself — describe exactly what is waiting for me and where.

Do not enter passwords anywhere. If a step needs credentials, hand it back."

**Prompt 7:**

"Take it the rest of the way. Check what state the account and certificates are actually in rather than assuming, and close every remaining gap you can reach without my credentials.

If you hit something blocking, do not stop at the first one — work out the full remaining chain and hand me all of it at once, in dependency order, so I am not discovering blockers one at a time."

**Prompt 8:**

"External testing, because I need to hand this to people I cannot add to an App Store Connect team individually.

That means Beta App Review, which changes what is required: a public privacy policy URL, the App Privacy declaration, beta test information, and review notes.

Write all of it. The privacy policy should be accurate to what the app actually does, not boilerplate. For the review notes, pre-empt the things about this app that look like problems from the outside — the clinical content and the sample data — and explain them before a reviewer has to ask. Tell me honestly what our rejection risk is."

**Prompt 9:**

"Produce a demo video of the app running.

If you cannot drive my physical phone, find another way — but be explicit about what the workaround costs, and do not modify the real project to get there. Work in a copy.

Whatever you cannot capture, tell me plainly and give me a shot list so I can film those parts myself. I need one to three minutes for the Congressional App Challenge, and I will be narrating over it."

**Prompt 10:**

"Reset. Here is the situation I am actually in: a team, a lead who has been assigning work, a meeting I need to be ready for, and a document I was sent and have not read.

Before doing anything else, find and read that document — it defines what I am supposed to be building, and everything we have done so far may not match it.

Then tell me, bluntly, where what exists conflicts with what the team expects. Include conflicts with instructions I gave you earlier; if I told you something that contradicts my lead's spec, I need to know before the meeting rather than after.

Work out the timeline for real. Check the actual deadline rather than taking 'we're creeping up on it' at face value."

**Prompt 11:**

"My role here is going to be relaying prompts to a separate coding session, so write prompts that work with no context beyond the repository.

Do not rewrite the prompts my lead already wrote — they are his, they are good, and diverging from them creates a problem for the team. Adapt them: make each one self-contained, and correct anything that has since stopped being true.

Verify the technical claims in them rather than trusting them. If a pinned version no longer resolves, find out what does and tell me, because that is something I need to raise with him.

Add guardrails where a coding model will predictably get it wrong."

**Prompt 12:**

"Step back and give me a plan, not a task list.

Establish the real constraints first — the actual deadline, the actual time until my meeting. Then identify the single biggest risk in how we are currently proceeding and tell me whether the ordering we have been handed is the right one.

If you think it is wrong, say so and propose an alternative — but be clear about which parts are mine to decide with the team rather than yours to change unilaterally.

End with what I should settle in the meeting, in priority order."

**Prompt 13:**

"We are following my lead's sequencing rather than your reordering. It is his project and his call, and I do not want to argue for a change I cannot justify.

Note the consequence once, then stop arguing it.

Update the prompt file so the order is unambiguous, and front-load whatever I need to do myself, because in strict order I will hit a blocker almost immediately and I would rather know now."

**Prompt 14:**

"Build and run the app on an iOS simulator so I can see it.

Open the simulator panel first so I can watch rather than waiting for a screenshot at the end.

If the build fails, diagnose the actual cause rather than working around it — and if the failure is environmental rather than in the code, fix the environment and tell me what it was, because it will happen again."

**Prompt 15:**

"Not the empty scaffold — the app that actually does something. I want the full build with the scanner, flight scoring and emergency screens, because that is what I can show people.

Whatever you have to strip to make it run on a simulator, do it in a copy and leave the real project untouched. Tell me exactly what is different in the build I am looking at, so I do not demo something and discover later it was stubbed."

**Prompt 16:**

"Do not start over on the scaffold. Take the requirements from my lead's Phase 1 pack and apply them to the app that already works.

Audit it against his scope first and tell me precisely which requirements it already meets, which it does not, and which it meets in name only. Then close the gaps.

Honour the boundaries in his document even where they conflict with what is already built — especially anything he deliberately deferred for liability reasons — and flag those conflicts rather than resolving them silently.

Be clear at the end about the difference between satisfying his requirements and conforming to his architecture, because those are not the same thing and I need to know which one I have."

**Prompt 17:**

"The FRD opens with 'create an account' and my lead's Phase 1 includes the sign-in foundation, so this is not optional.

Build the full account lifecycle: sign up, sign in, sign out, change password. Structure it so the backend can be swapped in later without rewriting any screen — an interface, with the implementation behind it.

Hash passwords properly even if the store is local; people reuse passwords and I do not want one leaking out of a device backup.

Do not let the UI overstate what the security actually is. If a local password does not protect the data on the phone, the app should say so, and anything elsewhere in the app that now contradicts having an account needs fixing."

**Prompt 18:**

"Wire up Google and Apple sign-in for real, through Firebase.

Do the console configuration in my browser: initialise Authentication, enable the providers, and whatever project-level settings they require. Then regenerate the platform config and do the iOS plumbing — URL scheme, entitlement, Xcode build settings.

Implement it behind the interface that already exists so no screen changes. Handle the two API traps my lead's document called out, because they are the ones that silently produce code that does not work.

Tell me what each provider actually needs before I go and buy or configure something I do not need."

**Prompt 19:**

"Drop Android — it is not a target, so ignore anything that only applies to it.

Now actually test Google sign-in rather than telling me it should work. Get the app onto a simulator, tap the button, and take it as far as you can.

Stop at my credentials. Do not type my password anywhere — get the flow to the login screen and leave it for me.

Tell me precisely what reaching that point does and does not prove, and report anything the test exposed along the way."

**Prompt 20:**

"Make sure the app never invents data.

Anything that ships pre-populated — sample flights, placeholder profiles, seeded history — has to go. A first launch should show real empty states, because an allergy app that shows a flight I never booked is an app I cannot trust about anything else.

Check every screen for the version of this problem it has, not just the obvious one."

**Prompt 21:**

"Build it and put it on my iPhone.

Use the signing team that actually owns the bundle identifier, and handle the extended-attribute problem that has broken codesign here before rather than working around it by hand each time.

If a step needs my device or my credentials, stop and tell me what to press."

**Prompt 22:**

"Four changes.

Emergency contacts should be textable, not only callable. A parent in a meeting or a partner in another time zone is easier to reach by message, and a message leaves a record of when it was sent. Do not send anything automatically — prefill it and let me press send.

Merge Cabin and Flights into one Travel tab. They are the same task at two distances.

Add translation throughout the app, not only on the chef card. If a reaction starts in a country whose language I do not read, I need the sentences that get an ambulance, not a menu.

Cut the app to four tabs: Travel, Scan, Emergency, Profile.

When it is done, commit it to the repository my lead set up."

**Prompt 23:**

"Take the sign-in out. No accounts, no email, no Firebase.

Replace it with a passcode and Face ID lock on the app itself. The reason for a lock here is that a phone gets handed to a child or left on a tray table, not that anyone is defending the database — so hash the passcode properly, and do not let any copy imply the lock is encryption.

Remove everything the accounts left behind: the screens, the repositories, the dependencies, the iOS configuration and the docs that describe them. The app has to open with no signal, which is the whole argument for not having a login in the first place."

**Prompt 24:**

"The lock should use the regular iOS one, not a passcode system you designed.

Face ID with the system passcode sheet behind it — the prompt people already know and
already trust. The app should not be holding a secret of its own at all.

While you are in there, the lock has to actually lock: if it does not cover whatever
screen I had open, it is not a lock. And it must not shut me out on the way back from
an emergency call."

# RecallOS — UI/UX design and Mobbin research protocol

Adopted by the owner on **7 Oct 2026**. It is a standing rule for every
UI/UX change to RecallOS: a new screen, a redesign, a flow, an empty state, a
sheet, copy. The owner's text is below, unchanged. The first section only
records how it applies to *this* repository, so that no chat has to work
that out again.

## How this applies here (read first)

- **The stack is Flutter**, not React Native/Expo. Riverpod, GoRouter and
  Drift. "Implementation engineer" below means Flutter.
- **The design system in §10 already exists, and it is deliberate.** It is
  three things:
  - `lib/core/theme/app_theme.dart`;
  - `design/DESIGN.md` and `design/screens.html`;
  - the five rules and the accessibility floor in `CLAUDE.md`.

  The wallet metaphor is part of the product identity: overlapping library
  cards with real lift, flat answers, recessed inputs, and ochre as a
  marker. Where the "avoid" list in §7 (shadows, rounded cards) reads
  against it, §19 decides: the existing system stands unless the owner
  agrees a change.
- **Smart Wallet (§16).** On 29 Sep 2026 the owner explicitly decided to fold
  Smart Wallet's *ideas* into RecallOS: receipts, warranties and reminders,
  which is Release B (`docs/PLAN.md` §2). That decision is the explicit
  instruction §16 allows for. Smart Wallet's code, terminology, branding and
  UI are still never copied.
- **Mobbin access.** Checked 7 Oct 2026: an official Mobbin connector
  (`search_screens`, `search_flows`, `search_sections`) is in the claude.ai
  connector directory, **not connected yet**.
  - Until it is, follow the fallback in §1. Say Mobbin was not inspected,
    name the searches that should be run, and use the owner's screenshots.
  - Never describe a Mobbin screen that was not actually opened.
- **Work done before this protocol.** The A6 search UI (lookup answer cards,
  people-filter list, the *why* block, built 7 Oct) was designed within the
  design system but without Mobbin research. Review it in the first UX pass.
- **The report.** The design reasoning in §18 doubles as evidence for the
  CSE499 report. Keep each record short and put it beside the feature in
  `docs/PLAN.md`.

---

## Role

For all UI/UX work on RecallOS, act as a senior mobile product designer, UX
architect, design-system designer, and React Native/Expo implementation
engineer.

RecallOS must not look or feel like a generic student project, AI-generated
template, admin dashboard, CRM clone, or collection of disconnected cards.

The target is a polished, modern, commercially credible Android application
with a coherent product identity and production-quality UX.

RecallOS is an:

- offline-first
- privacy-first
- intelligent professional memory and relationship system
- business-card capture and OCR system
- people/connection memory system
- contextual retrieval and recall tool

Its core product promise is:

> Help the user remember who someone is, where they met them, what matters
> about them, and what they should do next.

All UI decisions must support this purpose.

## 1. Mobbin is an official UI/UX research source

Use https://mobbin.com as one of the primary UI/UX research sources whenever
designing, redesigning, or significantly changing a RecallOS screen,
component, interaction, navigation pattern, workflow, empty state,
onboarding experience, form, scanner experience, search interface, AI
interaction, settings screen, or monetization experience.

If Mobbin MCP or another direct Mobbin integration is available, use it.

If direct Mobbin access is unavailable, DO NOT pretend that you inspected
Mobbin. Instead:

1. state that Mobbin research could not be accessed directly;
2. continue using established mobile UX principles and existing RecallOS
   design-system rules where appropriate;
3. identify the exact Mobbin searches/references that should be reviewed;
4. use screenshots/references provided by the project owner when available.

Never hallucinate Mobbin screens or claim that a specific application uses a
pattern unless you actually inspected it.

## 2. Never copy a Mobbin screen

Mobbin is for:

- studying successful UX patterns;
- comparing approaches;
- understanding information hierarchy;
- studying navigation;
- studying interaction design;
- discovering good component patterns;
- studying complete user flows;
- studying microcopy;
- studying loading/error/empty states;
- understanding how mature products solve similar problems.

Mobbin is NOT for cloning another application.

Never reproduce an entire competitor screen.

For important design decisions, ideally inspect at least 3 relevant
references.

Extract the principle from each reference and create an original RecallOS
solution.

Example:

- Reference A may have the best information hierarchy.
- Reference B may have the best bottom-sheet interaction.
- Reference C may have the best typography and spacing.
- Reference D may have the best empty state.

RecallOS should combine the lessons into an original design consistent with
its own product identity.

## 3. Research the UX problem before designing

Do not begin significant UI changes by immediately writing React Native code.

First identify:

1. What user problem is this screen solving?
2. What is the primary action?
3. What information matters most?
4. What information is secondary?
5. What could confuse the user?
6. What happens before this screen?
7. What happens after this screen?
8. What are the loading, empty, success, error and offline states?
9. Is another screen or interaction even necessary?
10. How do mature mobile products solve similar problems?

Then use Mobbin to study relevant patterns.

After research, define the RecallOS-specific solution.

Only then implement it.

## 4. Search Mobbin by UX problem, not by app name alone

Useful Mobbin searches for RecallOS include:

### Onboarding

Search: onboarding · welcome · product introduction · permissions · privacy
onboarding · camera permission · notification permission · get started

Study:

- number of onboarding steps;
- information hierarchy;
- when permissions are requested;
- how privacy is communicated;
- skip behaviour;
- progressive onboarding.

### Home

Search: home · dashboard · recent activity · productivity home · recent
contacts · recommendations · reminders · quick actions

Study:

- hierarchy;
- contextual content;
- recent activity;
- primary action placement;
- useful recommendations;
- avoiding dashboard clutter.

RecallOS Home should not simply be a grid of feature buttons. It should help
the user remember and act.

### Business Card Scanner

Search: document scanner · card scanner · camera capture · document capture ·
receipt scanner · KYC scan · camera guidance

Study:

- camera framing;
- instructions;
- capture button;
- flash controls;
- auto/manual capture;
- permission handling;
- failed scans;
- image confirmation;
- retry behaviour.

### OCR Review

Search: review information · detected information · edit profile · form
review · verification · extracted data · confirmation · form errors

Study how mature apps reduce the effort required to verify automatically
extracted information.

RecallOS must always let the user verify OCR results before trusting them.

Low-confidence information should be clearly distinguishable without making
the user feel that the entire scan failed.

### People

Search: contacts · people · connections · CRM contacts · contact list ·
member directory · search contacts

Study:

- list density;
- avatars;
- subtitles;
- grouping;
- filters;
- sorting;
- recently added contacts;
- search integration.

### Person Detail

Search: contact profile · profile details · CRM contact · relationship ·
activity timeline · notes · contact activity

RecallOS Person Detail should answer:

- Who is this person?
- What do they do?
- Where/how did I meet them?
- What should I remember about them?
- When did I interact with them?
- What should I do next?

Do not reduce Person Detail to Name + Phone + Email.

### Search

Search: global search · contact search · search suggestions · semantic
search · recent searches · search filters · no search results

Study:

- search entry point;
- progressive results;
- recent searches;
- filtering;
- query suggestions;
- empty results;
- result hierarchy.

### Ask RecallOS / AI Retrieval

Search: AI assistant · AI search · conversational search · copilot · chat
assistant · AI answer · suggested prompts

The RecallOS AI experience should feel like intelligent retrieval from the
user's own memory system, not a generic ChatGPT clone.

Example queries:

- "Who was the marketing manager I met at the event last month?"
- "Show me people I met from XYZ."
- "Who did I say I should follow up with?"

### Notes and Context

Search: notes · add note · quick note · bottom sheet · activity · timeline ·
contextual notes

Study how users can add context with minimum friction.

### Follow-ups and Reminders

Search: reminder · task · follow up · notification · schedule reminder ·
activity timeline

RecallOS reminders must feel relationship-aware rather than becoming a
generic to-do application.

### Settings / Privacy / Backup

Search: settings · privacy · security · permissions · data management ·
backup · account · local storage

Privacy controls must be understandable to normal users.

Avoid unnecessary technical terminology.

### Empty States

Search: empty state · first use · no contacts · no results · no activity ·
zero state

Every major RecallOS feature must have a deliberate empty state.

Never leave users staring at blank white space.

### Monetization

When monetization work begins, search: subscription · upgrade · premium ·
pricing · paywall · free trial · feature limit

Do not introduce monetization UI before product value is clear.

## 5. Design flows, not just screens

A visually attractive individual screen does not automatically create good
UX.

Always evaluate complete workflows.

For example:

Scan Card → Camera permission if necessary → Camera guidance → Capture →
Processing → OCR result → Review detected information → Correct uncertain
information → Save → Person created → Add context / note / meeting
information → Optional follow-up → Person Detail

The transition between these stages matters as much as the screens
themselves.

Use Mobbin flows where possible to study complete interactions rather than
isolated screenshots.

## 6. Use Mobbin for micro-UX

Research smaller interaction problems too.

Examples:

- Should Add Note use a full page, modal or bottom sheet?
- How should destructive deletion be confirmed?
- How should filters appear?
- How should OCR errors be shown?
- How should a successful save be communicated?
- How should offline status be communicated?
- How should loading skeletons behave?
- How should search suggestions appear?
- How should permission denial recovery work?

Search Mobbin for these individual UI patterns instead of inventing unusual
behaviour without reason.

## 7. RecallOS design principles

Every RecallOS screen should aim to feel:

- calm
- intelligent
- trustworthy
- human
- focused
- modern
- premium
- efficient
- privacy-conscious
- consistent

Avoid:

- excessive gradients;
- random glassmorphism;
- unnecessary shadows;
- giant rounded cards everywhere;
- excessive nested cards;
- decorative UI with no functional purpose;
- oversized headings;
- excessive whitespace that reduces usability;
- cluttered dashboards;
- too many floating buttons;
- random icon styles;
- inconsistent spacing;
- unnecessary animations;
- generic AI-chat aesthetics;
- copying another product;
- desktop-dashboard patterns forced into a mobile application.

Use visual effects only where they improve hierarchy, affordance or product
identity.

## 8. Mobile-first and Android-first

RecallOS is currently Android-first.

Design first for realistic Android phone dimensions and one-handed usage.

Consider:

- status bar;
- navigation area;
- safe areas;
- keyboard;
- back behaviour;
- scrolling;
- small screens;
- large screens;
- long names;
- long company names;
- accessibility font scaling;
- dark/light mode if supported;
- touch target sizes;
- physical-device behaviour.

Do not approve a design simply because it looks good in a static mockup.

It must work correctly on a real Android device.

## 9. Information hierarchy before decoration

Every screen must have an obvious:

- PRIMARY information/action
- SECONDARY information/action
- TERTIARY information/action

Do not give every element equal visual weight.

Example for Person Detail:

- PRIMARY: Person identity and relationship context.
- SECONDARY: Communication actions, important notes and follow-up.
- TERTIARY: Metadata, source details, technical information.

Visual design should reflect this hierarchy.

## 10. Design system first

Do not introduce unique styling independently on every screen.

Maintain a coherent RecallOS design system covering:

- colors;
- backgrounds;
- surfaces;
- typography;
- spacing;
- border radius;
- borders;
- elevation/shadows;
- icons;
- buttons;
- inputs;
- list rows;
- cards where actually appropriate;
- chips;
- tabs;
- bottom sheets;
- dialogs;
- navigation;
- empty states;
- skeletons;
- alerts;
- success/error states.

Prefer reusable components and design tokens.

Before introducing a new component, check whether an existing component can
be improved or reused.

## 11. UX copy matters

Do not use engineering-style language in user-facing interfaces.

Avoid text such as:

- "OCR PROCESSING FAILURE"
- "NULL DATA"
- "ERROR CODE 03"
- "INVALID OBJECT"

Prefer human wording.

Example:

- "We couldn't read part of this card."
- "Check the highlighted information before saving."
- "Camera access is needed to scan a business card."
- "Nothing found for this search."

Buttons should be specific.

Prefer "Scan another card" instead of "Continue" when that is the actual
action.

Use Mobbin's UI copy as inspiration for how mature products communicate
similar states, but write original RecallOS copy.

## 12. Handle all states

Never implement only the ideal state.

For every important screen or component consider:

- first use;
- empty;
- populated;
- loading;
- processing;
- partial result;
- offline;
- permission denied;
- recoverable error;
- unrecoverable error;
- success;
- long content;
- invalid content;
- deleted/missing data.

A screen is not finished until its major states are considered.

## 13. Accessibility

Maintain:

- readable text sizes;
- strong contrast;
- sufficiently large touch targets;
- clear focus hierarchy;
- accessible labels;
- no information communicated only through color;
- reasonable motion;
- support for longer text;
- appropriate disabled-state distinction.

Visual beauty must never reduce usability.

## 14. Privacy must appear in the UX

RecallOS is privacy-first and offline-first.

The interface should communicate privacy at useful moments without
repeatedly displaying security marketing messages.

Good places include:

- onboarding;
- scanner explanation;
- backup settings;
- AI/search explanations;
- permission requests;
- privacy/data settings.

The user should understand what happens to their information.

Do not make claims that are unsupported by the actual implementation.

## 15. Preserve working functionality

A UI redesign must not silently change business logic.

Before modifying an existing screen:

1. inspect its current functionality;
2. inspect navigation dependencies;
3. inspect data/state dependencies;
4. inspect tests;
5. identify functionality that must remain intact.

Then redesign.

Do not delete functionality simply because it complicates the visual
design.

If architectural changes are required, explicitly identify them.

## 16. Do not mix RecallOS with other projects

RecallOS is an independent product.

Do not copy architecture, terminology, UI decisions, feature assumptions or
branding from Smart Wallet or unrelated projects unless explicitly
instructed.

All design decisions must be based on RecallOS requirements.

## 17. Required workflow for major UI changes

For any substantial screen/flow redesign, follow this order:

**A. Audit.** Inspect the existing implementation. State:

- what currently works;
- UX weaknesses;
- visual weaknesses;
- inconsistencies;
- technical constraints.

**B. Define the UX objective.** Explain what the screen must help the user
accomplish.

**C. Research.** Use Mobbin when accessible. Study several relevant
patterns. Do not copy them.

**D. Extract principles.** Record the useful ideas learned from research.
Example:

- persistent primary action works well;
- bottom sheet reduces navigation;
- contextual subtitle improves recall;
- progressive disclosure reduces clutter.

**E. Propose RecallOS solution.** Translate those principles into an
original RecallOS interface.

**F. Check against the design system.** Avoid one-off styling.

**G. Implement.** Use clean reusable production code.

**H. Validate.** Check:

- layout;
- functionality;
- navigation;
- loading;
- errors;
- empty states;
- keyboard;
- Android back behaviour;
- different content lengths;
- accessibility;
- consistency.

**I. Self-review.** Before calling the UI finished, ask: "Would this look
credible if RecallOS were published on Google Play today beside mature
commercial applications?" If not, improve it.

## 18. Before implementing a significant design, report the design reasoning

Keep this concise. Use this format:

- **UX objective** — What problem are we solving?
- **Existing problems** — What is weak in the current implementation?
- **References/patterns studied** — What relevant Mobbin/product patterns
  were examined?
- **Lessons extracted** — What principles are useful?
- **RecallOS solution** — What are we going to build and why?
- **States** — What loading/error/empty/offline/etc. conditions must be
  handled?
- **Implementation impact** — Which components/files/design tokens will
  change?

Then proceed with implementation unless there is a genuinely blocking issue.

Do not produce huge reports for trivial spacing or typo fixes.

## 19. Do not redesign for the sake of redesigning

Existing UI that already solves its problem well should not be replaced
merely because another design looks newer.

Prioritize improvements with measurable UX value:

- clearer hierarchy;
- fewer steps;
- less cognitive load;
- greater trust;
- faster task completion;
- clearer feedback;
- improved accessibility;
- higher consistency;
- better discoverability.

## 20. Product standard

The final standard is not: "Good enough for a university project."

The standard is: "Could this reasonably ship as a polished consumer Android
product?"

University requirements still matter, but they must not become an excuse
for weak product design.

For major design choices, ensure we can later explain:

- the user problem;
- research/reference patterns;
- design decision;
- implementation;
- evaluation.

This also creates defensible design evidence for the CSE499 project report,
presentation and evaluation.

## 21. Core RecallOS experience to prioritize

When improving UI/UX, prioritize these experiences in approximately this
order:

1. Onboarding and first-use experience
2. Home
3. Business-card scanner
4. OCR processing/review
5. Save/create person
6. People
7. Person Detail
8. Search
9. Ask RecallOS / intelligent retrieval
10. Notes/context
11. Follow-ups/reminders
12. Settings/privacy/backup
13. Secondary states and polish
14. Monetization when appropriate

Do not spend disproportionate time polishing secondary Settings screens while
the primary scan → remember → retrieve experience remains weak.

## 22. Final rule

Whenever UI/UX work is requested, do not ask only: "How can I make this
prettier?"

Ask: "What is the user's goal, how do the best mobile products solve this
interaction, what can we learn from Mobbin, and what is the simplest
original RecallOS solution that solves it exceptionally well?"

Research first. Design deliberately. Implement consistently. Validate on the
actual product. Never blindly copy.

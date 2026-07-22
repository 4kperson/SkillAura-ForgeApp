# Product decisions

## MVP promise
Help users prove discipline to themselves through a short list of daily commitments, visible progress, XP, and streak continuity.

## Initial audience
18–35-year-old students, creators, builders, and early-career professionals who already consume productivity and self-improvement content.

## Deliberate exclusions from v1
- Social feed
- Public leaderboard
- AI coach
- Complex journaling
- App blocking

These can increase scope before the core retention loop is validated.

## Visual direction
Near-black surfaces, warm violet primary accent, large typography, restrained animation, and high-contrast progress feedback. SkillAura remains the parent company; the product has its own identity.

## Onboarding experience

The first-run experience is a seven-step commitment journey, not a survey.
Users can select up to three priorities because real improvement is rarely
one-dimensional. Difficulty directly controls habit duration, mission size, and
Day One XP expectations. Wake and sleep times place each recommendation at a
credible moment, making the generated starter plan visibly personal.

Each screen asks for one decision or communicates one idea. Language explains
why Forge needs each answer and emphasizes identity and achievable action;
progress is saved after every transition. The notification permission prompt
appears only after Forge explains its value and offers a clear "Not now" path.

## Core retention loop
Choose commitments → complete them → progress through levels → protect streak → review progress → return tomorrow.

## Morning experience

Home answers three questions in order: who the user is becoming, which promise
comes next, and how close the next meaningful milestone is. Progress is framed
through cumulative XP, levels, streak continuity, and achievements rather than
a generic daily percentage. Completed missions leave the action list so the
screen becomes calmer as the user moves through the day.

Notification refusal is treated as an informed product choice. Forge names the
quiet moments the user will not receive, stores denied separately from skipped,
and continues without guilt or repeated pressure.

## Notification consent and reminders

- Native permission statuses are mapped explicitly; provisional and granted
  access enable reminders, while denied, restricted, and permanently denied
  access use the respectful denial path.
- Reminder scheduling follows persisted consent, rather than merely visiting
  the notification screen.
- Forge schedules the confirmed active habit plan and owns reserved reminder
  ID ranges, so non-granted consent cannot affect unrelated notifications.
- Weekly reminders use each habit's IANA timezone and inexact Android delivery,
  preserving wall-clock intent without an exact-alarm permission prompt.
- Denied and skipped choices intentionally converge on one calm explanation.
  Continuing completes onboarding without pressure; enabling uses the native
  prompt or app settings according to the current platform and permission state.
- Home retains a clearly actionable reminder card while access is disabled, so
  the choice remains reversible without interrupting the Morning Experience.

## Habit ownership and destructive actions

- Onboarding promises become normal habits. The `STARTER` label explains their
  origin but never limits editing, pausing, reordering, archiving, or deletion.
- Archive is reversible and preserves history and XP. Permanent deletion is a
  separate confirmation that explains both history removal and recorded-XP
  reversal before the server transaction runs.
- Completion is available from Today's Mission, where intent is clearest. A
  five-second Undo action reverses the exact server-recorded XP and restores the
  mission without introducing a second competing completion control.

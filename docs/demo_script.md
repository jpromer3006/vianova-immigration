# ViaNova Immigration — 3-Minute Hackathon Demo Script

**Total time: 3:00**
**Presenter:** JP Romero
**Setup:** App running at localhost:8503, Chrome open to consent screen

---

## Beat 1 — The Problem (0:00 – 0:35)

> *Advance to Slide 2 — The Problem*

"There are 11 million undocumented immigrants in the United States.
73 percent of them delay or avoid seeking legal help — not because they don't
need it, but because they're afraid. They fear that the moment they tell someone
their story, that information could be used against them.

ViaNova changes that. It is a voice-first legal navigation assistant built on
top of Flashpoint AI — and its first job is not to give advice, but to
*earn trust* and get to the truth."

---

## Beat 2 — Workflow + Live Demo Start (0:35 – 1:10)

> *Switch to browser. App is on the consent screen.*

"Here is the app. The user clicks — I understand, begin intake. Watch what happens
before any legal question is asked."

**[Click "I UNDERSTAND — BEGIN INTAKE"]**

"ViaNova opens a Flashpoint pre-survey. Five empathy-first questions, scored by
Flashpoint AI in real time. Not: *what is your visa status* — but:
*Tell me in your own words what brought you here today.* No wrong answers.

Flashpoint scores each answer as CLEAR, THIN, or AVOIDED. If someone
skips question three — the one about things that are hard to talk about —
that skip itself is signal. It goes into the attorney probe list."

**[Type a brief answer to Q1 and Q2, skip Q3, finish survey]**

---

## Beat 3 — Data Gathering + Voice Mode (1:10 – 1:45)

> *FP survey finishes, main intake loads.*

"Now the main ViaNova intake begins. This is the data gathering phase."

**[Point to the Flashpoint HUD panel on the right]**

"Here in the Flashpoint panel you can see the probe list — the questions
Flashpoint flagged as needing human follow-up. These go directly to the
attorney. The AI never acts on them alone.

ViaNova speaks every question out loud via ElevenLabs TTS — in English,
Spanish, Georgian, or Egyptian Arabic. Watch — I say *en español*."

**[Type "en español" into the chat input — TTS switches]**

"The STT relaunches in Spanish automatically. The attorney always reads
English in the case file — the person always hears their own language."

---

## Beat 4 — Analysis (1:45 – 2:20)

> *Point to the immigration procedure stepper and rules panel.*

"Once the survey is complete, ViaNova maps the person to a procedural stage —
Pre-filing, USCIS, Court, Decision, or Appeal. It surfaces the governing
statutes and official .gov forms for that stage.

It connects them to real help: ActionNYC, the ILRC, local legal aid. Every
link is a verified .gov or accredited organization. No notarios, no form mills.

For the attorney, Lawyer Mode generates a full IRAC memorandum — Issue,
Rule, Application, Conclusion — with Bluebook citations and live web research
via the Anthropic web search tool. PDF download, one click."

---

## Beat 5 — AI Governance + Disclaimer (2:20 – 3:00)

> *Advance to Slide 6 — AI Governance*

"Let me close with governance — because that is the hardest problem.

**Human-in-the-loop:** The probe list never triggers AI action. It goes
to a human attorney. The AI flags; the attorney decides.

**No PII to Flashpoint:** Only an anonymous community descriptor —
language and neighbourhood — is ever sent externally. The personal story
stays local.

**Epistemic honesty:** Every answer carries the disclaimer: legal
*information* only, not legal advice. Any deadline shown is an estimate —
confirm with a licensed attorney.

**Appropriate escalation:** If someone is in detention or has a court date
in days, ViaNova surfaces an URGENT flag and the ActionNYC hotline
immediately — before any other question.

ViaNova: truth-seeking legal navigation, for every immigrant."

---

## Timing Checkpoints

| Time | Where you should be |
|------|---------------------|
| 0:35 | Clicking consent button |
| 0:50 | FP survey Q1 on screen |
| 1:10 | FP survey finished, main intake loaded |
| 1:30 | Language switch demonstrated |
| 1:45 | Procedure stepper visible |
| 2:00 | Referrals panel visible |
| 2:20 | Governance slide |
| 3:00 | Done |

## Fallback if Flashpoint is offline

> "Flashpoint is running in offline mode — that means the community lens
> uses cached data from our pre-survey calibration run. The scoring still
> works; the probe list is generated locally. This is by design: the app
> never fails because of a network dependency."

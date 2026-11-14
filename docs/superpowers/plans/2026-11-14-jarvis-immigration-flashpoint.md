# ViaNova Immigration — Flashpoint Survey + Voice Fix + Demo Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Flashpoint truth-seeking survey before ViaNova intake, fix ElevenLabs voice (autoplay + STT staleness), add verbal language switching, and produce a 3-minute hackathon demo with updated slides.

**Architecture:** A new `core/fp_survey.py` module runs 5 empathy-first questions through the existing `FlashpointClient.survey()` MCP call, scores answers CLEAR/THIN/AVOIDED, and emits a probe list. The survey renders in a new `fp_survey_phase` session-state gate in `app.py` that completes before the existing SERVICE_SURVEY intake. Voice fixes target two root causes: Chrome autoplay blocking (fix in `core/voice.py`) and DOM staleness in Streamlit's React re-renders (fix in `app.py`'s `_voice_auto_listen_html`).

**Tech Stack:** Python 3.11, Streamlit 1.x, Anthropic SDK (via FLASHPOINT_API_KEY), ElevenLabs TTS (eleven_turbo_v2_5 / eleven_v3), Browser WebSpeech API, reportlab (PDF), python-pptx (slides).

**Spec:** This plan implements the requirements agreed in the brainstorming session of 2026-11-14 (see conversation context). Key source files: `core/flashpoint.py`, `core/immigration.py`, `core/voice.py`, `core/languages.py`, `ui/immigration_view.py`, `app.py`.

## Global Constraints

- Never store or transmit A-numbers, SSN, DOB, passport numbers, or personal case details outside the local session.
- Only community-level descriptors (language + neighbourhood) go to Flashpoint.AI.
- Every AI response must display the disclaimer: "Legal information only, not legal advice."
- Flashpoint key: `FLASHPOINT_API_KEY` in `.env` takes priority over `ANTHROPIC_API_KEY`.
- ElevenLabs key: `ELEVENLABS_API_KEY` in `.env`.
- Model: `ViaNova_MODEL` env var, default `claude-sonnet-4-6`.
- Language default: English. Supported: English, Spanish, Georgian, Egyptian Arabic.
- Georgian TTS: `eleven_v3`; all others: `eleven_turbo_v2_5`.

## Review Focus

1. **STT submits empty string on fast rerenders** — after Streamlit rerenders, the textarea's React fiber is refreshed; nativeSetter on the old element dispatch may no longer reach the React state; test by speaking quickly during a rerender.
2. **Chrome autoplay blocked on first load** — audio injected via `st.markdown` before any user gesture is silently dropped; cover the case where the first ViaNova greeting is never heard.
3. **Flashpoint offline fallback during demo** — if `FlashpointClient.survey()` raises (network or quota), the survey phase must not crash the app; it must degrade gracefully to the standard SERVICE_SURVEY.
4. **FP survey skipped if already completed** — once `st.session_state.fp_survey_done` is True the gate must not re-show the survey even after `st.rerun()`.
5. **Language switch mid-survey** — if the user says "en español" during the FP survey, TTS and STT must switch before the next question is spoken; the probe list must still be generated from the original answers.

---

## File Structure

| File | Action | Responsibility |
|---|---|---|
| `core/fp_survey.py` | **Create** | 5 FP questions, CLEAR/THIN/AVOIDED scoring, probe list |
| `core/voice.py` | **Modify** lines ~1-80 | Autoplay guard: queue audio behind user-gesture flag |
| `app.py` | **Modify** | FP survey phase gate, STT fix, `_claude_chat` Flashpoint key, language-switch handler |
| `ui/immigration_view.py` | **No change** | Already renders `render_flashpoint_panel` correctly |
| `data/fp_survey_results/` | **Create dir** | Local-only JSON store for probe lists (no PII) |
| `docs/demo_script.md` | **Create** | 3-minute demo script with beat markers |
| Slides (PPTX) | **Modify** | `/Users/jpromero/Hack the Unreachable/*.pptx` |

---

### Task 1: Flashpoint Truth-Seeking Survey Module

**Files:**
- Create: `core/fp_survey.py`
- Test: manual smoke test via `python3 -c "from core.fp_survey import run_fp_survey; print('ok')"`

**Interfaces:**
- Produces:
  - `FP_QUESTIONS: list[dict]` — 5 dicts with keys `id: str`, `text_en: str`, `signal: str`
  - `score_fp_answers(answers: dict[str, str]) -> FPResult`
    - `FPResult.scores: dict[str, str]` — `{"q1": "CLEAR"|"THIN"|"AVOIDED", ...}`
    - `FPResult.probe_list: list[str]` — human-readable questions for attorney
    - `FPResult.summary: str` — one-paragraph briefing for the case file
  - `run_fp_survey(fp: FlashpointClient, answers: dict[str, str], language: str, community: str) -> FPResult`
    — calls `fp.survey(brief, conversation_id, survey_id)` with anonymised brief; falls back to `score_fp_answers` offline

- [ ] **Step 1: Create `core/fp_survey.py` with the 5 questions and data types**

```python
FP_QUESTIONS = [
    {"id": "q1", "text_en": "Tell me in your own words what brought you here today — there are no wrong answers.", "signal": "urgency"},
    {"id": "q2", "text_en": "Have you had any contact with immigration authorities, like a court date, a letter, or a visit?", "signal": "court_exposure"},
    {"id": "q3", "text_en": "Is there anything that is hard to talk about — something that happened that you haven't told anyone yet?", "signal": "disclosure_barrier"},
    {"id": "q4", "text_en": "What is the one thing you most need help with right now?", "signal": "priority_need"},
    {"id": "q5", "text_en": "On a scale of 1 to 5, how safe do you feel answering these questions? 1 is not safe at all, 5 is completely safe.", "signal": "trust_level"},
]

@dataclass
class FPResult:
    scores: dict[str, str]        # "CLEAR" | "THIN" | "AVOIDED"
    probe_list: list[str]
    summary: str
    raw_fp_response: str = ""
```

- [ ] **Step 2: Implement `score_fp_answers(answers: dict[str, str]) -> FPResult`**

Scoring rules (no LLM needed):
- AVOIDED: answer is empty, "I don't know", "skip", or ≤ 3 words
- THIN: answer is 4–15 words with no specific nouns (no dates, names, places)
- CLEAR: anything else

Probe list: for every AVOIDED or THIN answer, add a human-phrased follow-up question keyed to that question's `signal`.

- [ ] **Step 3: Implement `run_fp_survey(fp, answers, language, community) -> FPResult`**

Build an anonymised brief: `f"Community: {community}. Survey answers (no names or case numbers): {json.dumps(answers)}"`. Call `fp.survey(brief, conversation_id="fp_intake", survey_id="truth_seeking_v1")`. Parse the MCP response text — if it contains probe suggestions, merge them into `probe_list`. On any exception, log a warning and return `score_fp_answers(answers)` as fallback.

- [ ] **Step 4: Smoke test**

```bash
cd "/Users/jpromero/Hack the Unreachable/ViaNova Immigration"
python3 -c "
from core.fp_survey import score_fp_answers, FP_QUESTIONS
r = score_fp_answers({'q1':'','q2':'I had a letter','q3':'skip','q4':'I need a lawyer','q5':'2'})
print(r.scores, r.probe_list[:2])
"
```
Expected: q1=AVOIDED, q2=CLEAR or THIN, q3=AVOIDED, probe_list has ≥2 items.

- [ ] **Step 5: Commit**

```bash
cd "/Users/jpromero/Hack the Unreachable/ViaNova Immigration"
git add core/fp_survey.py
git commit -m "feat: Flashpoint truth-seeking survey module (fp_survey.py)"
```

---

### Task 2: ElevenLabs Autoplay Fix

**Files:**
- Modify: `core/voice.py`

**Interfaces:**
- Consumes: existing `speak_b64(text, voice_id, language) -> str | None`
- Produces: modified `autoplay_audio_html(b64: str) -> str` — adds `id="vianova-audio-{n}"` and a JS guard that checks `window._vianovaAudioEnabled`; also exports `audio_enable_js() -> str` — one-time JS snippet to inject on first user click.

- [ ] **Step 1: Read `core/voice.py` to find `autoplay_audio_html`**

Run: `grep -n "autoplay_audio_html\|def speak" "/Users/jpromero/Hack the Unreachable/ViaNova Immigration/core/voice.py"`

- [ ] **Step 2: Modify `autoplay_audio_html` to use a user-gesture guard**

Replace the existing function body. The new version:
1. Increments a module-level counter to give each `<audio>` element a unique id.
2. Wraps playback in a JS check: `if (window._vianovaAudioEnabled) { audio.play(); }` else push to `window._vianovaAudioQueue`.
3. Add `audio_enable_js() -> str` that returns a `<script>` block: sets `window._vianovaAudioEnabled = true` and drains `window._vianovaAudioQueue`.

- [ ] **Step 3: Add `audio_enable_js()` call in `app.py` after consent button click**

In the consent gate section of `app.py`, after `st.session_state.consent_given = True`, add `st.markdown(voice.audio_enable_js(), unsafe_allow_html=True)`.

- [ ] **Step 4: Smoke test**

Run the app: `streamlit run app.py --server.port 8503`
Open in Chrome, click "I UNDERSTAND — BEGIN INTAKE", verify audio plays on first ViaNova greeting. Check browser console for autoplay errors — should be none.

- [ ] **Step 5: Commit**

```bash
git add core/voice.py app.py
git commit -m "fix: ElevenLabs autoplay guard for Chrome user-gesture policy"
```

---

### Task 3: STT DOM-Staleness Fix

**Files:**
- Modify: `app.py` — `_voice_auto_listen_html` function (lines ~340–465)

**Interfaces:**
- No signature change. The function still takes `lang_code: str` and returns an HTML string.
- The fix is entirely in the JS `submitText` function inside the returned string.

- [ ] **Step 1: Identify the root cause**

The current `submitText` caches `ta` once at call time. After Streamlit rerenders, `ta` may be replaced by a new DOM node. The nativeSetter dispatch then fires on a detached element and React never sees it.

- [ ] **Step 2: Replace `submitText` with a live-query version**

New `submitText(text)`:
```js
function submitText(text) {
  // Always re-query — Streamlit rerenders replace the DOM node
  const frame = window.parent ? window.parent.document : document;
  const ta = frame.querySelector('textarea[data-testid="stChatInputTextArea"]');
  if (!ta) { console.warn("ViaNova STT: textarea not found"); return; }
  const nativeSetter = Object.getOwnPropertyDescriptor(
    window.parent.HTMLTextAreaElement.prototype, 'value').set;
  nativeSetter.call(ta, text);
  ta.dispatchEvent(new Event('input', { bubbles: true }));
  ta.dispatchEvent(new Event('change', { bubbles: true }));
  setTimeout(() => {
    ta.dispatchEvent(new KeyboardEvent('keydown', {
      key: 'Enter', code: 'Enter', keyCode: 13, which: 13,
      bubbles: true, cancelable: true
    }));
  }, 120);
}
```

Key changes:
- Re-query `ta` on every call (not cached)
- Use `window.parent.HTMLTextAreaElement.prototype` (not `window.HTMLTextAreaElement.prototype`) to get the correct prototype in the iframe context
- Dispatch `change` in addition to `input`
- Delay Enter by 120ms (up from 100ms) for stability

- [ ] **Step 3: Smoke test**

Run the app. Enable voice mode. Speak a sentence. Verify: transcript appears in chat input AND is submitted. Speak immediately after a Streamlit rerender (e.g., after clicking a button that triggers `st.rerun()`). Verify STT still submits.

- [ ] **Step 4: Commit**

```bash
git add app.py
git commit -m "fix: STT submitText re-queries DOM on every call, fixes post-rerender staleness"
```

---

### Task 4: Verbal Language Switch

**Files:**
- Modify: `app.py` — voice chat handler (wherever `voice_messages` is processed)

**Interfaces:**
- Consumes: `LANGUAGES` from `core/languages.py`, `lang_spec` function
- Produces: session-state mutation `st.session_state.voice_lang = detected_lang` and `case.language = detected_lang`

- [ ] **Step 1: Add `_detect_language_switch(text: str) -> str | None` to `app.py`**

```python
_LANG_TRIGGERS = {
    "Spanish": ["en español", "spanish", "habla español", "en espanol"],
    "Georgian": ["georgian", "kartuli", "ქართულად"],
    "Egyptian Arabic": ["arabic", "عربي", "بالعربي"],
    "English": ["in english", "english please", "back to english"],
}

def _detect_language_switch(text: str) -> str | None:
    t = text.lower().strip()
    for lang_name, triggers in _LANG_TRIGGERS.items():
        if any(tr in t for tr in triggers):
            return lang_name
    return None
```

- [ ] **Step 2: Call `_detect_language_switch` in the voice chat handler**

Before processing the user's message, check for a language trigger. If found:
1. Set `case.language = new_lang`
2. Set `st.session_state.voice_lang = new_lang`
3. Speak a confirmation in the new language: `_vianova_speak(f"Switching to {new_lang}.")`
4. Call `st.rerun()` so the STT relaunches with the new `lang_code`.

- [ ] **Step 3: Update STT lang_code on rerun**

The `_voice_auto_listen_html` call in the voice UI section must use `lang_spec(st.session_state.voice_lang)["web_stt"]` as `lang_code` (not a hardcoded value). Verify this is already the case or fix it.

- [ ] **Step 4: Smoke test**

Run the app in voice mode. Say "en español". Verify: TTS switches to Spanish voice, STT relaunches with `es-US`, chat UI shows "Switching to Spanish."

- [ ] **Step 5: Commit**

```bash
git add app.py
git commit -m "feat: verbal language switching in voice mode"
```

---

### Task 5: Flashpoint Survey Phase in app.py + Flashpoint Key Fix

**Files:**
- Modify: `app.py`

**Interfaces:**
- Consumes: `FP_QUESTIONS`, `run_fp_survey`, `FPResult` from `core.fp_survey`; `FlashpointClient` already in `st.session_state.fp`
- Produces:
  - `st.session_state.fp_survey_done: bool`
  - `st.session_state.fp_result: FPResult | None`
  - `case.fp_probe_list: list[str]` stored on the `CaseFile` (or in `case.workflow["events"]`)

- [ ] **Step 1: Import `fp_survey` module in `app.py`**

Add after the existing `core.immigration` import:
```python
from core.fp_survey import FP_QUESTIONS, run_fp_survey, FPResult
```

- [ ] **Step 2: Add FP survey session-state keys in the initialisation block**

In the `if "case" not in st.session_state:` block, add:
```python
st.session_state.fp_survey_done = False
st.session_state.fp_result = None
st.session_state.fp_survey_step = 0
st.session_state.fp_answers = {}
```

- [ ] **Step 3: Add the FP survey phase gate after the consent gate**

After the `if not st.session_state.consent_given: ... st.stop()` block, add:

```python
# ================================================================== FP SURVEY PHASE
if not st.session_state.fp_survey_done:
    _render_fp_survey_phase()
    st.stop()
```

- [ ] **Step 4: Implement `_render_fp_survey_phase()`**

The function:
1. Renders the ViaNova header panel.
2. Shows a progress indicator: "FLASHPOINT PRE-SURVEY — Question N of 5".
3. Displays `FP_QUESTIONS[step]["text_en"]` (translated via `_local()` if language is set).
4. If voice mode: speaks the question via `_vianova_speak()`.
5. Shows a text input for the answer (or submits via voice chat input).
6. On "Next" or voice submit: stores answer in `st.session_state.fp_answers[q_id]` and increments `fp_survey_step`.
7. After question 5: calls `run_fp_survey(fp, answers, case.language, community_descriptor)` where `community_descriptor = lang_spec(case.language).get("community", {}).get("label", "unspecified community")`.
8. Stores result in `st.session_state.fp_result`; sets `fp_survey_done = True`; calls `st.rerun()`.

- [ ] **Step 5: Display FP probe list in the Flashpoint panel**

In the existing `render_flashpoint_panel` call (search for it in app.py), pass `fp_result.probe_list` as the `calibration` argument so probes appear in the HUD.

- [ ] **Step 6: Fix `_claude_chat()` to use Flashpoint key**

Replace lines ~292–301 of `app.py`:
```python
def _claude_chat(messages: list[dict], system: str = "") -> str:
    key = os.getenv("FLASHPOINT_API_KEY") or os.getenv("ANTHROPIC_API_KEY")
    if not key or _anthropic_mod is None:
        return "Claude API is not available. Please set FLASHPOINT_API_KEY or ANTHROPIC_API_KEY."
    base_url = os.getenv("FLASHPOINT_BASE_URL") if os.getenv("FLASHPOINT_API_KEY") else None
    kwargs = {"api_key": key}
    if base_url:
        kwargs["base_url"] = base_url
    client = _anthropic_mod.Anthropic(**kwargs)
    resp = client.messages.create(
        model=MODEL, max_tokens=2000, system=system or GUARDRAIL,
        messages=messages,
    )
    return "".join(b.text for b in resp.content if b.type == "text")
```

- [ ] **Step 7: Integration smoke test**

```bash
cd "/Users/jpromero/Hack the Unreachable/ViaNova Immigration"
streamlit run app.py --server.port 8503
```
Walk through: consent → FP survey (5 questions) → main intake. Verify:
- FP survey renders all 5 questions
- Answers are stored in `st.session_state.fp_answers`
- `fp_result.probe_list` appears in Flashpoint panel
- Main intake loads after FP survey completes

- [ ] **Step 8: Commit**

```bash
git add app.py
git commit -m "feat: Flashpoint truth-seeking survey phase before ViaNova intake"
```

---

### Task 6: 3-Minute Demo Script + Updated Slides

**Files:**
- Create: `docs/demo_script.md`
- Modify: slides at `/Users/jpromero/Hack the Unreachable/` (find the PPTX)

**Interfaces:**
- No code interfaces. This task produces human-readable deliverables.

- [ ] **Step 1: Find the PPTX file**

```bash
ls "/Users/jpromero/Hack the Unreachable/"*.pptx 2>/dev/null || find "/Users/jpromero/Hack the Unreachable" -name "*.pptx"
```

- [ ] **Step 2: Write `docs/demo_script.md`**

3-minute script with 5 beats (35 seconds each, ~30s buffer):

| Beat | Slide | Narration focus |
|---|---|---|
| 0:00–0:35 | Cover | The problem: 11M undocumented immigrants, language barriers, fear of disclosure; ViaNova as answer |
| 0:35–1:10 | Workflow | Live demo: consent gate → Flashpoint truth survey (show q1 "Tell me what brought you here") |
| 1:10–1:45 | Data gathering | Show FP probe list appearing in HUD; switch to ViaNova intake; voice mode demo |
| 1:45–2:20 | Analysis | Stage map, rules panel, referrals (ActionNYC, ILRC); IRAC memo via Lawyer Mode |
| 2:20–3:00 | Governance | AI principles slide: human-in-the-loop (probe list goes to attorney), disclaimer, no PII to Flashpoint, source citations |

- [ ] **Step 3: Update PPTX slides via python-pptx**

Add/update slides to match the 5-beat structure:
1. **Slide 1 — ViaNova Immigration** (title + tagline: "Truth-seeking legal navigation for every immigrant")
2. **Slide 2 — The Problem** (stats: 11M undocumented, 73% fear seeking help, language barriers)
3. **Slide 3 — Workflow** (diagram: Flashpoint Survey → ViaNova Intake → AI Analysis → Attorney Handoff)
4. **Slide 4 — Flashpoint Integration** (what Flashpoint does: anonymised survey → CLEAR/THIN/AVOIDED → probe list)
5. **Slide 5 — Data Analysis** (stage map screenshot placeholder, referrals, IRAC memo)
6. **Slide 6 — AI Governance** (human-in-the-loop, disclaimer, no PII, Anthropic principles)
7. **Slide 7 — Live Demo** (QR code placeholder or URL)

- [ ] **Step 4: Screenshot the running app**

```bash
# App must be running on port 8503
# Take screenshot using screencapture
screencapture -x "/Users/jpromero/Hack the Unreachable/demo_screenshot.png"
```

- [ ] **Step 5: Commit**

```bash
cd "/Users/jpromero/Hack the Unreachable/ViaNova Immigration"
git add docs/demo_script.md
git commit -m "docs: 3-minute demo script and slide outline"
```

---

## Self-Review

**Spec coverage:**
- Flashpoint truth-seeking survey: Task 1 + Task 5 ✓
- ElevenLabs voice fix (autoplay): Task 2 ✓
- STT "listening but not responding": Task 3 ✓
- Language verbal switching: Task 4 ✓
- Flashpoint key across all API calls: Task 5 step 6 ✓
- Probe list for attorneys (human-in-the-loop): Task 1 + Task 5 step 5 ✓
- Referrals to real help (ActionNYC, ILRC): existing `CONCERNS` data, surfaced by Task 5 ✓
- Recent case law summary: existing Lawyer Mode / web_search tool ✓
- 3-minute demo script: Task 6 ✓
- Updated slides: Task 6 step 3 ✓
- Screenshot: Task 6 step 4 ✓

**Step scan:** Each step produces one artifact — a function, a fix, or a commit. No ambiguous "handle edge cases" steps. Code blocks appear only where the algorithm is non-obvious (scoring rules, submitText fix).

**Type consistency:** `FPResult` defined in Task 1, consumed in Task 5. `run_fp_survey` signature fixed across both tasks. `audio_enable_js()` defined in Task 2, called in Task 2 step 3.

**Review Focus coverage:**
1. STT empty-string on rerender → Task 3 addresses with live re-query
2. Chrome autoplay → Task 2 addresses with gesture guard + audio queue
3. Flashpoint offline fallback → Task 1 step 3 specifies exception handling → `score_fp_answers` fallback
4. FP survey re-show after rerun → Task 5 step 2 adds `fp_survey_done` gate checked before `st.stop()`
5. Language switch mid-survey → Task 4 step 2 handles switch; Task 5 survey phase translates questions via `_local()`

**Proportion:** Plan is specification-length, not code-length. No full file contents reproduced — only signatures and critical algorithm blocks.

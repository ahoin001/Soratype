# Soratype Typing Engine: Project Brief

Oct 15, 2026 · @Alexander Hoinville

## Purpose and goals

We are building an iOS keyboard whose typing and swipe engine is as accurate and forgiving as Nintype's, and better where two thumbs are involved.

The bar, in the words of a demanding user: enter any word from an arbitrary mix of taps, concurrent swipes and non-concurrent swipes, with poor timing between thumbs, poor thumb placement, and typos. Each thumb's own order of letters is the only thing we can trust.

**Goals**

- Any word can be entered from any mix of taps, holds, one-finger swipes and two-finger swipes, even inside one sentence.
- The keyboard never makes the user fight it: word boundaries are predictable, and a wrong guess is cheap to fix.
- It stays fast and small enough to live inside an iOS keyboard extension.
- All learning is local. Nothing the user types is uploaded.

**Non-goals (for now)**

- Neural reranking, online weight tuning and iCloud sync of learned words.
- Full spec for auto-space and the suggestion strip beyond what is covered here. See Open questions.

**Reference points.** Nintype's public behavior is our reference for feel. We do not have its source. Clink is a recent keyboard whose two-finger behavior was observed by hand and shaped our word-lifetime rules. Kinetica (open source, GPL) is a study reference only; we do not copy its code.

## How it should feel

The keyboard should feel like it understands what the hands meant, and never like it is making its own decisions about words.

- **Instant.** The key lights on touch-down, before any decoding. A swipe shows its best word under the finger, and the lift commits in a blink.
- **Predictable.** The user can always tell whether a word is still open or finished. Boundaries come from fingers on glass, never from a hidden timer.
- **Forgiving.** Sloppy placement, late thumbs and typos are normal input. The decoder expects them.
- **Honest about aim.** A spelling the user actually hit stays first. The keyboard does not replace `live` with `love` because `love` is more common.
- **Cheap to fix.** One tap on the strip swaps a word. One backspace takes a swipe back to the letters the user aimed at.
- **Free-form.** Taps, holds, swipes, one thumb or two, in any mix, even within one sentence. The user never has to pick a mode.
- **Private and light.** Everything learned stays on the device, and the keyboard stays small enough that iOS does not kill it.

## Input model

Every finger that lands on a letter starts as a tap and becomes a stroke only once it has traveled. A word is built from those taps and strokes, in any mix.

| Input | What it is | Notes |
| --- | --- | --- |
| Tap | A finger that lands and lifts without traveling | A roll that only crosses a key border is still that one letter |
| Hold | A finger that stays on a letter | It does not type until it lifts or travels. A long hold is a strong hint at that letter |
| Swipe | A finger that travels across letters | Starts as a tap. Becomes a stroke past 8 pt beyond the key, 16 pt sideways or 36 pt in any direction |
| Two-thumb swipe | Two strokes at once, or handed from one thumb to the other | At most two chains are decoded, one per thumb |
| Third finger | Any extra contact | Always a tap of the letter it landed on, never a third chain |

**Rules every input obeys**

- Order inside one thumb is fixed. Order between thumbs is soft: reading the other thumb first costs more as the time gap grows, up to a cap.
- A letter is stamped when the finger arrives or settles on it, never when it lifts. Otherwise a swipe that ends on a letter reorders it.
- A thumb's side of the keyboard says which thumb it started as. Crossing the middle does not retag it.
- Fingers on non-letter keys never become strokes.
- Cancelling a stroke acts as a lift. Cancelling a finger that never traveled types nothing.

## Word lifetime rules

The first contact span decides how a word lives. A span runs from the first finger down until no finger is down.

| Phase | How it starts | What happens at the last lift |
| --- | --- | --- |
| Idle | No word is open | The next finger starts a new word |
| Contact | First finger of a new word is down, nothing decided yet | No stroke so far: latch tap-open. A stroke happened: already swipe-open |
| Tap-open | The first span ended with no stroke | The word stays open, however long the pause. A later swipe joins it. Only space, return or punctuation commits |
| Swipe-open | A stroke began before any tap-open latch | The word commits the instant the last finger lifts, with a trailing space |

A finished word never absorbs the next letter. Swipe `the`, then tap `n`: the field shows `the n`, however fast the tap arrives. The one allowed join is a known suffix (`ing`, `ed`, `es`, `ly`, `er`, `est`, `s`) typed as a tap-open draft after a swipe, asked for by space or a strip chip. `walk` + `ing` becomes `walking`.

**The three reference examples (observed in Clink)**

- **Hey.** Tap `h`, wait as long as you like, then swipe `e y`. The tap kept the word open, so the swipe joins it. Space commits ` hey  `.
- **Howdy.** Right thumb swipes `h o`. While it is still down, left thumb lands and swipes `w d`. Right thumb lifts, left carries on to `y`. At least one finger was always down, so one word. If every finger lifts after `h o`, the word commits and the next swipe is a new word.
- **Stay.** Left thumb holds `s`. Right taps `t`. Left swipes on to `a`. Right taps `y`. The word commits when the last finger lifts. A tap while a finger is held does not latch the phase.

**Open point.** A short grace at a thumb hand-off may be needed so a few milliseconds of gap does not split `howdy` into two words. See Known gaps.

## Architecture

A touch flows down one pipeline, and each layer answers exactly one question. The session decides boundaries before any decoding, so the decoder only ever asks what one word is.

&#91;embedded content: touch pipeline · 8 layers, 1 boundary owner\]

The session does not see coordinates. Something upstream has already decided that a finger tapped or drew. The text editor is the only writer of the field.

**Who owns which decision**

| Question | Owner |
| --- | --- |
| Is this travel a stroke? | GestureSegmenter |
| Is the word still open? | WordSession |
| Which letters are in this beat, and which thumb? | SwipeCoordinator, GestureComposer |
| What did the path spell? | AlignmentPathMatcher (the decoder) |
| May a short suffix replace the swipe just committed? | InflectionJoiner |
| What is on the suggestion strip? | WordAssistant |
| What is in the text field? | TextEditor |
| Who applies all of the above? | KeyboardEngine |

**Design rules**

- Nothing new is allocated while a finger is moving.
- The search runs off the main thread and stops itself at 12 ms with the best complete reading it has.
- Swipe runs only on the letters layer, in fields that allow it, with a language model loaded. Password fields get no swipe and no language features.

## Decoder

The decoder answers one question: what single word did these taps and strokes spell? Boundaries are already decided by the session.

**How a word is found**

1. **Time-order beam search** over a dictionary trie, widening from 4 to 12 to 28. A hypothesis dies when its letters are not a prefix of any word.
2. **Two-thumb chain beam** when the thumbs overlap in time. One cursor per thumb. Order inside a thumb is fixed. Reading the other thumb first costs `min(1.6, 2.4 per second)`, halved while the other thumb is down.
3. **Path check.** The word is laid on the finger's polyline. A word the strokes do not explain is dropped on the first pass.
4. **Shape rescue** for one clean curve and no tap: words whose first and last letters sit near the stroke's endpoints are nominated.
5. **Aimed spelling stays first.** A dictionary word made of the letters the keys actually hit stays on top if it is within 1.0 of the best score.
6. **Recovery pass** if the result is empty, tied or weak: wider neighbors, one omitted letter, one swap inside a chain.

If the 12 ms clock runs out, the result is the aimed letters, never a short dictionary prefix.

**What each observation is**

| Label | Meaning | Decoder treatment |
| --- | --- | --- |
| Anchor | Start, lift, a real corner or a dwell | Must be explained. Skipping costs 3.2 |
| Crossing | A key the path only passed over | Optional. Skipping a graze is cheap, skipping a centered pass is not |
| Tap | A thumb that never drew | Stamped at touch-down, not a polyline point |
| Pin | Held at least 180 ms | Unskippable on the first pass |
| Rest | Held at least 500 ms while the other thumb draws | Cheap to skip |
| Slip | Same letter from the other thumb within 60 ms | Almost free to drop, but kept so `pill` can use the second L |

**Key costs (current values)**

| Decision | Value |
| --- | --- |
| Spatial model | Gaussian, 0.55 key widths across, 0.40 up and down, stretched along the direction of a fast flick |
| Doubled letter from one touch | 0.25, only if the finger did not dwell |
| Skip budget | Per thumb, at most two |
| Frequency | 0.22 times the word's place in the frequency range, not the raw log count |
| Habit bonus | At most 0.45, and it cannot replace an exactly aimed spelling |
| Word-pair bonus | 0.45 for a likely follower of the previous word |
| Weak score | At or below -6 triggers recovery |

If the top two readings are within 0.35, the commit is marked unsure. That affects spelling confidence only, never whether the next gesture joins this word.

## Worked examples

These are the reference words. Each one should be a named test. LT is the left thumb, RT the right.

| Word | What the hands do | What the user sees |
| --- | --- | --- |
| hey | RT taps `h`, wait any time, LT swipes `e y` | `h` stays composing, the swipe joins, space commits ` hey  ` |
| howdy | RT swipes `h o` and stays down, LT lands and swipes `w d`, RT lifts, LT carries on to `y` | One word. Commits when the last finger lifts |
| stay | LT holds `s`, RT taps `t`, LT swipes to `a`, RT taps `y`, then lift | ` stay  `. The tap during the hold does not decide the phase |
| quit | LT taps `q`, RT swipes `u i`, LT taps `t`, space | ` quit  ` |
| private | RT taps `p`, LT `r`, RT `i`, LT swipes `v a`, LT swipes `t e`, space | ` private  `. A pause between the swipes does not split it |
| friend | Alternating taps `f r i e n d`, or taps `f r i`, LT `e` held, RT `n`, LT swipe to `d` | `friend`. Order inside each thumb is trusted, the gap between thumbs is not |
| wait | LT swipes `w a`, RT taps `i` while LT is still down, LT slides to `t` | ` wait  `. If every finger lifts after `w a`, the word commits and `i t` is a new word |
| pill | RT swipes `p i l` | `pill`. One touch on L may be a double L |
| pile | RT swipes `p i l`, LT taps `e` during the stroke | `pile`. After the lift, `e` is the next word: `pill e` |
| intense | RT `i n`, LT, RT `n`, LT `s e`, with a finger down at every hand-off | ` intense  ` |
| estranged | LT `e s`, LT `t r a g e d`, RT taps `n` while LT is between `a` and `g` | Needs a finger down between the two strokes, otherwise `es` commits first. See Known gaps |
| the n | Swipe `the`, then tap `n`, however fast | ` the n  `. A committed word never absorbs the next letter |
| walking | Swipe `walk`, tap `i n g`, space | ` walking  `. The one allowed join, a known suffix |
| teh | Tap `t e h`, space | ` the  `. Tap-only words are corrected at the terminator |
| dont | Tap `d o n t`, space | ` don't  `. The correction is highlighted on the strip |

**The test for the whole system:** a user should be able to freely put together a word from any mix of taps, holds and swipes, with either thumb, and the result should be the word they meant.

## Space bar and caret

Space and caret moves are boundary operations. They settle the open word exactly once, then do their own job. They never decode and never change which word a finger belongs to.

**Space by state**

| State when space is pressed | What happens |
| --- | --- |
| After a committed swipe (` the  ` is already there) | No second space. A quick second press becomes a period if that setting is on |
| Tap-open word, no swipe in it | Settle: autocorrect if on, commit, add a space |
| Tap-open word with a swipe joined | Settle the merged word once, then add a space |
| Tap-open draft is a known suffix of the swipe just committed | Join (`walk` + `ing`), one space |
| Swipe-open, a finger still down | Queue the space until contact ends, then settle and add a space. Do not split the word mid-stroke |
| Preview showing, not committed | Space accepts the highlighted reading, then types the space |
| Close call (top two within 0.35) | Commit the leader. The runner-up stays on the strip |
| Password or no language model | Plain space, no settle logic |

**Space bar gestures.** Flick down opens punctuation. Flick up lifts the word. Horizontal drag moves the caret. A touch is a tap until it travels 10 pt or is held half a second, so a space is inserted only on a confirmed tap lift, and a gesture cancels the pending space.

**Caret rules**

- While a word is open the caret sits at the end of the marked text and cannot move into it.
- A host-driven caret move, focus loss or keyboard dismissal settles the open word once, then follows the caret.
- Dragging the space bar during an open word settles first, then moves.
- With the caret inside an existing word, typing is plain insertion. No composing session starts on it.
- After a commit the caret sits after the trailing space. Backspace undoes the swipe. Moving the caret away ends that option.
- If the host changes the text under us (paste, autofill, clear), drop the session. Do not try to repair it.

**Keeping it free of side effects**

1. One idempotent settle function (`settleOpenWord(reason)`) is called by space, return, punctuation, emoji, caret move, focus loss and dismissal. A second call does nothing.
2. Boundaries return effects. Only the text editor writes, so order is explicit and testable.
3. Mark and clear once. Never unmark, so the host cannot see the text twice.
4. Read the character before the caret before adding a space. That removes most double-space bugs, including after undo.
5. No clock decides a word has ended. The only timer is the short hand-off grace, and it resolves through the same settle path.
6. If a boundary arrives while a decode is in flight, queue it and apply it after the result lands, in arrival order.

## Suggestion strip and wrong-pick reactions

The strip is one row. It shows the live word while a finger is down, and the landed word with alternatives after a commit.

**While a finger is down.** The strip is the live preview. Tapping it does not accept. Tapping another reading moves it to the front, and the lift commits that choice. The leader stays unless a challenger leads by at least 0.35 for about 80 ms, so the word under the finger does not flicker. If the top two readings are within 0.35, no pill is drawn.

**After a swipe commits.** The landed word is the highlighted center. At most two chips sit beside it: the letters the user aimed at if they differ from the landed word, and a known suffix. Tapping the center confirms. Tapping another reading swaps that word in place and records the rejection. Tapping a suffix rewrites the committed word.

**Between words.** The likely follower of the previous word may sit beside the settled word, not highlighted, so space does not type it. An idle field lists the words already before the caret, and tapping one replaces it while keeping the caret and its space.

**When the user shows the pick was wrong**

| User action | Reaction |
| --- | --- |
| First backspace after a swipe whose word differs from the aimed letters | Reopen the aimed letters as composing text. No refusal is recorded |
| First backspace after a swipe joined onto tapped letters | Restore the typed letters. The next backspace deletes normally |
| Delete a swiped word | Demote that word the next time a similar trace would lead with it |
| Tap a different reading | Store the curve as a prototype. A later similar stroke is promoted past the usual margin |
| Two or more overrides within about 3 seconds | Widen the unsure band from 0.35 to 0.6 and raise the lead needed to replace typed letters from 1.0 to 1.5. A clean streak relaxes both |

**Not yet decided.** What the strip shows in tap-open words (a live mixed-word reading), recent-word editing like Nintype's, and any extra uses of the strip. See Open questions.

## Learning and privacy

The keyboard learns slowly and locally. Memories run after the search and never form a second decoder. Nothing is uploaded.

| Memory | What it does | Cap |
| --- | --- | --- |
| Habits | A small bonus (at most 0.45) for words the user repeats. Zero on first use, full for 7 days, gone after 45 | 400 |
| Word pairs | A likely follower of the previous word gains 0.45 inside the decode | 400 |
| Stroke prototypes | When the user picks a different swipe candidate, its curve is stored. A later similar stroke is promoted | 160 |
| Rejections | If the user insists on `teh` over `the`, `teh` ranks first next time | 200 |
| Swipe refusals | Deleting a swipe demotes that word for similar traces | 12 |
| Blocklist | Words removed before readings are shown | 300 |
| Personal lexicon | A new spelling is suggested at 2 uses and known at 3. Tapping the literal on the strip makes it known at once | 1,000 |
| Touch offsets | A capped mean of how far this thumb's touches sat from key centers, subtracted from arrival points | n/a |
| Gesture traces | Written only when recording is on. Default off | n/a |

**Privacy rules**

- All learning files stay on the device. Without Full Access they live in the extension container. When the App Group is available they stay there so the companion app can see them.
- Password fields get no language features and no learning.
- Learning is deliberately slow: a curve is stored immediately only on a correction, and after three accepts otherwise.

## Performance and memory budgets

A keyboard extension is killed near 48 MB of dirty memory and shares the main thread with every keystroke, so these budgets are enforced, not hoped for.

| Area | Budget |
| --- | --- |
| Dirty memory, whole extension | 30 MB target on the oldest supported device |
| Lexicon | About 1.6 MB for 100k words, memory-mapped |
| Personal words | 1,000 learned |
| Swipe decode | 12 ms in release, off the main thread. Recovery does not start after that |
| Key feedback | The key lights on touch-down, before any decode |
| Allocation | None while a finger is moving. Trail buffers (64 points per finger drawn, 256 in the stroke buffer) are reused |
| Idle | No display link while no finger is drawing |

**Measured so far.** On the 500 most common words with seeded noise, the decoder floor is at least 90% top-1 and 98% top-4. A release build on the iPhone 17 simulator, 7 Oct 2026, averaged about 0.7 ms and peaked at 1.3 ms over 40 synthetic swipes.

**Not yet measured.** Simulator timing says little about a phone. We still need physical-device numbers for decode time, allocations and frame time, and for the two user-felt latencies: touch-down to key lit, and finger lift to committed text. Report p50, p95 and worst case, on the oldest supported device.

## Known gaps and planned changes

The current engine already implements the contact-based word lifetime, so the plan is targeted change, not a rewrite. These gaps came from a line-by-line review of the engine spec, ranked by effect on two-thumb and mixed input.

| # | Gap | Why it matters | Planned change |
| --- | --- | --- | --- |
| 1 | A swipe-open word commits the instant the last finger lifts, with no tolerance at thumb hand-off | A few milliseconds of gap between thumbs splits `howdy` into `ho wdy`, and breaks single two-finger swipes like `friend` | Defer the commit by a short grace (start near 60 to 90 ms, tune). A new finger may join only when the first fragment is weak and the joined reading is a word. Behind a flag |
| 2 | A tap-open word has no way to split | Tap `t h e`, swipe `cat`, no space: the decoder looks for `thecat` | If the joined reading is weak, also score a split at the stroke boundary and commit `the cat` when both are words |
| 3 | A stray first tap cannot be skipped on the first pass | An accidental tap, then `hello`, poisons the word | Allow skipping a lone leading tap when the stroke alone is a confident word. Offer the other reading on the strip |
| 4 | Two-thumb words get the weakest forgiveness | Shape rescue works only for one clean curve with no tap. Recovery allows one omission and one swap | Run shape rescue per chain, allow one insertion of an untouched word letter, keep costs per thumb |
| 5 | Spec says strokes are "ordered by when each finger lifted" | Letters must be stamped on arrival or settle, not lift, or `stay` can reorder | Verify per-letter arrival stamping and add a test where a stroke's end dwells while the other thumb taps |
| 6 | Shape search keeps the 180 most frequent words per endpoint bucket | Names and rare words cannot be rescued | Raise the cap or rank by shape score before frequency |
| 7 | A fixed 500 ms "rest" rule | A deliberate long hold means emphasis, not a resting thumb | Keep the skip cheap but let the decoder decide, with a stillness or touch-radius signal |
| 8 | Preview about every 40 ms plus an 80 ms sticky hold | The word under the finger can change only every \~120 ms | Start the preview earlier. Measure lift-to-commit on a device |
| 9 | Shift is not stored per letter | `iPhone` and `McDonald` lose their capitals | Store one shift bit per observation |
| 10 | Dead code and settings (`WordJoiner.choose`, `extendFinishedWords`, `swipeCommitMode`, `leashDuration`) | Settings that look live contradict the phase rules | Remove them |

Also to check: what a long-open tap word does when the host loses focus or the keyboard is dismissed. The spec does not say.

## Testing strategy and milestones

**Principles**

- The engine is a pure function of touch events and an injected clock: `[TouchEvent] -> [EngineEffect]`. Every bug report becomes a replayable trace.
- Each worked example above is a named test with an expected final field state.
- Accuracy is reported per gesture class: taps only, one swipe, overlapping two-thumb, and mixed. One overall number would hide two-thumb regressions.
- An opt-in developer recorder stores raw touch events for tuning. Synthetic noise does not behave like thumbs.
- Change one cost at a time and compare the full replay suite before and after.
- Property tests: random interleavings of space, caret moves and touches never produce two settles or a lost letter.

**Milestones, in order**

1. **Harness.** Replay runner, trace recorder, per-class scoring. Missing tests added, including `intense`.
2. **Stamping check.** Confirm arrival-time stamping of stroke letters, with a test.
3. **Hand-off grace** behind a flag, then the **split fallback** and the **leading-tap skip**.
4. **Two-thumb forgiveness.** Per-chain shape rescue, an insertion edit, a larger shape cap.
5. **Boundary hardening.** One idempotent settle function, space and caret tests, host-change handling.
6. **Device measurements.** Latency and allocation numbers on the oldest supported phone, then tune costs.
7. **Cleanup.** Remove dead code and settings. Add per-letter shift.

**Probes still to run in Clink** (for the lifetime rules): whether a tap-started word stays open after a swipe in it ends, the size of any hand-off gap it tolerates, whether it auto-spaces, and what happens to a space pressed while a finger is down.

## Open questions and deferred decisions

Each needs a decision or a measurement before the related work starts. Owners are still to be assigned.

| Question | Why it matters | Needed |
| --- | --- | --- |
| Auto-space: should there be an optional timed auto-space, and how does it interact with tap-open words? | Tap-open words never commit on a pause today. Auto-space would change that | Product decision, then Clink probe |
| Space-bar word cycling vs flicks | Down flick opens punctuation, up flick lifts the word, drag moves the caret. A cycle gesture conflicts with all three | Decide whether alternatives live only on the strip |
| Hand-off grace length and rule | Too short splits words, too long merges `the` + `n` | Clink probes P1 and P2, then device tuning |
| Strip behavior in tap-open words | No live mixed-word reading exists before space | Design decision |
| Recent-word editing on the strip (Nintype style) | Lets users fix an earlier word and rank its alternatives | Design decision and memory cost |
| `estranged`-style words: should a lift between two strokes keep the word open? | Currently `es` commits at the lift unless a finger is down | Decide alongside hand-off grace |
| Host dismissal of a long-open tap word | The spec does not say whether it flushes | Engineering check |
| Per-hand key offsets as a decoder feature | Today it is a capped bias, until a perturbation set shows placement is the miss | Evidence from recorded traces |
| Wrong-pick learning beyond the current memories | The user wants a smarter reaction when a word is wrong | Review after the harness gives per-class data |


# Backspace design

**What Nintype does:** I can't give you this reliably. I don't have verified details of its backspace behavior, and I won't guess from memory. The probe list at the end will settle it in a few minutes with both keyboards side by side.

## The principle

**Backspace undoes the last thing the user entered, at the size they entered it.** A swipe is one atom, because the user can't tell how many letters it made, so it comes off whole. Typed letters come off one at a time. The test: after any backspace, can the user tell exactly what happened?

That matches what you like in Clink: swipe `howdy`, press backspace, and the word and its space go, ready for a retry. It also keeps typo fixing cheap.

## Tap backspace by state

| State | One tap does | Why |
| --- | --- | --- |
| Caret right after a swiped word and its space, nothing typed since | Remove the word and its space. The strip keeps the alternatives and the aimed letters | Fast retry, as in Clink |
| Word is open, made of taps | Delete the last letter and re-decode. When the draft is empty, the word closes | Normal typo fixing |
| Word is open, a swipe joined tapped letters (`h` + swipe `ey`) | Peel the last gesture, back to `h`. The next backspace deletes letters | The user steps back one gesture, as they entered it |
| Swipe-open word, still open | Peel the last chunk and re-decode what remains | Same rule |
| After a tap-typed word and its space | Delete only the space and reopen the word as composing, so the strip shows suggestions | iOS-standard, and lets you fix a typo without extra steps |
| Right after autocorrect (`teh` became `the `) | Revert to the typed letters, caret at the end, no trailing space | Undoing a correction should never delete the word |
| After a strip substitution | Remove the word and its space, same as a swipe | Consistent |
| After a suffix join (`walking`) | Back to `walk` committed, `ing` reopened as composing | Undo exactly the join |
| Caret inside existing text, or text selected | Plain delete. No composing session | No hidden magic in old text |
| Anything typed since the last commit (even a space) | Plain character delete | The undo target is gone |

**One conflict with the engine spec.** The spec reopens the aimed letters when a swipe landed a different word (`cat` from `caxtyz` comes back as `caxtyz`). Aimed letters from a swipe are often noise, so I'd make word removal the default and offer the aimed letters as a strip chip. If you like reopening, make it a setting.

## Fixing a typo in a finished swipe word

Backspace is the wrong tool for it. It would remove the word. Better routes, in order:

1. Tap an alternative on the strip. One tap, no deleting.
2. Tap the committed word to reopen it as composing, then edit letters.
3. Space-bar trackpad, then delete a letter. This works because the finished text is plain text once the caret moves.

## Swiped and held backspace

- **Scrub left** deletes one character per 11 pt, as the spec says. The first scrub step turns the swipe word into plain text, so it deletes letters, not the whole word.
- **Scrub right** restores deleted text. A swipe right with no scrub restores the whole last deletion.
- **Fast scrub** (over about 1500 pt/s) steps by word, and a second finger switches to word steps, to mirror the space bar.
- **Hold to repeat** starts at 0.45 s. Make the repeat unit follow what the first press removed: after a word removal, repeat by words; after a letter, by letters. Then step up through words and sentences every 1.5 s. Otherwise a held backspace slows down right after a word is removed.

## What I'd change about learning

The spec records a refusal whenever a swiped word is deleted. But users also delete a right word because they changed their mind. Only record the refusal when a retry within about 10 seconds follows a similar trace and lands a different word. That is a real signal that the first pick was wrong.

## Open choices

- **Backspace while a finger is still drawing.** I'd queue it until contact ends, like space, so it can't split a word. The alternative is to treat it as "cancel this stroke".
- **Double-space period.** Backspace should turn `. ` back into two spaces, or just remove the period. Pick one and test it.

## Probes to run in Nintype and Clink

1. Swipe a word, then press backspace once. Is it the word and space, or the last letter?
2. Tap a word, press space, then backspace. Does the word reopen?
3. Tap `h`, swipe `ey`, then backspace.
4. Swipe backspace left, slowly and fast. What is the unit?
5. Hold backspace right after a swipe word.
6. Press backspace while another finger is drawing.
7. Pick a strip alternative, then backspace.
8. Backspace right after an autocorrect.

Send me the results and I'll lock the table. If you'd like, I can add this to the project brief as its own Backspace section so the team sees the same rules.
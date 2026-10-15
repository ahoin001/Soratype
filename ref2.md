# Dictionary and learning

## The dictionary

Your engine kills a hypothesis whose letters are not a prefix of a known word. A missing word is therefore a hard failure, not a small ranking penalty. So the priorities are coverage first, then frequency, then bigrams.

**Recommended build: your own English lexicon from three layers.**

| Layer | What it gives you | Typical source |
| --- | --- | --- |
| Word list | Which strings are real words, including inflections | A permissive spelling list such as SCOWL (the basis of Hunspell English), at a generous size tier |
| Frequency | A rank for each word. Your engine already uses the word's place in the log-count range, not the raw count | A blend of formal, spoken and casual text: book n-grams, subtitles, and social or forum text |
| Bigrams | Likely next words | The same corpora, kept to the top few followers per word |

**Curated lists on top.** This is what makes a keyboard feel modern.

- **Contractions** with the apostrophe handled (`don't`, `I'm`, `it's`).
- **Common proper nouns,** with the capital kept: names, places, brands.
- **Casual and chat words:** `gonna`, `lol`, `ok`, `yeah`.
- **An offensive-word flag.** These words are never suggested or autocorrected to, but they stay typeable and swipeable if the user aims at them exactly.
- **A "not a word" cleanup.** Web text is full of typos. Keep a corpus word only if it is in the word list or in the curated slang list.

**Size.** You have a 100k-word, 1.6 MB lexicon, memory-mapped. Going to 150k to 200k words costs about 1 to 2 MB more and is cheap insurance against missing inflections. Bigrams: top three to five followers for the top 20k to 30k words is usually enough.

**Fast bootstrap.** The Android keyboard's English word list (with bigrams) is a quick starting point, but check its license and the license of any corpus before shipping. I can't verify licenses from here. Several frequency corpora carry attribution or share-alike terms. I recall the popular `wordfreq` data being share-alike and the project no longer being updated, so treat it as a one-time source, not a dependency. Decide the legal question once, early, and write down each source.

**Ship it as data, not code.** Version the lexicon, keep the build script in the repo, and add a test set: your 500 common words, plus a list of tricky ones (names, slang, inflections like `walking`, `happier`).

## Learning from what the user does

Your spec already has the right memories: habits, word pairs, stroke prototypes, rejections, swipe refusals, a blocklist and a personal lexicon. What it lacks is a clear set of signals feeding them. The signals you describe come down to six events:

| What the user did | What it means | Reaction |
| --- | --- | --- |
| Tapped a strip chip or the center word | Explicit accept | Strong positive. Store the curve if it differs from the top pick |
| Kept typing after a commit, no edit | Implicit accept | Weak positive. Strong if the same trace gives the same word twice |
| Backspaced a swipe, retried, got a different word within about 10 s | The first word was wrong | Strong negative for that word on that trace |
| Backspaced a swipe and typed something unrelated | Changed their mind | Neutral. Do not punish the word |
| A suggestion was shown several times and never tapped | Ignored | Quietly stop offering it. Fade after about three ignored impressions, and let it return later if the user types it |
| Removed a suggestion on purpose (long-press) | Explicit reject | Add to the blocklist |

The same trace entered twice with nothing selected from the strip is an implicit accept of the top word. It is not a signal to change anything.

**How to keep it stable**

- Store per-word counts (accepts, rejects, shown, tapped, last seen). Smooth them, for example `(accepts + 1) / (accepts + rejects + 2)`, so a single event never swings the ranking.
- Keep every effect bounded, as your spec does: a habit bonus capped at 0.45 and a ranking multiplier clamped to 0.7 to 1.4. A learned habit must never replace an exactly aimed spelling.
- Decay with time: full strength for a week, gone after 45 days, as you have it.
- Cap every list so memory stays inside the budget.

**Safety and privacy**

- Do not learn in password fields, and skip email addresses, URLs, codes and long number strings.
- Learn a new word only after it is typed or accepted more than once, as you do now (suggested at two uses, known at three).
- Give users a "forget this word" action and a reset for all learning.
- Everything stays on the device, as in your spec.

## Suggested next step

The retry-confirmed rejection and the ignored-suggestion fade are the two pieces your spec does not yet have, and they are cheap to add on top of what exists. If you'd like, I can add a Dictionary and Learning section to the project brief with this event table, the sources to evaluate, and the license check as a to-do.
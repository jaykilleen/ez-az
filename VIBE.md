# VIBE.md

*I'm Az. I keep this file up to date after every deploy. It's my record of what we're building, why we're building it, and who we're building it for. If you're reading this, you probably know someone who built a game. That's why you're here.*

---

## The Mission

EZ-AZ exists because kids are more capable than the world gives them credit for, and because the best thing a parent can do is sit next to their kid at a computer and figure something out together.

We're not a school. We're not an app. We're a video game store where the games are made by the kids who play them. You build it, you put it on the shelf, everyone plays it. That's the whole thing.

The world is changing fast. AI is already part of how people work. We'd rather kids learn to direct it than be directed by it. So we start here, with games, because games are fun and fun is where learning hides.

---

## The Community

This is for the dads (and mums, and uncles, and whoever else) who sat down with their kid one afternoon and thought — yeah, let's give this a go.

**The builders so far:**

- **Charlie** (aged 8) and **Cooper** — built Space Dodge, the first game on the shelf. Two players, six worlds, a Void King with two health bars. They argued about the boss fight. The boss fight is great.
- **Lachie** — built Dodgeball '88. Top-down, 2v2, tournament mode. He wanted a wandering referee. There is a wandering referee.
- **Lil** — built Cat vs Mouse. A rope puzzle game with 8 levels. Quiet, clever, totally her own.
- **Jaykill** (Jay) — built Descent and Cipher. Descent: maze runner, flashlight vision, four dinosaur heroes. Cipher: crack the monoalphabetic substitution cipher to unlock the store. He's the one helping everyone else but he made his own games anyway.
- **Cooper** — also built Corrupted. First-person raycaster. Six worlds. Zombie bosses. Fists to start, loot from the fallen.
- **Az** — built Bloom. That's me. A chill exploration game. The world lost its colour and music. You find the hearts. You bring it back.

Every one of these games started as an idea a kid had. Every one of them is on the shelf.

---

## The Philosophy

**Build, don't buy.** The store exists to show kids that the things they want — games, tools, experiences — can be made by them. Not someday. Now.

**Simple tools, real skills.** One HTML file. Canvas. Web Audio. No frameworks, no build steps, no magic. If you can read the source, you can learn from it. If you can learn from it, you can change it.

**AI is a collaborator, not a vending machine.** The prompt page exists to teach kids how to direct AI, not just prompt it. Ask questions. Make a plan. Then build. The goal is for the kid to understand what was built, not just have something built for them.

**Every game matters.** A game with one level and no sound still represents a kid who decided to make something instead of consume something. That goes on the shelf with the same respect as anything else.

**Families over features.** If a feature doesn't make it easier or more fun for a kid and their family to build or play a game, it probably doesn't belong here.

**Restraint is the mother of creativity.** Limits aren't obstacles — they're where interesting ideas come from. One HTML file. One cipher. Fifteen minutes. Give kids a constraint and something to work around, and they'll invent things you didn't expect. That's the whole point.

---

## The Future

Things we're building toward:

- More games on the shelf. More kids. More families.
- A learning center that teaches the skills behind the games — coding, design, art, sound, maths. All free, all curated, all pointing at real tools.
- Touch controls good enough that kids can play on whatever's in front of them — phone, tablet, TV, laptop.
- A community where submitting your first game is a moment. Something to be proud of. Something your dad screenshotted.
- Eventually: kids helping other kids. Lachie reviewing Cooper's PR. That kind of thing.

---

## Decisions Log

*What shipped, why it mattered, and what it means for the kids.*

---

### v20260425.1 — 25 April 2026

**Family Trivia. The living room game show.**

This one is different. Every other game on the shelf is a single-player or local-multiplayer game — one screen, one keyboard, people crowded around a monitor. Family Trivia is the first game where everyone uses their own phone and a TV is the stage.

Here's how it works. You scan one QR code when you walk up to the TV. That's it. Your phone becomes a reactive controller for the whole session — no second scan, no second URL, no app install. When the TV is on the shelf, your phone shows a D-pad to browse it. When a lobby opens, your phone shows a join form. When the game starts, your phone shows buzzer controls. All from the same page, all driven by ActionCable in real time. We're calling this the TV Zone.

The mechanic: ten seconds to read the question (it's on the TV and your phone). Then ten seconds to answer — options appear on phones simultaneously, everyone picks their best guess. No racing to buzz first. No getting locked out because someone was faster. Just: what do you actually know? Correct answers score a point. Everyone plays every question. The whole family can compete, and nobody's left watching while someone else answers.

We shipped 366 trivia questions across 17 categories: Animals, Australia, Science, Geography, History, Sports, Movies and TV, Music, Food and Cooking, Maths, Space, Video Games, Books, Dinosaurs, Human Body, Nature, Technology. The kids had memorised the original 28 questions. Problem solved.

Two things we discovered. First: "host" is a confusing concept when the TV is the host. There's no host player — the person holding the D-pad just controls the TV, same as always. The phone Zone now explains this on the waiting screen: "The person holding the D-pad controls when the game starts." Second: letting people join after the game has already started matters. Families are chaotic. Someone's always still getting a drink when the game kicks off. Late joiners now receive the current question immediately and can start answering. We removed the guard that blocked this.

What we're actually landing on: EZ-AZ isn't just a shelf. It's a place you go with your family. The TV is the campfire. The phones are the instruments. You walk into the lounge room, one scan, and everyone's playing. That's the product now. The ADR is in `docs/adr/001-tv-zone-phone-controller.md`.

**Coming next:** Theme picker (choose a category before the game starts). NAPLAN curriculum packs — Year 3, 5, 7, 9 — so the whole family can do school-grade trivia together. The infrastructure is already there. Every question has a category. It's just a filter in the lobby.

---

### v20260421.1 — 21 April 2026

**Cipher is on the shelf.**
Jaykill's second game. A monoalphabetic substitution cipher puzzle — Az locks up the store for the night, sets a cipher on the door, and you have to crack it to get back in. One word is your clue. You deduce the rest letter by letter, then hit SUBMIT. Wrong letters clear. Correct ones lock. No trial and error.

Three difficulty levels. A hint system that costs points (you can buy a reveal, but the score takes the hit). Scoring based on speed, errors, and hints used. Full leaderboard integration — top codebreakers are saved. Background music: slow A-minor arpeggio that pauses when you do. Particles burst from the tiles when you crack it.

The build happened in one session: 11 steps, each adding one layer. Sentences baked into the JS as arrays — easy to add more. Single HTML file, no dependencies, same as everything else on the shelf.

Two things worth noting. First: the leaderboard wasn't saving in early testing. The dev server had been restarted in production mode without the right environment, so it was pointing at an empty database. The code was fine. The server wasn't. Second: touch controls weren't reviewed until the final step — added `touch-action: none`, a minimum tile scale so tiles stay tappable on phones, and picker-on-first-tap for touch devices since there's no keyboard.

The philosophy behind this one: restraint is the mother of creativity. One cipher. One clue word. Fifteen letters. The constraint is the game.

---

### v20260417.3 — 17 April 2026

**Fixed: leaderboards and accounts were broken in production.**
Since we shipped player accounts two days ago, every kid who tried to create an account got "Something went wrong on our end." Every game that tried to load the leaderboard on its title screen got nothing. The database existed on the server but had no tables — Hatchbox (the hosting platform) doesn't run database migrations automatically, and nobody had told it to. The scores table, the players table, all of it sitting there empty. We didn't catch it because everything works fine locally.

The fix was an initializer that runs any pending migrations automatically when the server boots. Every deploy from now on, before the first request is served, the database gets checked and brought up to date. It adds maybe a second to startup time. That's fine. The alternative is shipping broken features and not knowing.

Honest lesson here: just because a feature passes tests doesn't mean it works in production. The test environment had a database. Production didn't. We've got an error tracker at `/errors` to catch this kind of thing going forward — and now the database will actually be there to record those errors.

**The `/whats-next` command now closes resolved issues automatically.**
When Jay runs `/whats-next` to pick what to work on, it now cross-references recent commits against open issues and closes anything that's already been shipped. Before this, old issues were cluttering the backlog with work that was already done. Small thing, but a tidy backlog means we spend less time figuring out what to do next and more time doing it.

---

### v20260417.2 — 17 April 2026

**VIBE.md — this file.**
Needed a place to record what we're actually building and why. Not a README. Not a changelog. Something alive that Az updates after every deploy. The idea: if someone discovers this project six months from now, VIBE.md should tell them everything a commit history can't — the philosophy, who the kids are, what decisions were made and why. The `/vibe` command runs automatically after each deploy and writes the new entry.

---

### v20260417.1 — 17 April 2026

**Learning Center launched at `/learn`.**
Eleven curated channel groups covering coding, game design, art, sound, maths, AI, cryptography, history, and cyber safety. All free resources, hand-picked for families. Linked from the store nav and the TV page. On Android TV, the remote's down arrow gets you there from the game shelf. This has been needed since day one — now when a kid asks "how do I make a game like that?" there's somewhere to point them.

**WASD tablet controls.**
On tablets and iPads, the touch controls now show a proper WASD layout instead of a joystick. W on top, A/S/D in a row. The reason: kids who play on a tablet should learn the same finger positions they'll use when they sit down at a real keyboard. The joystick is fine for phones. Tablets are close enough to a computer that we should teach the real thing.

**Space bar shoots in Space Dodge.**
Lachie's machine was popping the Windows Sticky Keys dialog mid-boss-fight because Shift was the only shoot key. Space bar now works too. Tiny fix, massive quality of life for Windows players. Sorry Lachie, that would've been infuriating.

**Smarter AI prompt.**
The prompt page now tells the AI to stop and ask questions if it detects unfilled placeholders, and to run a discovery phase before writing any code. ChatGPT was just building random games when kids pasted the prompt blank. The prompt is now opinionated: understand the idea first, build second.

**`bin/release` — deploy script.**
Tests, version bump, push, deployment validation. One command. Before this, version was bumped manually and there was no way to know if Hatchbox had actually deployed. Now we poll production until the new version appears. Takes about 2 minutes.

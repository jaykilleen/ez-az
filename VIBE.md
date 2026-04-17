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
- **Jaykill** (Jay) — built Descent. Maze runner, flashlight vision, four dinosaur heroes. He's the one helping everyone else but he made his own game anyway.
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

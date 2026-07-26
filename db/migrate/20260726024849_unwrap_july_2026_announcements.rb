# frozen_string_literal: true

# Rewrites the four 26 July announcement bodies as unwrapped paragraphs.
#
# The original migration wrote them from heredocs hard-wrapped at ~80 columns.
# simple_format turns every single newline inside a paragraph into a <br />, so
# each source line broke early and then wrapped again -- barely noticeable on a
# desktop, visibly ragged on a phone, which is what most kids read this on. It
# put 21 stray <br /> tags on the live page.
#
# A re-run of the original could not fix this: it skips rows that already
# exist, by design. Hence a second migration that updates in place.
#
# For future announcements: one paragraph per line, blank line between
# paragraphs. Let the browser do the wrapping.
#
# Two edits to the copy while rewriting, both from a read-through of the live
# page: name Hacker Pro rather than "some time-based games", which a kid could
# not act on, and stop the last entry opening by telling most readers it is not
# for them.
class UnwrapJuly2026Announcements < ActiveRecord::Migration[8.0]
  class Announcement < ActiveRecord::Base; end

  BODIES = {
    "Sorry — the store was shut when it shouldn't have been" => [
      "Rawr. I have to own this one.",
      "The countdown on the closed screen was broken. It would tick all the way down to zero and then jump straight back to 24 hours, so if you were waiting for me to open, it looked like I never would. That's fixed — when the clock hits zero the door actually opens now.",
      "Worse than that: my opening hours only knew about one set of school holidays. That means all through the winter break I was shut every weekday morning when I should have been wide open. If you came by on a holiday morning and found the lights off, that was my fault, not yours.",
      "I've now got the school holidays written down all the way to 2028, and I've set up an alarm that nags me well before they run out again."
    ],
    "Every legend gets their own spot on the leaderboard" => [
      "The high score boards were counting every single go you had. Sounds fair, but it meant one person having a really good session could fill up nearly the whole board on their own.",
      "On Space Dodge, one player held nine of the ten spots. Everyone else was pushed off, even though plenty of you had scores good enough to be there.",
      "Now every board shows your best run, once. Same top ten, but ten different players. Eight of you turned up on the Space Dodge board the moment I changed it — you were there the whole time, just buried.",
      "Your other runs aren't gone. If you've claimed a gamer name and signed in, you can still see every score you've set."
    ],
    "Cipher got its name back" => [
      "Rawr, a few small ones I'd let slide.",
      "Cipher was missing from the list of games you pick from when you report a bug. If something went wrong in there, you had no way to tell me. That's the one that actually mattered, and it's sorted.",
      "Its high score board was also calling itself \"az-cipher\" instead of Cipher. Not very welcoming.",
      "And Hacker Pro is scored on how fast you are, but the shelf was showing your times as points — so a good run looked like a tiny score. It shows proper times now."
    ],
    "Tidying up behind the shelf" => [
      "If you're building a game for the shelf, this one's for you.",
      "Every game used to carry its own copy of the bits around the edges — the EZ-AZ banner, the high score board, the pause screen. Thirteen copies of roughly the same thing, all slightly different.",
      "Now there's one shared set that every game can use, and a starter file to build from. You write the game. The controls, the scoreboard and the way back to the store come for free.",
      "Five games have moved across so far — Magnet Lab, Late Shift, Bloom, Dodgeball and Descent. The rest are on my list."
    ]
  }.freeze

  def up
    BODIES.each do |title, paragraphs|
      Announcement.where(title: title).update_all(body: paragraphs.join("\n\n"))
    end
  end

  # Irreversible in any useful sense -- the previous bodies were the same words
  # with worse line breaks, and nothing depends on getting them back.
  def down
    # no-op
  end
end

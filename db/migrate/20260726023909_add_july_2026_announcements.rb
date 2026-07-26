# frozen_string_literal: true

# What's New entries for the 26 July 2026 work.
#
# Announcements live in the database and there is no admin UI -- the model's
# own comment says to post them from a console. A data migration is the way to
# ship them with a deploy. Keyed on title with find_or_create_by! so re-running
# is harmless, and using a migration-local model so this keeps working if the
# Announcement class changes later.
#
# Only player-facing changes belong here. This page is for the kids and
# families who use the store, not a changelog -- the CI, caching and version
# plumbing from the same day is deliberately left off.
class AddJuly2026Announcements < ActiveRecord::Migration[8.0]
  class Announcement < ActiveRecord::Base; end

  ENTRIES = [
    {
      emoji: "🕗",
      title: "Sorry — the store was shut when it shouldn't have been",
      published_at: "2026-07-26 11:45:00",
      body: <<~BODY
        Rawr. I have to own this one.

        The countdown on the closed screen was broken. It would tick all the way
        down to zero and then jump straight back to 24 hours, so if you were
        waiting for me to open, it looked like I never would. That's fixed — when
        the clock hits zero the door actually opens now.

        Worse than that: my opening hours only knew about one set of school
        holidays. That means all through the winter break I was shut every
        weekday morning when I should have been wide open. If you came by on a
        holiday morning and found the lights off, that was my fault, not yours.

        I've now got the school holidays written down all the way to 2028, and
        I've set up an alarm that nags me well before they run out again.
      BODY
    },
    {
      emoji: "🏆",
      title: "Every legend gets their own spot on the leaderboard",
      published_at: "2026-07-26 11:40:00",
      body: <<~BODY
        The high score boards were counting every single go you had. Sounds fair,
        but it meant one person having a really good session could fill up nearly
        the whole board on their own.

        On Space Dodge, one player held nine of the ten spots. Everyone else was
        pushed off, even though plenty of you had scores good enough to be there.

        Now every board shows your best run, once. Same top ten, but ten
        different players. Eight of you turned up on the Space Dodge board the
        moment I changed it — you were there the whole time, just buried.

        Your other scores aren't gone. Sign in and you can still see all of them.
      BODY
    },
    {
      emoji: "🔐",
      title: "Cipher got its name back",
      published_at: "2026-07-26 11:35:00",
      body: <<~BODY
        Small one. When you opened the high scores for Cipher, the box at the top
        said "az-cipher" instead of "Cipher". Not very welcoming.

        While I was in there I found something worse: Cipher was missing from the
        list you pick from when you report a bug, so there was no way to tell me
        when something went wrong with it. Both sorted.

        Some of the time-based games were also showing your times as points,
        which made no sense at all. They show proper times now.
      BODY
    },
    {
      emoji: "🧰",
      title: "Tidying up behind the shelf",
      published_at: "2026-07-26 11:30:00",
      body: <<~BODY
        This one's mostly for the families building games.

        Every game used to carry its own copy of the bits around the edges — the
        EZ-AZ banner, the high score board, the pause screen. Thirteen copies of
        roughly the same thing, all slightly different.

        Now there's one shared set that every game can use, and a starter file to
        build from. If you're making a game for the shelf, you write the game.
        The controls, the scoreboard and the way back to the store come for free.

        Five games have moved across so far — Magnet Lab, Late Shift, Bloom,
        Dodgeball and Descent. The rest are on my list.
      BODY
    }
  ].freeze

  def up
    ENTRIES.each do |entry|
      record = Announcement.find_or_initialize_by(title: entry[:title])
      next if record.persisted?

      record.update!(
        emoji: entry[:emoji],
        body: entry[:body].strip,
        published_at: Time.zone.parse(entry[:published_at])
      )
    end
  end

  def down
    Announcement.where(title: ENTRIES.map { |e| e[:title] }).delete_all
  end
end

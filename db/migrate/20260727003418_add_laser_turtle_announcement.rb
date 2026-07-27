# What's New entry for Laser Turtle, a game submitted by Torrin.
#
# Announcements live in the database with no admin UI -- the model's own
# comment says to post them from a console. A data migration ships this one
# with the deploy instead. Keyed on title with find_or_initialize_by so a
# re-run is harmless, and using a migration-local model so this keeps working
# if the Announcement class changes later.
#
# Body is one paragraph per array entry, joined with a blank line between --
# not a hard-wrapped heredoc. simple_format turns every newline inside a
# paragraph into a <br />, so a hard-wrapped heredoc reads fine on desktop and
# ragged on a phone. See 20260726024849_unwrap_july_2026_announcements.rb.
class AddLaserTurtleAnnouncement < ActiveRecord::Migration[8.1]
  class Announcement < ActiveRecord::Base; end

  TITLE = "A new game on the shelf — Laser Turtle"
  EMOJI = "🐢"
  PUBLISHED_AT = "2026-07-27 10:35:00"
  BODY = [
    "Rawr! New game on the shelf, and I didn't build this one — Torrin did.",
    "Laser Turtle puts you on the back of Shelldon, riding through the reef with a laser gun and five hearts. Aim with your mouse, fire with click or space, and don't let the sharks get their teeth in. They come in waves, they get faster, and every fifth wave a megashark turns up looking for trouble.",
    "On a phone, just drag to swim — Shelldon fires on his own.",
    "It's got its own high score board on the shelf now, so go set the first one.",
    "The shelf has room for your game too. Just saying."
  ].join("\n\n").freeze

  def up
    record = Announcement.find_or_initialize_by(title: TITLE)
    return if record.persisted?

    record.update!(emoji: EMOJI, body: BODY, published_at: Time.zone.parse(PUBLISHED_AT))
  end

  def down
    Announcement.where(title: TITLE).delete_all
  end
end

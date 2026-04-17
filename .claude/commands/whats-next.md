Fetch all open GitHub issues for this project and recommend what to work on next.

Steps:
1. Run: `gh api "repos/jaykilleen/easy-az/issues?state=open&per_page=100&sort=created&direction=desc" --jq '.[] | {number: .number, title: .title, labels: [.labels[].name], created_at: .created_at, comments: .comments}'`
2. Also run: `git log --oneline -5` to see recent work so you don't suggest something just done.
3. Analyse the issues by priority:
   - **Critical/blocking** (`critical`, `bug` labels, or anything that breaks gameplay for players)
   - **High** (bugs affecting gameplay, `ux`, player-facing issues)
   - **Medium** (enhancements, `feature`, `mobile` improvements)
   - **Low** (learning paths, future features, nice-to-haves)
4. Recommend the top 3 things to work on, in order, with a one-sentence reason for each.
5. Ask which one to start on.

Keep the response short and punchy — this is a game store run by kids, not a corporate backlog review.

Fetch all open GitHub issues for this project and recommend what to work on next.

Steps:
1. Run: `git log --oneline -20` to see recent work.
2. Run: `gh api "repos/jaykilleen/easy-az/issues?state=open&per_page=100&sort=created&direction=desc" --jq '.[] | {number: .number, title: .title, labels: [.labels[].name], created_at: .created_at, comments: .comments}'`
3. Cross-reference the open issues against recent commits. If a commit message references an issue number (e.g. "fixes #44", "closes #12") or the commit subject clearly matches an open issue's title, close that issue: `gh issue close NUMBER --comment "Resolved in recent deploy."`. Close all matches before continuing.
4. Re-fetch the open issues list after closing: `gh api "repos/jaykilleen/easy-az/issues?state=open&per_page=100&sort=created&direction=desc" --jq '.[] | {number: .number, title: .title, labels: [.labels[].name], created_at: .created_at, comments: .comments}'`
5. Analyse the refreshed list by priority:
   - **Critical/blocking** (`critical`, `bug` labels, or anything that breaks gameplay for players)
   - **High** (bugs affecting gameplay, `ux`, player-facing issues)
   - **Medium** (enhancements, `feature`, `mobile` improvements)
   - **Low** (learning paths, future features, nice-to-haves)
6. Recommend the top 3 things to work on, in order, with a one-sentence reason for each. If any issues were closed in step 3, briefly mention them.
7. Ask which one to start on.

Keep the response short and punchy — this is a game store run by kids, not a corporate backlog review.

---
title: "Code Review That Actually Improves the Codebase"
description: "How to make code review actually improve the codebase — automate style, focus on design, ask questions, and keep PRs small."
date: 2026-05-22 10:00:00 +0600
categories: [Career, Leadership]
tags: [code-review, leadership, engineering-culture, quality]
garden_status: budding
---

Code review is the single most reliable lever a tech lead has on quality — and the most
commonly wasted. Done badly, it's a style-nitpicking gauntlet, a rubber stamp, or a
bottleneck that kills momentum. Done well, it raises the whole team's bar and spreads
knowledge as a side effect. After running review across several backend teams, here's
what separates the two.

## The problem

Two failure modes dominate. The first is the **nitpick review**: pages of comments about
quote styles and variable names while a real design flaw sails through. The second is the
**rubber stamp**: "LGTM" on a 2,000-line PR nobody actually read. Both feel like review.
Neither improves anything.

## How to approach it

Review for the things humans are uniquely good at catching, and let machines handle the
rest.

- **Automate style entirely.** Formatters and linters in CI end every style debate. If a
  human is commenting on formatting, your tooling has a gap. Reviews should never spend
  attention on what a tool can enforce.
- **Review for correctness, design, and maintainability.** Is the approach sound? Does it
  fit the existing architecture? Will the next person understand it? Are the edge cases
  and failure paths handled? That's where review earns its keep — it's often where a
  [technical decision](/posts/technical-decisions-you-wont-regret/) gets surfaced and
  questioned for the first time.
- **Ask questions, don't issue commands.** "What happens if this is called twice?" invites
  a conversation and teaches; "change this" shuts it down. Reviews are how a team learns,
  not just how code gets gated.
- **Explain the *why*.** A comment that includes the reasoning teaches a principle the
  author can reuse. A bare directive teaches nothing.
- **Keep PRs small.** A 200-line PR gets a real review; a 2,000-line one gets a rubber
  stamp. PR size is mostly a *review-quality* lever, and it's the author's responsibility.

## Pitfalls to watch for

- **Ego on either side.** Review critiques the code, not the person — and authors who
  defend reflexively miss the point. Set that tone explicitly.
- **Slow reviews.** A PR sitting for two days blocks flow and breeds giant batches. Make
  review a daily priority, not a someday task.
- **Approving without understanding.** If you can't explain what the PR does, you haven't
  reviewed it — you've waved it through.
- **Only ever criticizing.** Call out genuinely good solutions too; it reinforces the bar
  and makes the critical feedback land better.

## Takeaways

Great review is a culture decision: automate style, focus human attention on
correctness and design, ask rather than command, explain the why, and keep PRs small
enough to actually read. Treated this way, review stops being a gate and becomes the
mechanism by which the whole team levels up — which, as a lead, is exactly the outcome
you want.

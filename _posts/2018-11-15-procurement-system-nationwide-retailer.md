---
title: "Building a Procurement System for a Nationwide Retailer"
date: 2018-11-15 10:00:00 +0600
categories: [Backend, .NET]
tags: [csharp, dotnet, procurement, forecasting, retail, early-career]
---

This was one of the first real systems I built as a developer — a **C# procurement
application** for a nationwide retail chain. School projects have tidy inputs and no
consequences; this had real branches, real money, and real people depending on it
getting the order quantities right. That gap taught me more in a few months than a
year of tutorials.

## The problem

A retailer with branches across the country needs to procure goods continuously —
but how *much* to buy, and at what cost, depends on prices that move. Order too much
and capital is tied up in stock; too little and shelves go empty. The system had to
support procurement across **nationwide branches** with a **daily-updating price
forecast** feeding the buying decisions.

## How I approached it

I built it in **C# (.NET)**, backed by a relational database. The core pieces were:

- A **central procurement model** that consolidated demand and stock across all
  branches into one view.
- A **daily forecasting step** that updated price expectations so procurement
  decisions used fresh numbers rather than stale ones.
- Branch-level data feeding the centre, so a nationwide picture stayed consistent.

## What I learned

- **Data modelling is the foundation.** Get the schema right and features fall into
  place; get it wrong and every feature fights you. Most of my early bugs traced back
  to a model that didn't match the real business.
- **Batch jobs need to be reliable, not just correct.** A daily forecast that
  silently fails one night is worse than no forecast. I learned to care about
  re-runs, failures, and "did it actually run?" — lessons I'd formalize years later as
  idempotency and observability.
- **A forecast is only as good as its inputs.** Clean, trustworthy branch data
  mattered far more than any clever calculation on top.
- **Real users change everything.** Code that's "done" in a demo is not done when a
  branch is waiting on it to place tomorrow's order.

## Takeaways

My first production system wasn't glamorous — C#, a database, a nightly job — but it
drilled in the fundamentals I still lean on: model the domain honestly, make your
scheduled work dependable, and respect that real people are downstream of your code.
The technology stack has changed a lot since; those lessons haven't.

> *Specifics like the exact database and forecasting method are simplified here — the
> point is the lessons, not the 2018 implementation details.*

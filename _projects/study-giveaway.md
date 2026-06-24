---
title: Study Giveaway
description: Platform for managing student applications, scholarships, and interactions among admins, students, institutes, and agencies.
order: 2
tech: [Django, Python, Docker]
source:                # TODO: repo URL
demo:                  # TODO: live URL (omit if none)
mermaid: true
toc: true
# image:
---

{% if page.source or page.demo %}
> {% if page.source %}[Source]({{ page.source }}){% endif %}{% if page.source and page.demo %} · {% endif %}{% if page.demo %}[Live demo]({{ page.demo }}){% endif %}
{% endif %}

## At a glance

| | |
|---|---|
| **Role** | TODO |
| **Timeline** | TODO |
| **Team** | TODO |
| **Stack** | Django · Python · Docker |
| **Status** | TODO |

## Problem & context

TODO — what problem this solves and why it mattered.

## Architecture

TODO — short prose, then the system view.

```mermaid
flowchart LR
    Client --> API[API Service]
    API --> DB[(Database)]
    API --> Cache[(Cache)]
```

## Key flow

TODO — one important request/process.

```mermaid
sequenceDiagram
    Client->>API: Request
    API->>DB: Query
    DB-->>API: Result
    API-->>Client: Response
```

## Data model

TODO — core entities.

```mermaid
erDiagram
    USER ||--o{ ORDER : places
    ORDER ||--|{ ITEM : contains
```

## What I built

TODO — your ownership and key design decisions / trade-offs.

## Outcome

TODO — impact, metrics, or lessons learned.

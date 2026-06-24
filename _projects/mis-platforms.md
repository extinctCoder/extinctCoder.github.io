---
title: Government MIS Platforms
description: Planning, design, development, and DevOps for major MIS and government platforms (SPFMSP, EU RLFECT, RCMS AFIS).
order: 5
tech: [Django, Python, MySQL, Docker, Linux]
source:                # TODO: likely private
demo:                  # TODO: likely private
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
| **Stack** | Django · Python · MySQL · Docker · Linux |
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

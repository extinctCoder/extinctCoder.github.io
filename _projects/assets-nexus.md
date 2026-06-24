---
title: Assets Nexus
description: Internal operations SaaS — requisition & procurement, stock/asset management, and attendance, with org-hierarchy approvals and HRM/LDAP/OAuth.
order: 4
tech: [Django, Python, MySQL, Docker, LDAP, OAuth]
source:                # TODO: repo URL (likely private)
demo:                  # TODO: likely private
mermaid: true
toc: true
---

{% if page.source or page.demo %}
> {% if page.source %}[Source]({{ page.source }}){% endif %}{% if page.source and page.demo %} · {% endif %}{% if page.demo %}[Live demo]({{ page.demo }}){% endif %}
{% endif %}

## At a glance

| | |
|---|---|
| **Role** | R&D Engineer — sole developer |
| **Company** | ISTL (Integrated Software and Technologies Limited) |
| **Timeline** | During Jul 2020 – Feb 2023 |
| **Team** | Solo |
| **Users** | 250+ employees & field agents |
| **Modules** | Requisition · Procurement · Payments · Stock/Assets · Attendance |
| **Stack** | Django · Python · MySQL · Docker · LDAP / OAuth · Linux |
| **Status** | Deployed internally |

## Problem & context

ISTL needed to run its internal operations for **250+ employees and field agents** —
raising requests, routing them through layers of approval, ordering from vendors,
paying them, tracking stock, and recording attendance. Done manually, it was slow
and hard to audit. I built **Assets Nexus**, **solo**: a SaaS platform that
centralizes the entire requisition → approval → procurement → distribution
lifecycle, plus stock and attendance. Every device it ran on was secured by
[Data Citadel](/projects/data-citadel/).

## Modules

- **Requisition & approvals** — requests routed through the org command chain.
- **Procurement & vendor management** — purchase orders and vendor records.
- **Vendor payments** — payment tracking against purchase orders.
- **Stock & asset management** — inventory, distribution, and returns.
- **Attendance** — check-in/out for employees and field agents.
- **Access & audit** — role-based access via LDAP/OAuth identities, with an audit
  trail and reporting dashboards.

## Architecture

A **Django** application backed by **MySQL**, containerized with **Docker** on
**Linux**. Authentication uses **LDAP** for directory/login and **OAuth** for SSO,
while an **HRM** integration supplies the employee and **organizational
hierarchy** that drives the approval chain. Employees and field agents work
across the modules through one role-based interface.

```mermaid
flowchart TB
    Emp[Employees] --> App
    Agents[Field Agents] --> App
    LDAP[LDAP Directory] --> App
    OAuth[OAuth SSO] --> App
    HRM[HRM System] -->|org hierarchy| App
    subgraph App[Assets Nexus · Django]
        Req[Requisition & Approvals]
        Proc[Procurement & Payments]
        Stock[Stock & Assets]
        Att[Attendance]
        RBAC[RBAC & Audit]
    end
    App --> DB[(MySQL)]
    Proc --> Vendor[Vendors]
```

## Key flow

The requisition lifecycle — request through the command chain to distribution.

```mermaid
sequenceDiagram
    actor Employee
    participant App as Assets Nexus
    participant HRM as HRM (org hierarchy)
    participant Chain as Command Chain
    participant Vendor as Vendor
    participant Stock as Stock / Inventory

    Employee->>App: Raise requisition
    App->>HRM: Resolve approval chain
    loop Each level in the command chain
        App->>Chain: Request approval
        Chain-->>App: Approve / reject
    end
    App->>Vendor: Create purchase order
    Vendor-->>App: Fulfil order
    App->>App: Record vendor payment
    App->>Stock: Update inventory
    App-->>Employee: Asset distributed
```

## Data model

Employees, requisitions, approvals, vendors, stock, and attendance.

```mermaid
erDiagram
    DEPARTMENT ||--o{ EMPLOYEE : has
    ROLE ||--o{ EMPLOYEE : grants
    EMPLOYEE ||--o{ REQUISITION : raises
    REQUISITION ||--o{ APPROVAL : "routed through"
    EMPLOYEE ||--o{ APPROVAL : approves
    REQUISITION ||--o{ PURCHASE_ORDER : generates
    VENDOR ||--o{ PURCHASE_ORDER : fulfils
    PURCHASE_ORDER ||--o| PAYMENT : "paid via"
    PURCHASE_ORDER ||--o{ ASSET : delivers
    ASSET }o--|| STOCK : "tracked in"
    EMPLOYEE ||--o{ ATTENDANCE : logs
```

## What I built

- A **Django SaaS platform** unifying requisition, procurement, stock, and
  attendance for the whole organization.
- A **multi-level approval workflow** that routes each requisition dynamically
  through the **organizational command chain** sourced from HRM.
- **Identity & access** — LDAP directory/login, OAuth SSO, HRM employee data, and
  **role-based access control** with an **audit trail**.
- **Order management** and **vendor payment** tracking through purchase orders.
- **Stock/inventory management** with asset distribution and returns.
- An **attendance** module for employees and field agents.
- **Dockerized deployment** on Linux, with endpoints hardened by Data Citadel.

## Challenges & trade-offs

- **Dynamic approval chains** — different departments have different hierarchies,
  so the engine resolves the right chain of approvers per requisition from the
  live org structure rather than hard-coded levels.
- **Stock consistency** — keeping inventory accurate across concurrent
  procurement, distribution, and returns.
- **Field-agent attendance** — recording attendance reliably for agents working
  away from the office.

## Outcome

- Served **250+ employees and field agents** across the organization.
- **Boosted procurement efficiency ~20%** and **reduced asset costs ~15%**.
- Replaced a slow, manual, hard-to-audit process with a single auditable platform
  spanning requisition, approval, procurement, payment, stock, and attendance.

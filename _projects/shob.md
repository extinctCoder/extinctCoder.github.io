---
title: SHOB.COM.BD
description: B2B and B2C e-commerce platform connecting businesses and consumers.
order: 1
tech: [Django, React, Flutter, PostgreSQL, AWS, Kong]
image:
  path: /assets/img/projects/shob.png
  alt: SHOB.COM.BD storefront
source:                # TODO: repo URL
demo: https://shob.com.bd
mermaid: true
toc: true
---

## At a glance

| | |
|---|---|
| **Role** | Technical Project Lead — overall technical lead across backend, frontend, mobile & UX |
| **Company** | TecnoBZ (KM Group) |
| **Timeline** | Mar 2024 – present |
| **Team** | 2 backend · 2 frontend · 2 mobile · 2 UX, plus a project manager |
| **Stack** | Django · React · Flutter · PostgreSQL · AWS · Kong |
| **Peak load** | ~170K concurrent users during promotional offers |
| **Status** | Live at [shob.com.bd](https://shob.com.bd) |

## Problem & context

SHOB.COM.BD is a B2B **and** B2C e-commerce platform for Bangladesh — wholesale
(Alibaba-style) and retail (Amazon-style) in one marketplace. When I joined,
onboarding and basic functionality existed, but the system was a **monolith**,
order management and payment handling were **stubs**, and it was not ready to go
live at scale.

## Architecture

I re-architected the monolith into **microservices behind a Kong API gateway**.
Web (React) and mobile (Flutter) clients hit Kong, which routes to focused
**Django** services running on an **AWS auto-scaling cluster** that adds instances
when load crosses **90%**. Each service has its **own database on a single
PostgreSQL server**. Authentication is handled within Django, and order fulfilment
integrates with the company's external **delivery platform**. A Redis cache was
designed but left as planned work, and there is no message broker — services
communicate synchronously. The codebase follows Django's **MVT**
(Model–View–Template) structure.

```mermaid
flowchart TB
    Web[React Web] --> Kong
    Mobile[Flutter App] --> Kong
    Kong[Kong API Gateway]
    subgraph Cluster[Auto-scaling cluster · AWS — scales out at 90% load]
        Catalog[Catalog Service]
        Order[Order Service]
        Payment[Payment Service]
        Loyalty[Loyalty Service]
    end
    Kong --> Catalog
    Kong --> Order
    Kong --> Payment
    Kong --> Loyalty
    Order --> Delivery[Delivery Platform]
    subgraph PG[PostgreSQL Server · AWS]
        CatalogDB[(catalog_db)]
        OrderDB[(order_db)]
        PaymentDB[(payment_db)]
        LoyaltyDB[(loyalty_db)]
    end
    Catalog --> CatalogDB
    Order --> OrderDB
    Payment --> PaymentDB
    Loyalty --> LoyaltyDB
    Kong -. planned .-> Redis[(Redis Cache)]
```

## Key flow

Checkout — the path that ties order, payment, loyalty, and delivery together.

```mermaid
sequenceDiagram
    actor User
    participant Client as React / Flutter
    participant Kong as Kong Gateway
    participant Order as Order Service
    participant Payment as Payment Service
    participant Loyalty as Loyalty Service
    participant Delivery as Delivery Platform

    User->>Client: Place order
    Client->>Kong: POST /orders
    Kong->>Order: Route request
    Order->>Payment: Initiate payment
    Payment-->>Order: Payment confirmed
    Order->>Loyalty: Award points
    Order->>Delivery: Schedule delivery
    Delivery-->>Order: Tracking ID
    Order-->>Kong: Order confirmed
    Kong-->>Client: Confirmation + points earned
    Client-->>User: Success
```

## Data model

Core entities around orders, payments, and the loyalty program.

```mermaid
erDiagram
    USER ||--o{ ORDER : places
    USER ||--|| LOYALTY_ACCOUNT : has
    ORDER ||--|{ ORDER_ITEM : contains
    PRODUCT ||--o{ ORDER_ITEM : "appears in"
    ORDER ||--|| PAYMENT : "paid via"
    ORDER ||--o| DELIVERY : "fulfilled by"
    LOYALTY_ACCOUNT ||--o{ POINTS_TRANSACTION : records
    ORDER ||--o{ POINTS_TRANSACTION : earns
```

## What I built

- **Monolith → microservices** behind a Kong API gateway, with per-service databases.
- Built **order management** and **payment method handling** out from stubs to
  production features.
- Designed and shipped the **loyalty program**: points are earned as a percentage
  of order value and redeemed as a discount at checkout, with tiered benefits for
  repeat customers.
- **High-traffic handling & stabilization** — horizontal auto-scaling of the
  Django services (new instances at 90% load) behind Kong load balancing, database
  query optimization and connection pooling across the per-service databases, and
  rate limiting at the gateway.
- **Integrated the company's delivery platform** into the order lifecycle.

## Outcome

After these improvements the platform **went live and was a success**:

- Sustains **~170K concurrent users** during promotional offers, absorbed by the
  auto-scaling cluster.
- Microservices split cut **p95 API latency from ~1.2s to ~280ms** and reduced
  deployment time from **~30 min (whole monolith) to ~5 min per service**.
- **~99.9% uptime** since launch.
- A stable, scalable backend serving both B2B and B2C customers in Bangladesh.

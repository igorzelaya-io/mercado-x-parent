# MercadoX Parent

## Overview

`mercado-x-parent` is the root Maven parent project for the MercadoX ecosystem.

Its sole responsibility is to:

- Provide a centralized `pom.xml`
- Manage dependency versions
- Define shared plugins and configurations
- Declare the ecosystem modules
- Enforce consistent build standards

This project does **not** contain application code.

---

## Responsibilities

- Dependency Management (Spring Boot, Hibernate, QueryDSL, Kafka, etc.)
- Plugin Management (Maven Compiler, Surefire, Failsafe, etc.)
- Shared properties (Java version, encoding, etc.)
- Module aggregation

---

## Modules

The following modules compose the MercadoX ecosystem:

- mercado-x-library-entity
- mercado-x-library-jpa
- mercado-x-context
- mercado-x-oauth
- mercado-x-core
- mercado-x-email

---

## Purpose

To guarantee:

- Version consistency across services
- Standardized builds
- Maintainable multi-module architecture
- Clean separation of concerns

---

## Ecosystem Architecture

MercadoX is split into two kinds of modules: **libraries** (compiled JARs, no `main()`, shared via GitHub Packages) and **microservices** (deployable Spring Boot apps). Libraries carry no business logic of their own — they exist so the entities, tenant/context propagation, and Kafka/Redis plumbing aren't reimplemented per service.

### Build-time dependency graph

```mermaid
graph TD
    subgraph Libraries
        entity[mercado-x-library-entity<br/><i>entities, DTOs, ports</i>]
        redis[mercado-x-redis<br/><i>Redis config, idempotency store</i>]
        context[mercado-x-context<br/><i>tenant context, JWT, idempotency aspect</i>]
        jpa[mercado-x-library-jpa<br/><i>repositories, schema.sql</i>]
    end

    subgraph Microservices
        oauth[mercado-x-oauth<br/><i>identity provider</i>]
        core[mercado-x-core<br/><i>orders, inventory, carts</i>]
        email[mercado-x-email<br/><i>notifications</i>]
        ai[mercado-x-ai<br/><i>planned: AI messaging</i>]
    end

    redis --> entity
    context --> entity
    context --> redis
    jpa --> entity
    jpa --> context

    oauth --> jpa
    oauth --> context
    oauth --> redis

    core --> jpa
    core --> context
    core --> redis
    core --> oauth

    email --> jpa
    email --> context
    email --> oauth
```

`mercado-x-core` and `mercado-x-email` depend on `mercado-x-oauth` at compile time only for its JWT verification filter chain — neither calls it over the network at request time (see below).

### Runtime communication

```mermaid
graph LR
    client[Client]

    subgraph Services
        oauth[oauth :8081]
        core[core :8080]
        email[email]
    end

    subgraph Infra
        pg[(PostgreSQL<br/>mercado_x)]
        redis[(Redis)]
        kafka{{Kafka}}
    end

    client -->|login| oauth
    client -->|orders, cart, items| core

    oauth -.->|"public key<br/>(offline verify, no call)"| core
    oauth -.->|"public key<br/>(offline verify, no call)"| email

    oauth --> pg
    core --> pg
    email --> pg

    oauth --> redis
    core -->|idempotency keys| redis

    oauth -->|user.registration.validation| kafka
    core -->|order.operation.place / confirm / cancelled| kafka
    core -->|lead.created.v1| kafka
    kafka -->|consumed by email-service-group| email
    kafka -->|consumed by whatsapp-service-group| email

    email -->|SMTP| smtp[(Email Provider)]
    email -->|WhatsApp Business API| wa[(WhatsApp)]
```

Key points this diagram makes explicit:

- **oauth is the only service holding the JWT private key.** `core` and `email` verify tokens locally against the public key — no token-introspection round trip per request.
- **Kafka decouples core from email.** `core` never calls `email` directly; it publishes domain events (`ORDER_PLACING`, `ORDER_CONFIRMED`, `ORDER_CANCELLED`, `LEAD_CREATED`) and `email`'s two consumer groups (`email-service-group`, `whatsapp-service-group`) react independently. A slow/down email service doesn't block order placement.
- **Redis is shared but used differently per service** — `core` uses it for the `@IdempotentOperation` dedupe pattern; `oauth` uses it for its own session/token concerns.
- **`mercado-x-ai`** is scaffolded but not yet wired into this graph — it's the next planned consumer (see each service's README for module-specific detail).
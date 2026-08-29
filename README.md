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
- mercado-x-redis
- mercado-x-oauth
- mercado-x-core
- mercado-x-email
- mercado-x-ai

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
        email[mercado-x-email<br/><i>email, WhatsApp, webhooks</i>]
        ai[mercado-x-ai<br/><i>tenant-aware Claude conversations</i>]
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

    ai --> jpa
    ai --> context
```

`mercado-x-core` and `mercado-x-email` depend on `mercado-x-oauth` at compile time only for its JWT verification filter chain — neither calls it over the network at request time (see below).

### Runtime communication

```mermaid
graph LR
    client[Web / API Client]
    customer[WhatsApp Customer]

    subgraph Services
        oauth[oauth :8081]
        core[core :8080]
        email[email :8082]
        ai[ai :8083]
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
    email <-->|WhatsApp Cloud API| wa[(WhatsApp / Meta)]

    customer -->|message| wa
    email -->|whatsapp.inbound.v1| kafka
    kafka -->|consumed by ai-service-group| ai
    ai -->|Messages API| claude[(Anthropic Claude)]
    ai -->|ai.reply.generated.v1| kafka
    kafka -->|consumed by whatsapp-service-group| email

    ai --> pg
    ai -->|quotas and rate limits| redis
```

Key points this diagram makes explicit:

- **oauth is the only service holding the JWT private key.** `core` and `email` verify tokens locally against the public key — no token-introspection round trip per request.
- **Kafka decouples core from email.** `core` never calls `email` directly; it publishes domain events (`ORDER_PLACING`, `ORDER_CONFIRMED`, `ORDER_CANCELLED`, `LEAD_CREATED`) and `email`'s two consumer groups (`email-service-group`, `whatsapp-service-group`) react independently. A slow/down email service doesn't block order placement.
- **Redis is shared but used differently per service** — `core` uses it for the `@IdempotentOperation` dedupe pattern; `oauth` uses it for its own session/token concerns.
- **The AI assistant is an event-driven collaboration between two services.** `email` owns the Meta-facing transport boundary; `ai` owns conversation state, Claude orchestration, and usage policy. Neither service needs a synchronous call to the other.
- **Tenant identity survives every hop.** The inbound WhatsApp `phone_number_id` resolves an `OrganizationWhatsAppConfig`; `orgId` is then carried in the Avro event and Kafka header, restored by `@KafkaOrgIdPropagated`, and used for conversation, configuration, and quota isolation.

---

## Featured Workflow: Multi-Tenant WhatsApp AI Assistant

The AI workflow turns a company's WhatsApp Business number into a contextual customer assistant while preserving MercadoX's service boundaries:

```mermaid
sequenceDiagram
    autonumber
    participant Customer
    participant Meta as WhatsApp Cloud API
    participant Email as mercado-x-email
    participant Kafka
    participant AI as mercado-x-ai
    participant Claude as Anthropic Claude

    Customer->>Meta: Send text message
    Meta->>Email: Signed webhook
    Email->>Email: Verify signature, dedupe wamid, resolve tenant
    Email->>Kafka: WhatsAppMessageReceivedEvent
    Kafka->>AI: whatsapp.inbound.v1
    AI->>AI: Load tenant conversation and enforce plan quota
    AI->>Claude: Generate contextual response
    Claude-->>AI: Assistant text
    AI->>Kafka: AiReplyGeneratedEvent
    Kafka->>Email: ai.reply.generated.v1
    Email->>Meta: Deliver free-form reply or template
    Meta-->>Customer: AI-assisted response
```

Business-facing capabilities include:

- Per-organization WhatsApp identity, AI enablement, and conversation history
- Contextual multi-turn Claude responses persisted in PostgreSQL
- Redis-backed monthly quotas for `STARTER`, `GROWTH`, and `BUSINESS` plans
- Optional overage behavior and once-per-cycle administrator notifications
- A public, rate-limited demo chat that reuses the same conversation engine
- Two-layer deduplication for Meta webhook retries and Kafka redelivery
- An extensible tool boundary for future lead, catalog, order, and CRM actions

The tool executor and full multi-account routing for every outbound AI reply remain production-readiness work. The shipped workflow already covers signed webhook ingestion, tenant resolution, Kafka choreography, persisted Claude conversations, quota enforcement, and reply delivery.

For implementation details, see [`mercado-x-ai`](https://github.com/igorzelaya-io/mercado-x-ai) and [`mercado-x-email`](https://github.com/igorzelaya-io/mercado-x-email).

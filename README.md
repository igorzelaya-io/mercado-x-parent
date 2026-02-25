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
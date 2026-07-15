# Architecture Decision Record
## ADR-002 — Independent MariaDB and PostgreSQL Services

**Status:** Accepted; supersedes ADR-001  
**Date:** 2026-07-15

## Context

The Hostinger VPS already runs applications backed by MariaDB. The delivered AI Business Solutions operations backend uses Prisma with PostgreSQL-specific schema and migrations.

Converting every application to one database engine would create unnecessary risk. Running both database engines on the same Ubuntu VPS is technically valid when they are isolated.

## Decision

The VPS may run both MariaDB and PostgreSQL as independent services.

- Existing MariaDB applications remain on MariaDB.
- Applications designed and validated for PostgreSQL may use PostgreSQL.
- Each application has exactly one authoritative database engine.
- MariaDB and PostgreSQL will never be connected, replicated, synchronized, or dual-written.
- No application may use one engine as an automatic fallback for the other.

## Isolation requirements

- MariaDB: separate service, port 3306, users, databases, data directory, backups, and monitoring.
- PostgreSQL: separate service, port 5432, users, databases, data directory, backups, and monitoring.
- Neither database port is publicly exposed.
- Each application's connection string explicitly selects its assigned engine.
- Database credentials are unique per application.
- Caddy never proxies database ports.

## AI Business Solutions operations backend

The `aibiz-ops` backend may remain PostgreSQL if repository verification confirms that PostgreSQL is its intended and tested datastore.

Do not convert it to MariaDB merely for uniformity.

Before staging, verify PostgreSQL schema and migrations, Prisma generation, `prisma migrate deploy`, PostgreSQL-backed tests, backups and restore, resource consumption, and staging connectivity.

## Existing MariaDB applications

Do not stop, upgrade, reconfigure, migrate, or alter existing MariaDB databases as part of installing PostgreSQL.

Create and verify a MariaDB backup before the server change.

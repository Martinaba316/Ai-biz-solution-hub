# AI Business Solutions Master Project Bible

**Version:** 1.0  
**Date:** 2026-07-15  
**Owner:** Martin Abankwa  
**Company:** AI Business Solutions  
**Primary public domain:** `aibizsolutions.org`

## 1. Mission

AI Business Solutions helps organizations understand, adopt, build, and govern practical artificial intelligence systems that strengthen human performance.

## 2. Business model

Primary offer: AI consulting.

Additional offers:

- Custom AI tools
- Workflow automation
- Commercial applications
- Consumer applications
- Training
- Managed AI services
- Support and maintenance

## 3. Human + AI philosophy

AI handles scale, retrieval, repetition, drafting, summarization, analysis, and pattern recognition.

Humans retain judgment, empathy, authorization, accountability, context, relationships, creativity, and strategic control.

AI recommends and assists. Humans govern and approve consequential actions.

## 4. Platform architecture

One platform, many clients.

The operations platform owns canonical business records and business rules.

Clients include:

- Public website
- Operations dashboard
- Customer portal
- Bright AI Buddy
- Commercial SaaS applications
- Consumer applications
- Mobile applications
- AI agents
- Future products

## 5. Current repositories

- `aibiz-ops`: operational backend and dashboard
- `aibiz-public-site`: public web pages for `aibizsolutions.org`

## 6. Database policy

The VPS may run both MariaDB and PostgreSQL.

They remain completely independent.

- Existing MariaDB applications stay on MariaDB.
- PostgreSQL-only applications receive dedicated PostgreSQL databases and users.
- No dual writes, replication, cross-database links, or shared source of truth.
- Each application has one authoritative database engine.

## 7. Public website responsibilities

- Explain consulting and services
- Present applications
- Capture leads
- Capture booking requests
- Accept consent choices
- Send approved behavioral events
- Provide future Stripe entry points
- Provide future public AI assistance

## 8. Backend responsibilities

- Contacts
- Leads
- Bookings
- Applications
- Services
- Events
- Audit logs
- Permissions
- Future payments
- Future revenue
- Future support
- Future recommendations

## 9. API standard

Use versioned routes:

`/api/v1/public/*`

Public APIs must use explicit allowlists, validation, output shaping, rate limits, tenant/site resolution, safe errors, and audit/security events where appropriate.

## 10. Build history

- Slice A: public-site foundation
- Slice A.1: platform alignment
- Slice B: live public/backend integration
- Slice B.1 next: database/runtime alignment and staging readiness

## 11. Current verified state

Reported:

- 138 backend tests passing
- 80 public-site tests passing
- Real browser verification
- Versioned application, lead, booking, and event endpoints
- Staff application administration
- Consent-aware analytics
- Nothing deployed

The backend Slice B ZIP still requires independent verification when uploaded.

## 12. Security standard

- No secrets in source control
- Least-privilege users
- Separate database accounts
- Private database ports
- MFA for staff
- Secure sessions
- Rate limiting
- CORS restrictions
- Webhook verification
- Audit logs
- Backups and restore tests
- Public/internal AI isolation

## 13. Commerce standard

Stripe processes payments.

The platform owns:

- Customer records
- Orders
- Payments
- Subscriptions
- Entitlements
- Revenue classification
- Reconciliation
- Audit history

Verified webhooks determine payment state.

## 14. Release standard

Every slice must include:

- Input hashes
- Repository audit
- Exact changes
- Tests
- Build results
- Limitations
- Documentation
- ZIP checkpoints
- SHA-256 hashes
- Rollback notes
- No deployment unless authorized

## 15. Roadmap to Version 1.0

1. Verify complete Slice B backend package
2. Decide database engine per application
3. Prepare isolated PostgreSQL service for PostgreSQL applications
4. Preserve MariaDB services unchanged
5. Establish reproducible builds
6. Prepare Docker/Caddy staging
7. Validate backups and rollback
8. Deploy staging
9. Add Stripe
10. Add revenue reporting
11. Add public AI assistant
12. Add customer portal
13. Security and production hardening
14. Production launch

## 16. Authoritative rule

The public website is the intelligent front door.

The customer portal is the service-delivery layer.

The operations dashboard is the control center.

The shared APIs are the governed bridge.

Each application uses exactly one authoritative database engine.

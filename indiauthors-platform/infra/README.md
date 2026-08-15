# Infrastructure Baseline

This folder defines deployment and operational boundaries.

## Required Production Capabilities
- separate deployables for site and API
- relational database for platform domain entities
- object storage for release artifacts
- secret manager for credentials and signing keys
- centralized logging and monitoring
- backup and disaster recovery plan

## Non-Goals for W00
- no real provider credentials
- no fake payment or auth stubs marked as production

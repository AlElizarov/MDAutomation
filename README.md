# Online Consultation Platform

Backend platform for accepting, routing, and processing online consultation requests across multiple communication channels.

## Overview

The system is designed to:

- accept consultation requests from landing pages and forms
- route users into preferred communication channels
- connect requests with messenger identities
- support multi-channel onboarding flows
- provide a unified backend for consultation operations

Supported channels may include:

- Telegram
- VK
- MAX
- future messenger integrations

## Core Principles

- unified backend architecture
- channel-agnostic request handling
- scalable onboarding flows
- clean integration boundaries
- AI-assisted development workflow

## High-Level Architecture

```text
Landing Page / Form
        |
        v
Backend API
        |
        v
Request Processing
        |
        v
Messenger Routing
        |
        v
Channel Binding
        |
        v
Consultation Flow
```

## Request Flow

```text
User submits request
        |
        v
Request is stored in backend
        |
        v
Backend generates channel-specific links
        |
        v
User opens preferred messenger
        |
        v
Messenger identity is linked to request
        |
        v
Consultation flow starts
```

## Repository Structure

```text
/docs
  /tasks
  architecture.md
  api.md
  flows.md
  conventions.md

/src
/tests
```

## Development Workflow

### Jira

Jira is used for:

- roadmap
- epics
- backlog
- project management

### Repository Documentation

Technical implementation context is stored in:

```text
/docs/tasks
```

Task files should be committed to the repository together with the codebase.

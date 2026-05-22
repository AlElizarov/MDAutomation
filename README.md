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

### Backend

Install project dependencies locally:

```powershell
.\scripts\install_deps.ps1
```

Run the FastAPI application:

```powershell
.\scripts\run_server.ps1
```

Open the FastAPI application in a separate PowerShell window:

```powershell
.\scripts\run_server.ps1 -NewWindow
```

Run automated tests:

```powershell
.\scripts\test.ps1
```

Run the full local CI check:

```powershell
.\scripts\local-ci.ps1
```

Skip the Docker smoke test during local CI:

```powershell
.\scripts\local-ci.ps1 -SkipDocker
```

### Docker

Run the Docker smoke test:

```powershell
.\scripts\smoke-docker.ps1
```

Start Docker Desktop before running the Docker smoke test:

```powershell
.\scripts\smoke-docker.ps1 -StartDockerDesktop
```

Keep the backend container running after the smoke test:

```powershell
.\scripts\smoke-docker.ps1 -KeepRunning
```

Run the backend manually with Docker Compose:

```powershell
docker compose up --build
```

Check the containerized backend health endpoint:

```powershell
curl http://localhost:8000/health
```

Stop Docker Compose services:

```powershell
docker compose down --remove-orphans
```

### Documentation

Install documentation dependencies locally:

```powershell
.\scripts\install_deps.ps1
```

Build the MkDocs site:

```powershell
.\.venv\Scripts\python.exe -m mkdocs build --strict --site-dir site
```

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

# Naming Conventions

This document defines naming conventions and workflow rules for the MDAutomation project.

---

## Jira Issues

All Jira issues must use the project prefix:

```text
MDA-<number>
```

Where:

* `<number>` is a numeric identifier
* identifiers do not require leading zeroes

Examples:

```text
MDA-1
MDA-20
MDA-128
MDA-10001
```

---

## Branch Naming

Branch names must include the Jira issue key.

### Branch Creation

New branches must be created with:

```text
git checkout -b <branch-name>
```

Do not rename the current branch when creating a new work branch.

### Feature Branches

```text
feature/MDA-<number>-short-description
```

Examples:

```text
feature/MDA-1-project-bootstrap
feature/MDA-20-github-actions-ci
feature/MDA-10001-telegram-binding
```

### Fix Branches

```text
fix/MDA-<number>-short-description
```

Examples:

```text
fix/MDA-24-webhook-validation
fix/MDA-31-auth-timeout
```

---

## Commit Messages

All commit messages must start with the Jira issue key.
Prefer multi-line messages with detailed description of change.
Try to fit into 2-3 lines.

Format:

```text
MDA-<number> short description

comment
```

Examples:

```text
MDA-1 initialize project repository
MDA-20 add github actions ci
MDA-10001 implement telegram binding
```

Commit messages should:

* use lowercase descriptions
* be concise
* describe the actual change

---

## Pull Request Naming

Pull request titles must include the Jira issue key.

Format:

```text
MDA-<number> Short Description
```

Examples:

```text
MDA-1 Initialize project repository
MDA-20 Add GitHub Actions CI
MDA-10001 Implement Telegram binding
```

---

## Task Documentation

Technical implementation tasks should be stored in:

```text
/docs/tasks/
```

Examples:

```text
/docs/tasks/MDA-1-project-bootstrap.md
/docs/tasks/MDA-10001-telegram-binding.md
```

Task documents should contain:

* goal
* requirements
* acceptance criteria
* technical notes
* implementation details

Task files must be committed to the repository together with the codebase.

---

## Repository Documentation

Project documentation is stored in:

```text
/docs
```

Recommended structure:

```text
/docs
  architecture.md
  api.md
  flows.md
  conventions.md
  /tasks
```

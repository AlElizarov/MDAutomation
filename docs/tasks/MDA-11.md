# MDA-11 — Define AI-assisted increment development workflow

## Description

Create a repository document that formalizes how the MDA project is developed through value-bearing increments using ChatGPT and Codex.

The document must describe the agreed workflow for increment planning, architecture discussion, Jira task preparation, Codex implementation, PR review, increment verification, and persistent project memory.

This task is a process / documentation task. It does not require automated tests.

The main goal is to make the workflow reusable by future ChatGPT increment chats so that the project process does not depend on memory from previous conversations.

## Context

The project will use an increment-based AI-assisted development process.

Core principles:

* One increment = one working ChatGPT chat.
* One increment = one user-facing or business-facing outcome.
* One increment = one persistent increment document.
* The user describes the increment in free business language.
* ChatGPT structures the increment scope and task map.
* Architecture is discussed with ChatGPT before Codex implementation.
* Codex does not invent architecture from scratch.
* Codex applies accepted decisions to the repository.
* Implementation tasks must include automated proof.
* Architecture / process / documentation tasks may be accepted by documented decisions.
* Every increment must include an Increment Verification task.
* Long-term memory must live in repository docs, Jira, PRs, code and tests, not in ChatGPT chats.

## Scope

Create the document:

```text
docs/process/increment-chat-workflow.md
```

The document must cover the following sections.

### 1. Purpose

Explain that the workflow describes how to develop the project through short value-bearing increments with ChatGPT and Codex.

### 2. Core principles

Include the core rules:

* one increment = one working ChatGPT chat;
* one increment = one user/business-value outcome;
* one increment = one persistent increment document;
* delivery is planned only for the current increment;
* architecture is considered 2–3 increments ahead;
* technical/infrastructure work exists only inside a value-bearing increment;
* architecture tasks are inside increments but are not required for every increment;
* implementation/supporting tasks require automated proof;
* architecture/process/docs tasks may be accepted by documented decisions;
* Codex does not invent architecture from scratch;
* long-term memory lives in repo docs, Jira, PRs, code and tests.

### 3. Sources of truth

Describe source responsibilities:

* repository docs — project memory and decisions;
* Jira — delivery scope, task status, acceptance criteria;
* GitHub PRs — implementation history and review discussion;
* code/tests — actual system behavior;
* ChatGPT chat — temporary reasoning workspace for one increment.

### 4. Increment start

Describe that the user may start an increment in free business language, without filling a formal template.

ChatGPT must extract:

* goal;
* user/business value;
* expected result;
* scope;
* out of scope;
* user cases;
* assumptions;
* constraints.

Also state that ChatGPT helps split business flow into meaningful increments when the user is unsure how to do that.

### 5. Product understanding

Describe how ChatGPT validates the increment:

* what value it provides;
* who receives that value;
* whether it is user-facing or business-facing;
* whether it is only a technical slice disguised as an increment;
* what minimal completed result can be verified.

### 6. Architecture lookahead

Describe the rule:

Architecture lookahead is performed for the next 2–3 possible increments.

It is not:

* a roadmap;
* a backlog;
* a delivery plan;
* a commitment.

Its purpose is to avoid architectural dead ends and understand:

* which names/boundaries should not be too narrow;
* which extension points should remain open;
* what should not be implemented now;
* whether the current increment needs an architecture task.

### 7. Architecture baseline check

Describe that every increment must be checked against the architecture baseline.

The check should detect whether the increment affects:

* domain entities;
* lifecycle/status model;
* API contracts;
* database model;
* integration boundaries;
* system boundaries.

If architectural changes are needed, an architecture task is added inside the current increment.

If no architectural changes are needed, the increment proceeds without an architecture task.

### 8. Task map and Jira planning

Describe that ChatGPT first creates a task map, not final Jira tasks.

The task map is used to identify:

* task groups;
* dependencies;
* oversized tasks;
* missing supporting infrastructure;
* architecture/process/docs tasks;
* expected tests/checks.

After normalization, the task map is converted into Jira-ready tasks.

### 9. Task types

Describe allowed task types:

#### Architecture / process / documentation task

Used for decisions, rules and documents.

Examples:

* define architecture foundation;
* define testing strategy;
* define API/domain contract;
* define lifecycle contract.

These tasks may be accepted by documented decisions and do not require automated tests.

#### Outcome implementation task

Implements a part of user/business flow.

Must include automated proof.

#### Supporting infrastructure task

Implements technical/infrastructure support required by the current increment.

Must belong to a value-bearing increment.

Must include automated proof or automated check.

#### Increment Verification task

Mandatory for every increment.

Verifies the whole increment flow, not just a single task.

### 10. Rules for implementation tasks

State the rule:

```text
Implementation/supporting task = implementation + automated proof.
```

Each implementation task should include:

* scope;
* out of scope;
* acceptance criteria;
* tests/checks;
* docs impact;
* dependencies;
* notes for Codex.

### 11. Rules for architecture/process/docs tasks

State the rule:

```text
Architecture/process/docs task = decision + document.
```

These tasks may be accepted without automated tests, but must have a clear documented result.

They must include:

* what decision is being made;
* what documents are created/updated;
* what is explicitly out of scope;
* what future design must not be over-specified.

### 12. Codex handoff

Describe that Codex receives Jira tasks with accepted decisions and constraints.

Codex must:

* implement code changes;
* add/update tests;
* update docs;
* create PR;
* provide implementation report.

Codex must not:

* invent architecture from scratch;
* expand scope silently;
* introduce undocumented architectural decisions;
* ignore accepted architecture/process rules.

### 13. PR review

Describe that PR review is performed in the same increment chat.

The review checks:

* PR matches Jira scope;
* acceptance criteria are met;
* automated proof exists;
* docs are updated;
* architecture is not distorted;
* no accidental future scope was added.

### 14. Increment Verification

Describe that every increment must include a dedicated verification task.

Task-level tests verify parts.

Increment Verification verifies the full user/business flow.

The verification should be automated whenever possible.

### 15. Increment document

Describe that every increment creates a persistent document:

```text
docs/increments/000N-name.md
```

The document must include:

* goal;
* user/business value;
* implemented user cases;
* scope;
* out of scope;
* Jira tasks;
* architecture impact;
* updated docs;
* verification method/result;
* known limitations;
* follow-up tasks;
* next increment candidates;
* notes for next increment chat.

### 16. Increment completion criteria

An increment is complete when:

* the declared user/business value is implemented;
* all increment tasks are completed or explicitly moved out;
* Increment Verification passes;
* PR is accepted or ready for merge;
* repository docs are updated;
* increment document is created/updated;
* follow-up tasks are recorded.

### 17. What not to do

Explicitly document anti-patterns:

* do not create standalone technical increments without user/business value;
* do not maintain a separate roadmap document as a backlog;
* do not create Jira tasks for future increments during current increment planning;
* do not ask Codex to invent architecture from scratch;
* do not accept implementation tasks without proof/checks;
* do not store long-term project memory only in ChatGPT chats;
* do not turn architecture lookahead into Big Design Up Front.

### 18. Standard prompt for a new increment chat

Add a reusable prompt that can be used to start future increment chats.

It should say that the chat must read:

```text
docs/process/increment-chat-workflow.md
docs/architecture/baseline.md
relevant docs/architecture/*
recent relevant docs/increments/*
```

And then help with:

* structuring the increment;
* validating value;
* architecture lookahead;
* architecture baseline check;
* task map;
* Jira task preparation;
* Codex handoff;
* PR review;
* Increment Verification;
* increment document.

## Out of scope

* Do not design domain architecture for the consultation platform.
* Do not define database schema.
* Do not define API endpoints for the business flow.
* Do not implement backend code.
* Do not configure tests.
* Do not create the first increment document.
* Do not create Jira tasks for the whole first increment.
* Do not create a roadmap document.
* Do not rewrite unrelated existing documentation unless required to link the new process document.

## Acceptance Criteria

1. `docs/process/increment-chat-workflow.md` exists.

2. The document describes the full AI-assisted increment workflow:
   start increment → product understanding → architecture lookahead → architecture baseline check → task map → Jira tasks → Codex implementation → PR review → increment verification → increment document.

3. The document defines the main sources of truth:
   repository docs, Jira, PRs, code/tests, ChatGPT chats.

4. The document states that users may describe increments in free business language.

5. The document states that ChatGPT structures the increment scope.

6. The document states that every increment must provide user-facing or business-facing value.

7. The document states that technical and infrastructure work must belong to a value-bearing increment.

8. The document states that architecture tasks are inside increments but are not required for every increment.

9. The document states that architecture lookahead considers the next 2–3 possible increments but does not create delivery plans for them.

10. The document states that delivery is planned only for the current increment.

11. The document defines task types:
    architecture/process/docs task, outcome implementation task, supporting infrastructure task, increment verification task.

12. The document states that implementation/supporting tasks require automated proof or automated checks.

13. The document states that architecture/process/docs tasks may be accepted by documented decisions without automated tests.

14. The document states that Codex must not invent architecture from scratch.

15. The document describes Codex handoff rules.

16. The document describes PR review expectations.

17. The document states that every increment must have an Increment Verification task.

18. The document defines the structure and purpose of `docs/increments/000N-name.md`.

19. The document includes a reusable standard prompt for future increment chats.

20. MkDocs navigation is updated if MkDocs is present and the project documentation uses it.

## Docs impact

Create:

```text
docs/process/increment-chat-workflow.md
```

Update if applicable:

```text
mkdocs.yml
docs/index.md
```

Only update navigation/index files if they already exist and are used by the project.

## Notes for Codex

This is a process documentation task.

Do not implement backend code.

Do not configure tests.

Do not create architecture documents for domain/database/API in this task.

Do not create a roadmap document.

Do not create future increment Jira tasks.

Do not invent a different workflow.

Use the workflow rules described in this Jira task as the source of truth.

The resulting document must be concise enough to be useful as startup context for future ChatGPT increment chats, but detailed enough to preserve the agreed process.

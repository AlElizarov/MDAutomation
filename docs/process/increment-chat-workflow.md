# AI-Assisted Increment Development Workflow

This document defines how the MDAutomation project is developed through short,
value-bearing increments with ChatGPT and Codex.

The workflow is intended to be reusable by future increment chats. Long-term
project memory must live in repository documents, Jira, GitHub pull requests,
code, and tests rather than in previous ChatGPT conversations.

## Purpose

The project is developed through increments that produce a concrete user-facing
or business-facing outcome. ChatGPT is used as the increment planning and
reasoning workspace. Codex is used to apply accepted decisions to the repository.

The workflow covers increment planning, product understanding, architecture
discussion, Jira task preparation, Codex implementation, pull request review,
increment verification, and persistent project memory.

## Core Principles

* One increment equals one working ChatGPT chat.
* One increment equals one user-facing or business-facing outcome.
* One increment equals one persistent increment document.
* Delivery is planned only for the current increment.
* Architecture is considered 2-3 increments ahead.
* Technical and infrastructure work exists only inside a value-bearing increment.
* Architecture tasks are inside increments but are not required for every
  increment.
* Implementation and supporting tasks require automated proof.
* Architecture, process, and documentation tasks may be accepted by documented
  decisions.
* Codex does not invent architecture from scratch.
* Long-term memory lives in repository docs, Jira, PRs, code, and tests.

## Sources of Truth

* Repository docs store project memory, decisions, process rules, architecture
  baseline, increment documents, and operational guidance.
* Jira stores delivery scope, task status, acceptance criteria, and task-level
  implementation constraints.
* GitHub pull requests store implementation history, review discussion, and the
  final change set for each branch.
* Code and tests define the actual system behavior.
* ChatGPT chats are temporary reasoning workspaces for one increment.

## Increment Start

The user may start an increment in free business language. The user is not
required to fill a formal template.

ChatGPT must extract and clarify:

* goal;
* user or business value;
* expected result;
* scope;
* out of scope;
* user cases;
* assumptions;
* constraints.

When the user is unsure how to split a business flow, ChatGPT helps divide the
flow into meaningful value-bearing increments.

## Product Understanding

Before task planning, ChatGPT validates the increment by checking:

* what value it provides;
* who receives that value;
* whether it is user-facing or business-facing;
* whether it is only a technical slice disguised as an increment;
* what minimal completed result can be verified.

If the proposed work has no user-facing or business-facing value, it must be
attached to a value-bearing increment or moved out.

## Architecture Lookahead

Architecture lookahead is performed for the next 2-3 possible increments.

Architecture lookahead is not:

* a roadmap;
* a backlog;
* a delivery plan;
* a commitment.

Its purpose is to avoid architectural dead ends and understand:

* which names and boundaries should not be too narrow;
* which extension points should remain open;
* what should not be implemented now;
* whether the current increment needs an architecture task.

Delivery planning remains limited to the current increment.

## Architecture Baseline Check

Every increment must be checked against the architecture baseline.

The check should detect whether the increment affects:

* domain entities;
* lifecycle or status model;
* API contracts;
* database model;
* integration boundaries;
* system boundaries.

If architectural changes are needed, an architecture task is added inside the
current increment. If no architectural changes are needed, the increment proceeds
without an architecture task.

## Task Map and Jira Planning

ChatGPT first creates a task map, not final Jira tasks.

The task map is used to identify:

* task groups;
* dependencies;
* oversized tasks;
* missing supporting infrastructure;
* architecture, process, or documentation tasks;
* expected tests and checks.

After the task map is normalized, it is converted into Jira-ready tasks.

## Task Types

### Architecture, Process, or Documentation Task

Used for decisions, rules, and documents.

Examples:

* define architecture foundation;
* define testing strategy;
* define API or domain contract;
* define lifecycle contract.

These tasks may be accepted by documented decisions and do not require automated
tests.

### Outcome Implementation Task

Implements a part of the user or business flow.

Outcome implementation tasks must include automated proof.

### Supporting Infrastructure Task

Implements technical or infrastructure support required by the current increment.

Supporting infrastructure tasks must belong to a value-bearing increment. They
must include automated proof or an automated check.

### Increment Verification Task

Mandatory for every increment.

The Increment Verification task verifies the whole increment flow, not only a
single task.

## Rules for Implementation Tasks

```text
Implementation/supporting task = implementation + automated proof.
```

Each implementation or supporting task should include:

* scope;
* out of scope;
* acceptance criteria;
* tests or checks;
* docs impact;
* dependencies;
* notes for Codex.

## Rules for Architecture, Process, and Documentation Tasks

```text
Architecture/process/docs task = decision + document.
```

These tasks may be accepted without automated tests, but they must have a clear
documented result.

Each architecture, process, or documentation task must include:

* what decision is being made;
* what documents are created or updated;
* what is explicitly out of scope;
* what future design must not be over-specified.

## Codex Handoff

Codex receives Jira tasks with accepted decisions and constraints.

Codex must:

* implement code changes;
* add or update tests;
* update docs;
* create a pull request when requested and approved;
* provide an implementation report.

Codex must not:

* invent architecture from scratch;
* expand scope silently;
* introduce undocumented architectural decisions;
* ignore accepted architecture or process rules.

If Codex finds that a task requires an architectural decision that was not made,
it must stop and ask for the decision instead of silently choosing a new
architecture.

## PR Review

Pull request review is performed in the same increment chat.

The review checks that:

* the PR matches the Jira scope;
* acceptance criteria are met;
* automated proof exists for implementation and supporting tasks;
* docs are updated;
* architecture is not distorted;
* accidental future scope was not added.

Review findings should be resolved inside the increment before the increment is
completed.

## Increment Verification

Every increment must include a dedicated Increment Verification task.

Task-level tests verify parts of the change. Increment Verification verifies the
full user or business flow delivered by the increment.

Increment Verification should be automated whenever possible. If automation is
not practical for the current increment, the verification method and result must
be documented.

## Increment Document

Every increment creates a persistent document:

```text
docs/increments/000N-name.md
```

The increment document must include:

* goal;
* user or business value;
* implemented user cases;
* scope;
* out of scope;
* Jira tasks;
* architecture impact;
* updated docs;
* verification method and result;
* known limitations;
* follow-up tasks;
* next increment candidates;
* notes for the next increment chat.

The increment document is the main handoff artifact for future increment chats.

## Increment Completion Criteria

An increment is complete when:

* the declared user or business value is implemented;
* all increment tasks are completed or explicitly moved out;
* Increment Verification passes;
* the PR is accepted or ready for merge;
* repository docs are updated;
* the increment document is created or updated;
* follow-up tasks are recorded.

## What Not To Do

* Do not create standalone technical increments without user or business value.
* Do not maintain a separate roadmap document as a backlog.
* Do not create Jira tasks for future increments during current increment
  planning.
* Do not ask Codex to invent architecture from scratch.
* Do not accept implementation tasks without proof or checks.
* Do not store long-term project memory only in ChatGPT chats.
* Do not turn architecture lookahead into Big Design Up Front.

## Standard Prompt for a New Increment Chat

Use this prompt to start a future increment chat:

```text
We are starting a new MDAutomation increment.

Read the project context from:

- docs/process/increment-chat-workflow.md
- docs/architecture/baseline.md
- relevant docs/architecture/*
- recent relevant docs/increments/*

Then help me structure the increment from free business language.

For this increment:

- identify the goal, user/business value, expected result, scope, out of scope,
  user cases, assumptions, and constraints;
- validate whether the increment provides user-facing or business-facing value;
- perform architecture lookahead for the next 2-3 possible increments without
  turning it into a roadmap, backlog, delivery plan, or commitment;
- check the increment against the architecture baseline;
- decide whether the current increment needs an architecture/process/docs task;
- create a task map before final Jira tasks;
- normalize the task map into Jira-ready tasks;
- prepare Codex handoff notes with accepted decisions and constraints;
- keep PR review inside this increment chat;
- include an Increment Verification task;
- create or update docs/increments/000N-name.md with the increment result.

Do not plan delivery for future increments. Do not ask Codex to invent
architecture from scratch. Store long-term memory in repository docs, Jira, PRs,
code, and tests.
```

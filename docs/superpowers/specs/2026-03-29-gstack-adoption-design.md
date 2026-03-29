# Gstack Adoption Design

Date: 2026-03-29
Project: `sora-backend`
Status: Draft approved in conversation, pending final spec review

## Summary

Adopt `gstack` as a user-global toolchain for agent-assisted development while keeping the frontend and backend repositories fully separate in source control, deployment, and release cadence. Use Claude for high-value planning and decision checkpoints, and use Codex as the primary implementation agent.

## Goals

- Introduce `gstack` commands into the working process without changing deployment pipelines.
- Keep frontend and backend as independent repositories with independent release lifecycles.
- Support a solo workflow where Claude is used sparingly for important decisions and Codex handles most implementation work.
- Leave room for additional SKILL.md-compatible agents later without requiring repo restructuring now.

## Non-Goals

- Do not merge the frontend and backend repositories.
- Do not install `gstack` into each repository as a committed dependency.
- Do not make Gemini a first-class supported runtime in the initial rollout.
- Do not change CI/CD, release automation, or runtime infrastructure as part of this adoption.

## Context

The current backend repository is intentionally minimal and early-stage. The user expects a separate frontend repository with its own lifecycle and wants to avoid coupling the two codebases through shared deployment or build concerns. The user also wants to conserve Claude usage for critical planning and use Codex for the bulk of implementation work.

## Decision

Use a single user-global `gstack` source checkout and register it explicitly for Claude and Codex. Keep both application repositories clean of `gstack` installation artifacts. If repository-level guidance is needed, add only lightweight workflow documentation such as an `AGENTS.md` note or short README section.

## Installation Model

### Source of truth

- Keep one shared `gstack` checkout at `~/gstack`.
- Treat `~/gstack` as the only install and upgrade location.

### Agent registration

- Register Claude explicitly from `~/gstack` using the default setup flow.
- Register Codex explicitly from `~/gstack` using `./setup --host codex`.
- Do not rely on `--host auto` for the primary setup because the intended production usage is specifically Claude plus Codex, and explicit setup is easier to reason about.

### Repository boundaries

- Do not add `.agents/skills/gstack` or equivalent repo-local installs to either repository.
- Do not commit `gstack` files, generated skills, or runtime assets into the frontend or backend repositories.
- Keep deployment pipelines unchanged.

## Why This Model

### Recommended approach: user-global install plus repo-local workflow guidance

This approach keeps tooling centralized while preserving the independence of each repository. It avoids duplicate installs, avoids repo churn, and keeps CI/CD untouched. It also matches the desired operating model: one person, multiple repos, separate release lifecycles, and selective use of expensive planning capacity.

### Alternatives considered

#### User-global only, with no repo documentation

This is operationally simple, but it relies too much on memory. Over time it becomes harder to remember which commands should be used at which stage of work in each repository.

#### Repo-local install in each repository

This gives each repo a self-contained skill setup, but it adds maintenance duplication and increases the risk of drift between repos. It also conflicts with the goal of avoiding extra operational complexity.

## Role Split Between Claude and Codex

### Claude

Use Claude for work where strategic judgment matters more than raw implementation throughput.

Recommended usage:

- `/office-hours` for early reframing of a feature or product slice
- `/plan-ceo-review` for scope, wedge selection, and product-direction checks
- `/plan-eng-review` for architecture, edge cases, and test thinking before execution
- Important re-checkpoints before large refactors, contract changes, or release-sensitive decisions

### Codex

Use Codex as the default implementation engine once direction is approved.

Recommended usage:

- Main feature implementation
- Iterative code changes and debugging
- Test writing and test repair
- Running review-oriented commands during normal development
- Fast follow-up edits after planning decisions are already made

### Operating principle

The default loop is:

1. Claude clarifies or approves the direction.
2. Codex implements the approved change.
3. Codex runs review or QA-oriented follow-through when appropriate.
4. Claude is brought back only at meaningful decision boundaries.

## Repository Workflow Design

### Backend repository

Use Claude for API boundary changes, domain-model changes, integration flow decisions, and deployment-impacting choices. Use Codex for service implementation, handlers, tests, fixes, and normal day-to-day development after the plan is set.

### Frontend repository

Use Claude for UX framing, feature scope, major flow decisions, and larger structural choices. Use Codex for UI implementation, iteration, bug fixing, styling, and follow-up changes after the direction is approved.

### Shared workflow pattern

For both repositories, the baseline workflow is:

1. Start in Claude when the change is ambiguous, high-impact, or cross-cutting.
2. Move to Codex for implementation once the direction is clear.
3. Use `gstack` review and QA commands as part of completion rather than as optional extras.
4. Return to Claude only when a new decision boundary is reached.

## Initial Command Set

Do not adopt the full `gstack` surface area immediately. Start with a narrow set that matches the intended Claude/Codex split.

### Claude-first commands

- `/office-hours`
- `/plan-ceo-review`
- `/plan-eng-review`

### Codex-heavy commands

- `/review`
- `/qa` when a deployable or browser-verifiable surface exists

This keeps the first phase simple: thought and planning in Claude, implementation in Codex, and review/verification as a normal close-out step.

## Documentation Policy

If repository guidance is added later, keep it lightweight:

- One short `AGENTS.md` or README section per repo is enough.
- The document should describe when to use Claude, when to use Codex, and which `gstack` commands are part of the default workflow.
- The document should not introduce shared build logic, setup scripts, or repo-local `gstack` installation steps.

## Upgrade and Maintenance Policy

- Upgrade only from `~/gstack`.
- Do not maintain separate copies of `gstack` inside project repositories.
- Re-run agent registration from the shared install if skills become stale or invalid.
- Treat Gemini as out of scope for the initial setup. If it becomes important later, validate it separately instead of broadening the initial rollout now.

## Risks and Mitigations

### Risk: command usage drifts over time

Mitigation: add a short repo-level workflow note if repeated confusion appears.

### Risk: Codex and Claude workflows diverge

Mitigation: keep the command set intentionally small at first and reserve Claude for specific checkpoints rather than mixed ad hoc usage.

### Risk: future multi-agent expansion adds ambiguity

Mitigation: keep `~/gstack` as the single source of truth and add new agent registrations one host at a time, only after validating the need.

## Success Criteria

- `gstack` is installed once globally and usable from both the backend and frontend workflows.
- Frontend and backend remain operationally separate.
- Claude usage is focused on high-value planning and decision points.
- Codex becomes the default implementation path.
- No deployment pipeline changes are required for adoption.

## Next Step

After this design is approved, create a concrete implementation plan for:

1. global `gstack` installation and registration
2. optional repo-level workflow note for `sora-backend`
3. mirrored lightweight workflow note pattern for the frontend repository

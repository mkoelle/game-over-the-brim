# ADR-022: Development Workflow — Lean Trunk, Feel Gates, Model Tiering

**Status:** Accepted

**Date:** 2026-11-24

**Supersedes:** [ADR-008](ADR-008-llm-delegation-model-selection.md) (OpenRouter
delegation), and the AGENTS.md rule that `.squad/tasks.json` is the source of
truth for task tracking.

---

### Context

The owner asked for the process to be evaluated from scratch, treating
earlier choices as wrong unless evidence supports them. Findings
(2026-11-24):

**Repository and process facts**
- The `main` ruleset already requires a PR, the `QC` status check, an
  up-to-date branch, squash-only merges and linear history.
- Repo-level auto-merge is enabled.
- Together these make a PR a CI gate that costs almost nothing, not a
  review queue.
- `.squad/tasks.json` no longer exists; only `tasks.json.prev`
  (2026-09-15) remains. The squad tracker was abandoned once already.
- `docs/tasks/T-*.md` already holds each ticket's full implementation plan.
  A second tracker would duplicate its state and drift.
- For a game, the scarce resource is the **owner's hand feel-testing**.
  The Iteration 01 feel-test found steering, drift, camera and
  ramps/air/landing all wrong, even though CI was green.

**External evidence**
- Practitioner sources favor short-lived changes that integrate often, with
  strong automated tests, for solo work. PRs serve mainly as a self-review
  checkpoint. Agent-made PRs strain review bandwidth when humans review
  each one.
  ([trunkbaseddevelopment.com](https://trunkbaseddevelopment.com/committing-straight-to-the-trunk/),
  [InfoQ: Rootly small PRs](https://infoq.com/news/2026/08/rootly-small-pr-agentic-ai/),
  [smartscope: PRs in the agent era](https://smartscope.blog/en/blog/pull-request-ai-agent-change-management/))
- There is no controlled study showing multi-agent review beats a single
  reviewer on recall per dollar. One report found a second AI reviewer
  more than doubled cost.
  ([arXiv 2610.21914](https://arxiv.org/pdf/2610.21914),
  [LeadDev](https://leaddev.com/?p=34828))
- **Model pricing** (Anthropic first-party, cached 2026-11-03), per million
  tokens input/output:
  - Opus 5.5: $4 / $20
  - Sonnet 5.5: $2 / $10
  - Haiku 5.5: $0.10 / $0.50

  ADR-008's default OpenRouter model `kimi-k2.5` costs $0.45 / $2.25, more
  than Haiku 5.5. Through the MCP it also returns text only: it cannot run
  Godot, tests or `task ci`, so Claude has to re-check and apply everything
  it produces.
- **Poteto Mode** (`painhardcore/pstack`, MIT, v1.2.1, 24 stars,
  2026-11-13) is a young skill framework. Its principles are sound:
  - try a reversible probe before asking a question
  - give each code-writing subagent its own isolated worktree
  - never accept a subagent's self-reported success without checking
  - require explicit authority for external actions

  Installing it would add a third process layer next to the squad and
  caveman plugins. The principles are adopted below. The plugin is not.

---

### Decision

**1. Lean trunk.** Each ticket gets one short-lived branch
(`feature/…`, `chore/…`, `spike/…`, `docs/…`) and one PR. Enable
auto-merge (squash) right away, so the PR lands once `QC` passes. Vendor
tickets stay separate from integration tickets, so a vendored diff never
hides code changes. If a PR touches `project.godot`, merge it before the
next one branches. Strict up-to-date checks make parallel `project.godot`
edits churn.

**2. One tracker.** Each `docs/tasks/T-*.md` carries a `**Status:**` line:
`Todo`, `In progress`, `Done` or `Blocked (reason)`. The PR that implements a
ticket also flips its status, so the status change ships with the code.
The adoption plan's tables give the order. STATE.md stays at milestone
level.

**3. Feel gates, not review gates.** The owner is pulled in only at named
**feel checkpoints** (FC) defined in the plan, and for decisions only the
owner can make (product intent, money, external accounts, licenses).
Code review is automated: tests, `task ci`, and Opus reviewing the diff.

**4. Evidence in every PR.** The PR body states what was verified and how:
- the `task ci` result
- the new or changed tests
- for scene or camera work, a screenshot or log from the running project

"It compiles" is not evidence. Never accept a subagent's own report
without checking the diff and re-running verification.

**5. Model tiering inside Claude Code** (no OpenRouter):
- **Builder:** a Claude Sonnet 5.5 subagent per ticket in an isolated git
  worktree. Its prompt is the ticket file. In the worktree it first runs
  `mise trust && mise install && task import`, because a new worktree path
  is untrusted and has no `.godot/` cache.
- **Checker:** Opus (the main session) reviews the diff, re-runs `task ci`,
  then opens the PR.
- **Lookups:** read-only searches and inventories go to Haiku 5.5
  subagents.
- **Exceptions** stay with Opus directly:
  - work governed by an ADR-012 "self-implemented" item
  - gameplay-feel tuning
  - anything that failed twice with the builder
- **Fresh session per ticket batch.** Context size is the biggest cost
  lever: a long session re-sends its whole history on every turn.
  Carry state between sessions through the ticket files.

**6. Godot editor MCP (`godot-ai`).** Spike it on
[T-005](../tasks/T-005-replace-chase-camera-with-phantom-camera.md), using
it for scene edits through the editor API and for screenshot verification.
Adopt it for scene work if it proves reliable. Otherwise fall back to
hand-editing `.tscn` plus run/log checks. Record the result in this ADR.

**6a. Spike result (T-005, 2026-11-25): adopt for scene work, with
fallbacks.**

*Setup.* The session's own MCP tools pointed at the owner's 3.2.4
server, which is the wrong version. So the spike drove godot-ai 4.4.2
through a scripted stdio client (from T-019). It ran one session per call
sequence, against an editor started on the ticket worktree with an
isolated HOME and ports 8010/9510.

*Counts.* There were 58 tool calls: 49 succeeded and 9 failed.
- **Scene edits, once the scene was open:** 31 of 33 calls succeeded,
  counting the hierarchy and property reads in between. The edits were
  `scene_open`, `node_manage` delete and move, `node_create`,
  `script_attach`, 11 `node_set_property` calls, `resource_manage create`
  (a `SphereShape3D` sub-resource) and 2 `scene_save` calls. Every
  `main.tscn` change in T-005 went through the MCP; none were hand-edited.
  The saved file is a real editor save, with `unique_id`s, uids and the
  `@tool` host's own properties.
- **`node_create` with a script class failed 2 of 2:**
  `VALUE_OUT_OF_RANGE: Unknown node type: PhantomCameraHost` (and
  `PhantomCamera3D`). Workaround, which worked: create the base type
  (`Node`, `Node3D`), then `script_attach` the addon script. This is how
  the `.tscn` stores such nodes anyway.
- **The first edit attempt failed 4 calls with `EDITOR_NOT_READY: No scene
  open`.** Cause: `main.tscn` still referenced a script I had already
  renamed. `scene_open` returned success with `switched: false, settle:
  "timeout"`, and the editor log showed the load error. The editor had to
  be restarted. After the restart, the same calls succeeded.
- **`logs_read source="game"` failed 3 of 3** with `Command get_logs timed
  out after 5.0s`. `source="editor"` and `source="all"` worked. Game
  stdout was read from a CLI run instead.
- **`project_run` and `editor_screenshot source="game"` worked**, with
  one trap. `project_run` can return before the game is live (`status:
  "not_live"` at 3 s). A screenshot taken then showed frame 2, with the
  camera still at its start position. Poll `editor_state` until
  `game_status.status` is `"live"`, then capture. The second run was live
  in 0.8 s, and its screenshot showed the real framing.
- **Stale script defaults.** The editor did not rescan a script edited
  on disk while it ran. `node_get_properties` showed the old export
  defaults. `scene_save` did not bake them in, but this is a hazard.

*Recommendation.* Adopt godot-ai for scene edits and for run-plus-screenshot
checks. Its edits are real editor saves, and every edit call is undoable
and reports clear errors. Keep these rules:
- Finish script renames and edits before opening the editor.
- Create script-class nodes as the base type plus `script_attach`.
- Poll for `"live"` before taking a game screenshot.
- Read game output from a CLI run, not `logs_read source="game"`.
- Fall back to hand-editing `.tscn` only if the editor cannot load the
  scene.

**7. Ask less, probe more.** Before asking the owner, try a reversible
probe: run it, read it, test it. Ask only for what tools cannot establish.

---

### Consequences

**Positive:**
- Owner time goes to feel-testing, which is the actual gate for this game.
- One tracker, with no drift between a JSON file and the ticket docs.
- Builder tokens cost about half of Opus. The checker diff review is small.
- No external LLM service, API key or spend cap to manage.

**Negative / Tradeoffs:**
- Savings for Phase 1 are a few dollars at most, so the main win is a
  smaller context and parallel lookups, not price.
- Sonnet may miss Godot-specific details. The mitigation is tests plus the
  checker review, and a ticket that fails twice escalates to Opus.
- Worktree setup costs one `mise install` and one `task import` per
  ticket.
- Lookups at the low end lose the old "cheapest bulk model" option
  (`deepseek-v4-flash`, $0.06 / $0.12). This is accepted because Haiku 5.5
  runs inside the harness with tools.

---

### Alternatives Considered

1. **PR per ticket + `.squad/tasks.json` (old AGENTS.md rule):** Rejected.
   The tracker was already abandoned once and duplicates the ticket state.
2. **Trial Poteto Mode plugin:** Rejected as a plugin, adopted as
   principles (Decision 4, 5 and 7). Revisit if it matures.
3. **Push directly to `main`:** Rejected. It weakens the ruleset, main can
   go red, and releases are tagged from main.
4. **Squad multi-agent flow per ticket:** Rejected. Cost is more than 2x
   with weak evidence of better recall, and it adds approval prompts.
5. **Opus for everything:** Viable. Rejected as the default on cost and
   context, and kept as the escalation path.
6. **Keep OpenRouter delegation (ADR-008):** Rejected. It costs more than
   Haiku 5.5, has no tool access, and everything it produces must be
   re-checked.

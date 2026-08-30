# Rubric review — Architecture Spine

**Verdict: needs revision before finalization.** The spine has a coherent, enforceable core around snapshot isolation, event replay, and offline single-user operation, but it leaves V1 performance, recovery/session selection, and the executable local-operational contract insufficiently bound for initiative altitude.

## High findings

1. **PERF-001–005 are named but not made enforceable.** AD-9 says the recommendation is “fast” and limits the algorithmic scope, while AD-10 emits metrics, but neither fixes the PRD’s p95 budgets (100 ms pick/search, 300 ms recommendation, 500 ms UI, 3 s startup) nor a benchmark/acceptance gate. Builders could choose incompatible caching, query, and rendering strategies yet claim compliance. **Autofix:** bind the V1 budgets, benchmark fixture, and a precompute/cache/read-path rule in an AD or explicitly defer the measurement contract (which would conflict with V1).

2. **Recovery and session selection are only mapped, not governed.** DRAFT-009/REL-001 require a user to see sessions newest-first, have the latest preselected, then confirm or choose before restoration. AD-4 and AD-8 ensure durable/replayable data but do not establish the query/selection boundary or prohibit automatic restoration of an unintended session. **Autofix:** add a recovery invariant assigning ordered session discovery and explicit selection/confirmation to an application query/use case, with the selected `draft_id` as the only restoration input.

3. **The operational envelope does not yet specify how the local app is safely runnable.** AD-10 binds loopback, storage, logging, and startup checks, but does not decide or defer a supported runtime/launch contract (launch entry point, supported OS/R installation contract, browser handoff/port collision behavior, and local-file permissions). This leaves independently built delivery and run paths able to diverge, despite V1’s requirement that users complete the flow without editing code. **Autofix:** add a minimal local-launch and filesystem-permission invariant; if packaged distribution is intentionally out of V1, defer only installer/update mechanics, not runtime startup behavior.

4. **`ffanalytics` is not pinned to an exact verified dependency.** The Stack records “3.x; immutable Git commit locked in `renv.lock`,” which is neither an exact version nor present in the supplied tree; it cannot be checked from the spine and conflicts with the claimed reproducibility boundary. **Autofix:** name the exact package version plus remote commit (or make the pre-draft provider a port and defer the concrete implementation until the lockfile is created); retain `renv.lock` as the enforcement artifact.

## Checklist notes

- The draft is greenfield, so brownfield-ratification and inherited-spine checks are not applicable.
- No item in `Deferred` appears to silently permit a V1 divergence; the V2/V3 boundaries are generally clear.
- Package currency was checked for Shiny 1.14.0, which is current in Posit’s reference as of this review. The spine itself should preserve verification evidence for all pinned technologies when finalizing.

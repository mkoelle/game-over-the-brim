# DECISIONS

- **ADR-001**: Godot 4.x
- **ADR-002**: GDScript only
- **ADR-003**: Signal architecture
- **[ADR-004](file:///docs/adr/ADR-004-network-peer-and-car-decoupling.md)**: Decouple Network Peer from Vehicle Entities
- **[ADR-005](file:///docs/adr/ADR-005-presenter-and-active-spectator-architecture.md)**: Presenter Mode and Active Spectator Architecture
- **[ADR-006](file:///docs/adr/ADR-006-role-based-event-direction-and-multi-window.md)**: Role-Based Event Direction and Multi-Window Host Architecture
- **[ADR-007](file:///docs/adr/ADR-007-build-test-and-release-pipeline.md)**: Build, Test, and Release Pipeline (GdUnit4, GitHub Actions CI/release, Desktop+Android)
- **[ADR-008](file:///docs/adr/ADR-008-llm-delegation-model-selection.md)**: LLM Delegation Model Selection (OpenRouter), **superseded by ADR-022**
- **[ADR-009](file:///docs/adr/ADR-009-netcode-addon-netfox.md)**: Netcode Addon Selection (netfox)
- **[ADR-010](file:///docs/adr/ADR-010-input-glyph-addon-controller-icons.md)**: Input Prompt Glyph Addon Selection (Controller Icons)
- **[ADR-011](file:///docs/adr/ADR-011-ai-state-machine-addon-limboai.md)**: AI / State Machine Addon Selection (LimboAI)
- **[ADR-012](file:///docs/adr/ADR-012-self-implementation-boundary.md)**: Self-Implementation Boundary (systems that must never be delegated to an addon)
- **[ADR-013](ADR-013-camera-addon-phantom-camera.md)**: Camera Rig Addon (Phantom Camera)
- **[ADR-014](ADR-014-per-device-input-action-map.md)**: Per-Device Input Action Map (self-implemented; MultiplayerInput rejected on Godot 4.7)
- **[ADR-015](ADR-015-native-gdextension-addon-policy.md)**: Native (GDExtension) Addon Policy
- **[ADR-016](ADR-016-debug-visualization-addon-debug-draw-3d.md)**: Debug Visualization Addon (Debug Draw 3D, dev-only)
- **[ADR-017](ADR-017-track-tooling-road-generator-and-scatter.md)**: Track Tooling (Road Generator + ProtonScatter)
- **[ADR-018](ADR-018-menu-framework-maaack-menus-template.md)**: Menu Framework (Maaack's Menus Template)
- **[ADR-019](ADR-019-third-party-asset-sourcing-and-licensing.md)**: Third-Party Asset Sourcing and License Tracking
- **[ADR-020](ADR-020-steam-remote-play-together-online-path.md)**: Steam Remote Play Together as First Online Path (**Proposed**)
- **[ADR-021](ADR-021-3d-physics-engine.md)**: 3D Physics Engine Pin (Jolt Physics; `DEFAULT` resolved to Godot Physics on 4.7.2)
- **[ADR-022](ADR-022-dev-workflow-lean-trunk-and-model-tiering.md)**: Development Workflow: Lean Trunk, Feel Gates, Model Tiering (supersedes ADR-008)
- **[ADR-023](ADR-023-native-binary-toolchain.md)**: Native-Binary Dev Toolchain (gdscript-formatter + prek replace gdtoolkit + pre-commit; no Python)

Adoption order and tickets: [docs/plans/addon-adoption-plan.md](../plans/addon-adoption-plan.md)

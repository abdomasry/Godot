# Execution backlog and model handoff

All tasks below are TODO on 2026-09-17. They describe proposed work, not existing features. Execute in dependency order. Read MASTER_PLAN.md contracts before changing code. Do not use earlier conversation completion claims as evidence.

## Executor protocol

1. Read repository instructions and `docs/{MASTER_PLAN,CURRENT_AUDIT,EXECUTION_BACKLOG}.md`; inspect dirty status. Preserve user work and existing assets. Do not reset, overwrite unrelated files, publish or commit automatically.
2. Pick earliest dependency-ready ticket. Mark IN_PROGRESS in a new `docs/IMPLEMENTATION_STATUS.md`, include run date, task ID and planned verification. Do not mark the whole phase done when only a function exists.
3. Inspect relevant source, reproduce the defect with a test or explicit observation, implement one bounded slice, validate failure/success branches. Add tests for correctness and transactions, not for static cosmetic text.
4. Record changed paths, exact commands, exit status, assertion/log results, artifact paths/hashes and unresolved limits. Use `generated/qa/<run-id>/` for evidence; do not overwrite older evidence.
5. DONE requires every acceptance criterion. Use IMPLEMENTED_UNVERIFIED if code exists without required render/device proof; BLOCKED only for an identified dependency, with reason. Continue independent tasks.
6. Continue to next ticket within the active turn. Commentary reports evidence, not completion. A final response is appropriate only for the requested scope finishing or a real input/permission blocker. Never imply continued background work after the turn ends.
7. If new changes invalidate old checks, rerun the affected checks. Never assert APK freshness from file existence. Never label a stub production-ready, a test reward an ad, or simulation a playtest.
8. Do not delegate unless the user/repository explicitly authorizes agents. Ordinary independent reads/tests may run concurrently; project export/activation must remain isolated.

## P0 — establish a truthful baseline

### T00 — Snapshot, tool doctor and regression harness

Dependencies: none. Touch: new `automation/qa/`, `godot/masterGame/tests/`, status file; inspect `.gitignore`, project configuration and current source. No gameplay redesign yet.

- Inventory executable versions and paths; preserve dirty source fingerprint and APK hash/time. Discover ComfyUI through scoped known application/work directories/process ports; avoid dumping secrets or unrelated personal files.
- Add a Godot test entry point that instantiates real scenes, controls seeds/state and emits machine-readable assertions, nonzero exit on failure. Use an isolated test save root; never overwrite user progression.
- Python runner invokes Godot with argument arrays and bounded timeout, captures complete output, treats script/resource failures as failure even when process returns 0. Import first when resources are fresh. Narrow host-warning allowlist documented.
- Add failing regressions for unlimited chest claim, new-run reset, null optional upgrade fields, unsupported simulator effects and rejected duplicate reward callbacks. Implement fixes in subsequent tickets; baseline failures must be visible.

Acceptance: harness proves a deliberately failing assertion and synthetic script-error log fail the runner; current defects are reproduced; tool discovery states found/missing rather than assumed. Existing 17 tests still run. No source loss.

### T01 — Run state and combat lifecycle

Depends T00. Touch: GameManager.gd, Player.gd, Enemy.gd, Companion.gd, WeaponBase.gd and new run-state/clock helper if useful.

- Implement MASTER_PLAN state/clock/reset contracts with run-generation tokens.
- Deactivate and detach combat entities before deferred queue_free so no old-frame hit affects the next run.
- Companion gets deterministic name/ownership, actual range, nearest living target and state guards. Enemy death is idempotent. Invulnerability and pause are explicit.
- Fix input consumption and pointer ownership. Stop touch on focus loss, pause and death. Animation chooses idle/run from actual motion rather than autoplay.

Acceptance: 20 retries preserve only permanent stats; acquiring Nova/companion then restarting restores baseline; pause/choice/death freeze all combat; stale callbacks ignored; no duplicate companion or death reward; UI taps don't move player. Test physical touch later under T11.

### T02 — Valid upgrade offers and shared combat formulas

Depends T01. Touch: UpgradeManager.gd, UpgradePanel.gd, Player.gd, projectile/area scripts; game_config.py and runtime_config generation; fixtures.

- Normalize optional nulls, validate effect handlers and per-weapon targets, unique IDs, prerequisites/cycles, caps and no-op exclusion.
- Implement offer-ID transaction and empty-pool Continue. UI closes only after accepted commit.
- Adopt reference_damage and rounding rules from MASTER_PLAN; add explicit formula fixtures in both languages. Fix projectile range and boss payout discrepancy.
- Nova Radius requires unlock; companion card not repeatable; reset temporary levels; all seven families have at least one meaningful verified card.

Acceptance: generated canonical config offers eligible player/utility/unlock cards; invalid/unoffered/repeated card cannot change state; maxed pool continues; base Damage 10→20 doubles identical weapon non-crit hit; HP, crit, attack speed, weapon, companion and Nova deltas individually asserted; dead entities cannot eat a useful projectile.

### T03 — Wallet, durable saves and exactly-once rewards

Depends T01–T02. Touch: MetaProgression.gd, RewardedAds.gd, new RewardService/SaveService, GameManager/GameOverPanel, tests.

- Replace free unlimited Chest immediately with guarded transaction; disable claim UI after success, and guard service independently.
- Implement variant-scoped schema, old-save migration, nonnegative/capped data checks, atomic commit and backup recovery.
- Implement run ledgers and settlement; Coin spend and reward occur in one save transaction. Add test-only injectable save failure.
- Split provider from grant service. Debug mock gated by build type; unavailable release provider never grants or pretends an ad played.

Acceptance: repeated clicks/callbacks/scene reload/relaunch cannot double pay; insufficient funds have no side effects; corrupted primary recovers backup; failed save does not report committed purchase; two variants don't share saves; negative or enormous levels cannot load unchecked. DEBUG mock absent/disabled in release validation.

## P1 — one complete playable vertical slice

### T04 — Timed encounter director and bosses

Depends T02–T03. Touch: WaveManager, GameManager, encounter config/schema/runtime adapter; new behavior modules.

- Implement 45-second active stages, progressive spawns, alive caps and choice scheduling, including the boss-stage rules and same-frame priority in MASTER_PLAN.
- Zombie archetypes: pursuer, fast flanker, slow tank, ranged elite; boss 5 charger with visible windup, boss 10 charger + radial/zone attack. Reuse behavior components with configured timings.
- Track spawned/alive/retired/killed separately. Retiring on timeout cannot grant Coins or count as boss kill.
- Add stage 10 victory and same-stage one-use revive with 3-second protection.

Acceptance: accelerated deterministic clock tests plus real-time run show 30–60 active-second choices; no skip when wave dies early; capped spawns; readable attack windups; death/timer/boss simultaneous events yield one valid transition; 10 stages end in victory; revive doesn't duplicate rewards.

### T05 — Full menus, permanent shop and results

Depends T03–T04. Touch: new menu/shop/settings/pause/revive/result scenes and UI controllers; HUD/upgrade panel; minimal shared theme tokens.

- Implement every screen specified in MASTER_PLAN with explicit back/resume/retry routes and safe-area layouts.
- Add optional Coin extra-upgrade purchase, banked Coin chest, Gem permanent upgrades, pending/saved reward breakdowns and deterministic affordability refresh.
- Present locked ability, readiness and countdown distinctly. Nova VFX expires independently of pause/death and does not redraw forever.
- Connect all five reward placements to disabled/unavailable state or visibly marked debug mock; handle cancel/failure/retry without softlocks. Early dismissal grants nothing.
- Persist audio/settings; tutorial explains movement/autofire/choice/ability, is skippable and replayable.

Acceptance: fresh profile → play → loss → settlement → shop/chest → next run works; all screen buttons function; shop spending visibly changes next-run stats; poor player can keep playing without ads; 360dp/large phone/tablet layouts readable, critical controls >=48dp; back never leaves combat running under a modal.

### T06 — Local asset pipeline and animated Zombie art

Depends T00; final integration after T05. Touch: `automation/assets/`, workflows/manifests, animation controller and actor scenes.

- Identify actual local ComfyUI/GPU/models; smoke-run one reproducible asset job using available licensed model before claiming a pipeline.
- Build submit/poll/error/retry/resume/output-validation interface, with explicit endpoint override and per-job seed/manifest. Do not duplicate successful jobs after interruption.
- Establish coherent Zombie reference sheet; fulfill animation inventory in MASTER_PLAN. Use a rig/keyframe approach if generative temporal consistency fails.
- Pack uniform frames with foot anchors, metadata and verified alpha; select enemy/boss-specific animation resources from manifests. Fix fixed hit-tint restoration and stale tweens.
- Add damage/coin feedback, weapon VFX, boss telegraphs and companion fire art. Quality-check at actual gameplay size, not just full-size sheets.

Acceptance: playback clips for idle/run/attack/hit/death in each direction; no frozen sliding characters, clipping or substantial jitter; auto checks pass; boss uses correct art; rerunning same recipe reuses documented job/assets; missing model/asset fails explicitly without substituting placeholder into a production build.

### T07 — Audio and mobile feel/performance

Depends T05–T06. Touch: audio service, movement/feedback/presentation, settings and stress harness.

- Add licensed SFX/music catalog; buses and volume persistence; cap simultaneous sounds/effects. Give combat feedback without obscuring hit areas.
- Measure actual frame budget, memory and entity caps; optimize only measured bottlenecks. Avoid per-frame tree-wide queries for every weapon when crowd sizes grow.
- Check joystick and separate ability pointer, focus loss/resume, notch/system gesture clearance; add reduced-flash option.

Acceptance: 20-minute stress scene remains bounded; record named device/desktop results honestly; audible and visible hit/upgrade cues; no permanent post-hit tint, permanent Nova ring, stuck touch, input under overlays or duplicated music on retry.

## P2 — make the factory trustworthy

### T08 — Simulator parity and economy model

Depends T02–T05. Touch: simulate_balance.py, config validators and tests; new economy simulation if separation helps.

- Implement all seven upgrade families and actual ownership/prerequisite rules. Explicit model capability check rejects unknown handlers.
- Match damage, cooldown, rounding, spawn count, bonus rewards and stage schedule with engine fixtures. Include companion target/range, special cooldown/radius, coin multiplier and shop spend.
- Separate movement approximation from exact arithmetic. Policies: stationary baseline, simple kiting approximation, random eligible upgrades, survival-biased and damage-biased choices.
- Report earned/spent/banked Coins, Gems, time-to-permanent-upgrade, death/timeout/victory, choice intervals, active time and boss metrics. Ad simulation optional and disabled for baseline fairness.

Acceptance: exact fixtures match Godot within numerical tolerance (1e-4 for arithmetic, one timestep for event times); unsupported effect yields non-PASS; increasing useful range/radius/power affects relevant fixture; multiple seeds/policies report reproducibly; no forced PASS tuning. Reports disclose assumptions and never claim retention.

### T09 — Isolated generation and Android build identity

Depends T03, T06, T08. Touch: factory.py, generate_game.py, export_android.ps1, config/build/assets schema and tests.

- Implement proposed doctor/assets/qa/build/batch commands with usage docs; generate standalone staging projects as defined in MASTER_PLAN.
- Unique per-variant package, display name, icon, save namespace, config, content; write export settings through verified Godot schema/template, not guessed option names.
- Fingerprint source/config/assets and produce manifest. Reject unsafe paths, invalid aliases, missing assets and unsupported content before build.
- Build in fresh target path; verify complete command/session exit, logs, APK signature, manifest and embedded config/hash. Keep stale outputs distinguishable.
- Fix ignore-file prose/fences and generated .idsig handling. Inventory nested legacy project before any move; do not delete it casually.

Acceptance: parallel generation in separate directories has zero cross-contamination; two APK manifests have distinct names/packages and embedded variant configs; failed export cannot report old artifact as success; repeated seed yields identical resolved content hashes; no secrets/test mocks in release staging; dirty source preserved.

### T10 — Space and Ninja substantive content packs

Depends Zombie gates G1–G4 and T09. Touch: variant briefs/presets/assets/behavior modules only where possible.

- Implement the differentiation matrix in MASTER_PLAN with distinct weapons, enemies, bosses, encounter structures, synergies and reviewed animation/audio.
- Keep common engine modules shared; add explicit reusable behavior type when needed rather than sprinkling theme-name conditionals.
- Each variant gets a 10-stage chapter and all seven upgrade families appropriate to its identity. Different power curves must be validated, not copied blindly.

Acceptance: per-variant play footage and content matrix prove differences; no zombie art/title/hardcoded payout leaks; complete menu→run→meta→retry loop for each; visual and simulation gates rerun; human review explicitly recorded, not computed percent similarity.

## P3 — final verification and reproducible handoff

### T11 — Android QA and release preparation

Depends T07–T10. Touch: QA scripts/checklists, build metadata/docs; fixes only as failures require.

- Discover current devices/emulators again. Install only on authorized local test target; preserve unrelated device data. If no target, set device gate BLOCKED and finish remaining desktop/build work.
- Test install, first launch, touch/multitouch, all seven families, boss 5/10, pause/background/resume, death/revive/results, shop, chest, save/relaunch, low/unavailable network and all debug reward callbacks.
- Fresh profile and migrated profile, 20 retries and repeated claims; screenshots/video for main menu, gameplay, choice, boss, shop and results. Check gameplay art stays readable under load.
- Verify all variant APKs, package/version/icon/orientation/permissions/signatures and exact source+asset hash correspondence. Prepare production signing/AAB instructions and deferred integration checklist without publishing.

Acceptance: G0–G6 evidence complete for non-deferred scope; named limitations visible; no P0/P1 defects open; local rebuild instructions tested from clean staging; latest deliverables accessible. If device proof unavailable, describe as implemented/device-unverified, not fully release-ready.

### T12 — Factory operator handoff

Depends T11 or independently complete documentation while device gate blocked.

- Update README with verified quick start, tool discovery, content workflow, adding a variant, running tests, batch build, recovery and output locations.
- Provide a sample new-variant brief/config and a dry-run showing validation catches missing assets/duplicate identity. Do not generate a fourth superficial release game merely to prove command syntax.
- Update status and evidence table. Clearly mark live AdMob, store submission and production credentials DEFERRED.

Acceptance: another model can follow the README without machine-specific hidden assumptions; no instruction claims proposed command already exists until implemented; final report links builds and evidence and distinguishes implementation, visual QA, device QA and deferred services.

## Verification entry points available today

These paths were verified in the audit. Discover overrides on other machines; do not bake user-specific paths into the final factory.

```powershell
& 'C:\Users\abdullah\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' -m unittest automation.tests.test_factory
& '..\Godot_v4.7.2-stable_win64_console.exe' --headless --path godot\masterGame --editor --quit
```

Editor startup imports resources; it is not a gameplay test. Engine tests/qa commands must first be implemented in T00. Respect filesystem approval requirements for editor user-settings writes; prefer scoped test paths when supported.

## Status record template

```text
Task: Txx
State: TODO | IN_PROGRESS | IMPLEMENTED_UNVERIFIED | DONE | BLOCKED
Dependencies verified:
Changed files:
Reproduction before fix:
Commands and exit codes:
Assertions/log scan:
Rendered/device evidence:
Artifact/config/code hashes:
Acceptance criteria checked:
Unresolved issues / next ready task:
```

## Exact next execution request

Read docs/MASTER_PLAN.md, docs/CURRENT_AUDIT.md and docs/EXECUTION_BACKLOG.md. Start T00 and preserve all existing changes. Reproduce the recorded economy, reset and upgrade defects, then execute T01 onward in dependency order. Keep live AdMob deferred. Do not use PASS simulation or a short headless startup as a substitute for engine behavior tests and rendered/device QA. Track evidence and continue across tasks until the authorized non-deferred scope is done or a specific external dependency blocks it.

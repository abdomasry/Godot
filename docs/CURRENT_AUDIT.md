# Current implementation audit

2026-09-17. Evidence: inspected current source and reran `python -m unittest automation.tests.test_factory`: 17/17 passed in 0.633s. This review did NOT play the game, install the APK, test ComfyUI, or rebuild Android. Findings below are source-backed; behavioral reproductions are specified for the executor. Preserve pre-existing dirty/untracked work.

## What exists

- Config merge, Pydantic validation, seeded generation, simple Python combat simulation, three presets.
- Godot scene with player movement, enemy pursuit, projectile/area weapons, upgrade and result panels.
- Candidate arena/art sheets; player animation resource with four run frames.
- Basic Gem persistence, two purchase functions, companion and Nova prototypes.
- Local Android export script and an existing debug APK. Its timestamp is not evidence that it contains subsequent gameplay changes.

## Defects and gaps

Priority P0 = blocks trustworthy economy/run correctness; P1 = core behavior missing/broken; P2 = production quality/tooling. Confirm behavior with targeted tests before fixing.

| ID | Priority | Evidence / location | Impact / required reproduction |
|---|---|---|---|
| A01 | P0 | GameManager._on_chest_requested always adds 10; GameOverPanel.show_result always re-enables Chest | Repeated taps grant unlimited Gems; invoke twice and observe +20. No price, receipt, state guard or cap. |
| A02 | P0 | Player.configure does not reset nova_damage/radius/cooldown or remove Companion; GameManager.start_run does not reset player position | Temporary upgrades/position survive retry; acquire then restart and compare baseline. |
| A03 | P0 | Companion lacks combat-active/dead-owner guards and attacks first enemy at unlimited range | Can keep attacking after player death; ignores range/nearest/dead filtering. unlock_companion tests node name but never assigns that name. |
| A04 | P1 | UpgradeManager.is_eligible uses str(definition.get("weapon", "")); generated Pydantic model includes weapon:null | Non-weapon cards can be incorrectly excluded after null-to-string conversion. Verify exact engine conversion using runtime canonical JSON; do not assume legacy JSON behavior. |
| A05 | P1 | Nova Radius has no prerequisite; UpgradePanel hides before commit; no empty-choice continuation | Inactive/no-op choices; invalid commit or exhausted pool can freeze progression. |
| A06 | P1 | WaveManager does not read wave_duration_seconds; completion occurs on last kill | Required 30–60-second choice rhythm is absent. All enemies spawn immediately. |
| A07 | P1 | Player.can_cast_nova ignores game state; GameManager special handler has no state guard; draw refresh only at cast | Nova can be accepted while upgrade UI pauses movement; flash can remain drawn beyond intended duration. |
| A08 | P1 | Player._input takes touches globally, including UI; run animation autoplay has no velocity/state control | Button touches may start movement; stationary/dead player can keep running animation. |
| A09 | P1 | Enemy scene uses same fixed atlas region for every archetype; boss flag unused in configure | Boss artwork on sheet is not selected. Enemy movement/attack animation is absent. |
| A10 | P1 | Player/Enemy hit feedback restores fixed blue/red modulation | Art remains tinted; overlapping tweens may fight. Restore base material/modulate after feedback. |
| A11 | P0 | MetaProgression uses one fixed save filename; raw write with silent failure; no schema validation/backup/receipts | Corrupt saves, cross-variant shared profile, invalid values and interrupted transactions are unhandled. Shop functions exist but no shop screen calls them. |
| A12 | P0 | RewardedAds.apply_reward public unconditional grant; test hook unguarded; no pending request, receipt or cap | Reward service is a stub, not a safe/complete ad transaction implementation. Current UI has no real ad provider. |
| A13 | P1 | Coins only increment/display; no wallet settlement/spending | Kill → Coins → Upgrade economy is not implemented. Revive/main menu/settings/victory screens are missing. |
| A14 | P1 | ProjectileWeapon.find_nearest_enemy ignores projectile_range | Fires at unreachable enemies and spends cooldown. Verify collision/dead-body interception with an engine test. |
| A15 | P1 | Runtime damage divides by configured starting damage; simulator uses fixed 10 | Changing preset starting damage changes simulator damage but cancels out in runtime before permanent bonuses. |
| A16 | P1 | Runtime enemy count ceil; simulator round; Python round differs from Godot roundi | Counts and Coin rewards diverge. Python simulation adds boss_coin_reward; Enemy.configure does not. |
| A17 | P1 | simulate_balance.apply_upgrade has no companion/special behavior or coin multiplier handling; pulse approximation ignores configured radius | Reports can pass while new upgrades do nothing in simulation. Simulation timeout is currently recorded with death waves. |
| A18 | P1 | Main/Player/Enemy scenes hardcode zombie asset paths; export_presets fixes Zombie package/name | Space/Ninja can export as Zombie identity/art; changing filename is insufficient. |
| A19 | P1 | generate_variant writes shared active_game.json by default; build script uses same master directory | Parallel variants can contaminate one another. Existing APK existence does not prove newest export completed. |
| A20 | P2 | automation/assets contains only placeholder; no workflow/manifest; art supplied by cloud generation in earlier turns | ComfyUI production pipeline is unimplemented/unverified. Claimed local GPU/model capability has not been checked here. |
| A21 | P2 | .gitignore contains prose/fence remnants; .idsig appears untracked; nested monsterSurvivor project exists | Clean ignore rules; inventory/quarantine legacy project only after reference checks, preserve files. Do not delete user work. |
| A22 | P1 | Python tests exercise generation/simulation, not Godot combat/UI; short startup used as gameplay proof | Need engine regression harness plus rendered playtesting. 17 passing tests do not certify the new features. |

## Corrections to earlier conversation claims

- The earlier claimed Area Pulse direct-HP bug is NOT present in inspected AreaWeapon.gd: it already calls take_damage. The prior patch showed no meaningful change. Do not fix a fabricated defect.
- An AnimatedSprite2D with four autoplay frames is not verified natural animation. Frame alignment, alpha, pivots, idle/attack/death and enemy animations remain unchecked/incomplete.
- A generated character sheet containing a boss is not evidence that the boss sprite is actually used.
- Prior PASS reports are not validated estimates of real gameplay after companion/Nova additions. They cannot demonstrate retention, engagement, fairness, or release readiness.
- The existing APK is a prototype artifact. The full factory, monetization loop, art pipeline and production UI are not complete.
- `ui-ux-pro-max` previously returned a Swiss/minimal landing-page recommendation, not a verified game visual direction. The game's art/UX must be designed and reviewed directly.

## Remaining unknowns to resolve without blocking ordinary work

- Exact ComfyUI installation, running endpoint, available checkpoints/adapters, GPU/VRAM and licenses.
- Actual generated sheet frame bounds, animation stability, and current rendered UI fit.
- Current physical Android device/emulator availability and performance; old absence is not a permanent finding.
- Full compatibility of export preset keys with this exact Godot binary; query engine/export schema and inspect APK output instead of guessing keys.
- Current runtime status beyond source inspection; rerun engine import/QA when implementing the first ticket.

# Mobile Game Factory — execution specification

Revision: 2026-09-17 / 1.0. Status: PLANNED, NOT IMPLEMENTED.

## اقرأ أولاً

الهدف مصنع ألعاب Survivor قابل للتكرار، يبدأ بلعبة واحدة ممتعة ومكتملة ثم ينتج ألعابًا ذات اختلاف فعلي. الكود الحالي prototype غير مكتمل؛ وجود APK أو نتيجة PASS من المحاكاة لا يعني أن اللعبة جاهزة. لا تبدأ بإضافة صور أو تغيير أرقام التوازن قبل إغلاق أخطاء القتال والحفظ. ربط AdMob الحقيقي مؤجل بطلب المستخدم. استخدم قائمة المهام وشروط القبول أدناه، وسجّل الدليل قبل إعلان أي مهمة مكتملة.

## 1. Authority, scope, and definition of completion

- This specification captures the user's agreed objective and explicit deferral of live AdMob integration. Numerical defaults below are proposed implementation baselines, not measurements of retention or profitability. Keep them configurable; calibrate only after correctness tests.
- Read `CURRENT_AUDIT.md`, this file, then `EXECUTION_BACKLOG.md` before implementation. Reinspect source: the audit is a dated snapshot.
- Shared engine: Godot 4.7.2 Standard/GDScript; Python factory; local ComfyUI asset production. Existing generated artwork is candidate material, not approved animation.
- Offline core: movement, automated combat, timed upgrade choices, bosses, seven upgrade families, Coins, Gems, permanent upgrades, saved progression, menus, settings, sound, and an ending/results loop.
- Required upgrade families: Attack Speed, Damage, Crit, HP, New Weapon, Companion, Special Ability. Several cards per family are allowed; seven families do not mean only seven cards.
- Required reward placements: x2 Coins, +20 Gems, Revive, Free Upgrade, Open Chest. Implement and test provider-independent transactions now. Real ad SDK/account integration remains DEFERRED, never silently mocked in a release.
- Production factory: validated content, local asset recipes, isolated variant generation, batch simulation and engine QA, Android debug builds and release preparation, provenance reports, human review of identity and animation.
- Completion of current authorized scope requires all non-deferred backlog tasks and quality gates. Store acceptance, retention, revenue, and release signing are not guaranteed by the factory. Publication/account operations require a separate release decision.

## 2. Reuse versus meaningful differentiation

The user's approximate 50% similarity is a creative reuse target, not a measurable Google approval threshold. Share engine, save/economy services, UI components, input, build tooling, and test infrastructure. Do not assign a fabricated percent-different compliance score.

Before promoting any variant beyond internal prototype, require a written content brief and playable evidence of differences in all of: primary combat pattern, enemy/boss behavior, encounter/arena design, upgrade synergies, and visual/audio identity. Palette swaps and renamed currencies are insufficient. This is our internal quality gate, not a Google certification.

Proposed reusable modules and variant briefs:

| Variant | Combat identity | Encounters | Signature content | Art/audio |
|---|---|---|---|---|
| Zombie | projectile kiting, close defense | pursuing hordes, charger telegraphs, toxic zones | support drone + shock nova | abandoned district, tactical survivors, infected animation/audio |
| Space | directional volleys, shield timing | orbiting/ranged drones, projectile lanes | orbit companion + shield burst | orbital deck, pilots, synthetic VFX/audio |
| Ninja | short-range arcs and dash timing | flanking attackers, ranged traps | spirit companion + dash strike | courtyard, martial silhouettes, slash/percussion audio |

Finish Zombie vertical slice before implementing Space/Ninja behavior modules. All three need their own reviewed content before factory completion. Prefer fewer substantial games to many superficial exports.

## 3. Exact playable loop and timing

Baseline: portrait 720×1280 logical viewport, touch movement + separate ability button; keyboard alternatives arrows/WASD and Space. Respect UI-consumed touches and multiple pointers.

One chapter: 10 stages; 45 seconds of ACTIVE combat per stage; bosses on stages 5 and 10. Stages 1–4 and 6–9 spawn enemies progressively over the timer. Timer expiry transitions to the upgrade screen and retires remaining ordinary enemies WITHOUT kill rewards. Never allow a nearly empty early wave to end the stage prematurely: director maintains pressure within a configured alive-enemy cap.

Boss stages: one boss, capped adds, visible telegraphs. At 45 seconds pause for the scheduled choice even if boss lives, then resume that same stage. Further choices every 45 active seconds while the boss remains. Killing boss completes stage immediately. If death, timer expiry and boss death share a frame: player death takes priority; if player survives and boss dies, boss completion takes priority and supersedes that frame's timed choice. One transition/choice only. Boss 10 death while alive ends in Victory.

Every non-final stage completion offers three eligible choices; scheduled choices cost zero so poor runs cannot be progression-locked. Choice timer resets on a choice being committed. All clocks stop in pause, shop, upgrade, result, and reward-modal states. A revive resumes the same stage, not a new one. Retrying starts a fresh run using saved permanent stats.

Timing clarification: 30–60 seconds is the scheduled combat-choice cadence. An early boss kill can grant an additional stage-completion choice sooner as an explicit boss reward; record it separately from scheduled intervals. Optional paid/free-reward bonus choices do not reset the scheduled timer. Regular stage completion and its scheduled expiry represent ONE choice, never two. Active time excludes all UI delays.

Coins: kill rewards usable for an optional extra upgrade at the choice screen; one extra purchase per choice checkpoint, baseline price `ceil(20 * 1.25^purchases_this_run)`. No Coins are charged for the scheduled choice. Remaining run Coins are banked on final results exactly once; banked Coins fund chests. Keep run Coins and banked Coins separate.

Gems: primary persistent progression currency. Baseline +1 on cleared ordinary stage, +5 on cleared boss stage (instead of +1), +10 once for chapter victory. They are available through normal play; an ad is never necessary. Run rewards enter a run ledger and are settled on final results; the HUD distinguishes pending and saved Gems. Do not pay twice after revive, replayed signal, or reopening results.

Chest: spend 100 banked Coins, receive fixed 5 Gems initially (no loot-box randomness in first version). Separate optional reward-ad chest has the same specified reward. Remove the existing unlimited free result chest. Receipt IDs and debit/credit are saved together.

Permanent upgrades: Damage and HP start at 20 Gems; next price `20 + 15 * current_level`; +5% of base per level; cap 10 initially. Apply only at the next run start, without compounding an already multiplied stat. A maxed item is not purchasable. These numbers are tuning baselines.

## 4. Architecture and state contracts

Evolve the existing files incrementally; do not replace the whole project in one patch. Suggested new responsibilities (names may be retained as wrappers for compatibility):

| Owner | Owns | Must not own |
|---|---|---|
| ConfigManager | validated read-only active config/content references | save currency or mutate a running build |
| GameManager / RunController | state transitions, run ID, checkpoint ID, run settlement | asset generation or SDK calls |
| WaveManager / EncounterDirector | active-time timers, spawn budget, stage and boss tracking | reward payout or UI state |
| Player/weapon/companion | movement and combat behavior | persistent wallet writes |
| UpgradeManager | offer IDs, eligibility, deterministic application | hiding UI before a successful commit |
| MetaProgression / SaveService | wallets, levels, receipts, schema migration, atomic save | game scene references |
| RewardService | placement validation and exactly-once application | declaring an ad completed itself |
| RewardedAds provider | availability/show/completion/failure adapter | directly changing currencies |
| Presentation/UI | display state and send intents | deciding eligibility or paying rewards |

States: BOOT → MAIN_MENU → RUNNING; RUNNING ↔ PAUSED; RUNNING → CHOOSING_UPGRADE → RUNNING; lethal damage → REVIVE_OFFER → RUNNING or RESULTS; victory → RESULTS; RESULTS → MAIN_MENU or fresh RUNNING. META_SHOP is reachable from MAIN_MENU. AD_PENDING is a modal substate preserving its origin and checkpoint. Use a run-generation token to discard old timers and callbacks after retry/exit.

Combat active means player movement, enemy AI, weapons, companion, hazards, projectile lifetimes, hit resolution and cooldown clocks all agree. UI remains interactive when combat pauses. Nova cannot fire from a hidden or disabled HUD. Backgrounding the mobile app pauses combat; foreground requires resume, never immediately damages the player.

Run reset clears: player transform/velocity/touch pointers, HP, temporary stats, weapon ownership/levels/cooldowns, companion node/state, Nova unlock/radius/cooldown/VFX, enemies/projectiles/pickups/hazards, director timers, offer IDs, revive flag, reward pending IDs and temporary run ledger. Preserve only committed profile data.

Damage formula, shared across runtime and simulation: `weapon_base_damage * (effective_player_damage / reference_damage)`; reference_damage is explicit config value 10, not each preset's starting damage. Effective player damage = preset base × permanent multiplier + run flat bonuses. Crit rolled per hit/target using capped probability [0,1]; multiplier >=1. Cooldown = max(0.08, weapon_cooldown / max(0.05, attack_speed)). Use one documented positive rounding rule (floor(x+0.5)) for payouts in both languages. Enemy count uses ceil in both languages.

All hit sources use Enemy.take_damage → one death event with enemy ID, boss flag and reward breakdown. Dead/retiring/queued-free enemies are ineligible for targeting/collision damage. Range checks precede projectile firing and companion targeting. Boss reward is ordinary scaled kill reward + configured boss bonus exactly once; no separate hidden simulator payout.

## 5. Upgrade transactions

Canonical card fields: id, family, display_name, description template, effect handler, target, value, max_level, prerequisite IDs/owned items, exclusions, allowed variants, icon reference. Use explicit defaults and omit nullable fields in runtime output, or handle null by type checking; never stringify null into an item ID.

Generate offer once for a checkpoint with seeded RNG; three distinct eligible cards, ordered and retained until choice. Commit requires matching run ID + offer ID + offered card ID, state CHOOSING_UPGRADE, eligibility still true. Apply once, increment level once, then notify UI. Invalid selection retains panel and shows recoverable feedback. An empty eligible pool offers explicit Continue; it never freezes a run.

- Companion unlock is single ownership; named node, capped range, nearest valid living target; follows pause/death/reset; attacks with readable projectile/beam and fire animation.
- Nova Radius requires Nova unlocked. Nova has charge/ready/cooldown states, telegraph and self-expiring VFX. Changing radius changes hits as well as visuals.
- HP raises maximum and current HP by the granted delta, without exceeding maximum. Repair at full health is excluded unless the chosen design intentionally allows it.
- Weapon-specific stats only apply to that weapon type; no radius card on a projectile, no speed card on an area pulse. Exclude capped/clamped no-op cards.
- Upgrade descriptions derive actual values; UI shows level, prerequisites, and changed numbers.
- Free Upgrade reward opens a separate one-time bonus offer at a checkpoint; it does not consume the scheduled choice, reset the encounter timer twice, or allow recursion.

## 6. Save and reward contracts

Save: schema_version, variant_id, profile_id, revision, banked_coins, gems, permanent_levels, best_stage, settings, processed_receipts, pending_run/checkpoint ledger, claimed_reward_counts. Use variant-specific save path and safe ID validation. Clamp/reject invalid values and cap levels. Migrate the existing three-field save explicitly. Store temporary file → validate → atomic replace with backup; preserve last valid save on interrupted write. Show/save diagnostic on failure; do not report a durable purchase until commit succeeds. Local saves are not an anti-cheat security boundary.

Reward request: request_id, placement, run_id, checkpoint_id, declared amount, origin, status. Provider events: unavailable, loading, shown, earned, dismissed, failed. Only earned authorizes credit. Dismissal alone does not. Duplicate/reordered events must not duplicate payouts; a stale run cannot revive the current run. Persist durable rewards and receipt together; retain only bounded receipts after pending transactions are resolved.

| Placement | Eligibility | Result | Initial cap |
|---|---|---|---|
| double_coins | unclaimed results for this run | bonus equal to recorded earned run Coins, not current global wallet | once/run |
| gems_20 | menu/shop, provider available | +20 saved Gems | 3/day configurable |
| revive | lethal state, not victorious, not previously revived | 50% max HP, 3s invulnerability and enemy pushback; same stage | once/run |
| free_upgrade | active checkpoint, no pending offer reward | separate eligible bonus choice | once/checkpoint |
| chest | menu/shop, provider available | declared chest reward | 3/day configurable |

Without provider: hide/disable ad CTAs with clear unavailability; core play and Coin chest remain functional. A DEBUG-only mock UI exposes Earned/Cancel/Fail/Duplicate callback cases and visibly says TEST REWARD. Export validation must reject mock-enabled release builds. Preserve future consent/SDK integration seam; defer actual SDK, IDs and live traffic.

## 7. Visual/animation and audio production

First inspect local ComfyUI installation, running endpoint, workflows, available models, VRAM and model licenses. Do not claim it exists or works until checked. Use existing local assets where suitable. If a required model is missing, prepare exact resource/license/size requirement and continue other tasks. Do not switch to paid/cloud generation without the user's choice; earlier cloud images are only candidates.

Create a content manifest and asset recipes: asset ID, subject/design sheet, approved reference, workflow/API graph, model and adapter hashes/licenses, seed, negative prompt, dimensions, animation/state/direction/frame order, anchor, preprocessing, output hash, approval state. Save workflows in `automation/assets/workflows/`; write final packed output to variant staging, never to one shared fixed zombie path.

Animation minimum for each shipped hero: idle 4, run 8, attack 4, hit 2, death 6 frames. Each enemy archetype: idle 2, move 6, attack 4, hit 2, death 6; bosses add at least 6 telegraph/attack frames per unique move. Frame counts are minimum targets, not proof of quality. 3/4 view uses up/down/side sets; mirror side only if art permits. Drone: idle/flight cycle and fire animation. VFX may be procedural with bounded lifetime.

Generate consistent key art first, then derive animation with reference-conditioned workflow or articulated 2D rig where generative frames fail. Never trust a text-to-image contact sheet as equal-sized aligned frames. Pack individual alpha images using detected bounds into uniform frame canvases, fixed foot pivot and transparent margins. Manifest supplies exact atlas rectangles and FPS; scene rectangles are generated, not guessed. Visually inspect loop playback: no sliding feet, clipped limbs, identity drift, accidental duplicate frames, changing body size, or camera movement. Idle must not play run.

Automated art checks: file exists, decodable, expected dimensions and alpha, frame count, bounds inside atlas, consistent canvas/pivot, maximum texture size 2048 per atlas page initially; flag duplicate/near-duplicate frames for review. License provenance for every generated model-derived/exported asset and audio source. Include readable SFX for fire/hit/kill/coin/upgrade/boss/Nova, menu/run music with volume/mute persistence. No unlicensed borrowed music.

Screens: main menu (identity, Play, progression, settings); HUD (HP, stage/time, run Coins, pending Gems, boss HP, ability status); three-card choices (icons/levels/effects); pause; revive; results (reward breakdown/claim status/retry/menu); permanent shop; chest result; settings. Reference 360dp width: 48dp target minimum, 8dp spacing, safe areas. Convert to logical viewport units; 48 viewport pixels at 2× scale is not 48dp. Test 16:9, 19.5:9 and tablet; do not stretch hero proportions or expose bare arena edges.

## 8. Factory contract and build isolation

Proposed commands (NOT currently available): doctor, assets, generate, validate, simulate, qa, build, batch. Keep current CLI compatibility or document migrations. Preset names/IDs must be safe slugs. Treat generated directories as outputs; never fix a defect solely in generated JSON.

Version the canonical schema when adding required fields. Sections: metadata/package, theme/asset_manifest, player, weapons, enemies/behaviors, encounters, upgrade definitions, economy/meta, reward placements, gameplay, build. Resolve template → preset → bounded seed rules → full validation → staging. Validate cross-references, enum handlers, dependency cycles, supported model features, finite values, positive costs, stage timing and build identity. Runtime and simulator consume the same resolved config and formulas.

Generate standalone projects under `generated/<variant>/<build_id>/project/`; never run concurrent builds against `godot/masterGame/configs/active_game.json`. Explicit activate command may copy a validated variant for manual preview. Every project resolves only its own asset manifest, display name, package ID, version, icon and save namespace.

Build ID uses config+code+asset hashes. Manifest includes revision/dirty-worktree fingerprint, config/schema/generator versions, seed, model/workflow hashes, Godot version, tool versions, artifact hash and QA report references. Timestamp is metadata, not semantic determinism input. Reproducible content does not imply bit-identical signed APK bytes.

Pipeline: generate → schema/assets validation → import/compile → runtime tests → simulation → packaging → APK verification → device evidence. Publish artifact atomically only after success. Existing stale APK must not count after a failed build; keep previous artifacts under immutable names. Output policy: source/config/assets/workflows tracked as appropriate; secrets, signing keys, generated projects/builds and .idsig untracked. Never broadly discard user changes.

## 9. Verification gates and honest reporting

G0: snapshot source, preserve dirty tree; known defects mapped to tests.
G1: combat/upgrade/reset/reward tests pass inside Godot, with state transitions exercised.
G2: one Zombie chapter playable from menu to victory/death, upgrade every 30–60 active seconds, persisted shop/chest, no economy exploits.
G3: real animation/audio/UI reviewed in rendered play sessions; no headless-only visual claims.
G4: simulator parity fixtures and unsupported-feature rejection; all seven families modeled. Balance across seeds/build strategies, not one PASS.
G5: three independent substantive variants generated with correct identities/assets and isolated saves; batch failure recovery proven.
G6: latest build signed/verified, actual install/launch/resume/retry tested on an Android device or properly configured emulator. Emulator testing is not physical-device performance evidence.

Engine QA must inspect logs as well as exit code: SCRIPT ERROR, parse error, failed resource/autoload and runtime exceptions fail the gate even with exit 0. Narrowly documented host warnings may be separated; never globally ignore ERROR. A 120-frame smoke run only proves a brief startup path.

Simulation: compare fixed no-movement/no-RNG combat fixtures against Godot first; document movement approximation separately. Report death vs timeout vs victory separately; conditional wave mortality vs all-run mortality separately. Support companion/Nova/coin multipliers/economy and prerequisite selection. Unsupported config yields UNSUPPORTED/FAIL, never PASS. Run at least seeds 1, 7, 42, 12345 and multiple upgrade policies; evaluate 1000 runs/config for trends only after parity. Do not soften enemies to make a defective simulator pass.

Performance targets to measure: 60fps target, >=30fps under defined stress cap on named test hardware; start with 60 enemies, 100 projectiles, capped effects. Record p50/p95 frame time, memory, texture sizes, 20-minute stability, thermal context and hardware. Establish measured budgets before raising spawn caps. No invented retention targets as achieved results; real playtesting must evaluate clarity, enjoyment, first-upgrade timing and repeat-play interest.

## 10. External boundaries and sources

Deferred: live AdMob SDK/IDs/consent configuration, production signing credentials and store submission. Device/model availability may block a specific gate, not all independent work. Do not request a secret pasted into chat. User approved local discovery and implementation; use scoped filesystem approvals only when required by environment.

Policy checked 2026-09-17: Google describes repetitive content in terms of highly similar functionality/content/experience; no 50% safe harbor is stated. Internal differentiation review cannot guarantee acceptance. Rewarded ads require voluntary, disclosed reward behavior; callback completion is the technical grant boundary. Recheck current platform requirements at release time.

- Google Play policies: https://support.google.com/googleplay/android-developer/answer/17517561?hl=en-GB
- Repetitive-content guidance: https://storage.googleapis.com/support-kms-prod/MKkjTvEGQ9WOkjnRPvmDvt1futgiUXU4U1eQ
- Reward policy: https://support.google.com/admanager/answer/7496282?hl=en
- Reward callback documentation: https://developers.google.com/admob/android/rewarded

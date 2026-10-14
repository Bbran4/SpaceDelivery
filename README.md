# SpaceDelivery

**SpaceDelivery** is a 2D space-delivery incremental action game about piloting a cargo ship through procedurally generated routes, letting weapons fire automatically, and trying to finish a shift without losing the shipment or getting fired. Take contracts, choose branches through dangerous encounters, collect side earnings, deliver the cargo, and reinvest in a growing ship. There is no prestige or full reset: progression is permanent, so the economy and difficulty must scale for a long campaign.

This README is both a design document and a practical guide to the intended core loop. It describes a mix of current implementation and planned features; a design goal is not proof that a feature is already implemented.

## Design pillars

1. **The cargo is the reason for everything.** The contract payout is the major prize. Delivering earns it; losing the shipment forfeits it. Side earnings gathered along the way are retained, so a failed run can still move the player forward.
2. **Piloting is active; combat is automated.** The player primarily creates value by moving, positioning, dodging, kiting, and choosing targets or routes. Weapons handle firing. Upgrades can gradually reduce routine workload, but the first mode is an action game with incremental progression, not an unattended idle simulator.
3. **Every mission is a fresh but coherent route.** Seeded, branching node maps create variation within rules that protect connectivity, pacing, fairness, and meaningful choices.
4. **Short, repeatable missions.** Encounters should usually last around 60-90 seconds. The full delivery is a string of compact stages, not one exhausting battle.
5. **Risk and reward are visible.** Players choose contracts and routes with understandable trade-offs in danger, recovery, salvage, and potential pay.
6. **Permanent progress needs sustainable scaling.** Credits, upgrades, reputation, and unlocks persist. The economy must remain readable and challenging without relying on prestige resets.

## Tone, humour, and creative direction

SpaceDelivery takes inspiration from workplace sci-fi comedy: an ordinary delivery company trying to do an ordinary job in a galaxy that is anything but ordinary. The influence is tonal, not a shared setting. Characters, dialogue, locations, visual identity, and jokes must be original.

**The central fantasy:** the player is not saving the galaxy. They are trying to deliver a package across it without getting fired.

The company presents itself as professional, dependable, and safety-conscious. In practice, it accepts questionable contracts, cuts corners, hides problems behind paperwork, and expects the crew to treat catastrophes as routine work.

Possible company flavour:
- **Company motto:** “Your Package. Our Problem.”
- **Delivery guarantee:** “Your package will arrive eventually, provided the destination continues to exist.”
- **Safety policy:** “The company accepts no responsibility for injuries sustained during optional mandatory overtime.”
- **Ship diagnostics:** “Propulsion status: technically present.”
- **Incident reporting:** “The event has been classified as a minor scheduling irregularity.”

These are examples, not locked-in lines. Humour should emerge from systems, consequences, and the company's dry interpretation of events.

### Comedy rules

- Treat absurd events as routine workplace problems.
- Make choices funny as well as meaningful.
- Deliver jokes through reports, fines, diagnostics, complaints, bonuses, and corporate forms.
- Let success be messy: the package may arrive while the ship is damaged and the crew is furious.
- Keep outcomes clear. A punchline must never obscure whether the player was paid, fined, or failed.
- Build an original universe rather than borrowing characters, dialogue, designs, or settings from existing works.

### How mission comedy is authored

Use **authored event templates with conditional slots**, backed by a small pool of reusable lines. Each event defines its purpose, tone, eligible route or encounter context, and optional text variants. Route flags such as `cargo_damaged`, `rescued_crew`, `spent_credits`, and `route_alerted` can select follow-up lines and outcomes. This keeps jokes coherent and testable without requiring every generated route to have a fully bespoke script. Purely random line selection should not contradict what happened in the run.

## Core gameplay loop

1. **Accept a contract.** Review cargo, client, destination, base fee, hazard, and any optional rewards.
2. **Choose a mission and inspect its route.** A generated route belongs to the selected contract, not the general contract board. The route begins with only the opening node revealed.
3. **Prepare and test the ship.** Check the loadout and use Test Flight. Deliver remains disabled until a valid mission is selected.
4. **Select the next visible node and fly it.** Completing a node returns the player to the route map, marks the node complete, and reveals its connected successors. Hull, shields, cargo integrity, collected credits, and salvage inventory carry between nodes.
5. **Reach the destination or fail the contract.** The main contract payout is awarded only when delivery is resolved successfully. Failure forfeits that payout but keeps eligible side earnings.
6. **Read the company report and reinvest.** Results show payout, penalties, salvage, cargo condition, and the completed path. Spend credits on progression and take the next job.

## Cargo, capacity, and rewards

Cargo is both the objective of a contract and the reason its payout is at risk. Each contract specifies a shipment, its value, and delivery conditions. A successful delivery awards the contract fee, potentially adjusted for cargo condition and route bonuses.

Cargo capacity is an **eligibility and loadout constraint**, not a direct multiplier applied to every contract. Larger holds unlock bulky or high-volume contracts and can support a broader set of jobs; they do not automatically make every small parcel more valuable. Hull and module choices therefore trade cargo flexibility against defence, speed, and utility.

Keep three reward concepts distinct:

- **Contract payout:** the large, at-risk reward for delivering the shipment successfully.
- **Encounter earnings:** credits and eligible drops collected during the run. These are retained if the contract fails.
- **Salvage and valuables:** item drops are stored in the ship's salvage hold and carried between route nodes. On return to HQ after either success or failure, a recovery panel lists each collected item, quantity, unit value, and total value. The items are then removed from pending salvage and converted into credits exactly once using each item's credit_value. Salvage capacity limits how many units can be collected.

Possible cargo categories:
- **Standard parcels and supplies:** introductory, lower-risk jobs.
- **Bulk and oversized freight:** requires a suitable cargo hold.
- **Fragile cargo:** integrity loss can reduce the delivery fee or destroy the shipment.
- **Hazardous cargo:** higher pay in exchange for additional risk.
- **Time-sensitive shipments:** optional arrival-time bonus.
- **High-value or classified cargo:** lucrative jobs that may attract stronger opposition.
- **Medical, contraband, and unusual cargo:** mission-specific objectives, risks, or story events.

### Jettisoning cargo

Jettisoning is an escape option to consider when a fight is going badly. It forfeits the contract payout but may let the ship survive and keep encounter earnings. It should be kept only if playtesting proves it creates a real, understandable decision rather than an automatic best choice.

### Initial economy targets

These are **balancing hypotheses**, not current tuned values:

- A routine delivery should pay roughly **4-6 times** the side earnings of a typical run.
- A risky optional branch should offer a meaningful increase in salvage or route bonus, not just more enemies.
- A failed delivery should still yield enough side earnings to make the run feel worthwhile, but substantially less than a successful delivery.
- Jettisoning should be attractive when the cargo is likely to be lost anyway, not whenever it provides a small tactical advantage.

Instrument playtests to record contract fee, side earnings, cargo damage, failure rate, and jettison frequency. Adjust these ratios from actual results rather than treating the initial targets as final balance.

## Clients and reputation

Players choose which contracts to accept. Clients can differ in cargo, fees, hazards, and optional objectives. Successful deliveries can earn reputation, which unlocks contract tiers, cargo types, and more dangerous work. The initial economy uses authored prices and reward rules rather than simulating a dynamic galactic market.

## Procedural routes and encounters

Routes are seeded, branching graphs generated for the selected contract. Progressive discovery shows only the starting node initially. Completing a node reveals its connected successors while completed nodes remain marked. The generator guarantees exits for non-destination nodes and at least two distinct exits wherever the next layer offers alternatives. Encounter siblings are kept distinct where possible, early encounters are capped at risk 2, and later layers scale risk with some relief after harder layers. Service stops are less common than combat nodes, provide no direct credit bonus, repair 35% of maximum hull, and restore shields. `MissionRunState.begin_mission(mission, forced_seed)` can replay a specific route; completed node history and route flags are recorded for future event logic.

**Committed generation rules:**

1. Every generated route has a valid start and a reachable destination.
2. Every offered node is reachable from the current frontier, and every non-final node has a valid onward path.
3. Randomness varies the route inside constraints; it must not produce dead ends, impossible delivery paths, or contradictory events.
4. Node type, risk, cargo, and recent encounters influence what can appear next.
5. Pressure and relief alternate where practical. Avoid repeatedly stacking the hardest encounters without recovery or variation.
6. Branches communicate real trade-offs in risk, recovery, bonus pay, and salvage.
7. Use route history and flags to make later events respond to earlier choices.
8. Run the seeded route validator across batches of seeds, then expand it to measure pacing, difficulty spikes, and reward distribution. A valid graph is necessary, but human playtesting is still required to judge whether a route feels good.

Possible encounter types include combat, elite fights, salvage recovery, rescue, escort, inspections, anomalies, and the destination. `MissionRouteNode` now exposes an explicit objective type so route resources can describe what a node is meant to do. At present, flight gameplay handles combat and service objectives; salvage recovery, rescue, escort, and inspection handlers remain future work. The shared `MissionCatalog` in `scripts/mission_catalog.gd` is the source of offered mission resources for the HQ board, route-test panel, and seeded batch tool. The batch validator is available at `tools/route_seed_batch_test.gd` and checks graph reachability, dead ends, branch availability, risk pacing, and repeated encounter profiles.

## Combat feel and piloting

The ship builder opens the active saved build when one is valid. A default Starter Courier build with a basic laser is shown when no valid active build exists. Builds without a compatible weapon cannot be saved or loaded, and HQ disables View Route and Test Flight while showing a red NO ACTIVE WEAPON ON SHIP warning if no usable weapon is available.

Weapons and ship systems fire automatically. The player's primary moment-to-moment agency is movement and positioning: dodge incoming pressure, kite pursuers, keep distance from dangerous targets, line up safer paths through a fight, and choose which visible route branch to tackle next. Build choices change how those decisions feel, rather than replacing them with a pile of passive stat increases.

The intended identity is **active piloting with automated weapons and incremental meta-progression**. Later upgrades may automate routine tasks or provide navigation assistance, but they should not remove the movement decisions that make encounters engaging. Controls should remain consistent and understandable; input modes must not silently change who or what the player is targeting.

## Skill tree and progression

The skill tree is for **account-wide growth, multipliers, efficiency, and automation**. It can improve broad damage or defence scaling, reward efficiency, unlock route information, and eventually automate repetitive administrative choices. Milestones may unlock a new system, but the tree should not duplicate the basic capability of every ship module.

There is no prestige system. Permanent progression means late-game scaling must be planned deliberately:
- Use a documented set of base values and growth curves instead of adding arbitrary flat bonuses forever.
- Prefer diminishing returns, additive/multiplicative categories with clear rules, and enemy/contract tiers to uncontrolled exponential stacking.
- Define soft caps or tier transitions for major stats where necessary.
- Test early, middle, and late-game time-to-kill, survival, and earnings as one connected economy.
- Keep numbers readable. Large-number notation should be a deliberate UI choice, not a substitute for a balanced curve.

The initial combat values, including current hull and weapon damage, are implementation starting points rather than final balance targets. Tune them against encounter duration and survival targets.

## Ship, modules, and loot

The ship builder defines **capabilities and playstyle**; the skill tree defines broad long-term scaling and automation. This division avoids making two progression systems compete to provide the same small stat bonus.

Planned ship choices include:
- **Hull frames and size:** set base durability, cargo capacity, fitting space, and handling trade-offs.
- **Weapons:** automatic cannons, lasers, missiles, and other firing behaviours.
- **Defence:** shields, armour, repair systems, and defensive drones.
- **Engines and navigation:** handling, movement behaviour, and route utility.
- **Utility modules:** cargo protection, loot scanning, salvage collection, or specialist effects.
- **Slots and fitting limits:** force meaningful choices between cargo, combat, durability, and utility.

Loot can include credits, salvage, valuables, and modules. Where practical, rewards should reflect their source. Elite enemies may have improved rare-module chances, while bosses may eventually grant unique equipment. Exact rarity tiers, fitting rules, and salvage storage values remain to be balanced.

## Mission failure

A mission fails immediately if the ship is destroyed or cargo integrity reaches zero, because the shipment can no longer be delivered. The contract payout is lost on failure, but eligible encounter earnings and collected item drops remain. On return to HQ, a salvage recovery panel itemizes collected drops and converts their credit_value into credits once, regardless of mission success or failure. Permanent upgrades and previously earned progression are not reset. The results screen distinguishes contract loss from retained earnings and explains cargo condition plainly.

## Game modes

### Delivery Pilot

The first and primary mode. Pilot a cargo ship, accept contracts, choose a route, fight with automatic weapons, gather loot, and deliver packages. A final major contract can eventually conclude the campaign.

### Escort Pilot

A possible second mode unlocked after the Delivery Pilot campaign. Protect a delivery ship or convoy rather than carrying the shipment.

### Delivery Tycoon

A possible future management mode. It is out of scope until the core delivery loop is proven.

## Crew (planned)

Crew members may provide specialist or passive effects, such as navigation, engineering, gunnery, salvage, or cargo management. Crew is a later feature, after the core loop and progression balance work.

## Development scope and priorities

The first vertical slice is a single playable contract with a defined destination, a short branching route, two or three encounter types, persistent ship/cargo state between nodes, automatic combat, side earnings, a delivery payout, and a readable result report.

### Vertical-slice test contract: “The Wrong Parcel”

1. **HQ: Contract acceptance.** Accept a standard parcel delivery to a mining colony. Confirm that Deliver is disabled before mission selection and enabled afterward.
2. **Node 1: Customs Checkpoint.** A short introductory encounter. Completing it marks the node complete and reveals two connected options.
3. **Branch A: Salvage Drift.** A higher-risk detour with a chance of side earnings and salvage.
4. **Branch B: Service Beacon.** A recovery opportunity that trades a less lucrative route for improved ship condition.
5. **Merge: Mining Lane.** A short encounter that tests whether hull, shields, cargo integrity, and credits persist correctly from earlier nodes.
6. **Destination: Colony Freight Office.** Resolve delivery once, apply cargo-condition adjustments and route bonuses, and show the final payout and completed path.
7. **Failure check.** Repeat the contract and fail before the destination. Verify that the contract payout is zero while eligible encounter earnings remain.

This is a test specification for the intended experience; the named beats may need to be mapped onto the available generated node profiles as the implementation evolves.

### Development order

1. **Mission selection and route discovery:** Select a contract, generate a seeded route, reveal connected nodes progressively, and validate reachability.
2. **Vertical slice:** Complete one contract from HQ through encounters to destination, including persistent ship/cargo state and rewards.
3. **Results report:** Clearly show success/failure, payout, retained side earnings, cargo condition, and route summary.
4. **Encounter pacing:** Add and balance combat, salvage, service, and event nodes with controlled variation.
5. **Cargo risk:** Tune cargo integrity, hazardous cargo, and jettisoning through playtests.
6. **Economy and loot:** Establish credits, salvage capacity, valuables, and module drops.
7. **Progression split:** Implement skill-tree multipliers/automation separately from hull and module capabilities.
8. **Scaling and balance:** Test damage, hull, time-to-kill, contract tiers, and reward curves from early to late game.
9. **Clients and campaign:** Add reputation, cargo unlocks, a finale, then consider Escort Pilot.
10. **Future scope:** Consider crew and Delivery Tycoon only after the core experience is solid.

## Open design questions

The following are deliberately unresolved; the core direction is not:
- What exact control layout best supports consistent movement and targeting?
- What is the final full-mission duration once several encounters are linked?
- Which specific automation unlocks save busywork without removing piloting agency?
- What final late-game growth curves and soft caps feel rewarding without runaway numbers?
- How should the campaign finale and post-campaign contract loop work?
- What are the final salvage-capacity, cargo-jettison, and reward-ratio values after playtesting?

The game is already a 2D project, and the active-versus-idle direction is active piloting with automated weapons. Those are decisions, not open questions.

## Technical details

Confirmed from the project configuration and current source:

- **Engine:** Godot 4.7, Forward Plus renderer.
- **Game dimension:** 2D; gameplay uses 2D scene and physics nodes.
- **Primary language:** GDScript.
- **Startup scene:** `res://scenes/hq.tscn`.
- **Shared mission state:** `res://scripts/mission_run_state.gd`, registered as the `MissionRunState` autoload.
- **Procedural route generation:** `res://scripts/route_generator.gd`. Mission resources configure `layer_node_counts`, `branch_chance`, `risk_bias`, and optional `fixed_beats` in `res://scripts/mission_definition.gd`.
- **Route-map presentation and interaction:** `res://scripts/route_map.gd` and `res://scenes/route_map.tscn`.
- **Flight stage:** `res://scripts/mission_flight.gd`.
- **Route node data:** `res://scripts/mission_route_node.gd`.
- **Save format:** The save location and persistence implementation should be documented after confirming the current save/load path; do not assume that runtime mission state is the save system.
- **Physics note:** `project.godot` enables Jolt for 3D physics. The game is 2D, so this setting is not evidence of a 3D gameplay requirement and can be reviewed separately.
- **Windows rendering driver:** Direct3D 12.

## Procedural generation reference

Reference: [Video on procedural generation and game design](https://youtu.be/442FHQ-rymM?si=KcyazgQl7kRDs7zw).

The design takeaway is simple: **protect what matters; randomize what doesn't**. A route generator should not merely scatter random encounters. It should create a coherent delivery journey whose connectivity, risk, rewards, and pacing remain within tested bounds. Seeded generation makes results reproducible, while multi-seed testing helps expose edge cases. Traditional procedural generation uses rules, algorithms, weights, constraints, and validation; it does not require generative AI.

For SpaceDelivery, mission resources define the route's layer shape, branching likelihood, and risk bias. Optional `fixed_beats` are encounter templates assigned to a layer depth and lane; the generator preserves their authored title, description, encounter profile, risk, and bonus while generating node IDs and connections. `layer_node_counts` defines the number of nodes in each layer, with a single start and destination. The HQ validates these generator settings and logs actionable errors without hiding a contract because of obsolete route-graph data. Each node should have a reason to exist, route flags should let decisions matter later, and a generated route should surprise the player without becoming arbitrary or unfair.

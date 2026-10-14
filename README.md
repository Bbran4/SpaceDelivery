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

Implemented cargo variants share reusable rules in `scripts/cargo_rules.gd`:
- **Standard:** one-unit minimum capacity and baseline damage sensitivity.
- **Fragile:** one-unit minimum capacity and increased damage sensitivity.
- **Bulk:** four-unit minimum capacity and reduced damage sensitivity, balanced by the larger hold requirement.
- **Valuable:** two-unit minimum capacity and increased damage sensitivity.

Every variant uses the mission-authored minimum delivery integrity, full-reward integrity, declared value, and damaged-cargo penalty. Cargo capacity is checked before launch; integrity and payout rules are shared rather than duplicated in UI or flight code. These are initial tuning values and should be adjusted after playtesting.

Other planned cargo categories include:
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

## Mission framework implementation status

**Framework pass 01 (in progress):**
- Contract definitions now support reusable, authored objective definitions without storing per-run progress on the shared resource.
- Contract validation checks required metadata, cargo integrity thresholds, reward penalties, duplicate objective IDs, missing/self prerequisites, prerequisite cycles, and route-generation settings.
- The mission catalog rejects invalid contracts instead of offering them on the HQ board.
- HQ validates the selected contract and initializes a separate objective tracker before route generation. Invalid generated routes fail launch rather than continuing with an unusable graph.
- Objective progress supports LOCKED, AVAILABLE, ACTIVE, COMPLETED, and FAILED states, prerequisites, quantities, and required-versus-optional objectives.
- Confirmed enemy destruction now advances DESTROY objectives, and a cleared encounter advances ELIMINATE_GROUP objectives.
- Delivery is blocked when explicit mandatory objectives remain incomplete. Existing delivery-only contracts with no explicit objectives keep their current flow.
- Settlement records an objective snapshot and contract outcome in the mission result; both route-map and flight debriefs display objective status and progress. Combat failure is recorded, abandonment is explicitly tracked, and tracker state is cleared when the mission is cleared.
- Seeded route generation remains owned by `MissionRunState.begin_mission(mission, forced_seed)`; forced seeds are not silently changed after validation failure.
- Existing `MissionRunState.finish_mission` remains the single idempotent payout resolver: base contract pay is success-only, while eligible side earnings remain outside the contract payout.

**Implemented in the hazard/timer pass:** high-risk encounters apply periodic environmental exposure damage through the normal ship damage pipeline; required SURVIVE objectives use a countdown and complete if the pilot remains alive; required ESCAPE and INTERCEPT objectives have deadlines, with interception completing when the encounter is cleared in time. Missed deadlines fail the contract. Timers use `deadline_seconds` or a default when omitted. Authored test contracts and Godot playtesting remain. Shared cargo variant rules now cover standard, fragile, bulk, and valuable contracts in the HQ catalog; balance tuning and engine-level verification remain. Do not treat adding an objective definition as proof that its in-flight mechanic has been implemented.

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
- **Shared mission state:** `res://scripts/missions/mission_run_state.gd`, registered as the `MissionRunState` autoload.
- **Procedural route generation:** `res://scripts/missions/route_generator.gd`. Mission resources configure `layer_node_counts`, `branch_chance`, `risk_bias`, and optional `fixed_beats` in `res://scripts/missions/mission_definition.gd`.
- **Route-map presentation and interaction:** `res://scripts/missions/route_map.gd` and `res://scenes/route_map.tscn`.
- **Flight stage:** `res://scripts/missions/mission_flight.gd`.
- **Route node data:** `res://scripts/missions/mission_route_node.gd`.
- **Save format:** The save location and persistence implementation should be documented after confirming the current save/load path; do not assume that runtime mission state is the save system.
- **Physics note:** `project.godot` enables Jolt for 3D physics. The game is 2D, so this setting is not evidence of a 3D gameplay requirement and can be reviewed separately.
- **Windows rendering driver:** Direct3D 12.

## Procedural generation reference

Reference: [Video on procedural generation and game design](https://youtu.be/442FHQ-rymM?si=KcyazgQl7kRDs7zw).

The design takeaway is simple: **protect what matters; randomize what doesn't**. A route generator should not merely scatter random encounters. It should create a coherent delivery journey whose connectivity, risk, rewards, and pacing remain within tested bounds. Seeded generation makes results reproducible, while multi-seed testing helps expose edge cases. Traditional procedural generation uses rules, algorithms, weights, constraints, and validation; it does not require generative AI.

For SpaceDelivery, mission resources define the route's layer shape, branching likelihood, and risk bias. Optional `fixed_beats` are encounter templates assigned to a layer depth and lane; the generator preserves their authored title, description, encounter profile, risk, and bonus while generating node IDs and connections. `layer_node_counts` defines the number of nodes in each layer, with a single start and destination. The HQ validates these generator settings and logs actionable errors without hiding a contract because of obsolete route-graph data. Each node should have a reason to exist, route flags should let decisions matter later, and a generated route should surprise the player without becoming arbitrary or unfair.


## Mission design catalogue: types, mechanics, and semantics

This section is the long-term design reference for contract variety. It records the intended mission vocabulary so future implementation can be planned without losing the wider design. These entries are **design options, not claims that the mechanics are already implemented**. The first release should implement a small, reusable set of objective mechanics and combine them into many contract variants.

### Design principle: the assignment is ordinary; the complication is not

SpaceDelivery takes tonal inspiration from workplace science-fiction comedy: a routine courier job becomes complicated by hostile customers, broken infrastructure, strange cargo, bureaucracy, and questionable company decisions. The universe, characters, dialogue, locations, and stories must remain original.

Mission variety should come primarily from combining reusable objectives, cargo rules, route nodes, encounter templates, complications, and consequences. A mission type describes the contract's overall purpose; objective semantics define exactly what the player must do; route nodes define the stages along the journey. These are related but separate systems.

### A. Delivery and transport

| ID | Mission type | Primary objective | Distinct rules |
| --- | --- | --- | --- |
| DEL-01 | Standard delivery | Deliver a shipment | Cargo integrity, destination validation, payout |
| DEL-02 | Fragile delivery | Deliver above a minimum integrity | Damage-sensitive reward and failure threshold |
| DEL-03 | Bulk freight | Transport oversized cargo | Cargo-capacity eligibility gate |
| DEL-04 | High-value delivery | Deliver valuable cargo | Higher reward and potentially stronger enemy interest |
| DEL-05 | Perishable delivery | Deliver before expiry | Deadline or cargo-condition decay |
| DEL-06 | Live-cargo transport | Keep a living specimen alive | Survival threshold and fragile return cargo |
| DEL-07 | Passenger transport | Transport passengers safely | Passenger survival and capacity rules |
| DEL-08 | Secure transport | Deliver restricted or dangerous cargo | Inspection, interception, or containment rules |
| DEL-09 | Multi-stop delivery | Deliver to several destinations | Ordered stops and partial-reward rules |
| DEL-10 | Split shipment | Deliver separate parcels to recipients | Cargo allocation and per-recipient checks |
| DEL-11 | Emergency supply run | Deliver essential goods urgently | Deadline and failure consequences |
| DEL-12 | Smuggling contract | Deliver concealed or prohibited cargo | Detection risk and penalties |
| DEL-13 | Contract relay | Transfer cargo to another ship or station | Handover objective and possible ambush |
| DEL-14 | Return shipment | Carry goods back to the original client | Return leg and delivery validation |
| DEL-15 | Blind delivery | Find and reach an initially unknown destination | Destination reveal and route discovery |

Shared mechanics: cargo capacity, cargo integrity, destination arrival, delivery validation, contract settlement, optional bonuses, and penalties.

### B. Retrieval, rescue, and recovery

| ID | Mission type | Primary objective | Distinct rules |
| --- | --- | --- | --- |
| REC-01 | Cargo retrieval | Collect designated cargo | Pickup and objective tracking |
| REC-02 | Stolen cargo recovery | Recover cargo carried by raiders | Cargo-carrying enemy and recovery drop |
| REC-03 | Search and rescue | Locate and recover a missing target | Search points and target discovery |
| REC-04 | Escape-pod recovery | Collect survivors or pods | Multiple pickups and optional deadline |
| REC-05 | Personnel extraction | Reach and extract a stranded person | Extraction point and survival condition |
| REC-06 | Live specimen capture | Acquire a living target | Target condition and safe return |
| REC-07 | Artifact recovery | Retrieve a unique object | Protected site, guardian, or hazard |
| REC-08 | Wreck salvage | Recover materials from a wreck | Multiple pickups and salvage value |
| REC-09 | Black-box recovery | Retrieve flight records | Specific objective item and investigation reward |
| REC-10 | Missing-ship recovery | Locate a lost ship or remains | Search route and target identification |
| REC-11 | Prisoner extraction | Free and recover a captive | Hostile location and pressured escape |
| REC-12 | Emergency evacuation | Collect people from a threatened area | Capacity and escalating danger |
| REC-13 | Component recovery | Recover a repair-critical component | Required item identity |
| REC-14 | Stolen-technology recovery | Recover a valuable device or prototype | Pursuit, guards, or secure location |

**Important rule:** collecting an object does not automatically complete a recovery contract. If the assignment requires bringing it home, the player must survive the return journey and pass the delivery check.

### C. Combat and target elimination

| ID | Mission type | Primary objective | Distinct rules |
| --- | --- | --- | --- |
| COM-01 | Elimination | Defeat a designated enemy group | Required kill count or all-required-hostiles condition |
| COM-02 | Bounty hunt | Defeat or capture a named target | Target identity and bounty reward |
| COM-03 | Elite hunt | Defeat one powerful enemy | Elite modifiers, target marker, special reward |
| COM-04 | Pirate interception | Stop raiders carrying stolen goods | Cargo recovery and possible target escape |
| COM-05 | Convoy attack | Disable a hostile transport convoy | Multiple targets and priority selection |
| COM-06 | Convoy defence | Protect friendly transports | Ally survival and attacker waves |
| COM-07 | Boss encounter | Defeat a major hostile threat | Boss phases and special attack patterns |
| COM-08 | Enemy blockade | Break through a defensive line | Waves and a protected exit |
| COM-09 | Stronghold assault | Neutralize a defended installation | Staged encounters and defensive structures |
| COM-10 | Reinforcement interception | Stop reinforcements arriving | Deadline and escalating opposition |
| COM-11 | Swarm suppression | Defeat or survive large numbers of enemies | Waves and spawning pressure |
| COM-12 | Capital-ship engagement | Disable a large hostile vessel | Large health pool or subsystem objectives |
| COM-13 | Wanted-target capture | Disable and secure a target | Capture condition rather than ordinary destruction |
| COM-14 | Retaliation | Attack a faction linked to a prior incident | Campaign flags and faction hostility |

With the current auto-fire combat model, most combat variants should change objective conditions, enemy composition, target priority, and encounter pacing rather than require a new shooting system.

### D. Hazards, survival, and disaster response

| ID | Mission type | Primary objective | Distinct rules |
| --- | --- | --- | --- |
| HAZ-01 | Hazard-zone crossing | Reach an exit through a dangerous area | Continuous environmental damage |
| HAZ-02 | Radiation exposure | Cross a radiation field | Exposure accumulation or periodic damage |
| HAZ-03 | Heat-zone traversal | Cross a high-temperature region | Hull pressure and limited safe time |
| HAZ-04 | Asteroid navigation | Survive a debris field | Collision or periodic hazard damage |
| HAZ-05 | Timed escape | Reach safety before time expires | Countdown and failure trigger |
| HAZ-06 | Stranded survival | Survive until rescue or reach safety | Resource pressure or escalating encounters |
| HAZ-07 | Ship malfunction | Complete work with impaired systems | Restricted weapons, movement, or shields |
| HAZ-08 | Hull-breach emergency | Survive a critical ship condition | Damage pressure and repair/escape objective |
| HAZ-09 | Disaster prevention | Stop a catastrophic event | Countdown and specific objective |
| HAZ-10 | Hazard containment | Prevent a threat from spreading | Timed containment objective |
| HAZ-11 | Debris clearance | Clear dangerous objects from a route | Destructible obstacles or targetable hazards |
| HAZ-12 | Rescue under fire | Recover an objective as danger escalates | Pickup plus survival pressure |
| HAZ-13 | Environmental extraction | Retrieve an objective from a hostile environment | Exposure management and cargo acquisition |
| HAZ-14 | Emergency-landing recovery | Escape a compromised area after an incident | Restricted capabilities and recovery objective |

A hazard mission must change how long the player can safely remain in an area or how they choose their path. It should not merely be an ordinary combat room with different scenery.

### E. Interception, pursuit, and races

| ID | Mission type | Primary objective | Distinct rules |
| --- | --- | --- | --- |
| PUR-01 | Timed interception | Destroy or disable a target before a deadline | Countdown and target condition |
| PUR-02 | Target pursuit | Catch a moving target | Escape timer or pursuit progress |
| PUR-03 | Racing contract | Reach a destination before a rival | Completion-time comparison |
| PUR-04 | Courier interception | Stop a competing courier | Rival progress and contract competition |
| PUR-05 | Incoming-threat interception | Stop an object before impact | Impact timer and threat health |
| PUR-06 | Convoy interception | Catch a moving group | Multiple targets and escape conditions |
| PUR-07 | Escort interception | Protect an ally from pursuers | Ally condition and attacker suppression |
| PUR-08 | Emergency rendezvous | Reach a location before a critical event | Deadline and rendezvous radius |
| PUR-09 | Chase and recover | Catch a thief and recover stolen cargo | Pursuit followed by collection |
| PUR-10 | Escape pursuit | Reach safety while enemies chase | Escape condition and survival |
| PUR-11 | Timed delivery | Deliver before contract expiry | Deadline and late penalty |
| PUR-12 | Signal interception | Reach or disable a transmitting target | Signal tracking and confirmation |

Deadlines must be achievable with reasonable equipment and ordinary play, not require a perfect build or lucky encounter rolls.

### F. Exploration, investigation, and anomalies

| ID | Mission type | Primary objective | Distinct rules |
| --- | --- | --- | --- |
| EXP-01 | Uncharted exploration | Reach and explore an unknown location | Discovery nodes and unknown encounters |
| EXP-02 | Reconnaissance | Survey a designated area | Scan or visit required locations |
| EXP-03 | Anomaly investigation | Investigate an unusual phenomenon | Anomaly effects and special objective |
| EXP-04 | Signal investigation | Track a distress or unknown signal | Signal source discovery |
| EXP-05 | Scientific expedition | Gather samples or research data | Collection requirements |
| EXP-06 | Site survey | Inspect several locations | Ordered location objectives |
| EXP-07 | Missing-vessel investigation | Discover what happened to a lost ship | Search, wreck, and signal objectives |
| EXP-08 | Evidence recovery | Retrieve evidence from a hostile location | Specific pickup and escape condition |
| EXP-09 | Artifact survey | Locate and examine a rare object | Discovery before recovery |
| EXP-10 | Restricted-area investigation | Investigate a controlled location | Detection risk or hostile response |
| EXP-11 | Cosmic-anomaly expedition | Enter and survive an abnormal region | Altered encounter or hazard rules |
| EXP-12 | First-contact assignment | Reach an unknown civilization or faction | Delivery, diplomacy, or hostile response |
| EXP-13 | Multi-stage investigation | Complete related objectives in sequence | Objective chain and conditional branches |
| EXP-14 | Unknown-destination delivery | Discover the destination during the run | Delayed route reveal |

Investigation can be staged without a large detective system. For example, finding a distress signal unlocks a wreck node, and reaching the wreck reveals a recovery objective.

### G. Stealth, infiltration, and sabotage

| ID | Mission type | Primary objective | Distinct rules |
| --- | --- | --- | --- |
| INF-01 | Covert delivery | Deliver without attracting attention | Detection meter or alert threshold |
| INF-02 | Facility infiltration | Enter a restricted location | Security encounters and access conditions |
| INF-03 | Data theft | Retrieve information from a target | Data pickup or timed interaction |
| INF-04 | Sabotage | Disable a designated system | Targeted destruction or interaction |
| INF-05 | Communications disruption | Disable an enemy signal source | Objective structure or target health |
| INF-06 | Prison break | Free a captive and escape | Rescue interaction and extraction |
| INF-07 | Security shutdown | Disable a defensive system | Sequential objectives |
| INF-08 | Contraband extraction | Recover restricted cargo and escape | Detection risk and cargo retention |
| INF-09 | Decoy operation | Draw enemies away from another objective | Survival timer or distraction target |
| INF-10 | Black-site recovery | Retrieve an asset from a secret facility | Elite defenders and restricted objective |
| INF-11 | Hostile-system disruption | Disable an installation's capabilities | Multiple system objectives |
| INF-12 | Evidence and escape | Recover evidence without being trapped | Pickup and escape deadline |

For an early version, stealth can be represented by an alert value, route flags, escalating encounters, and a timer after objective acquisition. Full stealth AI is not a prerequisite.

### H. Company, faction, and campaign assignments

These are not all flight modes. Some belong on the HQ mission board or in between-flight event nodes.

| ID | Mission/event | Primary objective | Distinct rules |
| --- | --- | --- | --- |
| CAM-01 | Rival courier contract | Beat a competing delivery company | Rival progress and reputation effects |
| CAM-02 | Corporate recovery | Recover company property or funds | Asset retrieval and financial consequences |
| CAM-03 | Faction assistance | Complete a job for a faction | Reputation and standing |
| CAM-04 | Faction retaliation | Respond to a previous hostile action | Persistent hostility or special encounters |
| CAM-05 | Diplomatic transport | Deliver a diplomat or sensitive cargo | Passenger survival and faction consequences |
| CAM-06 | Negotiated settlement | Complete a task to resolve a dispute | Contract choices and outcome flags |
| CAM-07 | Corporate inspection | Satisfy an inspection or recover records | HQ event or optional retrieval flight |
| CAM-08 | Contract dispute | Choose how to respond to a client dispute | Reward, reputation, or future access |
| CAM-09 | Emergency company assignment | Respond to a threat to company operations | Priority contract and deadline |
| CAM-10 | Crew-related assignment | Resolve a crew problem | Crew or ship modifier |
| CAM-11 | Resource procurement | Acquire operational supplies | Credit expenditure or resource pickups |
| CAM-12 | Company expansion | Complete a milestone | Unlock an upgrade, route, or contract tier |
| CAM-13 | Multi-contract campaign | Complete connected assignments | Persistent campaign flags |
| CAM-14 | Major crisis event | Resolve a sector-wide or company-wide threat | Multi-stage objectives and branching outcomes |

Company events should not automatically become new flight mechanics. Use them to change choices, rewards, reputation, available contracts, and later mission conditions.

### Objective semantics: the verbs the game understands

Mission types are contract labels. Objective verbs are reusable, testable rules that define completion.

| Objective verb | Meaning | Completion condition |
| --- | --- | --- |
| DELIVER | Deliver a required shipment or item | Correct destination reached with required cargo |
| DESTROY | Destroy a designated target | Target health reaches zero |
| ELIMINATE_GROUP | Defeat a designated group | All required enemies defeated |
| SURVIVE | Stay alive for a duration | Timer expires while player remains alive |
| REACH | Enter a designated location | Objective-area condition is met |
| COLLECT | Acquire an object or quantity | Required pickups collected |
| RESCUE | Recover a person or living target | Target collected or extracted |
| ESCORT | Protect an ally or convoy | Ally survives or reaches its destination |
| INTERCEPT | Stop a target before a deadline | Target neutralized before the deadline |
| INVESTIGATE | Inspect or discover an objective | Required scan, discovery, or evidence condition met |
| INTERACT | Activate a device or complete an interaction | Interaction registered |
| ESCAPE | Leave a dangerous location | Exit reached before failure conditions |
| DEFEND | Protect a target or location | Protected target survives the required encounter |
| DISABLE | Render a system inoperative without necessarily destroying it | System enters its disabled state |
| DELIVER_ALL | Deliver multiple required shipments | Every required delivery is validated |
| COMPLETE_SEQUENCE | Finish ordered objectives | Every mandatory stage is completed |

Objectives may be combined. A rescue can require REACH, COLLECT, and ESCAPE; an interception can require DESTROY before a timer expires. Optional objectives must remain distinct from mandatory ones. Defeating every enemy must not be required if the contract only asks the player to recover cargo and return safely.

### Objective and mission-run states

Each objective has a predictable lifecycle:

- **LOCKED:** prerequisites have not been met.
- **AVAILABLE:** the objective can be pursued.
- **ACTIVE:** the objective is currently being pursued.
- **COMPLETED:** its success conditions are satisfied.
- **FAILED:** a required condition can no longer be met.

The overall contract has a separate lifecycle:

- **AVAILABLE:** offered on the board.
- **SELECTED:** chosen at HQ.
- **IN_PROGRESS:** flight has started.
- **OBJECTIVE_COMPLETE:** mandatory in-flight objectives are done, but delivery or extraction may remain.
- **DELIVERED:** required delivery or extraction is confirmed.
- **SUCCEEDED:** contract requirements have been met.
- **FAILED:** a failure condition has triggered.
- **ABANDONED:** the player deliberately leaves the contract, if this is supported.
- **SETTLED:** rewards and consequences have been calculated.

Not every mission needs every state. A bounty may finish when its target is destroyed; a recovery job may remain active until the recovered item reaches its destination. **Objective completion, successful delivery, and financial settlement are separate events.** The resolver must settle a run exactly once.

### Cargo semantics

| Cargo tag | Meaning and effect |
| --- | --- |
| STANDARD | Ordinary shipment with normal capacity and integrity rules |
| FRAGILE | Damage has a greater impact on condition, reward, or success |
| LIVE | Living specimen must remain above a survival threshold |
| PASSENGERS | People require survival and capacity checks |
| HAZARDOUS | Dangerous material may trigger hazards or containment rules |
| VALUABLE | High-value shipment with larger reward and potentially higher risk |
| PERISHABLE | Cargo deteriorates or expires over time |
| CONTRABAND | Restricted cargo creates detection and penalty rules |
| BULK | Large shipment requires sufficient hold capacity |
| QUEST_ITEM | Unique objective item with identity and return conditions |
| STOLEN | Recovered cargo needs ownership and recovery validation |
| SALVAGE | Recovered material may be mandatory or optional and can be sold |

Cargo condition is independent from ship hull and shields. Do not damage cargo on every ship hit by default. Cargo damage should come from explicit mission rules, relevant attacks, or defined hazard effects.

Possible delivery outcomes include full reward for intact cargo, reduced reward for damaged cargo, contract failure below a required integrity threshold, and no delivery bonus when the destination is never reached. Eligible side earnings remain governed by the existing failure and settlement rules.

### Route-node semantics

A route node represents a stage of the journey, not necessarily a whole mission type.

| Node type | Purpose | Possible contents |
| --- | --- | --- |
| START | Begin the contract | Initial conditions and briefing |
| COMBAT | Resolve an encounter | Enemy groups, elites, or waves |
| HAZARD | Navigate environmental danger | Heat, radiation, debris |
| PICKUP | Collect an objective | Cargo, passengers, artifacts |
| OBJECTIVE | Complete a mission task | Destroy, scan, activate, rescue |
| SERVICE | Repair or resupply | Hull repair and shield restoration |
| CHOICE | Choose a route or accept a risk | Shortcut, detour, optional reward |
| EVENT | Trigger a contract event | Inspection, distress call, ambush |
| ELITE | Face a designated strong enemy | Bounty, guardian, captain |
| EXIT | Leave the route or finish the journey | Extraction, return, or next stage |

For example, a delivery can contain a start, a hostile patrol, a choice between a risky shortcut and a safer route, a debris hazard, an optional service stop, and a destination. The route graph describes the journey; the objective system describes what must be accomplished.

**Route invariants:**

1. Every generated route has a reachable destination.
2. Every reachable non-terminal node has at least one valid forward exit.
3. Where meaningful alternatives exist, branches should be distinct in risk, recovery, rewards, or information.
4. Do not require backtracking unless a mission explicitly depends on it.
5. Optional nodes may offer loot, services, or side objectives without becoming mandatory.
6. Use a seed so a route can be reproduced for testing.
7. Mission rules and prior events may influence eligible nodes.
8. Reaching the exit does not itself prove mission success; objectives and cargo conditions must be validated.
9. Preserve the current committed route rules: progressive reveal, forward-only progression, guaranteed exits, distinct siblings where alternatives exist, service stops that repair 35% of maximum hull and restore shields without granting a direct credit bonus, and early risk/pacing constraints documented above.

### Complication semantics

Complications alter a mission's conditions without requiring a new mission implementation.

| Complication | Rule | Example |
| --- | --- | --- |
| Hostile territory | Select encounters from a hostile faction roster | Delivery through pirate-controlled space |
| Ambush | Add enemies or start under pressure | Routine shipment is intercepted |
| Cargo damage risk | Specific attacks or hazards can harm cargo | Fragile parcel through debris |
| Deadline | An objective must be completed before time expires | Stop a ship before it escapes |
| Pursuit | Enemies pressure the player until an exit condition | Recover cargo and flee |
| Reinforcements | A trigger adds another enemy group | Destroying a relay calls backup |
| Route alert | A choice increases later danger | Shortcut alerts a patrol |
| Stowaway | A recovered object or passenger adds a surprise | A pod contains an unwanted visitor |
| Equipment failure | A ship capability is restricted | Shields or weapons malfunction |
| Environmental exposure | Staying in a zone causes damage or buildup | Radiation field |
| Target escape | A target can escape if not stopped | Courier carrying stolen technology |
| Protected objective | An ally or object must survive | Defend a transport |
| Restricted weapons | Some attacks or systems are unavailable | Sensitive cargo job |
| Unstable cargo | Cargo condition worsens under defined circumstances | Volatile material |
| False destination | Discovery changes the destination | Signal redirects the contract |
| Rival interference | A competitor changes the objective or reward | Rival attempts the same delivery |
| Optional detour | Side route trades risk for extra earnings | Salvage field |
| Destination trap | Arrival triggers danger | Bulk shipment is a setup |
| Faction retaliation | Previous action changes hostility | Earlier attack triggers later pressure |
| Bonus opportunity | A secondary condition earns extra reward | Finish without cargo damage |

Complications should be data-driven wherever possible. HOSTILE_TERRITORY should influence encounter selection, for example, rather than duplicate the combat implementation.

### Route flags and mission memory

A mission run records facts that later nodes, events, and debriefs can inspect. Example flags:

- `cargo_damaged`
- `cargo_stolen`
- `route_alerted`
- `optional_detour_taken`
- `distress_signal_answered`
- `elite_defeated`
- `service_stop_used`
- `objective_recovered`
- `deadline_missed`
- `rival_encountered`

Example: the player takes a shortcut, setting `route_alerted = true`; a later node checks the flag and adds reinforcements; the debrief explains the resulting pressure. A flag records what happened; it is not itself the consequence system.

### Outcomes, payout, and settlement

| Outcome | Definition | Financial result |
| --- | --- | --- |
| Full success | All mandatory objectives and contract conditions met | Base payout plus earned bonuses |
| Qualified success | Contract completed but quality conditions missed | Reduced payout or lost bonuses |
| Partial success | Some recoverable value secured without completing the main contract | Only explicitly permitted rewards |
| Failure | Mandatory condition becomes impossible or the ship is destroyed | No successful-delivery payout; eligible side earnings may remain |
| Abandonment | Player deliberately leaves, if supported | Apply explicitly defined abandonment rules |

Use a single resolver to produce one final outcome and settle the run once. The reward model is:

`Reward = Base payout + Side earnings + Optional bonuses + Quality bonus - Penalties`

- **Base payout:** at-risk contract reward, paid only on successful delivery or the contract's explicitly defined success condition.
- **Side earnings:** eligible encounter earnings retained under the existing rules, including on failure.
- **Optional bonuses:** payment for optional objectives.
- **Quality bonus:** performance reward where applicable.
- **Penalties:** cargo damage, lateness, or contract-specific costs.

For SpaceDelivery, preserve the existing rule: successful delivery determines the base payout, while eligible side earnings may survive a failed run. Salvage items are retained in the salvage hold and converted to credits exactly once on return to HQ, according to the current salvage rules.

Useful debrief metrics include cargo integrity, relevant completion time, mandatory and optional objectives, protected targets, recovered cargo, ship survival, route risks, penalties, contract payout, side earnings, salvage value, and campaign consequences. Only metrics relevant to the contract should affect the reward.

### Contract-definition data

A contract definition should be data rather than hardcoded into the flight controller. It should describe:

| Field | Purpose |
| --- | --- |
| `mission_id` | Unique contract identifier |
| `title` / `description` | Mission-board text |
| `mission_type` | Primary archetype |
| `objectives` | Mandatory and optional objectives |
| `cargo_rules` | Cargo type, capacity, condition, and thresholds |
| `destination` | Final destination or extraction point |
| `route_template` | Route graph/template and generation rules |
| `encounter_pool` | Eligible encounter templates |
| `complications` | Compatible mission modifiers |
| `deadline` | Optional mission or objective timer |
| `base_reward` | Successful-completion payout |
| `bonus_rules` | Optional and performance rewards |
| `failure_rules` | Conditions that fail the contract |
| `prerequisites` | Requirements for offering the contract |
| `outcome_flags` | Facts recorded for future events |
| `forced_seed` | Optional deterministic seed for replay/testing |

The definition describes the reusable contract. The mission-run state stores changing data for one attempt: current node and objective, objective outcomes, cargo and integrity, elapsed time and active timers, route flags, side earnings, final outcome, and settlement status.

### Mission board and player experience

Before committing, the player should be able to see:

- Contract name and type, client, and destination.
- Main objective and any return/extraction requirement.
- Cargo type, capacity requirement, and condition threshold.
- Expected threat level, known hazards, and complications.
- Base reward, potential bonuses, and penalties.
- Required ship, reputation, or progression unlocks.

Selecting a contract reveals its details but does not launch the flight. **Deliver remains disabled until a valid mission is selected.** Test Flight remains a separate activity.

After a run, the company report should show the outcome, objective status, cargo condition and losses, base reward, side earnings, bonuses, penalties, and campaign/faction consequences. Explain why the reward changed; the player should never need to guess.

### Mission generation and validation

Generate contracts by composing compatible, authored parts:

1. Select a mission archetype.
2. Generate mandatory and optional objectives.
3. Assign cargo and capacity requirements where relevant.
4. Select a compatible route template.
5. Choose eligible encounter and hazard templates.
6. Add compatible complications.
7. Add optional objectives and reward rules.
8. Validate graph connectivity, objective feasibility, exits, and settlement rules.
9. Store the seed and mission definition used for the run.

Reject incoherent combinations. A live-specimen job needs a collection method and a viable return path. An interception must place its target in the route and provide a valid deadline. A delivery cannot require more cargo capacity than the contract permits. Every mandatory objective must be reachable and completable; optional rewards must not accidentally become mandatory.

Use controlled route patterns rather than unconstrained random graphs. Validate batches of seeds for reachability, dead ends, branch availability, encounter repetition, risk pacing, and reward distribution. Automated validation catches structural defects; playtesting is still required to judge whether the mission feels fair and fun. Randomness should create variety within tested rules, not decide whether the mission makes sense.

### Recommended implementation order

Build reusable mechanics before trying to implement every catalogue entry as a bespoke system:

1. **Objective framework and completion validation:** standardize objective identity, required/optional status, state transitions, and success conditions.
2. **Hazard zones and survival timers:** add a genuinely different source of pressure beyond combat.
3. **Pickup and return objectives:** unlock cargo retrieval, live-cargo transport, rescue, escape-pod recovery, and evacuation.
4. **Timed interception and target tracking:** add deadline-driven objectives and escaping targets.
5. **Encounter pools and elite targets:** enable faction variants, bounty hunts, and stronger enemies mostly through data.
6. **Cargo variants and capacity gates:** implement perishable, live, fragile, hazardous, bulk, and restricted cargo rules as needed.
7. **Complication and route-flag evaluation:** let earlier decisions change later encounters and debriefs.
8. **Investigation and interaction objectives:** add scans, devices, evidence, and sequential objectives.
9. **Stealth abstractions and rival progress:** use alert, timers, and competition state before considering more complex AI.
10. **Campaign and HQ events:** add reputation, faction consequences, company crises, and multi-contract chains.

The first playable slice should not attempt all catalogue entries. Start with delivery, hazard crossing, pickup-and-return, timed interception, and elite hunt. Those mechanics create a foundation that can express many of the other mission types through data and combinations.

# SpaceDelivery

**SpaceDelivery** is a space-delivery incremental game with procedurally generated routes, automatic weapon systems, and a large skill tree. Take contracts from different clients, fly through a branching network of space encounters, deliver the cargo, and invest your earnings in a growing ship. There is no prestige and no full reset, just steady growth.

The core fantasy is simple: take a contract, pilot your ship through a dangerous route, deliver the cargo, collect your fee and any loot you find, then reinvest your rewards to take on bigger jobs.

This README documents the current design vision. It describes planned concepts as well as the intended core loop; it does not imply that every feature is already implemented.

## Design pillars

1. **The cargo is the reason for everything.** Every mission exists because there is a package to deliver, and the cargo is the large payout the player stands to win or lose.
2. **Incremental progression, not resets.** Growth comes from a large skill tree and ship upgrades. The player never has to restart everything for a small power boost.
3. **Every mission is a fresh route.** Procedural, node-based routes make each delivery a different journey, like a small dungeon.
4. **Short, repeatable missions.** Each encounter is a quick stage, so "one more delivery" is always easy.
5. **Risk and reward are the player's choice.** Players choose the contract, the client, and the route, and the harder choices pay more.

## Core gameplay loop

1. **Choose a delivery contract.** Review the cargo, client, destination, base fee, hazard level, and optional rewards. Contracts come from different clients depending on the package.
2. **Prepare your ship.** Use your skill tree upgrades and installed modules. Hull size affects the cargo you can carry.
3. **Travel a procedural route.** Pick your path through a branching network of encounter nodes, choosing between safer routes and riskier, more rewarding ones.
4. **Play each encounter.** Every node is a short stage of about 60-90 seconds, such as defending against bandits, escorting a ship, or landing at a base. The player pilots the ship while weapons fire automatically.
5. **Deliver or fail.** Reach the destination to collect the contract payout. Fail, and the contract is lost.
6. **Collect and reinvest.** Keep any credits, salvage, and rare drops earned along the way, spend them in the skill tree, and take on the next contract.

## Cargo and the contract payout

Cargo is the amount of money the player can earn from a mission. The large contract payout is the main prize, and it is only collected by delivering the cargo successfully.

Players also earn money along the way from side activities such as defeating bandits, salvaging wrecks, and finding rare drops. This money belongs to the player immediately, whether or not the delivery succeeds.

Cargo types add different challenges:

- **Standard parcels and supplies:** Low-risk introductory jobs.
- **Bulk and oversized freight:** Larger shipments that require more cargo capacity.
- **Fragile cargo:** Has its own **integrity bar**. Damage to the cargo reduces the payout and can destroy the shipment if the bar empties.
- **Hazardous cargo:** Volatile or dangerous freight that pays more but causes extra damage or other problems if the ship is hit.
- **Time-sensitive shipments:** Earn a bonus for arriving quickly.
- **High-value or classified cargo:** More lucrative jobs that can attract stronger enemies.
- **Medical and emergency supplies:** Special contracts with time or survival-related objectives.
- **Wanted or contraband cargo:** Risky jobs with high rewards and possible bounty-related encounters.
- **Rare and mysterious cargo:** Unusual shipments that can introduce unique events or threats.

These are design possibilities; the final cargo list, requirements, and unlock thresholds remain to be defined.

### Jettisoning cargo (experimental)

The player may be able to dump the cargo to escape a lost fight. This gives up the contract payout but lets the ship survive with its side earnings. It is uncertain how often players will use it, so it should be implemented simply and evaluated through playtesting.

## Clients and reputation

Players choose which contracts to accept and who to work for, depending on the package. Different clients can offer different cargo types, rewards, and risks.

Successful deliveries earn reputation. Higher reputation unlocks new contract tiers, cargo types, and more dangerous opportunities. The game does not aim to simulate a dynamic galactic economy; contract fees and item values are predefined.

## Procedural routes and encounters

Missions use a branching, node-based network of space encounters, like a procedural dungeon. A route has several locations, and the player's choice at each step decides which locations they can reach next.

### Encounter stages

Each node plays as a short stage lasting roughly 60-90 seconds. No encounter should take longer than 5 minutes. Possible stage types include:

- **Defend:** Protect the ship or cargo against waves of bandits, drones, or mercenaries.
- **Escort:** Protect another ship while it travels through a hazard.
- **Base / landing site:** A safe location where the player can land to refill ship HP and shield.
- **Salvage:** Wrecks, derelict freighters, probes, and abandoned stations that offer loot.
- **Special events:** Distress calls, anomalies, rescue opportunities, and suspicious discoveries.
- **Elite encounters:** More dangerous fights with better loot chances.
- **Destination:** The planet, station, freight ship, or other location where the delivery is completed.

### Route risk

Route choice is a risk-versus-reward decision. Safer routes are easier but pay less, and dangerous routes offer higher rewards but tougher encounters. The fast and slow routes are different risk levels rather than a separate time system.

## Skill tree and progression

The skill tree is the main long-term progression system, in the style of incremental and idle games: a large, visible tree where players always have something to work toward. Completed missions grant credits, and credits are spent on upgrades that make the next missions easier or more profitable.

Design goals for the tree:

- Always show a few affordable upgrades, with a more expensive one just out of reach.
- Mix small incremental upgrades with milestone upgrades that change how the ship plays.
- Offer branches for different playstyles, such as cargo and economy, firepower, defence, and speed or utility.
- Reveal later branches gradually as the player progresses.
- Possibly unlock automation as a reward, such as route preferences or automatic contract selection.

There is no planned prestige system. Progress is permanent.

## Ship, modules, and loot

Players should be able to modify their ship to suit their preferred build rather than being locked into a fixed ship class. A ship designer is a planned feature, and a simple slot-based loadout is the likely first version.

Potential customisation systems include:

- **Hull size:** Increase cargo capacity to accept larger, more valuable deliveries.
- **Weapons:** Automatic weapons such as autocannons, lasers, missiles, or other systems.
- **Defence:** Shields, armor, repair systems, and defensive drones.
- **Engines and navigation:** Speed, route options, or mission efficiency.
- **Utility modules:** Cargo protection, loot scanners, salvage collectors, or other specialist effects.
- **Module slots and fitting limits:** Players choose between cargo space, firepower, durability, and utility.

Defeated enemies and discovered locations can reward more than credits:

- **Credits:** The main currency for purchases and upgrades.
- **Salvage:** A resource collected from wrecks and encounters.
- **Valuables:** Items such as gold, rare minerals, space rock, and artifacts with predefined base prices.
- **Ship modules:** Equipment that can be installed, swapped, or sold.

Loot should reflect its source where practical. Elite enemies can have better chances of dropping rare modules, and bosses may eventually offer unique rewards.

## Automatic combat and piloting

Combat is largely automatic: weapons and ship systems attack or defend based on their stats, modules, and skill tree upgrades. The player still controls the ship, so movement, positioning, and build choices matter. The exact control scheme and balance between movement and automation are still to be designed.

## Mission failure

A mission fails if the ship is destroyed or the cargo is lost, and the player loses the contract payout. Failure does not wipe long-term progress:

- Credits, salvage, and rare drops collected during the mission are kept.
- Skill tree upgrades, reputation, and unlocked content remain.
- The player returns to the upgrade screen and can start another contract.

A results screen shows the money earned, loot collected, and the lost contract. Optional systems such as insurance or delivery streaks could soften or reward the outcome, but they are not core requirements.

## Game modes

### Delivery Pilot

The primary game mode and first development target. The player pilots their own cargo ship, accepts contracts, chooses routes, fights hostile ships, gathers loot, and delivers packages for a fee. The campaign ends with a final major contract that completes the story.

### Escort Pilot

A planned second game mode unlocked after completing the Delivery Pilot campaign. The player protects a delivery ship or convoy instead of carrying the cargo.

### Delivery Tycoon

A possible future mode focused on managing a delivery company. This is a separate future direction, not part of the initial scope.

## Crew (planned)

Crew members can provide passive bonuses or specialist effects, such as a navigator, engineer, gunner, salvage specialist, or quartermaster. Crew is a later addition after the core loop works.

## Development scope and priorities

The first playable version should focus on the Delivery Pilot mode and prove that the core loop is fun.

Suggested development order:

1. **Vertical slice:** One contract, a short route of 3-4 nodes, a couple of encounter types, automatic combat, a payout, and a handful of skill tree upgrades to buy.
2. Build the contract board and delivery mission flow.
3. Expand the procedural route map with more encounter types.
4. Add cargo integrity, hazardous cargo, and cargo jettisoning.
5. Implement credits, salvage, valuables, and module drops.
6. Grow the skill tree and add a first version of the ship designer.
7. Add clients, reputation, cargo unlocks, and hull-size progression.
8. Add automation unlocks, crew, elite encounters, and richer events.
9. Add the campaign finale, then develop Escort Pilot.
10. Consider Delivery Tycoon only after the core experience is working well.

## Open design questions

- How long should a full mission be, in total? (Individual encounters are about 60-90 seconds.)
- What is the exact control scheme for piloting?
- Is the game 2D or 3D?
- How large do numbers grow in the late game?
- Which automation features should the skill tree unlock?
- How should the campaign finale work?

## Technical details

Confirmed from the project files:

- **Engine:** Godot 4.7 (Forward Plus renderer)
- **Physics:** Jolt Physics
- **Windows graphics driver:** Direct3D 12

The scripting language, 2D or 3D choice, startup scene, save format, and important gameplay scripts should be documented once confirmed.


## Procedural Generation Design Notes

Reference: [Video on procedural generation and game design](https://youtu.be/442FHQ-rymM?si=KcyazgQl7kRDs7zw). These notes summarize the transcript supplied for this project and apply its principles to SpaceDelivery's mission routes.

### Core principle: design possibilities, not just random content

Procedural generation is not simply choosing random rooms, enemies, or rewards. Randomness creates variety, but does not understand fun, fairness, pacing, or encounter quality. The designer's job is to define the rules and relationships that make the generated result feel intentional.

**Protect what matters; randomize what doesn't.** Guarantee essential mission structure and fair conditions, while allowing variation in encounters, route choices, rewards, and details. A generated mission should surprise the player without feeling arbitrary or breaking the game's logic.

### Rules, constraints, and validation

A useful procedural system combines:
- **Randomness and seeds:** provide variation; a fixed seed can reproduce a route for debugging and testing.
- **Design rules and constraints:** prevent invalid or undesirable outcomes.
- **Weights and probabilities:** make some events common, some rare, and some impossible in specific contexts.
- **Validation and testing:** check that generated routes are reachable, completable, and within intended limits.

For SpaceDelivery, critical constraints could include:
- Every route starts at the delivery contract and reaches the destination.
- Branches eventually merge into a shared final approach or destination.
- Every chosen path is connected and completable.
- Encounter difficulty and rewards fit the mission's intended risk.
- Essential resources or opportunities appear before challenges that require them.
- Avoid repeatedly stacking the most demanding encounters without recovery or variation.

### Generate an experience with pacing

A route should have rhythm rather than feel like a list of unrelated random encounters. Plan for pressure, relief, discovery, escalation, and payoff. Use encounter history to influence what can appear next. For example, after a demanding fight, a refuelling or rescue opportunity may be more appropriate than another extreme battle; repeated encounter types or high-value rewards can be temporarily less likely.

The system should consider **what kind of encounter belongs here**, not only which encounter to pick. Enemy combinations should account for space, range, movement pressure, synergy, and difficulty. Rewards should consider recent rewards and the player's condition, rather than relying only on fixed independent chances.

### Meaningful route choices and consequences

Branches should represent real trade-offs, such as:
- A safer route with lower rewards versus a dangerous route with better salvage.
- A station stop that restores the ship but costs time or credits.
- Helping a stranded ship for a possible ally or future benefit versus bypassing it.
- Investigating a derelict for loot while risking an ambush.

Where possible, a choice should influence later nodes or outcomes. Record simple route flags such as `rescued_crew`, `route_alerted`, `spent_credits`, `cargo_damaged`, or `earned_ally`. Later encounters, dialogue, available assistance, or rewards can react to these flags. This makes the route feel connected and gives choices a memory.

### Build from purpose to variation

For authored mission templates, decide the destination, mission theme, major turning point, and final challenge first. Then build the branches that lead there. Give each node a purpose in the overall journey. Randomize within that structure rather than generating an unconstrained tree of unrelated encounters.

A practical approach for SpaceDelivery is a **hybrid system**:
1. Define a coherent mission structure and required beats.
2. Generate or select branches from encounter options that fit each beat.
3. Apply constraints and weights based on mission theme, cargo, route risk, and recent events.
4. Validate reachability, pacing, and reward/difficulty bounds.
5. Use seeds and automated batches of generated routes to reproduce bugs and identify patterns, then playtest representative results.

### Traditional procedural generation versus AI

Traditional procedural generation uses developer-defined algorithms, rules, probabilities, and constraints; it does not inherently require machine learning or generative AI. The algorithm is machinery, not a substitute for design. AI may be combined with procedural systems, but SpaceDelivery can build a strong route generator using explicit, testable rules.

### Testing philosophy

One good generated route does not prove the generator works. Test many seeds and look for patterns: unreachable nodes, repeated encounters, difficulty spikes, rewards arriving too early or too late, long stretches without relief, and dominant or unrewarding choices. Automated checks can measure structural properties, but human playtesting is still needed to judge whether a route feels engaging.

**Guiding question:** Before asking “How do we randomize this?”, ask “What must remain true for this mission to feel like SpaceDelivery?” The route generator should encode those design promises, then use randomness to explore the space between them.

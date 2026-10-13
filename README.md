# SpaceDelivery

**SpaceDelivery** is a space-delivery roguelike incremental game with automatic weapon systems, procedural expeditions, ship building, and long-term progression. Start as an independent courier taking risky jobs across the universe, then grow into a legendary pilot with a ship built to suit your playstyle.

The core fantasy is simple: take a contract, pilot your ship through a dangerous route, deliver the cargo, collect your fee and any loot you find, then reinvest your rewards to take on bigger jobs.

This README documents the current design vision. It describes planned concepts as well as the intended core loop; it does not imply that every feature is already implemented.

## Core gameplay loop

1. **Choose a delivery contract.** Review the cargo, destination, base fee, deadline, hazard level, and optional rewards.
2. **Prepare your ship.** Choose installed modules and upgrades to fit the mission. Hull size affects the cargo you can carry.
3. **Explore a procedural route.** Travel through a branching network of encounter nodes, choosing between safer routes, dangerous shortcuts, combat, salvage, and special events.
4. **Pilot through danger.** The player controls the ship. Weapons and combat systems are intended to operate automatically, with ship movement and build choices giving the player ways to respond to threats.
5. **Deliver or fail.** Successful deliveries pay the contract fee and applicable bonuses. Failed deliveries end the mission and may trigger insurance compensation.
6. **Collect rewards.** Earn credits, salvage, valuables, and a chance to recover ship modules from enemies and encounters.
7. **Upgrade and try again.** Improve the ship, unlock more cargo and contracts through reputation, recruit crew, and build a stronger setup for the next expedition.

## Game modes

### Delivery Pilot

The primary game mode and first development target. The player pilots their own cargo ship, accepts delivery contracts, chooses routes through procedural expeditions, fights hostile ships, gathers loot, and delivers packages for a fee.

The long-term campaign focuses on reputation, increasingly valuable cargo, ship upgrades, module builds, and more dangerous routes.

### Escort Pilot

A planned second game mode unlocked after completing the Delivery Pilot campaign. Instead of carrying the cargo, the player protects a delivery ship or convoy. Rewards can include escort fees, combat loot, salvage, and bonuses for keeping the cargo ship safe.

### Delivery Tycoon

A possible future mode focused on managing a delivery company: acquiring ships, assigning pilots, selecting contracts, and building a delivery operation. This is a separate future direction, not part of the initial scope.

## Procedural expeditions

Missions use a branching, node-based space route rather than one continuous open-world journey. The player chooses which connected location to visit next, then pilots the ship through the resulting journey and encounters.

Possible node types include:

- **Combat:** Pirates, hostile drones, mercenaries, and elite enemies.
- **Salvage sites:** Wrecks, derelict freighters, probes, and abandoned stations.
- **Friendly locations:** Stations and other places that may offer repairs, resupply, crew, or services.
- **Special events:** Distress calls, anomalies, rescue opportunities, and suspicious discoveries.
- **Elite encounters:** More dangerous fights with better loot chances.
- **Destinations:** The planet, station, freight ship, or other location where the delivery must be completed.

Routes should offer meaningful trade-offs. A safer route may take longer or offer fewer rewards, while a dangerous shortcut may improve the payout and expose the ship to tougher encounters. Environmental hazards and route modifiers can add variety later.

## Contracts, cargo, and reputation

The player earns money by delivering cargo for a fee. The game does not aim to simulate a dynamic galactic economy. Salvage and valuables such as gold, rare minerals, space rock, and alien artifacts have base values that can be improved through upgrades or other progression systems.

Successful deliveries provide reputation. Higher reputation unlocks new contract tiers, cargo types, and more dangerous opportunities.

Possible cargo categories include:

- **Standard parcels and supplies:** Low-risk introductory jobs.
- **Bulk and oversized freight:** Larger shipments that require more cargo capacity.
- **Fragile cargo:** Deliver carefully to protect the cargo-integrity bonus.
- **Time-sensitive shipments:** Earn a bonus for arriving before the deadline.
- **High-value or classified cargo:** More lucrative jobs that can attract stronger enemies.
- **Medical and emergency supplies:** Special contracts with time or survival-related objectives.
- **Wanted or contraband cargo:** Risky jobs with high rewards and possible bounty-related encounters.
- **Rare and mysterious cargo:** Unusual shipments that can introduce unique events or threats.

These are design possibilities; the final cargo list, requirements, and unlock thresholds remain to be defined.

## Ship progression and ship designer

Players should be able to modify their ship to suit their preferred build rather than being locked into a fixed ship class. A ship designer is a planned feature that lets players customise their ship and its equipment.

Potential customisation systems include:

- **Hull size:** Increase cargo capacity to accept larger, more valuable deliveries. Larger hulls may cost more to maintain or attract greater danger.
- **Weapons:** Choose automatic weapons such as autocannons, lasers, missiles, or other weapon systems.
- **Defence:** Install shields, armor, repair systems, and defensive drones.
- **Engines and navigation:** Improve speed, route options, or mission efficiency.
- **Utility modules:** Add cargo protection, loot scanners, salvage collectors, or other specialist effects.
- **Module slots and fitting limits:** Make players choose between cargo space, firepower, durability, and utility.

Ship progression should support multiple viable builds. A fast, lightly equipped courier might excel at timed deliveries, while a heavier ship might carry valuable freight and survive longer fights.

## Modules, loot, and salvage

Defeated enemies and discovered locations can reward more than credits.

- **Credits:** The main currency for purchases and upgrades.
- **Salvage:** A resource collected from wrecks and encounters. It can be sold or used for upgrades or module-related systems.
- **Valuables:** Items such as gold, rare minerals, space rock, and artifacts with predefined base prices.
- **Ship modules:** Equipment that can be installed, swapped, or sold.

Loot should reflect the source where practical. For example, combat ships may drop weapon or defensive components, while derelict freighters may contain salvage and cargo-related equipment. Elite enemies can have better chances of dropping rare modules, and bosses may eventually offer unique rewards.

Permanent upgrades and modules serve different purposes. **Permanent upgrades** provide steady, lasting incremental growth. **Modules** change the ship's build and capabilities. Players should have ways to obtain useful equipment even when random drops are unlucky.

## Automatic combat and piloting

Combat is intended to be largely automatic: weapons and ship systems attack or defend based on their stats, modules, and effects. However, the player still controls the ship rather than simply watching a route resolve on its own. Piloting, route choices, ship configuration, and responses to encounters should all matter.

The exact control scheme, encounter pacing, and balance between movement and automation are still to be designed.

## Delivery rewards, bonuses, and insurance

Each contract has a base delivery fee. Successful missions can add bonuses based on factors such as:

- Arriving before a deadline.
- Delivering cargo without damage.
- Taking a dangerous route or completing optional encounters.
- Completing additional objectives.
- Maintaining a delivery streak.

Combat and exploration loot are separate from the delivery fee, so a risky detour can be worthwhile even when it does not directly improve the contract payout.

Insurance can soften the consequences of a failed delivery. Coverage may compensate for part of the lost contract value, with more advanced coverage available later. Insurance should reduce frustration without making deliberate failure profitable.

## Mission failure and persistent progression

A single delivery expedition is a mission or run. If the player fails the delivery, the mission ends and a results screen shows the money earned, bonuses, loot, losses, and any insurance compensation. The player can return to upgrades and try another mission.

The initial design favours **persistent progression rather than losing overall progress**:

- Purchased permanent upgrades remain.
- Reputation and unlocked content remain.
- Credits and retained loot remain according to the eventual reward rules.
- The failed contract ends.
- A delivery streak may break or decrease.
- Insurance can compensate for part of a failed contract.

The first version should not require players to discard their long-term progress when a mission fails.

## Crew and delivery streaks

Crew members are a planned progression system that can provide passive bonuses or specialist effects.

Possible roles include:

- **Navigator:** Improves route information or travel efficiency.
- **Engineer:** Helps repair the ship.
- **Gunner:** Improves weapon performance.
- **Salvage specialist:** Improves salvage collection or loot chances.
- **Quartermaster:** Improves delivery rewards.
- **Insurance specialist:** Reduces insurance costs or improves coverage.

A delivery streak rewards a series of successful missions. Streak milestones could improve payouts or unlock achievements and special contracts. Failure can break the streak without removing permanent upgrades or other long-term progress.

## Roguelike progression and future prestige

The initial progression model focuses on persistent upgrades, reputation unlocks, ship customisation, and increasingly dangerous contracts. Prestige is a possible later system, but it should not be designed until the core progression and reward pacing are understood.

If introduced, prestige should offer meaningful new options, such as new sectors, research branches, exclusive modules, or contract types, rather than simply resetting progress for a numerical bonus.

## Development scope and priorities

The first playable version should focus on the Delivery Pilot mode and prove the core mission loop before expanding into additional modes.

Suggested development order:

1. Build the contract board and delivery mission flow.
2. Create a branching procedural route map with combat, salvage, events, and destination nodes.
3. Implement ship piloting and automatic weapon combat.
4. Add delivery success/failure results, payout bonuses, and basic insurance.
5. Implement credits, salvage, valuables, and enemy module drops.
6. Add permanent upgrades, module inventory, and a first version of the ship designer.
7. Add reputation, cargo unlocks, hull-size progression, and delivery streaks.
8. Expand with crew, elite encounters, richer events, and balance improvements.
9. Develop Escort Pilot as a second mode after the Delivery Pilot campaign is complete.
10. Consider Delivery Tycoon and prestige only after the core experience is working well.

## Technical details

The game engine, scripting language, startup scene, save format, and important gameplay scripts should be documented once confirmed from the project files.

extends Resource
class_name RunProfile

## Data for one mission's gauntlet: route length, run clock, gates and pressure.
## generate_layout() turns this plus a seed into a concrete list of zones, gates
## and police checkpoints. Create one per mission and assign it to
## MissionDefinition.run_profile; a missing profile falls back to these defaults.

enum ZoneKind { RING, DRIFT, CUSTOMS, WRECKS, BLOCKADE }

const ZONE_NAMES: Dictionary = {
	ZoneKind.RING: "Orbital Debris Ring",
	ZoneKind.DRIFT: "Comet Drift",
	ZoneKind.CUSTOMS: "Customs Corridor",
	ZoneKind.WRECKS: "Wreck Field",
	ZoneKind.BLOCKADE: "Compliance Zone",
}
const GATE_NAMES: Array[String] = [
	"Unlicensed Toll Barrier",
	"Mandatory Inspection Platform",
	"Customs Cordon",
]
const FINAL_GATE_NAME: String = "Compliance Blockade"
const CHECKPOINT_LINES: Array[String] = [
	"ROUTINE INSPECTION. PLEASE HOLD STILL.",
	"YOUR CARGO HAS BEEN SELECTED FOR RANDOM REVIEW.",
	"INSPECTION FEE WAIVED, PENDING PAPERWORK.",
	"HAVE YOU CONSIDERED A SMALLER SHIP?",
]

@export_group("Route")
@export_range(60.0, 600.0, 5.0) var travel_seconds: float = 180.0
## Speed used to convert travel_seconds into distance. Starter courier is 220.
@export_range(100.0, 600.0, 5.0) var reference_speed: float = 220.0
## Total run clock. Must exceed travel_seconds so gate fights fit inside it.
@export_range(60.0, 1200.0, 5.0) var run_clock_seconds: float = 330.0
@export var start_position: Vector2 = Vector2(350.0, 0.0)
@export var planet_center: Vector2 = Vector2(120.0, 0.0)
@export var ring_radius: float = 1680.0
@export var ring_half_width: float = 170.0
@export_range(2, 6, 1) var gate_count: int = 4
## When true the map depends only on the mission, so players can learn it.
## When false it also depends on the run seed (replayable with a forced seed).
@export var lock_layout_to_mission: bool = false

@export_group("Gates")
@export var gate_base_hull: float = 300.0
@export var gate_growth: float = 1.9
@export_range(0.0, 2.0, 0.05) var gate_shield_ratio: float = 0.4
@export var gate_clear_bonus: int = 40

@export_group("Pressure")
@export_range(0.5, 3.0, 0.05) var chaos_curve: float = 1.5
@export_range(0, 60, 1) var enemy_cap_at_full_chaos: int = 18
@export_range(0.0, 8.0, 0.1) var enemy_hull_scaling: float = 2.5


func route_length() -> float:
	return travel_seconds * reference_speed


## 0 = quiet, 1 = full chaos. Progress is measured after the debris ring.
func chaos_for_progress(progress: float) -> float:
	return clampf(pow(clampf(progress, 0.0, 1.0), chaos_curve) * 1.15, 0.0, 1.0)


func generate_layout(layout_seed: int) -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = layout_seed
	var length: float = route_length()
	var ring_end: float = planet_center.x + ring_radius + ring_half_width + 500.0
	var span_end: float = length - 800.0

	var weights: Array[float] = []
	var total: float = 0.0
	for _i: int in range(gate_count):
		var weight: float = rng.randf_range(0.8, 1.25)
		weights.append(weight)
		total += weight

	var mids: Array[int] = [ZoneKind.DRIFT, ZoneKind.CUSTOMS, ZoneKind.WRECKS]
	for i: int in range(mids.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var swap: int = mids[i]
		mids[i] = mids[j]
		mids[j] = swap

	var zones: Array[Dictionary] = []
	zones.append({
		"index": 0, "kind": ZoneKind.RING, "name": ZONE_NAMES[ZoneKind.RING],
		"start_x": -100000.0, "end_x": ring_end, "gate_x": -1.0,
		"gate_name": "", "gate_hull": 0.0,
	})
	var cursor: float = ring_end
	var cumulative: float = 0.0
	for i: int in range(gate_count):
		cumulative += weights[i]
		var end_x: float = ring_end + (span_end - ring_end) * cumulative / total
		var kind: int = ZoneKind.BLOCKADE if i == gate_count - 1 else mids[i % mids.size()]
		var gate_name: String = FINAL_GATE_NAME if i == gate_count - 1 else GATE_NAMES[i % GATE_NAMES.size()]
		zones.append({
			"index": i + 1, "kind": kind, "name": ZONE_NAMES[kind],
			"start_x": cursor, "end_x": end_x, "gate_x": end_x,
			"gate_name": gate_name,
			"gate_hull": gate_base_hull * pow(gate_growth, float(i)) * rng.randf_range(0.92, 1.08),
		})
		cursor = end_x

	var checkpoints: Array[Dictionary] = []
	for zone: Dictionary in zones:
		var count: int = 0
		match int(zone["kind"]):
			ZoneKind.CUSTOMS:
				count = 2
			ZoneKind.BLOCKADE:
				count = 1
			ZoneKind.DRIFT:
				count = 1 if rng.randf() < 0.5 else 0
		var zone_start: float = float(zone["start_x"]) + 1200.0
		var zone_end: float = float(zone["end_x"]) - 1500.0
		if count == 0 or zone_end <= zone_start:
			continue
		for c: int in range(count):
			var slot_start: float = zone_start + (zone_end - zone_start) * float(c) / float(count)
			var slot_end: float = zone_start + (zone_end - zone_start) * float(c + 1) / float(count)
			checkpoints.append({
				"x": rng.randf_range(slot_start, slot_end),
				"y": rng.randf_range(-250.0, 250.0),
				"half_span": 430.0,
				"line": rng.randi_range(0, CHECKPOINT_LINES.size() - 1),
				"state": 0, # 0 pending, 1 inspected, 2 evaded
			})

	return {
		"length": length,
		"destination": Vector2(length, 0.0),
		"ring_end": ring_end,
		"zones": zones,
		"checkpoints": checkpoints,
	}


static func zone_at(layout: Dictionary, x: float) -> Dictionary:
	var zones: Array = layout["zones"]
	for zone: Dictionary in zones:
		if x < float(zone["end_x"]):
			return zone
	return zones[zones.size() - 1]

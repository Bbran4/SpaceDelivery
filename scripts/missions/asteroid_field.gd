extends Node2D
class_name AsteroidField

## Chunked asteroid field. Rocks are plain data, not nodes:
##  - The world is cut into CELL_SIZE cells. Cells near the player are generated
##    deterministically from (cell, field_seed), cells far away are returned to a pool.
##  - A revisited cell regenerates identically, so nothing needs to be stored.
##  - All visible rocks are drawn in this one node from a few shared meshes.
##  - Rocks are not in the "enemy" group, so projectiles and targeting ignore them.
## density_source is a Callable(world_position: Vector2) -> float (0..1 spawn chance).

signal rock_struck(normal: Vector2, rock_radius: float)

const CELL_SIZE: float = 512.0
## Cells loaded around the player's cell. Covers a 1920x1080 view with margin.
const REACH: Vector2i = Vector2i(3, 2)
const CANDIDATES_PER_CELL: int = 56
const VARIANT_COUNT: int = 8
const WOBBLE: float = 26.0
const PLAYER_RADIUS: float = 14.0
const STRIKE_COOLDOWN: float = 0.6


class Chunk:
	var cell: Vector2i = Vector2i.ZERO
	var base: PackedVector2Array = PackedVector2Array()
	var radius: PackedFloat32Array = PackedFloat32Array()
	var phase: PackedFloat32Array = PackedFloat32Array()
	var variant: PackedInt32Array = PackedInt32Array()
	var tint: PackedColorArray = PackedColorArray()

	func reset(new_cell: Vector2i) -> void:
		cell = new_cell
		base.clear()
		radius.clear()
		phase.clear()
		variant.clear()
		tint.clear()


var player: Ship
var field_seed: int = 0
var density_source: Callable = Callable()

var _chunks: Dictionary = {}
var _pool: Array = []
var _unit_polygons: Array[PackedVector2Array] = []
var _time: float = 0.0
var _last_cell: Vector2i = Vector2i(1 << 30, 1 << 30)
var _strike_cooldown: float = 0.0


func _ready() -> void:
	z_index = -1
	_build_meshes()


func _process(delta: float) -> void:
	_time += delta
	if is_instance_valid(player):
		_update_chunks(player.global_position)
	queue_redraw()


func _physics_process(delta: float) -> void:
	_strike_cooldown = maxf(0.0, _strike_cooldown - delta)
	if not is_instance_valid(player) or player.is_destroyed:
		return
	var player_position: Vector2 = player.global_position
	var player_cell: Vector2i = _cell_of(player_position)
	for dx: int in range(-1, 2):
		for dy: int in range(-1, 2):
			var chunk: Chunk = _chunks.get(player_cell + Vector2i(dx, dy)) as Chunk
			if chunk == null:
				continue
			for i: int in range(chunk.base.size()):
				var offset: Vector2 = player_position - _rock_position(chunk, i)
				var reach: float = chunk.radius[i] * 0.85 + PLAYER_RADIUS
				var distance_squared: float = offset.length_squared()
				if distance_squared >= reach * reach:
					continue
				var distance: float = sqrt(distance_squared)
				var normal: Vector2 = offset / distance if distance > 0.001 else Vector2.LEFT
				# Rocks are solid: always push the ship out, damage only on cooldown.
				player.global_position += normal * (reach - distance)
				player_position = player.global_position
				if _strike_cooldown <= 0.0:
					_strike_cooldown = STRIKE_COOLDOWN
					rock_struck.emit(normal, chunk.radius[i])


func _cell_of(position_value: Vector2) -> Vector2i:
	return Vector2i(floori(position_value.x / CELL_SIZE), floori(position_value.y / CELL_SIZE))


func _update_chunks(position_value: Vector2) -> void:
	var cell: Vector2i = _cell_of(position_value)
	if cell == _last_cell:
		return
	_last_cell = cell
	var wanted: Dictionary = {}
	for cx: int in range(cell.x - REACH.x, cell.x + REACH.x + 1):
		for cy: int in range(cell.y - REACH.y, cell.y + REACH.y + 1):
			wanted[Vector2i(cx, cy)] = true
	for key: Vector2i in _chunks.keys():
		if not wanted.has(key):
			_pool.append(_chunks[key])
			_chunks.erase(key)
	for key: Vector2i in wanted.keys():
		if not _chunks.has(key):
			_chunks[key] = _make_chunk(key)


func _make_chunk(cell: Vector2i) -> Chunk:
	var chunk: Chunk = _pool.pop_back() as Chunk if not _pool.is_empty() else Chunk.new()
	chunk.reset(cell)
	if not density_source.is_valid():
		return chunk
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = (cell.x * 73856093) ^ (cell.y * 19349663) ^ (field_seed * 83492791)
	var origin: Vector2 = Vector2(cell) * CELL_SIZE
	for _i: int in range(CANDIDATES_PER_CELL):
		var rock_position: Vector2 = origin + Vector2(rng.randf(), rng.randf()) * CELL_SIZE
		var roll: float = rng.randf()
		var rock_scale: float = rng.randf_range(0.65, 1.9)
		var phase: float = rng.randf_range(0.0, TAU)
		var variant: int = rng.randi_range(0, VARIANT_COUNT - 1)
		var shade: float = rng.randf_range(0.55, 0.95)
		if roll > float(density_source.call(rock_position)):
			continue
		chunk.base.append(rock_position)
		chunk.radius.append(11.0 * rock_scale)
		chunk.phase.append(phase)
		chunk.variant.append(variant)
		chunk.tint.append(Color(shade * 0.85, shade * 0.95, minf(shade * 1.1, 1.0), 1.0))
	return chunk


func _rock_position(chunk: Chunk, index: int) -> Vector2:
	var phase: float = chunk.phase[index]
	return chunk.base[index] + Vector2(
		cos(_time * 0.35 + phase), sin(_time * 0.27 + phase * 1.7)
	) * WOBBLE


func _draw() -> void:
	for chunk_value: Variant in _chunks.values():
		var chunk: Chunk = chunk_value
		for i: int in range(chunk.base.size()):
			var rock_radius: float = chunk.radius[i]
			var spin: float = 0.3 if chunk.variant[i] % 2 == 0 else -0.3
			var angle: float = chunk.phase[i] * 3.0 + _time * spin
			draw_set_transform(_rock_position(chunk, i), angle, Vector2(rock_radius, rock_radius))
			draw_colored_polygon(_unit_polygons[chunk.variant[i]], chunk.tint[i])
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Debug readout: loaded chunks and rocks. Rocks > 0 but nothing visible means a drawing problem.
func get_debug_text() -> String:
	var rock_count: int = 0
	for chunk_value: Variant in _chunks.values():
		rock_count += (chunk_value as Chunk).base.size()
	return "CHUNKS %d  ROCKS %d" % [_chunks.size(), rock_count]


func _build_meshes() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7731
	for _v: int in range(VARIANT_COUNT):
		var count: int = rng.randi_range(7, 10)
		var vertices: PackedVector2Array = PackedVector2Array()
		for i: int in range(count):
			var angle: float = TAU * float(i) / float(count)
			vertices.append(Vector2.RIGHT.rotated(angle) * rng.randf_range(0.72, 1.0))
		_unit_polygons.append(vertices)

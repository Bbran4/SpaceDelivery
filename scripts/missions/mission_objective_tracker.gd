extends Node
class_name MissionObjectiveTracker

## Per-attempt objective progress. MissionDefinition resources remain reusable and unchanged.
enum ObjectiveState {
	LOCKED,
	AVAILABLE,
	ACTIVE,
	COMPLETED,
	FAILED,
}

enum ContractState {
	AVAILABLE,
	SELECTED,
	IN_PROGRESS,
	OBJECTIVE_COMPLETE,
	DELIVERED,
	SUCCEEDED,
	FAILED,
	ABANDONED,
	SETTLED,
}

var contract_state: ContractState = ContractState.AVAILABLE
var objective_states: Dictionary = {}
var objective_progress: Dictionary = {}
var active_mission_id: StringName = &""
var last_error: String = ""


func reset_run() -> void:
	contract_state = ContractState.AVAILABLE
	objective_states.clear()
	objective_progress.clear()
	active_mission_id = &""
	last_error = ""


func begin_run(mission: MissionDefinition) -> bool:
	reset_run()
	last_error = ""
	if mission == null:
		last_error = "No contract was selected."
		return false
	var errors: PackedStringArray = mission.validate_contract()
	if not errors.is_empty():
		last_error = "; ".join(errors)
		return false
	active_mission_id = mission.mission_id
	contract_state = ContractState.IN_PROGRESS
	objective_states.clear()
	objective_progress.clear()
	for objective: MissionObjectiveDefinition in mission.objectives:
		if objective == null:
			continue
		objective_states[objective.objective_id] = ObjectiveState.LOCKED if not objective.prerequisite_ids.is_empty() else ObjectiveState.AVAILABLE
		objective_progress[objective.objective_id] = 0
	_refresh_available_objectives(mission)
	return true


func activate_objective(mission: MissionDefinition, objective_id: StringName) -> bool:
	if not _matches_active_mission(mission):
		return false
	var objective: MissionObjectiveDefinition = _find_objective(mission, objective_id)
	if objective == null or int(objective_states.get(objective_id, ObjectiveState.LOCKED)) not in [ObjectiveState.AVAILABLE, ObjectiveState.ACTIVE]:
		return false
	objective_states[objective_id] = ObjectiveState.ACTIVE
	return true


## Adds objective progress and completes it when the required quantity is reached.
## The caller must only report progress after the corresponding gameplay event is verified.
func add_progress(mission: MissionDefinition, objective_id: StringName, amount: int = 1) -> bool:
	if not _matches_active_mission(mission) or amount <= 0:
		return false
	var objective: MissionObjectiveDefinition = _find_objective(mission, objective_id)
	if objective == null:
		return false
	var state: int = int(objective_states.get(objective_id, ObjectiveState.LOCKED))
	if state not in [ObjectiveState.AVAILABLE, ObjectiveState.ACTIVE]:
		return false
	objective_states[objective_id] = ObjectiveState.ACTIVE
	objective_progress[objective_id] = mini(objective.required_quantity, int(objective_progress.get(objective_id, 0)) + amount)
	if int(objective_progress[objective_id]) >= objective.required_quantity:
		objective_states[objective_id] = ObjectiveState.COMPLETED
		_refresh_available_objectives(mission)
		if are_required_objectives_complete(mission):
			contract_state = ContractState.OBJECTIVE_COMPLETE
	return true


## Called by the flight scene only after an enemy is confirmed destroyed.
## DESTROY tracks individual hostiles; ELIMINATE_GROUP completes once the encounter is cleared.
func report_enemy_destroyed(mission: MissionDefinition, remaining_enemies: int) -> void:
	if not _matches_active_mission(mission) or contract_state in [ContractState.FAILED, ContractState.ABANDONED, ContractState.SETTLED]:
		return
	for objective: MissionObjectiveDefinition in mission.objectives:
		if objective == null:
			continue
		if objective.objective_type == MissionObjectiveDefinition.ObjectiveType.DESTROY:
			add_progress(mission, objective.objective_id, 1)
		elif objective.objective_type == MissionObjectiveDefinition.ObjectiveType.ELIMINATE_GROUP and remaining_enemies <= 0:
			add_progress(mission, objective.objective_id, 1)


func fail_objective(mission: MissionDefinition, objective_id: StringName) -> bool:
	if not _matches_active_mission(mission):
		return false
	var objective: MissionObjectiveDefinition = _find_objective(mission, objective_id)
	if objective == null or int(objective_states.get(objective_id, ObjectiveState.LOCKED)) not in [ObjectiveState.AVAILABLE, ObjectiveState.ACTIVE]:
		return false
	objective_states[objective_id] = ObjectiveState.FAILED
	if objective.required:
		contract_state = ContractState.FAILED
	return true


func are_required_objectives_complete(mission: MissionDefinition) -> bool:
	if not _matches_active_mission(mission):
		return false
	for objective: MissionObjectiveDefinition in mission.objectives:
		if objective == null or not objective.required:
			continue
		if int(objective_states.get(objective.objective_id, ObjectiveState.LOCKED)) != ObjectiveState.COMPLETED:
			return false
	return true


## Delivery-only legacy contracts have no explicit objectives and retain existing behavior.
func can_deliver(mission: MissionDefinition) -> bool:
	if not _matches_active_mission(mission):
		return false
	return are_required_objectives_complete(mission)


func mark_delivered(mission: MissionDefinition, success: bool) -> bool:
	if not can_deliver(mission):
		return false
	contract_state = ContractState.DELIVERED
	if success:
		contract_state = ContractState.SUCCEEDED
	else:
		contract_state = ContractState.FAILED
	return true


func mark_failed() -> void:
	if contract_state == ContractState.SETTLED:
		return
	contract_state = ContractState.FAILED


func mark_abandoned() -> void:
	if contract_state == ContractState.SETTLED:
		return
	contract_state = ContractState.ABANDONED


func mark_settled() -> void:
	if contract_state != ContractState.SETTLED:
		contract_state = ContractState.SETTLED


func get_objective_snapshot(mission: MissionDefinition) -> Array[Dictionary]:
	var snapshot: Array[Dictionary] = []
	if not _matches_active_mission(mission):
		return snapshot
	for objective: MissionObjectiveDefinition in mission.objectives:
		if objective == null:
			continue
		snapshot.append({
			"id": String(objective.objective_id),
			"title": objective.title,
			"required": objective.required,
			"state": ObjectiveState.keys()[int(objective_states.get(objective.objective_id, ObjectiveState.LOCKED))],
			"progress": int(objective_progress.get(objective.objective_id, 0)),
			"required_quantity": objective.required_quantity,
		})
	return snapshot


func _refresh_available_objectives(mission: MissionDefinition) -> void:
	for objective: MissionObjectiveDefinition in mission.objectives:
		if objective == null or int(objective_states.get(objective.objective_id, ObjectiveState.LOCKED)) != ObjectiveState.LOCKED:
			continue
		var prerequisites_complete: bool = true
		for prerequisite_id: StringName in objective.prerequisite_ids:
			if int(objective_states.get(prerequisite_id, ObjectiveState.LOCKED)) != ObjectiveState.COMPLETED:
				prerequisites_complete = false
				break
		if prerequisites_complete:
			objective_states[objective.objective_id] = ObjectiveState.AVAILABLE


func _matches_active_mission(mission: MissionDefinition) -> bool:
	return mission != null and active_mission_id != &"" and mission.mission_id == active_mission_id


func _find_objective(mission: MissionDefinition, objective_id: StringName) -> MissionObjectiveDefinition:
	for objective: MissionObjectiveDefinition in mission.objectives:
		if objective != null and objective.objective_id == objective_id:
			return objective
	return null

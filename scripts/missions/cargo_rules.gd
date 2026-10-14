extends RefCounted
class_name CargoRules

## Shared cargo rules. Mission resources provide authored values; this class applies
## reusable category constraints and settlement calculations.
enum CargoVariant {
	STANDARD,
	FRAGILE,
	BULK,
	VALUABLE,
}

const VARIANT_NAMES: Dictionary = {
	CargoVariant.STANDARD: "Standard",
	CargoVariant.FRAGILE: "Fragile",
	CargoVariant.BULK: "Bulk",
	CargoVariant.VALUABLE: "Valuable",
}

const MINIMUM_CAPACITY_BY_VARIANT: Dictionary = {
	CargoVariant.STANDARD: 1,
	CargoVariant.FRAGILE: 1,
	CargoVariant.BULK: 4,
	CargoVariant.VALUABLE: 2,
}

const DAMAGE_MULTIPLIER_BY_VARIANT: Dictionary = {
	CargoVariant.STANDARD: 1.0,
	CargoVariant.FRAGILE: 1.5,
	CargoVariant.BULK: 0.75,
	CargoVariant.VALUABLE: 1.2,
}


static func get_variant_name(variant: int) -> String:
	return str(VARIANT_NAMES.get(variant, "Standard"))


static func get_required_capacity(mission: Variant) -> int:
	if mission == null:
		return 1
	var category_minimum: int = int(MINIMUM_CAPACITY_BY_VARIANT.get(mission.cargo_variant, 1))
	return maxi(category_minimum, mission.cargo_capacity_required)


static func get_damage_sensitivity(mission: Variant) -> float:
	if mission == null:
		return 1.0
	var category_multiplier: float = float(DAMAGE_MULTIPLIER_BY_VARIANT.get(mission.cargo_variant, 1.0))
	return maxf(0.0, mission.cargo_damage_sensitivity) * category_multiplier


static func get_condition(mission: Variant, integrity_percent: float) -> String:
	if integrity_percent <= 0.0:
		return "LOST"
	if mission != null and integrity_percent < float(mission.full_reward_integrity_percent):
		return "DAMAGED"
	return "INTACT"


static func can_deliver(mission: Variant, integrity_percent: float) -> bool:
	return mission != null and integrity_percent >= float(mission.minimum_delivery_integrity_percent)


static func get_payout_penalty_percent(mission: Variant, integrity_percent: float) -> int:
	if mission == null or not can_deliver(mission, integrity_percent):
		return 0
	if integrity_percent >= float(mission.full_reward_integrity_percent):
		return 0
	return clampi(mission.damaged_cargo_payout_penalty_percent, 0, 100)


static func get_delivery_failure_reason(mission: Variant, integrity_percent: float) -> String:
	if mission == null:
		return "Delivery failed: no valid cargo contract is active."
	if integrity_percent <= 0.0:
		return "Delivery failed: the shipment was destroyed and can no longer be delivered."
	if integrity_percent < float(mission.minimum_delivery_integrity_percent):
		return "Delivery failed: cargo integrity is below the contract minimum of %d%%." % mission.minimum_delivery_integrity_percent
	return ""

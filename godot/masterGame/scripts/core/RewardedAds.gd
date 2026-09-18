extends Node

signal reward_granted(placement: String)
signal request_finished(request_id: String, status: String)
var debug_mock := false
var requests: Dictionary = {}
var sequence := 0
var run_id := ""
var checkpoint := 0
var coin_bonus := 0
const PLACEMENTS := ["double_coins", "gems", "revive", "free_upgrade", "chest"]

func available() -> bool:
	return OS.is_debug_build() and debug_mock

func set_context(id: String, point: int) -> void:
	run_id = id
	checkpoint = point
	requests.clear()

func request_reward(placement: String) -> String:
	if not available() or not PLACEMENTS.has(placement): return ""
	sequence += 1
	var id := "%s:%s:%s" % [run_id, placement, sequence]
	requests[id] = {"placement":placement, "run":run_id, "checkpoint":checkpoint, "status":"pending"}
	return id

func finish(id: String, outcome: String) -> bool:
	if not available() or not requests.has(id): return false
	var request: Dictionary = requests[id]
	if request.status != "pending" or request.run != run_id or request.checkpoint != checkpoint: return false
	if outcome not in ["earned", "cancelled", "failed"]: return false
	request.status = outcome
	if outcome == "earned":
		var placement: String = request.placement
		var receipt := "ad:" + id
		if placement in ["double_coins", "revive"]: receipt = "ad:%s:%s" % [run_id, placement]
		if placement == "free_upgrade": receipt = "ad:%s:upgrade:%s" % [run_id, checkpoint]
		var amount := 20 if placement == "gems" else (5 if placement == "chest" else 0)
		if not MetaProgression.grant_once(receipt, coin_bonus if placement == "double_coins" else 0, amount, placement if placement in ["gems", "chest"] else ""):
			request.status = "failed"
			request_finished.emit(id, "failed")
			return false
		reward_granted.emit(placement)
	request_finished.emit(id, request.status)
	return outcome == "earned"

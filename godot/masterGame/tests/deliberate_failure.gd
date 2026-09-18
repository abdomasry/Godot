extends SceneTree
func _initialize() -> void:
	print("ASSERT_FAIL intentional runner self-test")
	print(JSON.stringify({"suite_complete":true}))
	quit(1)

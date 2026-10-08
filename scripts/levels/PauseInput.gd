extends Node

# 暂停状态下仍然需要能够接收输入（Esc 恢复）。
# 由于 SceneTree.paused = true 时普通节点不再收到 _input，
# 本节点在场景中设置 process_mode = PROCESS_MODE_ALWAYS 以持续接收输入。

signal pause_toggled

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		emit_signal("pause_toggled")
		get_viewport().set_input_as_handled()

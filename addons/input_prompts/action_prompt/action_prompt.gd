# Copyright (C) 2022-2023 John Pennycook
# SPDX-License-Identifier: MIT
@tool
@icon("res://addons/input_prompts/action_prompt/icon.svg")
class_name ActionPrompt
extends "res://addons/input_prompts/input_prompt.gd"
## Displays a prompt based on an action registered in the [InputMap].
##
## Displays a prompt based on an action registered in the [InputMap].
## The texture used for the prompt is determined automatically, based on the
## contents of the [InputMap] and an icon preference. When the icon preference
## is set to "Automatic", the prompt automatically adjusts to match the most
## recent input device.

## The name of an action registered in the [InputMap].
var action := "ui_accept":
	set = _set_action

## The icon preference for this prompt:
## Automatic (0), Xbox (1), Sony (2), Nintendo (3), Keyboard (4).
## When set to "Automatic", the prompt automatically adjusts to match the most
## recent input device.
var icon := Icons.AUTOMATIC:
	set = _set_icon


func _ready() -> void:
	ProjectSettings.settings_changed.connect(_update_events)
	_update_events()
	_update_icon()


func _set_action(new_action: String) -> void:
	action = new_action
	_update_events()
	_update_icon()


func _set_icon(new_icon) -> void:
	icon = new_icon
	_update_icon()


func _update_events() -> void:
	# In the Editor, InputMap reflects Editor settings
	# Read the list of actions from ProjectSettings instead
	if Engine.is_editor_hint():
		events.assign(ProjectSettings.get_setting("input/%s" % action)["events"])
	else:
		events.assign(InputMap.action_get_events(action))
	update_configuration_warnings()


func _find_event(list: Array[InputEvent], types: Array) -> InputEvent:
	for candidate: InputEvent in list:
		if types.any(func(type) -> bool: return is_instance_of(candidate, type)):
			return candidate
	return null


func _update_icon() -> void:
	# If icon is set to AUTOMATIC, first determine which icon to display
	var display_icon := icon
	if icon == Icons.AUTOMATIC:
		display_icon = PromptManager.icons

	# Choose the atlas and region associated with the InputEvent
	# If the InputMap contains multiple events, choose the first
	if display_icon == Icons.KEYBOARD:
		var types := [InputEventKey, InputEventMouseButton]
		var ev := _find_event(events, types)
		if ev is InputEventKey:
			var textures := PromptManager.get_keyboard_textures()
			texture = textures.get_texture(ev)
		elif ev is InputEventMouseButton:
			var textures := PromptManager.get_mouse_textures()
			texture = textures.get_texture(ev)
	else:
		var types := [InputEventJoypadButton, InputEventJoypadMotion]
		var ev := _find_event(events, types)
		if ev is InputEventJoypadButton:
			var textures := PromptManager.get_joypad_button_textures(display_icon)
			texture = textures.get_texture(ev)
		elif ev is InputEventJoypadMotion:
			var textures := PromptManager.get_joypad_motion_textures(display_icon)
			texture = textures.get_texture(ev)
	queue_redraw()


func _refresh() -> void:
	_update_events()
	_update_icon()


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed(action):
		return
	pressed.emit()


func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	properties.append(
		{
			name = "ActionPrompt",
			type = TYPE_NIL,
			usage = PROPERTY_USAGE_CATEGORY | PROPERTY_USAGE_SCRIPT_VARIABLE
		}
	)
	# In the Editor, InputMap reflects Editor settings
	# Read the list of actions from ProjectSettings instead
	var actions := ",".join(
		ProjectSettings.get_property_list()
			.map(func(property: Dictionary) -> String: return property["name"])
			.filter(func(property_name: String) -> bool: return property_name.begins_with("input/"))
			.map(func(property_name: String) -> String: return property_name.substr(6))
	)
	properties.append(
		{
			name = "action",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_ENUM,
			hint_string = actions
		}
	)
	properties.append(
		{
			name = "icon",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Automatic,Xbox,Sony,Nintendo,Keyboard"
		}
	)
	return properties


func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []

	# Check that the action is associated with Keyboard/Mouse in the InputMap
	if icon == Icons.AUTOMATIC or icon == Icons.KEYBOARD:
		var types := [InputEventKey, InputEventMouseButton]
		var ev := _find_event(events, types)
		if ev == null:
			warnings.append("No Key/Mouse input for " + action + " in InputMap.")

	# Check that the action is associated with Joypad in the InputMap
	if icon == Icons.AUTOMATIC or icon != Icons.KEYBOARD:
		var types = [InputEventJoypadButton, InputEventJoypadMotion]
		var ev = _find_event(events, types)
		if ev == null:
			warnings.append("No Joypad input for " + action + " in InputMap.")

	return warnings

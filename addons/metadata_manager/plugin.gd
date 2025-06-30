@tool
extends EditorPlugin

const InspectorPluginScript = preload("res://addons/metadata_manager/metadata_inspector_plugin.gd")
var inspector_plugin_instance

const SETTING_PATH = "addons/metadata_manager/template_script_path"
const DEFAULT_TEMPLATE_PATH = "res://metadata_definitions.gd"

func _enter_tree():
	# --- 1. Setup Project Settings ---
	if not ProjectSettings.has_setting(SETTING_PATH):
		ProjectSettings.set_setting(SETTING_PATH, DEFAULT_TEMPLATE_PATH)
	var property_info = {
		"name": SETTING_PATH, "type": TYPE_STRING,
		"hint": PROPERTY_HINT_FILE, "hint_string": "*.gd",
	}
	ProjectSettings.add_property_info(property_info)
	ProjectSettings.set_as_basic(SETTING_PATH, true)

	# --- 2. Auto-create template file if it doesn't exist ---
	var script_path = ProjectSettings.get_setting(SETTING_PATH, DEFAULT_TEMPLATE_PATH)
	if not FileAccess.file_exists(script_path):
		_create_default_template_file(script_path)

	# --- 3. Setup Inspector Plugin ---
	inspector_plugin_instance = InspectorPluginScript.new()
	inspector_plugin_instance.set_main_plugin(self)
	add_inspector_plugin(inspector_plugin_instance)

func _exit_tree():
	if is_instance_valid(inspector_plugin_instance):
		remove_inspector_plugin(inspector_plugin_instance)
		inspector_plugin_instance = null

func _create_default_template_file(path: String):
	var example_content = """
@tool
extends RefCounted
# ==============================================================================
# METADATA MANAGER TEMPLATE FILE
# ==============================================================================
# This is a metadata template file. You can define available metadata for
# different node types here. The plugin will read this file and display a
# management interface in the inspector for matching node types.
#
# Structure:
# get_all_templates() -> Dictionary:
#   "Template Name": {
#     "applicable_types": [Array of node type Strings, e.g., &"Node2D", &"CharacterBody3D"],
#     "definitions": [Array of metadata Dictionaries]
#   }
#
# Each dictionary in the "definitions" array:
#   { "name": "metadata_name", "type": Godot_Type_Constant, "default_value": a_default_value }
# ==============================================================================
func get_all_templates() -> Dictionary:
	return {
		"Character Stats": {
			"applicable_types": [&"CharacterBody2D", &"CharacterBody3D"],
			"definitions": [
				{ "name": "health", "type": TYPE_INT, "default_value": 100 },
				{ "name": "mana", "type": TYPE_INT, "default_value": 50 },
				{ "name": "speed", "type": TYPE_FLOAT, "default_value": 300.0 },
				{ "name": "is_player_controlled", "type": TYPE_BOOL, "default_value": false },
			]
		},
		"Item Data": {
			"applicable_types": [&"Node2D"], 
			"definitions": [
				{ "name": "item_id", "type": TYPE_STRING, "default_value": "item_00" },
				{ "name": "is_quest_item", "type": TYPE_BOOL, "default_value": false },
			]
		},
	}
"""
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(example_content)
		file.close() 

		if EditorInterface.get_resource_filesystem():
			EditorInterface.get_resource_filesystem().scan()
		
		print("Metadata Manager: Created default template file at '", path, "'.")
	else:
		printerr("Metadata Manager: Failed to create template file at '", path, "'.")


# --- UNDO/REDO PUBLIC API (THE FINAL, CORRECTED VERSION) ---

func add_meta_with_undo(object: Object, meta_name: String, value):
	var undo_redo = get_undo_redo()
	undo_redo.create_action("Add Metadata: '%s'" % meta_name)
	# DO: Set the metadata and notify the editor to refresh the UI
	undo_redo.add_do_method(object, &"set_meta", meta_name, value)
	undo_redo.add_do_method(object, &"notify_property_list_changed")
	# UNDO: Remove the metadata and notify the editor to refresh the UI
	undo_redo.add_undo_method(object, &"remove_meta", meta_name)
	undo_redo.add_undo_method(object, &"notify_property_list_changed")
	undo_redo.commit_action()

func remove_meta_with_undo(object: Object, meta_name: String):
	if not object.has_meta(meta_name): return
	var undo_redo = get_undo_redo()
	var old_value = object.get_meta(meta_name)
	undo_redo.create_action("Remove Metadata: '%s'" % meta_name)
	# DO: Remove the metadata and notify the editor to refresh the UI
	undo_redo.add_do_method(object, &"remove_meta", meta_name)
	undo_redo.add_do_method(object, &"notify_property_list_changed")
	# UNDO: Restore the metadata and notify the editor to refresh the UI
	undo_redo.add_undo_method(object, &"set_meta", meta_name, old_value)
	undo_redo.add_undo_method(object, &"notify_property_list_changed")
	undo_redo.commit_action()
	
# The new function no longer needs control and control_property parameters
func change_meta_with_undo(object: Object, meta_name: String, new_value, old_value, merge := UndoRedo.MERGE_ENDS):
	if new_value == old_value: return
	var undo_redo = get_undo_redo()
	undo_redo.create_action("Change Metadata: '%s'" % meta_name, merge)
	# DO: Set the new value and notify the editor to refresh the UI
	undo_redo.add_do_method(object, &"set_meta", meta_name, new_value)
	undo_redo.add_do_method(object, &"notify_property_list_changed")
	# UNDO: Restore the old value and notify the editor to refresh the UI
	undo_redo.add_undo_method(object, &"set_meta", meta_name, old_value)
	undo_redo.add_undo_method(object, &"notify_property_list_changed")
	undo_redo.commit_action()

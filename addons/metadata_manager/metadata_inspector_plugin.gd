@tool
extends EditorInspectorPlugin

var main_plugin: EditorPlugin
var edited_object: Node

func set_main_plugin(plugin: EditorPlugin):
	main_plugin = plugin

func _can_handle(_object): return true

func _parse_begin(object: Object):
	if not object is Node: return
	edited_object = object
	var script_path = ProjectSettings.get_setting("plugins/metadata_manager/template_script_path", "")
	if script_path.is_empty() or not ResourceLoader.exists(script_path): return
	var script_resource = load(script_path)
	if not script_resource or not script_resource.can_instantiate(): return
	var template_provider = script_resource.new()
	if not template_provider.has_method("get_all_templates"): return
	var all_templates: Dictionary = template_provider.get_all_templates()
	add_custom_control(HSeparator.new())
	for template_name in all_templates:
		var template_data: Dictionary = all_templates[template_name]
		var applicable_types: Array = template_data.get("applicable_types", [])
		if _is_node_type_applicable(edited_object, applicable_types):
			var definitions: Array = template_data.get("definitions", [])
			_add_manager_section_to_inspector(template_name, definitions)

func _is_node_type_applicable(node: Node, types: Array) -> bool:
	if types.is_empty(): return false
	var current_class = node.get_class()
	while current_class != "":
		if types.has(current_class): return true
		current_class = ClassDB.get_parent_class(current_class)
	return false

func _add_manager_section_to_inspector(title: String, definitions: Array):
	var section_container = VBoxContainer.new()
	var header_button = Button.new(); header_button.text = title; header_button.flat = true
	header_button.toggle_mode = true; header_button.button_pressed = true
	section_container.add_child(header_button)
	var content_grid = GridContainer.new(); content_grid.columns = 3
	header_button.toggled.connect(func(is_pressed): content_grid.visible = is_pressed)
	section_container.add_child(content_grid)
	for definition in definitions:
		var meta_name: String = definition.get("name")
		if meta_name.is_empty(): continue
		var label = Label.new(); label.text = meta_name.capitalize()
		content_grid.add_child(label)
		if edited_object.has_meta(meta_name):
			var current_value = edited_object.get_meta(meta_name)
			var editor_control = _create_editor_for_type(definition, current_value)
			editor_control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			content_grid.add_child(editor_control)
			var delete_button = Button.new()
			delete_button.icon = EditorInterface.get_base_control().get_theme_icon(&"Remove", &"EditorIcons")
			delete_button.flat = true
			delete_button.pressed.connect(_on_delete_button_pressed.bind(meta_name))
			content_grid.add_child(delete_button)
		else:
			var default_value = definition.get("default_value")
			var default_label = Label.new(); default_label.text = "Default: %s" % [str(default_value)]
			default_label.modulate = Color(1, 1, 1, 0.6)
			default_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			content_grid.add_child(default_label)
			var add_button = Button.new(); add_button.text = "+"
			add_button.tooltip_text = "Add metadata with default value"
			add_button.pressed.connect(_on_add_button_pressed.bind(definition))
			content_grid.add_child(add_button)
	add_custom_control(section_container)

func _create_editor_for_type(definition: Dictionary, value) -> Control:
	var meta_name = definition.get("name")
	var meta_type = definition.get("type")
	var control: Control
	match meta_type:
		TYPE_BOOL:
			var c = CheckBox.new(); c.button_pressed = value
			c.toggled.connect(func(is_on):
				# Directly call the main plugin's modification function
				main_plugin.change_meta_with_undo(edited_object, meta_name, is_on, not is_on)
			)
			control = c
		TYPE_INT, TYPE_FLOAT:
			var c = SpinBox.new()
			c.step = 0.01 if meta_type == TYPE_FLOAT else 1
			c.allow_lesser = true
			c.allow_greater = true
			c.value = value
			
			c.value_changed.connect(func(new_val):
				# The "old value" is simply what's currently in the object's metadata.
				var old_val = edited_object.get_meta(meta_name, value)
				# Call the new, non-merging function for robust, per-click actions.
				main_plugin.change_meta_with_undo(edited_object, meta_name, new_val, old_val, UndoRedo.MERGE_DISABLE)
			)
			control = c
		TYPE_STRING:
			var c = LineEdit.new(); c.text = value
			c.focus_entered.connect(func(): c.set_meta("old_value", c.text))
			
			var commit_change = func(_new_text = ""): # The _new_text parameter is for compatibility with the text_submitted signal
				var old_text = c.get_meta("old_value", value)
				if c.text != old_text:
					# Directly call the main plugin's modification function
					main_plugin.change_meta_with_undo(edited_object, meta_name, c.text, old_text)

			c.text_submitted.connect(commit_change)
			c.focus_exited.connect(commit_change)
			control = c
		_:
			var c = Label.new(); c.text = "Unsupported Type"; control = c
	return control

# --- SIGNAL HANDLERS ---

func _on_add_button_pressed(definition: Dictionary):
	if not main_plugin or not is_instance_valid(edited_object): return
	main_plugin.add_meta_with_undo(edited_object, definition.get("name"), definition.get("default_value"))

func _on_delete_button_pressed(meta_name: String):
	if not main_plugin or not is_instance_valid(edited_object): return
	main_plugin.remove_meta_with_undo(edited_object, meta_name)

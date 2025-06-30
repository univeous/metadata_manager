# res://my_metadata_definitions.gd
@tool
extends RefCounted

# 这是插件将要读取的核心数据。
# 结构: { "模板名称": { "applicable_types": [节点类型], "definitions": [元数据定义] } }
func get_all_templates() -> Dictionary:
	return {
		"Character Stats": {
			"applicable_types": [&"CharacterBody2D", &"CharacterBody3D"],
			"definitions": [
				{ "name": "health", "type": TYPE_INT, "default_value": 100 },
				{ "name": "mana", "type": TYPE_INT, "default_value": 50 },
				{ "name": "speed", "type": TYPE_FLOAT, "default_value": 300.0 },
			]
		},
		
		"Item Data": {
			# 这里我们使用自定义类名，假设你有一个 class_name Item extends RigidBody2D
			# 如果没有，用 "RigidBody2D" 或 "Sprite2D" 等也可以
			"applicable_types": [&"RigidBody2D", &"Sprite2D"], 
			"definitions": [
				{ "name": "is_quest_item", "type": TYPE_BOOL, "default_value": false },
				{ "name": "item_id", "type": TYPE_STRING, "default_value": "item_00" },
				{ "name": "stackable", "type": TYPE_BOOL, "default_value": true },
				{ "name": "quantity", "type": TYPE_INT, "default_value": 1 },
			]
		},
		
		"Destructible Object": {
			# 这个模板适用于所有从 Node2D 继承的节点
			"applicable_types": [&"Node2D"],
			"definitions": [
				{ "name": "hit_points", "type": TYPE_INT, "default_value": 10 },
				{ "name": "drops_loot", "type": TYPE_BOOL, "default_value": true },
			]
		}
	}

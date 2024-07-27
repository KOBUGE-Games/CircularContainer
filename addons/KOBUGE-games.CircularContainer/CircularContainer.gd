@tool
class_name CircularContainer
extends Container

## Properties ##
var _force_squares: bool = false:
	set(value):
		_force_squares = value
		_resort()
	get:
		return _force_squares

var _force_expand: bool = false:
	set(value):
		_force_expand = value
		_resort()
	get:
		return _force_expand

var _start_angle: float = 0:  #radians
	set(value):
		_start_angle = value
		_resort()
	get:
		return _start_angle

var _percent_visible: float = 1:
	set(value):
		_percent_visible = clamp(value, 0, 1)
		_resort()
	get:
		return _percent_visible

var _appear_at_once: bool = false:
	set(value):
		_appear_at_once = value
		_resort()
	get:
		return _appear_at_once

var _allow_node2d: bool = false:
	set(value):
		_allow_node2d = value
		_resort()
	get:
		return _allow_node2d

var _start_empty: bool = false:
	set(value):
		_start_empty = value
		_resort()
	get:
		return _start_empty

@warning_ignore("untyped_declaration")
var _custom_animator_func = null  # Callable

## Cached variables ##
var _cached_min_size_key: String = ""
var _cached_min_size_dirty: bool = false
@warning_ignore("untyped_declaration")
var _cached_min_size = null  #Vector2

## Callbacks ##


func _ready() -> void:
	sort_children.connect(_resort)
	_resort()


## Properties / Public API ##


func set_custom_animator(custom_func: Callable) -> void:
	_custom_animator_func = custom_func


func unset_custom_animator() -> void:
	_custom_animator_func = null


func set_start_angle_deg(angle: float) -> void:
	_start_angle = deg_to_rad(angle)
	_resort()


func get_start_angle_deg() -> float:
	return rad_to_deg(_start_angle)


@warning_ignore("untyped_declaration")


func _get_minimum_size():  #Vector2
	if _cached_min_size == null:
		_cached_min_size_dirty = true
		_update_cached_min_size()
	return _cached_min_size


func _get_property_list() -> Array:
	return [
		{usage = PROPERTY_USAGE_CATEGORY, type = TYPE_NIL, name = "CircularContainer"},
		{type = TYPE_BOOL, name = "arrange/force_squares"},
		{type = TYPE_BOOL, name = "arrange/force_expand"},
		{
			type = TYPE_FLOAT,
			name = "arrange/start_angle",
			hint = PROPERTY_HINT_RANGE,
			hint_string = "-1080,1080,0.01"
		},
		{type = TYPE_BOOL, name = "arrange/start_empty"},
		{type = TYPE_BOOL, name = "arrange/allow_node2d"},
		{
			type = TYPE_FLOAT,
			name = "animate/percent_visible",
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0,1,0.01"
		},
		{type = TYPE_BOOL, name = "animate/all_at_once"}
	]


func _set(property: StringName, value: Variant) -> bool:
	if property == "arrange/force_squares":
		_force_squares = value
	if property == "arrange/force_expand":
		_force_expand = value
	elif property == "arrange/start_angle":
		set_start_angle_deg(value)
	elif property == "arrange/start_empty":
		_start_empty = value
	elif property == "arrange/allow_node2d":
		_allow_node2d = value
	elif property == "animate/percent_visible":
		_percent_visible = value
	elif property == "animate/all_at_once":
		_appear_at_once = value
	else:
		return false

	return true  # When return false doesn't happen


func _get(property: StringName) -> Variant:
	if property == "arrange/force_squares":
		return _force_squares
	if property == "arrange/force_expand":
		return _force_expand
	elif property == "arrange/start_angle":
		return rad_to_deg(_start_angle)
	elif property == "arrange/start_empty":
		return _start_empty
	elif property == "arrange/allow_node2d":
		return _allow_node2d
	elif property == "animate/percent_visible":
		return _percent_visible
	elif property == "animate/all_at_once":
		return _appear_at_once
	else:
		return null


## Main Logic ##


func _resort() -> void:
	var rect: Rect2 = get_rect()
	var origin: Vector2 = rect.size / 2

	var children: Array[Node] = _get_filtered_children()

	if children.size() == 0:
		return

	var min_child_size: Vector2 = Vector2.ZERO
	for child: Node in children:
		var size: Vector2 = _get_child_min_size(child)
		min_child_size.x = max(min_child_size.x, size.x)
		min_child_size.y = max(min_child_size.y, size.y)

	var radius: float = min(rect.size.x - min_child_size.x, rect.size.y - min_child_size.y) / 2

	if !_cached_min_size_dirty:
		call_deferred("_update_cached_min_size")
		_cached_min_size_dirty = true  # Prevent double-queueing

	var angle_required: float = 0
	var total_stretch_ratio: float = 0
	var angle_for_child: Array[float] = []
	for child: Node in children:
		var angle: float = _get_max_angle_for_diagonal(_get_child_min_size(child).length(), radius)
		angle_required += angle
		angle_for_child.push_back(angle)
		total_stretch_ratio += _get_child_stretch_ratio(child)

	if total_stretch_ratio > 0:  # Division by zero otherwise
		for i: int in range(children.size()):
			var child: Node = children[i]
			angle_for_child[i] += (
				(2 * PI - angle_required) * _get_child_stretch_ratio(child) / total_stretch_ratio
			)

	var angle_reached: float = _start_angle
	if !_start_empty:
		angle_reached -= angle_for_child[0] / 2

	var appear: float = _percent_visible
	if !_appear_at_once:
		appear *= children.size()

	for i: int in range(children.size()):
		var child: Node = children[i]
		_put_child_at_angle(
			child, radius, origin, angle_reached, angle_for_child[i], clamp(appear, 0, 1)
		)
		angle_reached += angle_for_child[i]
		if !_appear_at_once:
			appear -= 1


func _put_child_at_angle(
	child: Node,
	radius: float,
	origin: Vector2,
	angle_start: float,
	angle_size: float,
	appear: float
) -> void:
	var size: Vector2 = _get_child_min_size(child)
	var target: Vector2 = Vector2(0, -radius).rotated(-(angle_start + angle_size / 2)) + origin

	if child is Control:
		child.set_size(size)

	if _custom_animator_func != null:
		_custom_animator_func.call_func(child, origin, target, appear)
	else:
		_default_animator(child, origin, target, appear)


func _update_cached_min_size() -> void:
	if !_cached_min_size_dirty:
		return
	_cached_min_size_dirty = false

	var children: Array[Node] = _get_filtered_children()

	if children.size() == 0:
		return

	var min_radius: float = 1
	var min_child_size: Vector2 = Vector2.ZERO
	var max_radius: float = 1

	var diagonals: Array[float] = []
	for child: Node in children:
		var size: Vector2 = _get_child_min_size(child)
		min_child_size.x = max(min_child_size.x, size.x)
		min_child_size.y = max(min_child_size.y, size.y)
		var diagonal: float = size.length()
		min_radius = max(min_radius, diagonal / 2)
		max_radius += diagonal / 2
		diagonals.push_back(diagonal)

	var key: String = str(diagonals)
	if _cached_min_size_key == key:
		return

#	var iter = 0
	while max_radius > min_radius + 0.5:
#		iter += 1
		var new_radius: float = (max_radius + min_radius) / 2

		var angle_required: float = 0
		for child: Node in children:
			angle_required += _get_max_angle_for_diagonal(
				_get_child_min_size(child).length(), new_radius
			)

		if angle_required < 2 * PI:
			max_radius = new_radius  # The angle needed is not high enough, we continue trying smaller values
		else:
			min_radius = new_radius  # The angle needed is too high, we continue trying larger values

#	print(max_radius, "; found in ", iter, " iterations")

	_cached_min_size = Vector2(max_radius, max_radius) * 2 + min_child_size
	_cached_min_size_key = key

	emit_signal("minimum_size_changed")


func _default_animator(
	node: Node, container_center: Vector2, target_pos: Vector2, time: float
) -> void:
	if node is Control:
		node.set_position(container_center.lerp(target_pos - node.get_size() / 2 * time, time))
	else:
		node.set_position(container_center.lerp(target_pos, time))
	#node.set_opacity(time)
	if time == 0:
		node.set_scale(Vector2(0.01, 0.01))
	else:
		node.set_scale(Vector2(time, time))


## Helpers ##


func _get_filtered_children() -> Array[Node]:
	var children: Array[Node] = get_children()
	var i: int = children.size()
	while i > 0:
		i -= 1
		var keep: bool = false
		if children[i] is Control:
			keep = true
		elif _allow_node2d and children[i] is Node2D:
			keep = true

		if children[i] is CanvasItem and children[i].visible == false:
			keep = false

		if !keep:
			children.remove_at(i)
	return children


func _get_child_min_size(child: Node) -> Vector2:
	if child is Control:
		var size: Vector2 = child.get_combined_minimum_size()
		if _force_squares:
			var s: float = max(size.x, size.y)
			return Vector2(s, s)
		return size
	else:
		return Vector2(0, 0)


func _get_child_stretch_ratio(child: Node) -> float:
	if (
		child is Control
		and (child.get_h_size_flags() & SIZE_EXPAND or child.get_h_size_flags() & SIZE_EXPAND)
	):
		return child.get_stretch_ratio()
	elif child is Node2D:
		return 1
	elif _force_expand:
		return 1
	else:
		return 0


func _get_max_angle_for_diagonal(diagonal: float, radius: float) -> float:
	var fit_length: float = diagonal / 2
	if fit_length > radius:
		return PI
	else:
		return asin(fit_length / radius) * 2

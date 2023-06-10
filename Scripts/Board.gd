class_name Board extends Node2D


var board: Array
var shield_board: Array


var touch_enabled := true


var _shift_timer: Timer
var _shift_again: bool

var _selected_tile: Tile
var _selected_tile_2: Tile


func _ready() -> void:
	randomize()
	_initialize_board(9, 7)
	
	_shift_timer = Timer.new()
	_shift_timer.wait_time = Global.DROP_TIME + 0.001 # Wait a little after shift has finished to avoid race
	_shift_timer.autostart = false
	_shift_timer.one_shot = true
	_shift_timer.connect("timeout", self, "_on_shift_timer_timeout")
	add_child(_shift_timer)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and touch_enabled:
		var grid_pos := Global.world_to_grid(event.position)
		if grid_pos.x >= 0 and grid_pos.y >= 0 and grid_pos.x < board.size() and grid_pos.y < board[0].size():
			_selected_tile = board[grid_pos.x][grid_pos.y]
		else:
			_selected_tile = null
	elif event is InputEventScreenDrag and touch_enabled and _selected_tile:
		var grid_pos := Global.world_to_grid(event.position)
		# I selected a different tile
		if !out_of_bounds(grid_pos.x, grid_pos.y) and board[grid_pos.x][grid_pos.y] != _selected_tile:
			var direction := grid_pos - Vector2(_selected_tile.row, _selected_tile.col)
			# Different tile is adjacent
			if direction.length_squared() == 1:
				_selected_tile_2 = board[grid_pos.x][grid_pos.y]
				_move_tile(_selected_tile, Vector2(direction.y, direction.x))
				
				touch_enabled = false
				_shift_timer.start()


func _initialize_board(row: int, col: int) -> void:
	var background: Sprite = Sprite.new()
	background.texture = preload("res://Assets/Background.png")
	background.offset = (Global.TILE_SIZE + Global.MARGIN) * 4.5
	background.position = Global.OFFSET/2 - Vector2(10,10)
	add_child(background)
	
	for i in range(row):
		var r := []
		for j in range(col):
			r.append(null)
		board.append(r)
	for i in range(row - 1, -1, -1):
		for j in range(col - 1, -1, -1):
			var colour: int
			while true:
				colour = _get_random_colour()
				if !_is_right_match(i, j, colour) and !_is_down_match(i, j, colour):
					break
			var tile := Tile.new(colour, i, j)
			board[i][j] = tile
			add_child(tile)


func _initialize_shield_board(row: int, col: int) -> void:
	for i in range(row):
		var r := []
		for j in range(col):
			r.append(1 if rand_range(0, 1) < 0.2 else 0)
		board.append(r)


func _move_tile(tile: Tile, direction: Vector2) -> void:
	var new_row := tile.row + direction.y
	var new_col := tile.col + direction.x
	if new_row < 0 or new_row >= board.size():
		return
	if new_col < 0 or new_col >= board[0].size():
		return
	var temp: Tile = board[new_row][new_col]
	board[new_row][new_col] = tile
	board[tile.row][tile.col] = temp
	tile.queue_move(direction)
	
	if board[new_row - direction.y][new_col - direction.x]:
		_selected_tile_2 = board[new_row - direction.y][new_col - direction.x]
		board[new_row - direction.y][new_col - direction.x].queue_move(-direction)


func out_of_bounds(row: int, col: int) -> bool:
	return row < 0 or row >= board.size() or col < 0 or col >= board[0].size()


# Takes in Array of Tiles corresponding to a match3, and returns created special Tile
func _create_special_tile(match3: Array, type := 0) -> Tile:
	var tile: Tile = match3[0]
	if _selected_tile in match3: # Try to make it tile I moved, otherwise make it at the first tile
		tile = _selected_tile
	elif _selected_tile_2 in match3:
		tile = _selected_tile_2
	if tile.type != Tile.Type.Normal: # New tile is already a special Tile. Trigger it, then create a new Tile
		var new_tile := Tile.new(tile.colour, tile.row, tile.col)
		match3.erase(tile)
		_destroy_tile(tile)
		tile = new_tile
		board[tile.row][tile.col] = tile
		add_child(tile)
	else:
		match3.erase(tile)
	tile.type = type if match3.size() == 3 else Tile.Type.Rainbow # size == 3 since we deleted one tile from match3
	return tile


func _delete_matches() -> bool:
	var to_delete_h := _find_horizontal_match()
	var to_delete_v := _find_vertical_match()
	var potential_bombs := []
	for match3 in to_delete_h:
		if match3.size() >= 4: # Create horizontal tile type
			potential_bombs.append(_create_special_tile(match3, Tile.Type.Horizontal))
		for tile in match3:
			_destroy_tile(tile)
			potential_bombs.append(tile)
	for match3 in to_delete_v:
		if match3.size() >= 4:
			potential_bombs.append(_create_special_tile(match3, Tile.Type.Vertical))
		for tile in match3:
			# Create bomb tile
			if tile in potential_bombs and tile.type != Tile.Type.Rainbow:
				if board[tile.row][tile.col] == null:
					board[tile.row][tile.col] = Tile.new(tile.colour, tile.row, tile.col)
					add_child(board[tile.row][tile.col])
				board[tile.row][tile.col].type = Tile.Type.Bomb
			else:
				_destroy_tile(tile)
	_selected_tile = null
	_selected_tile_2 = null
	return to_delete_h.size() != 0 or to_delete_v.size() != 0


func _destroy_tile(tile: Tile, tile2: Tile = null) -> void:
	if tile2:
		var colour := tile.colour if tile.type != Tile.Type.Rainbow else tile2.colour
		var combo := tile.type | tile2.type
		
		# Rainbow combos
		if combo == Tile.Type.Rainbow:
			pass
		elif combo == Tile.Type.Rainbow | Tile.Type.Normal:
			_destroy_tiles_of_colour(colour)
		elif combo & Tile.Type.Rainbow != 0:
			_convert_colours_to_type(colour, combo & ~Tile.Type.Rainbow)
		
		# Bomb combos
		elif combo == Tile.Type.Bomb:
			_trigger_bomb_bomb(tile, tile2)
		elif combo == Tile.Type.Bomb | Tile.Type.Vertical:
			_trigger_bomb_vertical(tile, tile2)
		elif combo == Tile.Type.Bomb | Tile.Type.Horizontal:
			_trigger_bomb_horizontal(tile, tile2)
		
		# V/H Combos
		elif combo & (Tile.Type.Vertical | Tile.Type.Horizontal):
			if combo == Tile.Type.Vertical:
				tile2.type = Tile.Type.Horizontal
			elif combo == Tile.Type.Horizontal:
				tile2.type = Tile.Type.Vertical
			_destroy_tile(tile)
			_destroy_tile(tile2)
		
		if board[tile2.row][tile2.col]:
			board[tile2.row][tile2.col].hide()
			board[tile2.row][tile2.col].queue_free()
			board[tile2.row][tile2.col] = null
		if board[tile.row][tile.col]:
			board[tile.row][tile.col].hide()
			board[tile.row][tile.col].queue_free()
			board[tile.row][tile.col] = null
		return
	elif tile.type == Tile.Type.Rainbow: # destroy rainbow as a result of a chain
		_destroy_tiles_of_colour(_get_random_colour())
	if board[tile.row][tile.col] == null: return
	board[tile.row][tile.col].hide()
	board[tile.row][tile.col].queue_free()
	board[tile.row][tile.col] = null
	
	if tile.type == Tile.Type.Vertical:
		for r in range(0, board.size()):
			if board[r][tile.col]:
				_destroy_tile(board[r][tile.col])
	elif tile.type == Tile.Type.Horizontal:
		for c in range(0, board[0].size()):
			if board[tile.row][c]:
				_destroy_tile(board[tile.row][c])
	elif tile.type == Tile.Type.Bomb:
		for i in range(-1, 2):
			for j in range(-1, 2):
				if !out_of_bounds(tile.row + i, tile.col + j) and board[tile.row + i][tile.col + j]:
					_destroy_tile(board[tile.row + i][tile.col + j])
	elif tile.type == Tile.Type.Rainbow: # Should never reach here. Rainbow will never be part of a match3
		pass


func _destroy_tiles_of_colour(colour: int) -> void:
	for i in range(board.size()):
		for j in range(board[0].size()):
			if board[i][j] and board[i][j].colour & colour != 0: #and board[i][j].type != Tile.Type.Rainbow:
				_destroy_tile(board[i][j])


func _convert_colours_to_type(colour: int, type: int) -> void:
	for i in range(board.size()):
		for j in range(board[0].size()):
			if board[i][j] and board[i][j].colour & colour != 0 and board[i][j].type == Tile.Type.Normal:
				board[i][j].type = type


func _shift_down() -> bool:
	var moved := false
	for c in range(board[0].size()):
		for r in range(board.size() - 1, 0, -1):
			if board[r][c] == null and board[r - 1][c]:
				for row in range(r - 1, -1, -1):
					if board[row][c]:
						_move_tile(board[row][c], Vector2(0, 1))
						moved = true
				break
		if board[0][c] == null: # Create another tile at the top
			board[0][c] = Tile.new(_get_random_colour(), -1, c)
			add_child(board[0][c])
			board[0][c].queue_move(Vector2(0, 1))
			moved = true
	return moved


func _find_horizontal_match() -> Array:
	var all_deletions := []
	for r in range(board.size()):
		var c := 0
		while c < board[0].size():
			var match3 := _is_right_match(r, c, board[r][c].colour)
			if match3.size() != 0:
				all_deletions.append(match3)
				c += match3.size() - 1
			c += 1
	return all_deletions


# Xxx where X is at position (row, col)
# returns array of tiles if they match, otherwise empty
func _is_right_match(row: int, col: int, colour: int) -> Array:
	if col >= board[0].size() - 2:
		return []
	var matching_tiles := [board[row][col]]
	var check_col := col + 1
	while check_col < board[0].size() and board[row][check_col] and board[row][check_col].colour & colour != 0:
		matching_tiles.append(board[row][check_col])
		check_col += 1
	if matching_tiles.size() >= 3:
		return matching_tiles
	return []


func _find_vertical_match() -> Array:
	var all_deletions := []
	for c in range(board[0].size()):
		var r := 0
		while r < board.size():
			var match3 := _is_down_match(r, c, board[r][c].colour)
			if match3.size() != 0:
				all_deletions.append(match3)
				r += match3.size() - 1
			r += 1
	return all_deletions


# X
# x
# x where X is at position (row, col)
# returns array of tiles if they match, otherwise empty
func _is_down_match(row: int, col: int, colour: int) -> Array:
	if row >= board.size() - 2:
		return []
	var matching_tiles := [board[row][col]]
	var check_row := row + 1
	while check_row < board.size() and board[check_row][col].colour & colour != 0:
		matching_tiles.append(board[check_row][col])
		check_row += 1
	if matching_tiles.size() >= 3:
		return matching_tiles
	return []


func _get_random_colour() -> int:
	return Tile.Colour.values()[randi() % (Tile.Colour.size() - 2) + 1]


func _trigger_bomb_bomb(tile: Tile, tile2: Tile) -> void:
	var row := min(tile.row, tile2.row)
	var col := min(tile.col, tile2.col)
	for i in range(row - 2, row + (4 if tile.row != tile2.row else 3)):
		for j in range(col - 2, col + (4 if tile.col != tile2.col else 3)):
			if !out_of_bounds(i, j) and board[i][j]:
				_destroy_tile(board[i][j])


func _trigger_bomb_vertical(tile: Tile, tile2: Tile) -> void:
	#var row := tile.row if tile.type == Tile.Type.Bomb else tile2.row
	var col := tile.col if tile.type == Tile.Type.Bomb else tile2.col
	for i in range(board.size()):
		for j in range(col - 1, col + 2):
			if !out_of_bounds(i, j) and board[i][j]:
				_destroy_tile(board[i][j])


func _trigger_bomb_horizontal(tile: Tile, tile2: Tile) -> void:
	var row := tile.row if tile.type == Tile.Type.Bomb else tile2.row
	for i in range(row - 1, row + 2):
		for j in range(board[0].size()):
			if !out_of_bounds(i, j) and board[i][j]:
				_destroy_tile(board[i][j])


func _on_shift_timer_timeout() -> void:
	# Shift was due to a swap
	if _selected_tile and _selected_tile_2:
		if _selected_tile.type == Tile.Type.Rainbow or _selected_tile_2.type == Tile.Type.Rainbow or \
				_selected_tile.type != Tile.Type.Normal and _selected_tile_2.type != Tile.Type.Normal:
			_destroy_tile(_selected_tile, _selected_tile_2)
			_selected_tile = null
			_selected_tile_2 = null
			_shift_again = true
	if _shift_again:
		_shift_again = _shift_down()
		_shift_timer.start()
	elif _delete_matches():
		_shift_again = _shift_down()
		_shift_timer.start()
	else:
		touch_enabled = true

extends Node2D


const OFFSET := Vector2(23, 23) * 4
const TILE_SIZE := Vector2(26, 26) * 4
const MARGIN := Vector2(2, 2) * 4

const DROP_TIME := 0.1

const NUM_TILE_COLOURS := 4


func grid_to_world(grid_pos: Vector2) -> Vector2:
	var pos := grid_pos * (TILE_SIZE + MARGIN) + OFFSET - TILE_SIZE / 2
	return Vector2(pos.y, pos.x)


func world_to_grid(world_pos: Vector2) -> Vector2:
	var pos := (world_pos - OFFSET + TILE_SIZE / 2) / (TILE_SIZE + MARGIN)
	return Vector2(int(pos.y), int(pos.x))

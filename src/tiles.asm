; =============================================================================
;   tiles.asm - initial tile and playfield constants for LightCycles
; =============================================================================

GRID_COLS   = 32
GRID_ROWS   = 24

FIELD_LEFT   = 1
FIELD_RIGHT  = 30
FIELD_TOP    = 1
FIELD_BOTTOM = 22

ARENA_MIN_X  = 8
ARENA_MAX_X  = 247
ARENA_MIN_Y  = 8
ARENA_MAX_Y  = 183

TILE_BLANK   = 32
TILE_HEAD    = $80
TILE_BODY    = $88
TILE_FOOD    = $90
TILE_WALL    = $98
TILE_FRAME   = $A0

COLOR_HEAD   = (TMS_LT_GREEN  << 4) | TMS_BLACK
COLOR_BODY   = (TMS_MED_GREEN << 4) | TMS_BLACK
COLOR_FOOD   = (TMS_MED_RED   << 4) | TMS_BLACK
COLOR_WALL   = (TMS_GRAY      << 4) | TMS_DK_BLUE
COLOR_TEXT   = (TMS_WHITE     << 4) | TMS_BLACK

PATTERN_BASE   = $0800
PAT_HEAD_ADDR  = PATTERN_BASE + (TILE_HEAD*8)
PAT_BODY_ADDR  = PATTERN_BASE + (TILE_BODY*8)
PAT_FOOD_ADDR  = PATTERN_BASE + (TILE_FOOD*8)
PAT_WALL_ADDR  = PATTERN_BASE + (TILE_WALL*8)
PAT_FRAME_ADDR = PATTERN_BASE + (TILE_FRAME*8)

.segment "CART"

TileHeadData:
	.byte %00111100
	.byte %01111110
	.byte %11011011
	.byte %11111111
	.byte %11111111
	.byte %11111111
	.byte %01111110
	.byte %00111100

TileBodyData:
	.byte %00111100
	.byte %01111110
	.byte %11111111
	.byte %11111111
	.byte %11111111
	.byte %11111111
	.byte %01111110
	.byte %00111100

TileFoodData:
	.byte %00011000
	.byte %00111100
	.byte %01111110
	.byte %11111111
	.byte %11111111
	.byte %01111110
	.byte %00111100
	.byte %00011000

TileWallData:
	.byte %11111111
	.byte %11111111
	.byte %11111111
	.byte %11111111
	.byte %11111111
	.byte %11111111
	.byte %11111111
	.byte %11111111

TileFrameData:
	.byte %11111111
	.byte %11111111
	.byte %11111111
	.byte %11111111
	.byte %11111111
	.byte %11111111
	.byte %11111111
	.byte %11111111

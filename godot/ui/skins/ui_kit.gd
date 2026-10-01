extends RefCounted
class_name UiKit

# Drawing helpers every menu shares, so buttons, ribbons, bars and badges look
# and move the same everywhere. Everything is drawn in UI pixels (the game's
# 192x108 grid) with the skins' style boxes.

const RIBBON_TEXT : Color = Color(1.0, 0.95, 0.86)
const RIBBON_SHADOW : Color = Color(0.25, 0.05, 0.05, 0.9)
const NEW_COLOR : Color = Color(1.0, 0.86, 0.3)
# The HUD (toasts, the quest tracker, prompts over things) is drawn smaller than
# the menus, so it stays out of the way.
const HUD : float = 0.75


static func box(canvas : CanvasItem, style : StyleBox, area : Rect2, tint : Color = Color.WHITE) -> void:
	if not style:
		return
	# Style boxes draw right away, so tinting the shared one for a moment is safe.
	if style is StyleBoxTexture and tint != Color.WHITE:
		var copy : StyleBoxTexture = (style as StyleBoxTexture)
		var old : Color = copy.modulate_color
		copy.modulate_color = tint
		canvas.draw_style_box(copy, area)
		copy.modulate_color = old
	else:
		canvas.draw_style_box(style, area)

# Text with a one pixel outline when the color's alpha is above 0.
static func label(canvas : CanvasItem, font : Font, at : Vector2, text : String, size : int, color : Color, align : HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, width : float = -1.0, edge : Color = Color(0.0, 0.0, 0.0, 0.0)) -> void:
	if edge.a > 0.0:
		canvas.draw_string_outline(font, at, text, align, width, size, 2, edge)
	canvas.draw_string(font, at, text, align, width, size, color)

# The baseline that centers a line of text vertically in a box.
static func baseline(font : Font, area : Rect2, size : int) -> float:
	return roundf(area.position.y + (area.size.y + font.get_ascent(size) - font.get_descent(size) * 0.5) * 0.5)

static func text_width(font : Font, text : String, size : int) -> float:
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x

# A ribbon behind a title, centered on the x given. Returns its rect.
static func ribbon(canvas : CanvasItem, font : Font, skin : MenuSkin, center : float, top : float, title : String, size : int) -> Rect2:
	var width : float = ceilf(text_width(font, title, size)) + 16.0
	var area : Rect2 = Rect2(roundf(center - width * 0.5), top, width, size + 7.0)
	if skin and skin.ribbon:
		box(canvas, skin.ribbon, area)
		label(canvas, font, Vector2(area.position.x, baseline(font, area.grow_individual(0.0, 0.0, 0.0, -1.0), size)), title, size, RIBBON_TEXT, HORIZONTAL_ALIGNMENT_CENTER, area.size.x, RIBBON_SHADOW)
	else:
		label(canvas, font, Vector2(area.position.x, baseline(font, area, size)), title, size, skin.title if skin else Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, area.size.x)
	return area

# A skin button. It sinks a pixel while held and when it was just pressed.
static func button(canvas : CanvasItem, font : Font, skin : MenuSkin, area : Rect2, text : String, size : int, enabled : bool, hovered : bool, pressed : bool = false) -> void:
	var style : StyleBox = skin.buttonOff
	if enabled:
		style = skin.buttonDown if pressed else (skin.buttonHover if hovered else skin.button)
	var drop : float = 1.0 if pressed and enabled else 0.0
	box(canvas, style, Rect2(area.position + Vector2(0.0, drop), area.size))
	var color : Color = skin.buttonText if enabled else Color(skin.buttonText, 0.45)
	label(canvas, font, Vector2(area.position.x, baseline(font, area, size) + drop), text, size, color, HORIZONTAL_ALIGNMENT_CENTER, area.size.x)

# A tab on a paper page: the open one light with a line of ink under it,
# the others a shade darker.
static func paper_tab(canvas : CanvasItem, font : Font, area : Rect2, text : String, on : bool, hovered : bool, ink : Color, dim : Color) -> void:
	var paper : Color = Color(0.88, 0.8, 0.63)
	canvas.draw_rect(area, Color(0.45, 0.33, 0.2))
	canvas.draw_rect(area.grow(-1.0), paper if on else (paper.darkened(0.1) if hovered else paper.darkened(0.18)))
	if on:
		canvas.draw_rect(Rect2(area.position.x + 1.0, area.end.y - 1.0, area.size.x - 2.0, 1.0), ink)
	label(canvas, font, Vector2(area.position.x, baseline(font, area, 3)), text, 3, ink if on else dim, HORIZONTAL_ALIGNMENT_CENTER, area.size.x)

# A progress bar with a dark trough and a highlight on the fill.
static func bar(canvas : CanvasItem, area : Rect2, amount : float, fill : Color, back : Color = Color(0.04, 0.07, 0.13)) -> void:
	canvas.draw_rect(area, back)
	var inner : Rect2 = area.grow(-1.0) if area.size.y > 2.0 else area
	var width : float = roundf(inner.size.x * clampf(amount, 0.0, 1.0))
	if width <= 0.0:
		return
	canvas.draw_rect(Rect2(inner.position, Vector2(width, inner.size.y)), fill)
	if inner.size.y >= 2.0:
		canvas.draw_rect(Rect2(inner.position, Vector2(width, 1.0)), fill.lightened(0.35))

# A small rounded pill with text, like "NEW" or a price.
static func pill(canvas : CanvasItem, font : Font, right : Vector2, text : String, size : int, fill : Color, color : Color) -> Rect2:
	var width : float = ceilf(text_width(font, text, size)) + 4.0
	var area : Rect2 = Rect2(right.x - width, right.y, width, size + 3.0)
	canvas.draw_rect(area.grow_individual(-1.0, 0.0, -1.0, 0.0), fill)
	canvas.draw_rect(area.grow_individual(0.0, -1.0, 0.0, -1.0), fill)
	label(canvas, font, Vector2(area.position.x, baseline(font, area, size)), text, size, color, HORIZONTAL_ALIGNMENT_CENTER, area.size.x)
	return area

# A one pixel frame.
static func outline(canvas : CanvasItem, area : Rect2, color : Color) -> void:
	canvas.draw_rect(Rect2(area.position, Vector2(area.size.x, 1.0)), color)
	canvas.draw_rect(Rect2(area.position.x, area.end.y - 1.0, area.size.x, 1.0), color)
	canvas.draw_rect(Rect2(area.position.x, area.position.y + 1.0, 1.0, area.size.y - 2.0), color)
	canvas.draw_rect(Rect2(area.end.x - 1.0, area.position.y + 1.0, 1.0, area.size.y - 2.0), color)

# Corner brackets that breathe, for the thing the pointer is on.
static func brackets(canvas : CanvasItem, area : Rect2, color : Color, time : float) -> void:
	var out : float = 0.5 + 0.5 * sin(time * 6.0)
	var r : Rect2 = area.grow(out)
	var arm : float = minf(3.0, r.size.x * 0.3)
	for corner in [r.position, Vector2(r.end.x - 1.0, r.position.y), Vector2(r.position.x, r.end.y - 1.0), r.end - Vector2.ONE]:
		var sx : float = 1.0 if corner.x <= r.position.x else -1.0
		var sy : float = 1.0 if corner.y <= r.position.y else -1.0
		canvas.draw_rect(Rect2(Vector2(minf(corner.x, corner.x + sx * (arm - 1.0)), corner.y), Vector2(arm, 1.0)), color)
		canvas.draw_rect(Rect2(Vector2(corner.x, minf(corner.y, corner.y + sy * (arm - 1.0))), Vector2(1.0, arm)), color)

# An eased 0-1 value that overshoots a little, for pops.
static func pop(t : float) -> float:
	t = clampf(t, 0.0, 1.0) - 1.0
	return 1.0 + t * t * (2.7 * t + 1.7)

static func coins_text(amount : int) -> String:
	var text : String = str(absi(amount))
	var out : String = ""
	while text.length() > 3:
		out = "," + text.right(3) + out
		text = text.left(text.length() - 3)
	return ("-" if amount < 0 else "") + text + out

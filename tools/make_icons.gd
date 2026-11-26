extends SceneTree
## Regenerates every platform icon from `icon.svg` (T-026). Run with
## `task icons`. Uses only Godot, so there is no Pillow or iconutil step.
##
## Outputs (paths are the ones export_presets.cfg points at):
## - assets/art/ui/icon.ico: Windows, PNG entries at 16-256 px
## - assets/art/ui/icon.icns: macOS, PNG entries at 16-1024 px
## - assets/art/ui/android/main_192x192.png: Android legacy launcher icon
## - assets/art/ui/android/adaptive_foreground_432x432.png: icon.svg without
##   its id="background" element, scaled into the adaptive safe zone
## - assets/art/ui/android/adaptive_background_432x432.png: that
##   background element's fill colour

const SOURCE: String = "res://icon.svg"
const UI_DIR: String = "res://assets/art/ui"
const ICO_SIZES: Array[int] = [16, 24, 32, 48, 64, 128, 256]
## ICNS element types that hold PNG data, and their pixel size. "icp6" is
## left out: iconutil reads it as 48 px, and "ic12" already covers 64 px.
const ICNS_TYPES: Dictionary[String, int] = {
	"icp4": 16,
	"icp5": 32,
	"ic07": 128,
	"ic08": 256,
	"ic09": 512,
	"ic10": 1024,
	"ic11": 32,
	"ic12": 64,
	"ic13": 256,
	"ic14": 512,
}
const SVG_SIZE: float = 128.0
const ADAPTIVE_SIZE: int = 432
## Android keeps the centre 66 dp of a 108 dp adaptive icon always visible,
## so the artwork is scaled to fit inside that circle.
const ADAPTIVE_SAFE_FRACTION: float = 66.0 / 108.0


func _initialize() -> void:
	var svg: String = FileAccess.get_file_as_string(SOURCE)
	if svg.is_empty():
		push_error("make_icons: cannot read %s" % SOURCE)
		quit(1)
		return
	var ok: bool = true
	ok = _write(UI_DIR.path_join("icon.ico"), _ico(svg)) and ok
	ok = _write(UI_DIR.path_join("icon.icns"), _icns(svg)) and ok
	ok = _save_png(_render(svg, 192), UI_DIR.path_join("android/main_192x192.png")) and ok
	var foreground: Image = _render(_without_background(svg), ADAPTIVE_SIZE, ADAPTIVE_SAFE_FRACTION)
	ok = _save_png(foreground, UI_DIR.path_join("android/adaptive_foreground_432x432.png")) and ok
	var background := Image.create(ADAPTIVE_SIZE, ADAPTIVE_SIZE, false, Image.FORMAT_RGBA8)
	background.fill(_background_color(svg))
	ok = _save_png(background, UI_DIR.path_join("android/adaptive_background_432x432.png")) and ok
	print("make_icons: ", "done" if ok else "FAILED")
	quit(0 if ok else 1)


## Renders `svg` to a `size` x `size` image. With `fraction` < 1 the artwork
## is drawn smaller and centred on a transparent canvas.
func _render(svg: String, size: int, fraction: float = 1.0) -> Image:
	var art := Image.new()
	art.load_svg_from_string(svg, size * fraction / SVG_SIZE)
	art.convert(Image.FORMAT_RGBA8)
	if fraction >= 1.0:
		return art
	var canvas := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var offset: Vector2i = (Vector2i(size, size) - art.get_size()) / 2
	canvas.blend_rect(art, Rect2i(Vector2i.ZERO, art.get_size()), offset)
	return canvas


func _ico(svg: String) -> PackedByteArray:
	var count: int = ICO_SIZES.size()
	var out := PackedByteArray()
	out.resize(6 + 16 * count)
	out.encode_u16(0, 0)
	out.encode_u16(2, 1)
	out.encode_u16(4, count)
	var offset: int = out.size()
	var blobs: Array[PackedByteArray] = []
	for i: int in count:
		var size: int = ICO_SIZES[i]
		var png: PackedByteArray = _render(svg, size).save_png_to_buffer()
		var entry: int = 6 + 16 * i
		out.encode_u8(entry, size % 256)
		out.encode_u8(entry + 1, size % 256)
		out.encode_u8(entry + 2, 0)
		out.encode_u8(entry + 3, 0)
		out.encode_u16(entry + 4, 1)
		out.encode_u16(entry + 6, 32)
		out.encode_u32(entry + 8, png.size())
		out.encode_u32(entry + 12, offset)
		offset += png.size()
		blobs.append(png)
	for png: PackedByteArray in blobs:
		out.append_array(png)
	return out


func _icns(svg: String) -> PackedByteArray:
	var body := PackedByteArray()
	for type: String in ICNS_TYPES:
		var png: PackedByteArray = _render(svg, ICNS_TYPES[type]).save_png_to_buffer()
		body.append_array(type.to_ascii_buffer())
		body.append_array(_u32_be(png.size() + 8))
		body.append_array(png)
	var out := PackedByteArray("icns".to_ascii_buffer())
	out.append_array(_u32_be(body.size() + 8))
	out.append_array(body)
	return out


func _u32_be(value: int) -> PackedByteArray:
	return PackedByteArray(
		[(value >> 24) & 0xFF, (value >> 16) & 0xFF, (value >> 8) & 0xFF, value & 0xFF]
	)


func _background_element(svg: String) -> RegExMatch:
	var re := RegEx.create_from_string('<[^<>]*id="background"[^<>]*/>')
	return re.search(svg)


func _without_background(svg: String) -> String:
	var found: RegExMatch = _background_element(svg)
	if found == null:
		push_error("make_icons: icon.svg has no id=\"background\" element")
		return svg
	return svg.replace(found.get_string(), "")


func _background_color(svg: String) -> Color:
	var found: RegExMatch = _background_element(svg)
	if found == null:
		return Color.BLACK
	var fill: RegExMatch = RegEx.create_from_string('fill="(#[0-9a-fA-F]{6})"').search(
		found.get_string()
	)
	return Color.html(fill.get_string(1)) if fill != null else Color.BLACK


func _write(path: String, bytes: PackedByteArray) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("make_icons: cannot write %s" % path)
		return false
	file.store_buffer(bytes)
	print("make_icons: wrote ", path, " (", bytes.size(), " bytes)")
	return true


func _save_png(image: Image, path: String) -> bool:
	var err: Error = image.save_png(path)
	if err != OK:
		push_error("make_icons: cannot write %s (%d)" % [path, err])
		return false
	print("make_icons: wrote ", path)
	return true

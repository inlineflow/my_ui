package my_ui

import ft "shared:freetype"

Glyph :: struct {
  texture_id: u32,
  size: [2]u32,
  bearing: [2]i32,
  advance: u32,
}

Line :: struct {
  text: [dynamic]rune,
}

Editor :: struct {
  cursor_pos: [2]u32,
  lines: [dynamic]Line,
  face: ft.Face,
  glyphs: map[rune]Glyph,
  font_rd: UI_Rect_Render_Data,
  line_height_px: u32,
  max_advance_px: u32,
}

push_char :: proc(editor: ^Editor, char: rune) {
  line_index := editor.cursor_pos.y
  line := &editor.lines[line_index].text
  append(line, char)
  editor.cursor_pos.x += 1
}


package my_ui

import ft "shared:freetype"
import "core:fmt"
import "core:math"

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
  cursor_pos: [2]i32,
  lines: [dynamic]Line,
  face: ft.Face,
  glyphs: map[rune]Glyph,
  font_rd: UI_Rect_Render_Data,
  line_height_px: u32,
  max_advance_px: u32,
}

push_char :: proc(editor: ^Editor, char: rune) {
  if char < 32 || char > 126 {
    when ODIN_DEBUG {
      fmt.printfln("tried to print non ASCII: %v", char)
    }
    return
  }
  
  fmt.println("cur: ", editor.cursor_pos)
  line_index := editor.cursor_pos.y - 1
  line := &editor.lines[line_index].text
  append(line, char)
  editor.cursor_pos.x += 1
}

// TODO: going up is broken
place_cursor :: proc(editor: ^Editor, new_target_pos: [2]i32) {
      // assert(editor.cursor_pos.x > 0 && editor.cursor_pos.y > 0)
      new_target_pos := new_target_pos
      fmt.println("new_target_pos: ", new_target_pos)
      new_line_index := math.max(math.min(cast(i32)len(editor.lines), new_target_pos.y) - 1, 0)
      assert(new_line_index >= 0)
      new_column := math.max(math.min(cast(i32)len(editor.lines[new_line_index - 1].text) + 1, cast(i32)new_target_pos.x), 1)
      assert(new_column >= 0)
      new_pos := [2]i32{
        new_column,
        new_line_index + 1,
      }
      fmt.println("new_pos: ", new_pos)
      editor.cursor_pos = new_pos
}

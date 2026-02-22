package my_ui

import ft "shared:freetype"
import "core:fmt"
import "core:math"
import "core:unicode/utf8"
import "core:slice"
import "core:strings"

DEFAULT_COLUMN_LENGTH :: 80

Glyph :: struct {
  texture_id: u32,
  size: [2]u32,
  bearing: [2]i32,
  advance: u32,
}

Line :: struct {
  buf: [dynamic]byte,
  reserved_starts_at: int,
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

// push_new_line :: proc(editor: ^Editor, pre_alloc_chars: int) {
//   l := Line {
//     buf = make([dynamic]byte, 0, pre_alloc_chars),
//   }
// }

push_char :: proc(editor: ^Editor, char: rune, #any_int index: int = -1) {
  if char < 32 || char > 126 {
    when ODIN_DEBUG {
      fmt.printfln("tried to print non ASCII: %v", char)
    }
    return
  }
  
  line_index := editor.cursor_pos.y - 1
  line := &editor.lines[line_index]
  bytes, byte_count := utf8.encode_rune(char)
  if index == -1 {
    append(&line.buf, ..bytes[:byte_count])
    line.reserved_starts_at += 1
    editor.cursor_pos.x += 1
  } else {
    left := line.buf[:editor.cursor_pos.x - 1]
    right := slice.clone(line.buf[editor.cursor_pos.x - 1:], context.temp_allocator)
    resize(&line.buf, len(left))
    append(&line.buf, ..bytes[:byte_count])
    append(&line.buf, ..right)
    line.reserved_starts_at += 1
    editor.cursor_pos.x += 1
    free_all(context.temp_allocator)
  }
}

get_editor_text :: proc(e: ^Editor, allocator := context.allocator) -> string {
  lines_str := make([dynamic]string, context.temp_allocator)
  for l in e.lines {
    append(&lines_str, string(l.buf[:l.reserved_starts_at]))
  }
  text := strings.join(lines_str[:], "\n", context.temp_allocator)
  return text
}

// TODO: going up is broken
place_cursor :: proc(editor: ^Editor, new_target_pos: [2]i32) {
      // assert(editor.cursor_pos.x > 0 && editor.cursor_pos.y > 0)
      new_target_pos := new_target_pos
      // fmt.println("new_target_pos: ", new_target_pos)
      // new_line_index := math.max(math.min(cast(i32)len(editor.lines), new_target_pos.y) - 1, 0)
      new_line := math.max(math.min(cast(i32)len(editor.lines), new_target_pos.y), 1)
      assert(new_line >= 1)
      new_column := math.max(math.min(cast(i32)len(editor.lines[new_line - 1].buf) + 1, cast(i32)new_target_pos.x), 1)
      assert(new_column >= 1)
      new_pos := [2]i32{
        new_column,
        new_line,
      }
      // fmt.println("new_pos: ", new_pos)
      editor.cursor_pos = new_pos
}

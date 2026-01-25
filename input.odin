package my_ui

import sdl "sdl2"

handle_input :: proc(event: sdl.Event) {
  #partial switch event.key.keysym.sym {
  case .ESCAPE:
    break main_loop
  case .A..<.Z:
    // fmt.println(event.key.keysym.sym)
    push_char(&editor_window.editor, rune(event.key.keysym.sym))
    // append(&editor_window.text_buf, rune(event.key.keysym.sym))
  case .DOWN:
    fmt.println("down")
    editor_window.editor.cursor_pos.y += 1
  case .UP:
    fmt.println("up")
    editor_window.editor.cursor_pos.y -= 1
  case .RIGHT:
    fmt.println("right")
    editor_window.editor.cursor_pos.x += 1
  case .LEFT:
    fmt.println("left")
    editor_window.editor.cursor_pos.x -= 1
  case .RETURN:
    l := Line {
      text = make([dynamic]rune),
    }
    append(&editor_window.editor.lines, l)
    editor_window.editor.cursor_pos.y += 1
    editor_window.editor.cursor_pos.x = 0
  }
}

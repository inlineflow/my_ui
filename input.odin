package my_ui

import sdl "sdl2"
import "core:fmt"
import "core:strings"
import "core:math"
import "core:slice"
import "core:mem"

Cmd_Type :: enum {
  Editor_Cursor_Up,
  Editor_Cursor_Right,
  Editor_Cursor_Down,
  Editor_Cursor_Left,
  Editor_Text,
  Editor_Paste,
  Editor_Copy,
  Editor_Cursor_Move,
  Editor_Newline,
  Editor_Backspace,
  Editor_Tab,
  Game_Move_Up,
  Global_Pause,
  Global_Unpause,
}

Cmd_List :: bit_set[Cmd_Type]

Mouse_Button :: enum {
  Left = 1,
  Middle,
  Right,
}

Mouse_Button_State :: enum {
  None,
  Up,
  Down,
}

Mouse_Click :: struct {
  // button: Mouse_Button,
  pos: [2]i32,
  state: Mouse_Button_State,
}

Mouse_Input_Data :: struct {
    pos: [2]i32,
    rel: [2]i32,
    clicks: [Mouse_Button]Mouse_Click,
  }

Input_Data :: struct {
  text: string,
  mouse: Mouse_Input_Data,
}

// Cmd_Editor :: enum {
//   Cursor_Up,
//   Cursor_Right,
//   Cursor_Down,
//   CursorLeft,
//   Paste,
//   Copy,
//   Cursor_Move,
// }
//
// Cmd_Game :: enum {
//   Move_Up = int(max(Cmd_Editor)),
// }

// Cmd :: bit_set[cast(int)Cmd_Editor.Cursor_Up..<cast(int)Cmd_Game.Move_Up]

// Cmd :: union {
//   Cmd_Editor,
// }

Game_State_Type :: enum {
  Editor_Active,
  Game_Active,
  Global_Paused,
}

Game_State :: bit_set[Game_State_Type]

process_input :: proc(events: []sdl.Event, state:Game_State_Type, last_frame_input: Input_Data) -> (cmd_list: Cmd_List, res: Input_Data) {
  // TODO: this is an ugly hack, kinda have to fix that later
  for b, i in last_frame_input.mouse.clicks {
    if b.state == .Down {
      res.mouse.clicks[i] = b
    }
  }

  for &e in events {
    if e.type == .QUIT {
      cmd_list += { .Global_Pause }
    }
  }

  switch state {
  case .Editor_Active: {
    for &event in events {
      #partial switch event.type {
        case .KEYDOWN: {
          #partial switch event.key.keysym.sym {
            case .ESCAPE:
              cmd_list += {.Global_Pause}
          }

          #partial switch event.key.keysym.scancode {
            case .UP:
              cmd_list += { .Editor_Cursor_Up }
            case .RIGHT:
              cmd_list += { .Editor_Cursor_Right }
            case .DOWN:
              cmd_list += { .Editor_Cursor_Down }
            case .LEFT:
              cmd_list += { .Editor_Cursor_Left }
            case .RETURN:
              cmd_list += { .Editor_Newline }
            case .BACKSPACE:
              cmd_list += { .Editor_Backspace }
            case .TAB:
              cmd_list += { .Editor_Tab }
          }
        }

        case .MOUSEMOTION:
          m := [2]i32{ event.motion.x, event.motion.y }
          rel := [2]i32{ event.motion.xrel, event.motion.yrel }
          res.mouse.pos = m
          res.mouse.rel = rel

        case .MOUSEBUTTONDOWN:
          click := [2]i32{ event.button.x, event.button.y }
          b := cast(Mouse_Button)event.button.button
          res.mouse.clicks[b] = {
            pos = click,
            state = .Down,
          }

        case .MOUSEBUTTONUP:
          click := [2]i32{ event.button.x, event.button.y }
          b := cast(Mouse_Button)event.button.button
          res.mouse.clicks[b] = {
            pos = click,
            state = .Up,
          }

        case .TEXTINPUT:
          fmt.println(event.text.text)
          cs := cstring(raw_data(event.text.text[:]))
          s := strings.clone_from_cstring(cs)
          res.text = s
          fmt.println(s)
          cmd_list += { .Editor_Text }
      }
    }
  }
    case .Game_Active: {

    }
    case .Global_Paused: {
      for &event in events {
        if event.type == .KEYDOWN {
          if event.key.keysym.sym == .ESCAPE {
            cmd_list += { .Global_Unpause }
          }
        }
      }
    }
  }

  return cmd_list, res
}

ui_handle_input :: proc(ui: UI_Data, cmds: Cmd_List, input_data: Input_Data) {
  click := input_data.mouse.clicks[Mouse_Button.Left]
  // fmt.println(click)
  for w in ui.windows {
    if w == nil {
      continue
    }

    if click.state == .Down {
      h := w.handle
      if cast(f32)click.pos.x > w.pos.x && cast(f32)click.pos.x < w.pos.x + w.size.x && cast(f32)click.pos.y > w.pos.y + h.size.y && cast(f32)click.pos.y < w.pos.y + w.size.y {
          // fmt.println("in window by x and y")
          w.state += { .ACTIVE }
      } else {
          w.state -= { .ACTIVE }
      }

      if cast(f32)click.pos.x > w.pos.x && cast(f32)click.pos.x < w.pos.x + h.size.x && cast(f32)click.pos.y > w.pos.y && cast(f32)click.pos.y < w.pos.y + h.size.y {
        // fmt.println("we're in handle by x and y")
        w.state += { .DRAGGED, .CLICKED, .ACTIVE }
      }

      if .DRAGGED in w.state {
          w.pos += [2]f32 { cast(f32)input_data.mouse.rel.x, cast(f32)input_data.mouse.rel.y }
      }
    } else {
      w.state -= { .DRAGGED }
    }
  }

}

text_editor_handle_input :: proc(editor_win: ^UI_Editor_Window, cmds: Cmd_List, input: Input_Data) {
  w := editor_win
  editor := w.editor
  h := w.handle
  for click in input.mouse.clicks {
    if cast(f32)click.pos.x > w.pos.x && cast(f32)click.pos.x < w.pos.x + w.size.x && cast(f32)click.pos.y > w.pos.y + h.size.y && cast(f32)click.pos.y < w.pos.y + w.size.y {
      // fmt.println("we're in the text box")
      // detect cursor hit here
      hit := [2]i32{click.pos.x, click.pos.y} - {cast(i32)w.pos.x, cast(i32)w.pos.y}
      // hit := [2]u32{cast
      hit_line_column:[2]i32 = {hit.x / cast(i32)w.editor.max_advance_px, (hit.y / cast(i32)w.editor.line_height_px)}
      place_cursor(w.editor, hit_line_column)
      // new_line := math.min(math.min(cast(u32)len(w.editor.lines), cast(u32)hit.y) - 1, 0)
      // assert(new_line >= 0)
      // new_column := math.min(cast(u32)len(w.editor.lines[new_line].text), cast(u32)hit.x)
      // new_pos := [2]u32{
      //   new_column,
      //   new_line,
      // }
      // w.editor.cursor_pos = new_pos
      // fmt.println(new_pos)

      // fmt.println([2]f32{cast(f32)click.pos.x, cast(f32)click.pos.y} - w.pos)
    }
  }

  if .Editor_Tab in cmds {
    for i in 0..<2 {
      pos := editor.cursor_pos.x - 1
      push_char(editor_win.editor, ' ', pos)
    }
  }

  if .Editor_Text in cmds {
    for r in input.text {
      // fmt.println(r)
      // TODO: detect the cursor position and inject the character at that position
      pos := editor.cursor_pos.x - 1
      push_char(editor_win.editor, r, pos)
      // pos := editor.cursor_pos.x - 1
      // current_line_index := w.editor.cursor_pos.y - 1
      // current_line := &w.editor.lines[current_line_index]
      // inject_at(current_line.buf, pos, r)
    }
    // fmt.println(input.text)
  }

  switch cmds {
    case {.Editor_Cursor_Up}:
      new_pos := [2]i32{w.editor.cursor_pos.x, w.editor.cursor_pos.y - 1}
      place_cursor(w.editor, new_pos)
    case {.Editor_Cursor_Right}:
      new_pos := [2]i32{w.editor.cursor_pos.x + 1, w.editor.cursor_pos.y}
      place_cursor(w.editor, new_pos)
    case {.Editor_Cursor_Down}:
      new_pos := [2]i32{w.editor.cursor_pos.x, w.editor.cursor_pos.y + 1}
      place_cursor(w.editor, new_pos)
    case {.Editor_Cursor_Left}:
      new_pos := [2]i32{w.editor.cursor_pos.x - 1, w.editor.cursor_pos.y}
      place_cursor(w.editor, new_pos)
    case {.Editor_Newline}:
      current_line_index := w.editor.cursor_pos.y - 1
      current_line := &w.editor.lines[current_line_index]
      current_line_str := string(current_line.buf[:current_line.reserved_starts_at])

      // TODO: fix this
      if current_line_str == "" {
        l := Line {
          buf = make([dynamic]byte),
        }
        // append(&w.editor.lines, l)
        inject_at(&w.editor.lines, current_line_index + 1, l)
        new_pos := [2]i32{0, w.editor.cursor_pos.y + 1 }
        place_cursor(w.editor, new_pos)
      } else {
        // TODO: this indexes using ASCII, won't work with arbitrary UTF-8 | maybe I should fix that
        cur := w.editor.cursor_pos.x - 1
        left := current_line_str[:cur]
        right := current_line_str[cur:]
        new_line_buf, err := slice.clone_to_dynamic(transmute([]byte)right)
        if err != nil {
          fmt.eprintln("Couldn't clone text to dynamic array when creating a new line")
          return
        }

        reserve(&new_line_buf, DEFAULT_COLUMN_LENGTH)
        l := Line {
          buf = new_line_buf,
          text = string(new_line_buf[:]),
          reserved_starts_at = len(right),
        }
        // append(&w.editor.lines, l)

        leftover_len := len(left)
        current_line.reserved_starts_at = leftover_len
        current_line.text = string(current_line.buf[:current_line.reserved_starts_at])
        resize(&current_line.buf, leftover_len)
        inject_at(&w.editor.lines, current_line_index + 1, l)
        new_pos := [2]i32{0, w.editor.cursor_pos.y + 1 }
        place_cursor(w.editor, new_pos)
        // fmt.println("left: ", left)
        // fmt.println("right: ", right)
      }

    case {.Editor_Backspace}:
      if editor.cursor_pos == {1, 1} { return }

      current_line_index := w.editor.cursor_pos.y - 1
      current_line := &w.editor.lines[current_line_index]
      current_line_str := string(current_line.buf[:current_line.reserved_starts_at])
      delete_index := editor.cursor_pos.x - 2
      if len(current_line.buf) == 0 {
        ordered_remove(&editor.lines, current_line_index)
        editor.cursor_pos.y -= 1
        new_line := editor.lines[current_line_index - 1]
        editor.cursor_pos.x = cast(i32)len(new_line.buf) + 1
      } else if editor.cursor_pos.x == cast(i32)len(current_line.buf) + 1 {
        pop(&current_line.buf)
        current_line.reserved_starts_at -= 1
        editor.cursor_pos.x -= 1
      } else if delete_index >= 0 {
        ordered_remove(&current_line.buf, delete_index)
        current_line.reserved_starts_at -= 1
        editor.cursor_pos.x -= 1
      }
  }
}

// handle_input :: proc(event: sdl.Event) {
//   #partial switch event.key.keysym.sym {
//   case .ESCAPE:
//     break main_loop
//   case .A..<.Z:
//     // fmt.println(event.key.keysym.sym)
//     push_char(&editor_window.editor, rune(event.key.keysym.sym))
//     // append(&editor_window.text_buf, rune(event.key.keysym.sym))
//   case .DOWN:
//     fmt.println("down")
//     editor_window.editor.cursor_pos.y += 1
//   case .UP:
//     fmt.println("up")
//     editor_window.editor.cursor_pos.y -= 1
//   case .RIGHT:
//     fmt.println("right")
//     editor_window.editor.cursor_pos.x += 1
//   case .LEFT:
//     fmt.println("left")
//     editor_window.editor.cursor_pos.x -= 1
//   case .RETURN:
//     l := Line {
//       text = make([dynamic]rune),
//     }
//     append(&editor_window.editor.lines, l)
//     editor_window.editor.cursor_pos.y += 1
//     editor_window.editor.cursor_pos.x = 0
//   }
// }

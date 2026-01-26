package my_ui

import sdl "sdl2"
import "core:fmt"
import "core:strings"

Cmd_Type :: enum {
  Editor_Cursor_Up,
  Editor_Cursor_Right,
  Editor_Cursor_Down,
  Editor_Cursor_Left,
  Editor_Paste,
  Editor_Copy,
  Editor_Cursor_Move,
  Editor_Newline,
  Game_Move_Up,
  Global_Pause,
}

Cmd_List :: bit_set[Cmd_Type]

Input_Data :: struct {
  text: string,
  mouse: [2]i32,
  mouse_rel: [2]i32,
  // m := v2{cast(f32)event.motion.x, cast(f32)event.motion.y}
  // rel := v2{cast(f32)event.motion.xrel, cast(f32)event.motion.yrel}
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

handle_input :: proc(event: ^sdl.Event, state:^Game_State,  cmd_list: ^Cmd_List) -> Input_Data {
  res: Input_Data
  #partial switch event.type {
    case .KEYDOWN: {
      #partial switch event.key.keysym.sym {
        case .ESCAPE:
          cmd_list^ += {.Global_Pause}
          state^ += {.Global_Paused}
      }
      #partial switch event.key.keysym.scancode {
        case .UP:
          cmd_list^ += { .Editor_Cursor_Up }
        case .RIGHT:
          cmd_list^ += { .Editor_Cursor_Right }
        case .DOWN:
          cmd_list^ += { .Editor_Cursor_Down }
        case .LEFT:
          cmd_list^ += { .Editor_Cursor_Left }
        case .RETURN:
          cmd_list^ += { .Editor_Newline }
      }
    }

  case .MOUSEMOTION:
      m := [2]i32{ event.motion.x, event.motion.y }
      rel := [2]i32{ event.motion.xrel, event.motion.yrel }
      res.mouse = m
      res.mouse_rel = rel

    case .TEXTINPUT:
      if .Editor_Active in state^ {
        fmt.println(event)
        cs := cstring(raw_data(&event.text.text))
        res.text = strings.clone_from_cstring(cs)
      }
  }

  return res
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

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

// TODO: clean up the api
// this proc probably shouldn't update the state of the game, just read it
// handle_input :: proc(event: ^sdl.Event, state: Game_State) -> (Cmd_List, Input_Data)
// handle_input :: proc(event: ^sdl.Event, state:^Game_State,  cmd_list: ^Cmd_List) -> Input_Data {
handle_input :: proc(events: []sdl.Event, state:Game_State) -> (cmd_list: Cmd_List, res: Input_Data) {
  for &event in events {
    #partial switch event.type {
      case .KEYDOWN: {
        #partial switch event.key.keysym.sym {
          case .ESCAPE:
            cmd_list += {.Global_Pause}
            // state^ += {.Global_Paused}
        }
        // TODO: fix this shit
        #partial switch event.key.keysym.scancode {
          case .UP:
            if .Editor_Active in state {
              cmd_list += { .Editor_Cursor_Up }
            }
          case .RIGHT:
            if .Editor_Active in state {
              cmd_list += { .Editor_Cursor_Right }
            }
          case .DOWN:
            if .Editor_Active in state {
              cmd_list += { .Editor_Cursor_Down }
            }
          case .LEFT:
            if .Editor_Active in state {
              cmd_list += { .Editor_Cursor_Left }
            }
          case .RETURN:
            if .Editor_Active in state {
              cmd_list += { .Editor_Newline }
            }
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
        if .Editor_Active in state {
          fmt.println(event)
          cs := cstring(raw_data(&event.text.text))
          res.text = strings.clone_from_cstring(cs)
        }
    }
  }

  return cmd_list, res
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

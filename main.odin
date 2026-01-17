package my_ui

import sdl "sdl2"
import gl "opengl"
import glm "core:math/linalg/glsl"
import lin "core:math/linalg"
import "core:fmt"
import "core:os"
import "core:strings"

v2 :: [2]f32
v3 :: [3]f32

START_WINDOW_WIDTH :: 1280
START_WINDOW_HEIGHT :: 720

UI_Rect_Render_Data :: struct {
  vao: u32,
  vbo: u32,
  shader_id: u32,
  uniforms: gl.Uniforms,
}

UI_Window :: struct {
  pos: v2,
  size: v2,
  rd: ^UI_Rect_Render_Data,
  color: v3,
  state: bit_set[UI_Element_State],
  handle: struct {
    size: v2,
  },
  buttons: []UI_Button,
}

OS_Window :: struct {
  size: v2,
}

UI_Element_State :: enum {
  HOVERED,
  CLICKED,
  DRAGGED,
  DROPPED,
  RESIZING,
}

UI_Button :: struct {
  pos: v2,
  size: v2,
  state: bit_set[UI_Element_State],
  rd: ^UI_Rect_Render_Data,
  color: v3,
}

projection := glm.mat4Ortho3d(0, START_WINDOW_WIDTH, START_WINDOW_HEIGHT, 0, -1, 1)

root_os_window := OS_Window{{ START_WINDOW_WIDTH, START_WINDOW_HEIGHT }}

ui_draw_rect :: proc(pos, size: v2, rd: UI_Rect_Render_Data, color: v3) {
  gl.UseProgram(rd.shader_id)
  color := color
  translate := glm.mat4Translate(v3{pos.x, pos.y, 1.0})
  scale_offset_plus := glm.mat4Translate(v3{0.5 * size.x, 0.5 * size.y, 0})
  scale_offset_minus := glm.mat4Translate(v3{-0.5 * size.x, -0.5 * size.y, 0})
  scale := glm.mat4Scale(v3{size.x, size.y, 1.0})
  transform := translate * scale_offset_plus * scale_offset_minus * scale

  gl.UniformMatrix4fv(rd.uniforms["model"].location, 1, false, &transform[0][0])
  gl.UniformMatrix4fv(rd.uniforms["projection"].location, 1, false, &projection[0][0])
  gl.Uniform3fv(rd.uniforms["in_color"].location, 1, &color[0])

  gl.BindVertexArray(rd.vao); defer gl.BindVertexArray(0)
  gl.DrawArrays(gl.TRIANGLES, 0, 6)
}

ui_setup_rect_rd :: proc(vertex_filepath, fragment_filepath: string) -> (rd: UI_Rect_Render_Data, ok: bool) {
  vertex_source_data, vert_source_ok := os.read_entire_file_from_filename(vertex_filepath, context.temp_allocator)
  if !vert_source_ok {
    return 
  }

  fragment_source_data, frag_source_ok := os.read_entire_file_from_filename(fragment_filepath, context.temp_allocator)
  if !frag_source_ok {
    return 
  }

  vert_source := strings.clone_to_cstring(string(vertex_source_data), context.temp_allocator)
  frag_source := strings.clone_to_cstring(string(fragment_source_data), context.temp_allocator)

  program, program_ok := gl.load_shaders_source(string(vert_source), string(frag_source))
  if !program_ok {
    fmt.eprintln("Failed to create GLSL program")
    return
  }
  
  uniforms := gl.get_uniforms_from_program(program)
  vao, vbo: u32
  vertices := [?]f32 {
    // pos    
    0.0, 1.0,
    1.0, 0.0,
    0.0, 0.0,
    0.0, 1.0,
    1.0, 1.0,
    1.0, 0.0,
  }

  gl.GenVertexArrays(1, &vao)
  gl.GenBuffers(1, &vbo)
  gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
  gl.BufferData(gl.ARRAY_BUFFER, size_of(vertices), &vertices, gl.STATIC_DRAW)

  gl.BindVertexArray(vao)
  gl.EnableVertexAttribArray(0)
  gl.VertexAttribPointer(0, 2, gl.FLOAT, gl.FALSE, 2 * size_of(f32), 0)
  gl.BindBuffer(gl.ARRAY_BUFFER, 0)
  gl.BindVertexArray(0)

  return UI_Rect_Render_Data {
    uniforms = uniforms,
    shader_id = program,
    vao = vao,
    vbo = vbo,
  }, true

}

button :: proc(b: UI_Button) -> bool {
  ui_draw_rect(b.pos, b.size, b.rd^, b.color)
  return true
}

draw_window :: proc(w: UI_Window) -> bool {
  ui_draw_rect(w.pos, w.size, w.rd^, w.color)
  for b in w.buttons {
    ui_draw_rect(w.pos + b.pos, b.size, b.rd^, b.color)
  }
  ui_draw_rect(w.pos, w.handle.size, w.rd^, {0.1, 0.7, 0.1})
  return true
}


main :: proc() {

  sdl.Init({.TIMER, .VIDEO})

  window := sdl.CreateWindow("SDL2", sdl.WINDOWPOS_UNDEFINED, sdl.WINDOWPOS_UNDEFINED, START_WINDOW_WIDTH, START_WINDOW_HEIGHT, {.OPENGL, .RESIZABLE} )
  if window == nil {
    fmt.eprintln("Failed to create window")
    return
  }
  defer sdl.DestroyWindow(window)

  gl_context := sdl.GL_CreateContext(window)
  sdl.GL_MakeCurrent(window, gl_context)
  gl.load_up_to(3, 3, sdl.gl_set_proc_address)
  gl.Viewport(0, 0, START_WINDOW_WIDTH, START_WINDOW_HEIGHT)


  ui_rect_rd, ui_rect_rd_ok := ui_setup_rect_rd("shaders/default.vert", "shaders/default.frag")
  assert(ui_rect_rd_ok)


  now:u64 = 0
  last: u64 = sdl.GetPerformanceCounter()
  dt: f32 = 0
  freq := sdl.GetPerformanceFrequency()

  b := UI_Button{
    pos = {0, 0},
    size = {400, 200},
    rd = &ui_rect_rd,
    color = {1, 1, 1},
  }

  editor_window := UI_Window{
    pos = root_os_window.size / 2 - {800, 600} / 2,
    size = {800, 600},
    color = {0.8, 0.8, 0.8},
    rd = &ui_rect_rd,
    buttons = { b },
    handle = { size = { 800, 25 } },
  }

  main_loop: for {

    now = sdl.GetPerformanceCounter()
    elapsed_ticks: u64 = now - last
    dt = cast(f32)(cast(f64)elapsed_ticks / cast(f64)freq) // in seconds
    last = now


    event: sdl.Event
    for sdl.PollEvent(&event) {
      #partial switch event.type {
      // case .KEYDOWN: 
      //   fallthrough
      // case .KEYUP:

      case .KEYDOWN:
        #partial switch event.key.keysym.sym {
        case .ESCAPE:
          break main_loop
        }

      case .MOUSEMOTION:
        fmt.println(event.motion.x, event.motion.y)
        // editor_window.color = {cast(f32)event.motion.x / editor_window.size.x, cast(f32)event.motion.y / editor_window.size.y, 1}
        m := v2{cast(f32)event.motion.x, cast(f32)event.motion.y}
        rel := v2{cast(f32)event.motion.xrel, cast(f32)event.motion.yrel}
        w := &editor_window
        if m.x > w.pos.x && m.x < w.pos.x + w.size.x && m.y > w.pos.y && m.y < w.pos.y + w.size.y {
            fmt.println("in window by x and y")
        }
        fmt.println(event.motion)

        if .DRAGGED in w.state {
          w.pos += rel
        }
      case .MOUSEBUTTONDOWN:
        fmt.println(event.button.x, event.button.y)
        click := v2{cast(f32)event.button.x, cast(f32)event.button.y}
        // w_pos := editor_window.pos
        // w := editor_window
        // if click.x > w.pos.x && click.x < w.pos.x + w.size.x && click.y > w.pos.y && click.y < w.pos.y + w.size.y {
        //     fmt.println("in window by x and y")
        // }


        w := &editor_window
        h := editor_window.handle
        if click.x > w.pos.x && click.x < w.pos.x + h.size.x && click.y > w.pos.y && click.y < w.pos.y + h.size.y {
          fmt.println("we're in handle by x and y")
          w.state += { .DRAGGED, .CLICKED }
        }
      case .MOUSEBUTTONUP:
        editor_window.state -= { .DRAGGED, .CLICKED }

      case .QUIT: 
        break main_loop
      case .WINDOWEVENT:
          width: i32
          height: i32

          sdl.GL_GetDrawableSize(window, &width, &height)
          // game.width = width
          // game.height = height
          projection = glm.mat4Ortho3d(0, cast(f32)width, cast(f32)height, 0, -1, 1)
          gl.Viewport(0, 0, width, height)
      }
    }

    gl.ClearColor(1.0, 0.8039, 0.7882, 1.0) // FFCDC9
    gl.Clear(gl.COLOR_BUFFER_BIT)

    // ui_draw_rect({200, 200}, {200, 200}, ui_rect_rd, {1, 1, 1})
    // button(b)

    draw_window(editor_window)
    fmt.println(editor_window.state)
    sdl.GL_SwapWindow(window)
    // fmt.println(projection)
  }
  fmt.println("hello world")
}

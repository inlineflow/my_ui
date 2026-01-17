package my_ui

import sdl "sdl2"
import gl "opengl"
import glm "core:math/linalg/glsl"
import lin "core:math/linalg"
import "core:fmt"
import "core:os"
import "core:strings"

START_WINDOW_WIDTH :: 800
START_WINDOW_HEIGHT :: 600

UI_Rect_Render_Data :: struct {
  vao: u32,
  vbo: u32,
  shader_id: u32,
  uniforms: gl.Uniforms,
}

setup_rect_rd :: proc(vertex_filepath, fragment_filepath: string) -> (rd: UI_Rect_Render_Data, ok: bool) {
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


// draw_rect :: proc() {
//
// }

main :: proc() {

  sdl.Init({.TIMER, .VIDEO})

  window := sdl.CreateWindow("SDL2", sdl.WINDOWPOS_UNDEFINED, sdl.WINDOWPOS_UNDEFINED, START_WINDOW_WIDTH, START_WINDOW_HEIGHT, {.OPENGL, .RESIZABLE, .FULLSCREEN} )
  if window == nil {
    fmt.eprintln("Failed to create window")
    return
  }
  defer sdl.DestroyWindow(window)

  gl_context := sdl.GL_CreateContext(window)
  sdl.GL_MakeCurrent(window, gl_context)
  gl.load_up_to(3, 3, sdl.gl_set_proc_address)
  gl.Viewport(0, 0, START_WINDOW_WIDTH, START_WINDOW_HEIGHT)

  // s, ok := load_shader("shaders/default.vert", "shaders/default.frag")
  // if !ok {
  //   fmt.eprintln("couldn't load shader")
  //   return
  // }

  ui_rect_rd, ui_rect_rd_ok := setup_rect_rd("shaders/default.vert", "shaders/default.frag")
  assert(ui_rect_rd_ok)

  projection := glm.mat4Ortho3d(0, START_WINDOW_WIDTH, START_WINDOW_HEIGHT, 0, -1, 1)

  now:u64 = 0
  last: u64 = sdl.GetPerformanceCounter()
  dt: f32 = 0
  freq := sdl.GetPerformanceFrequency()

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

      case .QUIT: 
        break main_loop
      }
    }


    sdl.GL_SwapWindow(window)
  }
  fmt.println("hello world")
}

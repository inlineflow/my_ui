package my_ui

import sdl "sdl2"
import gl "opengl"
import glm "core:math/linalg/glsl"
import lin "core:math/linalg"
import "core:fmt"

START_WINDOW_WIDTH :: 800
START_WINDOW_HEIGHT :: 600

main :: proc() {

  sdl.Init({.TIMER, .VIDEO})

  window := sdl.CreateWindow("SDL2", sdl.WINDOWPOS_UNDEFINED, sdl.WINDOWPOS_UNDEFINED, START_WINDOW_WIDTH, START_WINDOW_HEIGHT, {.OPENGL, .RESIZABLE})
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

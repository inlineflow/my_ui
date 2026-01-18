package my_ui

import sdl "sdl2"
import gl "opengl"
import glm "core:math/linalg/glsl"
import lin "core:math/linalg"
import "core:fmt"
import "core:os"
import "core:strings"
import ft "shared:freetype"
import "core:unicode/utf8"

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
  active_color: v3,
  state: bit_set[UI_Element_State],
  handle: struct {
    size: v2,
  },
  buttons: []UI_Button,
}

UI_Editor_Window :: struct {
  using window: UI_Window,
  cursor_pos: u32,
  // text: string,
  text_buf: [dynamic]rune,
  ft_face: ft.Face,
  glyphs: map[rune]UI_Glyph,
  font_rd: UI_Rect_Render_Data,
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
  ACTIVE,
}

UI_Button :: struct {
  pos: v2,
  size: v2,
  state: bit_set[UI_Element_State],
  rd: ^UI_Rect_Render_Data,
  color: v3,
}

UI_Glyph :: struct {
  texture_id: u32,
  size: [2]u32,
  bearing: [2]i32,
  advance: u32,
}

FONT_SIZE :: 16

// font_projection := glm.mat4Ortho3d(0, START_WINDOW_WIDTH, 0, START_WINDOW_HEIGHT, -1, 1)
setup_font_quad :: proc(vertex_filepath, fragment_filepath: string) -> (rd: UI_Rect_Render_Data, ok: bool) {
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

  gl.GenVertexArrays(1, &vao)
  gl.GenBuffers(1, &vbo)
  gl.BindVertexArray(vao); defer gl.BindVertexArray(0)
  gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
  gl.BufferData(gl.ARRAY_BUFFER, size_of(f32) * 6 * 4, nil, gl.DYNAMIC_DRAW)
  gl.EnableVertexAttribArray(0)
  gl.VertexAttribPointer(0, 4, gl.FLOAT, gl.FALSE, 4 * size_of(f32), 0)
  gl.BindBuffer(gl.ARRAY_BUFFER, 0)

  return UI_Rect_Render_Data {
    uniforms = uniforms,
    shader_id = program,
    vao = vao,
    vbo = vbo,
  }, true
}

render_text :: proc(rd: UI_Rect_Render_Data, face: ft.Face, glyphs: map[rune]UI_Glyph, text: string, x, y, scale: f32, color: v3) {
  gl.UseProgram(rd.shader_id)
  gl.Uniform3f(rd.uniforms["text_color"].location, color.x, color.y, color.z)
  gl.UniformMatrix4fv(rd.uniforms["projection"].location, 1, false, &projection[0][0])
  gl.ActiveTexture(gl.TEXTURE0)
  gl.BindVertexArray(rd.vao)
  x := x
  line_height := cast(f32)(face.size.metrics.height >> 6)
  // line_height: f32 = 19
  for c in text {
    glyph := glyphs[c]
    xpos := x + cast(f32)glyph.bearing.x * scale;
    // ypos := y - (cast(f32)glyph.size.y - cast(f32)glyph.bearing.y) * scale;
    ypos := (y + line_height) - cast(f32)glyph.bearing.y * scale;
    w := cast(f32)glyph.size.x * scale;
    h := cast(f32)glyph.size.y * scale;

    vertices := [?][4]f32 {
        {xpos,     ypos + h, 0, 1}, // Bottom Left
        {xpos,     ypos,     0, 0}, // Top Left
        {xpos + w, ypos,     1, 0}, // Top Right
        {xpos,     ypos + h, 0, 1}, // Bottom Left
        {xpos + w, ypos,     1, 0}, // Top Right
        {xpos + w, ypos + h, 1, 1}, // Bottom Right
    }

    gl.BindTexture(gl.TEXTURE_2D, glyph.texture_id)
    gl.BindBuffer(gl.ARRAY_BUFFER, rd.vbo)
    gl.BufferSubData(gl.ARRAY_BUFFER, 0, size_of(vertices), &vertices)
    gl.BindBuffer(gl.ARRAY_BUFFER, 0)
    gl.DrawArrays(gl.TRIANGLES, 0, 6)

    x += cast(f32)(glyph.advance >> 6) * scale
  }

  gl.BindVertexArray(0)
  gl.BindTexture(gl.TEXTURE_2D, 0)
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
  color := .ACTIVE in w.state ? w.active_color : w.color;
  ui_draw_rect(w.pos, w.size, w.rd^, color)
  for b in w.buttons {
    ui_draw_rect(w.pos + b.pos, b.size, b.rd^, b.color)
  }
  ui_draw_rect(w.pos, w.handle.size, w.rd^, w.color - 0.3)
  return true
}

draw_editor :: proc(e: UI_Editor_Window, draw_cursor: bool) -> bool {
  draw_window(e)
  text := utf8.runes_to_string(e.text_buf[:])
  render_text(e.font_rd, e.ft_face, e.glyphs, text, e.pos.x, e.pos.y + e.handle.size.y, 1, {1, 1, 1})
  cursor_size := v2{2, 19}
  if .ACTIVE in e.state && draw_cursor {
    ui_draw_rect({e.pos.x + cast(f32)e.cursor_pos, e.pos.y + e.handle.size.y}, cursor_size, e.rd^, {1, 1, 1})
  }
  return true
}

make_glyphs :: proc(face: ft.Face) -> map[rune]UI_Glyph {
  result := make(map[rune]UI_Glyph)
  gl.PixelStorei(gl.UNPACK_ALIGNMENT, 1)

  for i in 0..<128 {
    c:u64 = cast(u64)i
    if ft.load_char(face, c, {.Render}) != .Ok {
      fmt.eprintln("failed to load glyph: ", c)
      continue
    }

    texture: u32
    gl.GenTextures(1, &texture)
    gl.BindTexture(gl.TEXTURE_2D, texture)
    gl.TexImage2D(
      gl.TEXTURE_2D,
      0,
      gl.RED,
      cast(i32)face.glyph.bitmap.width,
      cast(i32)face.glyph.bitmap.rows,
      0,
      gl.RED,
      gl.UNSIGNED_BYTE,
      face.glyph.bitmap.buffer
    )

    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
    glyph := UI_Glyph{
      texture,
      {face.glyph.bitmap.width, face.glyph.bitmap.rows},
      {face.glyph.bitmap_left, face.glyph.bitmap_top},
      cast(u32)face.glyph.advance.x,
    }

    result[rune(c)] = glyph
  }

  return result
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
  gl.Enable(gl.BLEND)
  gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)

  ftlib: ft.Library
  ft_err := ft.init_free_type(&ftlib)
  assert(ft_err == .Ok)

  ft_face: ft.Face
  ft_err = ft.new_face(ftlib, "fonts/FiraMonoNerdFontMono-Regular.otf", 0, &ft_face)
  assert(ft_err == .Ok)


  ft.set_pixel_sizes(ft_face, 0, FONT_SIZE)

  line_height := cast(f32)(ft_face.size.metrics.height >> 6)
  fmt.println("line_height: ", line_height)
  fmt.println("face: ", ft_face)
  fmt.println("face.size.metrics: ", ft_face.size.metrics)

  glyphs := make_glyphs(ft_face)
  font_rd, font_rd_ok := setup_font_quad("shaders/font.vert", "shaders/font.frag")
  assert(font_rd_ok)
  // fmt.println(ft_face)

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

  // editor_text_buf := make([dynamic]rune)
  // for c in "hello world" {
  //   append(&editor_text_buf, c)
  // }
  editor_window := UI_Editor_Window{
    pos = root_os_window.size / 2 - {800, 600} / 2,
    size = {800, 600},
    color = {0.6, 0.6, 0.6},
    active_color = {0.7, 0.7, 0.7},
    rd = &ui_rect_rd,
    // buttons = { b },
    handle = { size = { 800, 25 } },
    glyphs = glyphs,
    // text = "hello world",
    text_buf = make([dynamic]rune),
    ft_face = ft_face,
    font_rd = font_rd,
  }

  for c in "hello world" {
    append(&editor_window.text_buf, c)
  }

  acc:f32
  main_loop: for {

    now = sdl.GetPerformanceCounter()
    elapsed_ticks: u64 = now - last
    dt = cast(f32)(cast(f64)elapsed_ticks / cast(f64)freq) // in seconds
    last = now


    // fmt.println(acc)

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
        case .A..<.Z:
          fmt.println(event.key.keysym.sym)
          append(&editor_window.text_buf, rune(event.key.keysym.sym))
        }

      case .MOUSEMOTION:
        // fmt.println(event.motion.x, event.motion.y)
        // editor_window.color = {cast(f32)event.motion.x / editor_window.size.x, cast(f32)event.motion.y / editor_window.size.y, 1}
        m := v2{cast(f32)event.motion.x, cast(f32)event.motion.y}
        rel := v2{cast(f32)event.motion.xrel, cast(f32)event.motion.yrel}
        w := &editor_window
        // if m.x > w.pos.x && m.x < w.pos.x + w.size.x && m.y > w.pos.y && m.y < w.pos.y + w.size.y {
        //     fmt.println("in window by x and y")
        // }
        // fmt.println(event.motion)

        if .DRAGGED in w.state {
          w.pos += rel
        }
      case .MOUSEBUTTONDOWN:
        // fmt.println(event.button.x, event.button.y)
        click := v2{cast(f32)event.button.x, cast(f32)event.button.y}
        // w_pos := editor_window.pos
        // w := editor_window

        w := &editor_window
        h := editor_window.handle
        if click.x > w.pos.x && click.x < w.pos.x + w.size.x && click.y > w.pos.y + h.size.y && click.y < w.pos.y + w.size.y {
            fmt.println("in window by x and y")
            w.state += { .ACTIVE }
        } else {
            w.state -= { .ACTIVE }
        }
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
          // font_projection = glm.mat4Ortho3d(0, cast(f32)width, 0, cast(f32)height, -1, 1)
          gl.Viewport(0, 0, width, height)
      }
    }

    gl.ClearColor(1.0, 0.8039, 0.7882, 1.0) // FFCDC9
    gl.Clear(gl.COLOR_BUFFER_BIT)

    // ui_draw_rect({200, 200}, {200, 200}, ui_rect_rd, {1, 1, 1})
    // button(b)
    threshhold:f32 = 0.8
    draw_editor(editor_window, acc >= threshhold)
    // render_text(font_rd, ft_face, glyphs, , editor_window.pos.x, editor_window.pos.y + editor_window.handle.size.y, 1, {1, 1, 1})
    if acc >= threshhold * 2 {
      acc = 0
    }
    // fmt.println(editor_window.state)
    sdl.GL_SwapWindow(window)
    // fmt.println(projection)
    acc += dt
  }
  fmt.println("hello world")
}

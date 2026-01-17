#version 330 core
out vec4 out_color;

uniform vec3 in_color;

void main() {
  out_color = vec4(in_color, 1.0);
}

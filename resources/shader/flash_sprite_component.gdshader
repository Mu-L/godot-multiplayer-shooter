shader_type canvas_item;

uniform vec3 input_color: source_color = vec3(1.0, 1.0, 1.0);
uniform float percent: hint_range(0.0, 1.0);

void fragment() {
	vec4 color = texture(TEXTURE, UV);
	vec4 flash_color = vec4(input_color, color.a);
	COLOR = mix(color, flash_color, percent);
}

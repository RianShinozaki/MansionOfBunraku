shader_type canvas_item;

uniform float grey_level;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable;

void fragment() {
	COLOR = textureLod(screen_texture, SCREEN_UV, 0.0);

	vec3 greyscale = vec3(0.299 * COLOR.r + 0.587 * COLOR.g + 0.114 * COLOR.b);
	COLOR.rgb = mix(COLOR.rgb, greyscale, grey_level);
}

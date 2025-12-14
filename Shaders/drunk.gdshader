shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float wiggleMult:hint_range(0.0, 0.1, 0.0001)=0.005;

void fragment( ){
//	set up
	vec2 iResolution = 1.0 / SCREEN_PIXEL_SIZE;
    vec2 uv = FRAGCOORD.xy / iResolution.xy;
    vec3 color;
//	wiggle
	float x=  sin(0.3*TIME+uv.y*5.0)*sin(0.7*TIME+uv.y*7.0)*sin(0.3+0.33*TIME+uv.y*9.0)*wiggleMult;
//draw the actual game lol
	//the color adjustments is a simpler chromatic aberration
    color.r = texture(screen_texture,vec2(x+uv.x,uv.y)).x;
    color.g = texture(screen_texture,vec2(x+uv.x,uv.y)).y;
    color.b = texture(screen_texture,vec2(x+uv.x,uv.y)).z;


    COLOR = vec4(color,1.0);
}
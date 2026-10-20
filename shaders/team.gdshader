shader_type canvas_item;
// Swaps the two key reds in the sprites for the owning player's colour.
uniform vec4 team : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform float flash = 0.0;
uniform vec3 tint = vec3(1.0);   // e.g. a powered-down construct goes cold grey

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 o = c.rgb;
	if (distance(c.rgb, vec3(1.0, 0.0, 0.0)) < 0.08) o = team.rgb;
	else if (distance(c.rgb, vec3(150.0 / 255.0, 0.0, 0.0)) < 0.08) o = team.rgb * 0.6;
	o = mix(o, vec3(1.0), flash);
	COLOR = vec4(o * tint, c.a * COLOR.a);
}

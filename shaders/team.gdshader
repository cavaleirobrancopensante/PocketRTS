shader_type canvas_item;
// Swaps the two key reds in the sprites for the owning player's colour.
uniform vec4 team : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform float flash = 0.0;
uniform vec3 tint = vec3(1.0);   // e.g. a powered-down construct goes cold grey

// Horse coats (tools/import_horse_coats.py): a mask beside each horse strip says which pixels
// are the horse (R), where a spotted coat has a patch (G) and the pixel's tone (B); the
// horse's tone is mapped onto the coat's row of coat_ramps. coat < 0: as painted.
uniform int coat = -1;           // 0 dark, 1 bay, 2 grey, 3 white, 4 spotted (white + patches)
uniform sampler2D horse_mask : filter_nearest, repeat_disable, hint_default_black;
uniform sampler2D coat_ramps : filter_linear, repeat_disable;

vec3 coat_ramp(int row, float t) {
	return texture(coat_ramps, vec2(t * (63.0 / 64.0) + 0.5 / 64.0, (float(row) + 0.5) / 5.0)).rgb;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 o = c.rgb;
	if (distance(c.rgb, vec3(1.0, 0.0, 0.0)) < 0.08) o = team.rgb;
	else if (distance(c.rgb, vec3(150.0 / 255.0, 0.0, 0.0)) < 0.08) o = team.rgb * 0.6;
	else if (coat >= 0) {
		vec4 m = texture(horse_mask, UV);
		if (m.r > 0.5) {
			vec3 col = coat == 4 ? mix(coat_ramp(3, m.b), coat_ramp(4, m.b), m.g) : coat_ramp(coat, m.b);
			// the outline darks stay as painted
			float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
			o = mix(c.rgb, col, smoothstep(0.035, 0.10, l));
		}
	}
	o = mix(o, vec3(1.0), flash);
	COLOR = vec4(o * tint, c.a * COLOR.a);
}

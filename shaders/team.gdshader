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
// Veterancy on the sprite (scripts/vet_look.gd): a mask beside each strip marks the pixels
// that show it (R) and their tone (G, dark 0 .. light 1). vet_style 1: a Crown soldier's trim
// (tools/import_vet_trim.py: hat lace, hat band, helmet comb and brim), black / silver / gold
// by vet_level 0 / 1 / 2. vet_style 2: a Brood creature's skin (tools/import_vet_skin.py),
// as painted / amber-ochre / obsidian. 0: no veterancy shown.
uniform int vet_style = 0;
uniform int vet_level = 0;
uniform sampler2D vet_mask : filter_nearest, repeat_disable, hint_default_black;
// a Powder Wagon whose horse was released (RELEASE HORSE): its painted horse isn't drawn
uniform bool hide_horse = false;
// THE VENOM LINE (the Spitter, the Venom Challenger, the Venom Sire, the Mist Toad; tools/import_venom_colours.py):
// SCALES in the team colour and SPIKES and FRILL in olive, the other way round from the rest of the Brood. A mask beside
// each strip: R = a scale pixel and G its tone (dark 0 .. light 1), B = 0 or 1 + a spike pixel's tone. A veteran's
// scales mix half of the veterancy skin into the team colour (the side still reads).
uniform bool venom_swap = false;
uniform sampler2D venom_mask : filter_nearest, repeat_disable, hint_default_black;

vec3 coat_ramp(int row, float t) {
	return texture(coat_ramps, vec2(t * (63.0 / 64.0) + 0.5 / 64.0, (float(row) + 0.5) / 5.0)).rgb;
}

// (keep the colours in step with tools/import_vet_trim.py and tools/import_vet_skin.py)
vec3 vet_trim(int level, float t) {
	if (level >= 2) return mix(vec3(0.50, 0.30, 0.04), vec3(1.00, 0.88, 0.36), t);   // gold
	if (level == 1) return mix(vec3(0.42, 0.45, 0.50), vec3(0.96, 0.97, 1.00), t);   // silver
	return mix(vec3(0.05, 0.05, 0.06), vec3(0.22, 0.22, 0.24), t);                   // black
}

vec3 vet_skin(int level, float t) {
	if (level == 1) {      // amber-ochre
		vec3 c = mix(vec3(0.20, 0.10, 0.03), vec3(0.66, 0.42, 0.12), smoothstep(0.0, 0.6, t));
		return mix(c, vec3(0.93, 0.74, 0.38), smoothstep(0.6, 1.0, t));
	}
	// obsidian: near black, a dark violet sheen on the highlights
	vec3 c = mix(vec3(0.025, 0.025, 0.035), vec3(0.12, 0.11, 0.16), smoothstep(0.0, 0.8, t));
	return mix(c, vec3(0.48, 0.45, 0.64), smoothstep(0.86, 1.0, t));
}

// (keep the two ramps in step with tools/import_venom_colours.py)
vec3 team_ramp(vec3 t, float x) {
	vec3 c = mix(t * 0.24, t * 0.85, smoothstep(0.0, 0.7, x));
	return mix(c, mix(t, vec3(1.0), 0.35), smoothstep(0.7, 1.0, x));
}

vec3 olive_ramp(float x) {
	vec3 c = mix(vec3(0.235, 0.243, 0.078), vec3(0.435, 0.443, 0.129), smoothstep(0.0, 0.5, x));
	return mix(c, vec3(0.675, 0.682, 0.31), smoothstep(0.5, 1.0, x));
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
	bool venom_scale = false;
	if (venom_swap) {
		vec4 nm = texture(venom_mask, UV);
		if (nm.b > 0.0) o = olive_ramp((nm.b * 255.0 - 1.0) / 254.0);
		else if (nm.r > 0.5) {
			vec3 sc = team_ramp(team.rgb, nm.g);
			if (vet_style == 2 && vet_level > 0) sc = mix(sc, vet_skin(vet_level, nm.g), 0.5);
			// the scales' outline darks stay as painted
			float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
			o = mix(c.rgb, sc, smoothstep(0.035, 0.10, l));
			venom_scale = true;
		}
	}
	if (vet_style > 0 && !venom_scale) {
		vec4 vm = texture(vet_mask, UV);
		if (vm.r > 0.5) {
			if (vet_style == 1) o = vet_trim(vet_level, vm.g);
			else if (vet_level > 0) {
				// the skin's outline darks stay as painted
				float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
				o = mix(o, vet_skin(vet_level, vm.g), smoothstep(0.035, 0.10, l));
			}
		}
	}
	o = mix(o, vec3(1.0), flash);
	float a = c.a;
	if (hide_horse && texture(horse_mask, UV).r > 0.5) a = 0.0;
	COLOR = vec4(o * tint, a * COLOR.a);
}

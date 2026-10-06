// Restoration of a find: soil, a hard crust and patina drawn over the clean
// artwork. The masks come from RestorationScreen (1 = still dirty); the brush,
// the scalpel and the sponge erase them. No extra art per find: all procedural.
// Shards: the same material on every shard, each shows only its own region of
// shard_map (shard_id >= 0); the whole find can show its empty outline
// (silhouette) where the shards go, and the glue seams between them.
shader_type canvas_item;

uniform sampler2D soil_mask : filter_linear, hint_default_black;
uniform sampler2D patina_mask : filter_linear, hint_default_black;
uniform sampler2D crust_mask : filter_linear, hint_default_black;
// Shard index * 32 per pixel (nearest), only read when shard_id >= 0 or seams > 0.
uniform sampler2D shard_map : filter_nearest, hint_default_black;
uniform int shard_id = -1;
uniform float silhouette : hint_range(0.0, 1.0) = 0.0;
uniform float seams : hint_range(0.0, 1.0) = 0.0;
uniform float crust_fade : hint_range(0.0, 1.0) = 1.0;
uniform vec3 crust_colour : source_color = vec3(0.70, 0.62, 0.48);
// Multipliers used by the auto-finish at ~90 %.
uniform float soil_fade : hint_range(0.0, 1.0) = 1.0;
uniform float patina_fade : hint_range(0.0, 1.0) = 1.0;
// Position of the diagonal shine band; below -0.4 it is off screen.
uniform float shine = -1.0;
uniform vec3 soil_dark : source_color = vec3(0.30, 0.21, 0.13);
uniform vec3 soil_light : source_color = vec3(0.60, 0.46, 0.30);
uniform vec3 patina_tint : source_color = vec3(0.45, 0.43, 0.31);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x),
		u.y
	);
}

float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int octave = 0; octave < 4; octave++) {
		value += amplitude * value_noise(p);
		p *= 2.03;
		amplitude *= 0.5;
	}
	return value;
}

void fragment() {
	vec4 clean = texture(TEXTURE, UV);
	float blotches = fbm(UV * 9.0);
	float shard_here = floor(texture(shard_map, UV).r * 255.0 / 32.0 + 0.5);
	if (shard_id >= 0 && int(shard_here) != shard_id) {
		discard;
	}

	// Patina: dull, greyish-brown, blotchy; the sponge brings the colour back.
	float patina = texture(patina_mask, UV).r * patina_fade;
	float luminance = dot(clean.rgb, vec3(0.30, 0.59, 0.11));
	vec3 dull = mix(vec3(luminance) * patina_tint * 1.7, clean.rgb * 0.55, 0.35);
	dull += (blotches - 0.5) * 0.12;
	vec3 object_colour = mix(clean.rgb, dull, patina);

	// Crust: hard earthy-lime deposit stuck to the object, with a little relief
	// (lit from the top left) and grain; the scalpel chips it off.
	float crust_value = texture(crust_mask, UV).r * crust_fade;
	float crust_alpha = smoothstep(0.15, 0.45, crust_value + (fbm(UV * 30.0) - 0.5) * 0.18);
	vec2 step_uv = vec2(2.0 / 256.0);
	float relief = texture(crust_mask, UV - step_uv).r - texture(crust_mask, UV + step_uv).r;
	vec3 crust = crust_colour * (0.88 + (fbm(UV * 55.0 + 7.0) - 0.5) * 0.3);
	crust = mix(crust, object_colour * 0.6 + crust * 0.4, 0.25);
	crust *= 1.0 + clamp(relief, -0.5, 0.5) * 0.5;
	object_colour = mix(object_colour, crust, crust_alpha * 0.95);

	// Glue seams between the shards: thin dark lines that fade as the glue sets.
	if (seams > 0.0) {
		vec2 px = vec2(1.5 / 256.0);
		float right = floor(texture(shard_map, UV + vec2(px.x, 0.0)).r * 255.0 / 32.0 + 0.5);
		float down = floor(texture(shard_map, UV + vec2(0.0, px.y)).r * 255.0 / 32.0 + 0.5);
		float edge = (right != shard_here || down != shard_here) ? 1.0 : 0.0;
		object_colour = mix(object_colour, object_colour * 0.35, edge * seams);
	}
	// Shine: a soft diagonal band sweeping over the object.
	float offset = (UV.x + UV.y) * 0.5 - shine;
	object_colour += exp(-offset * offset * 180.0) * 0.55;

	// Soil: crumbly earth with a torn edge, grains and small pebbles.
	float soil_value = texture(soil_mask, UV).r * soil_fade;
	float soil_alpha = smoothstep(0.22, 0.55, soil_value + (blotches - 0.5) * 0.35);
	vec3 soil = mix(soil_dark, soil_light, fbm(UV * 14.0 + 3.0));
	soil += (fbm(UV * 40.0) - 0.5) * 0.14;
	soil = mix(soil, soil * 0.68, step(0.87, value_noise(UV * 62.0)));

	float alpha = soil_alpha + clean.a * (1.0 - soil_alpha);
	vec3 colour = (object_colour * clean.a * (1.0 - soil_alpha) + soil * soil_alpha) / max(alpha, 0.0001);
	// Empty outline where the shards go (the find itself is hidden).
	if (silhouette > 0.0) {
		colour = mix(colour, vec3(0.2, 0.14, 0.09), silhouette);
		alpha *= mix(1.0, 0.6, silhouette);
	}
	COLOR = vec4(colour, alpha);
}

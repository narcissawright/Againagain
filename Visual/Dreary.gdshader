shader_type sky;
uniform vec4 albedo_dark : source_color;
uniform vec4 albedo_bright : source_color;
uniform sampler2D texture_albedo : source_color;
uniform vec3 moon_pos;

void sky() {
	// calc cloud color
	float height_offset = 10.0;
	float scale_amount = height_offset / EYEDIR.y;
	vec3 hitpos = EYEDIR * scale_amount;
	vec2 uv = vec2(hitpos.x, hitpos.z) / 200.0;
	vec2 uv2 = vec2(hitpos.x, hitpos.z) / 100.0;
	vec2 shift = vec2(TIME * 0.03, TIME * 0.01);
	vec2 shift2 = vec2(TIME * 0.015, TIME * 0.005);
	vec4 albedo_tex = texture(texture_albedo, uv + shift);
	vec4 albedo_tex2 = texture(texture_albedo, uv2 + shift2);
	vec3 skycolor = mix(albedo_tex.rgb, albedo_tex2.rgb, 0.25);
	skycolor = mix(albedo_dark.rgb, albedo_bright.rgb, skycolor.rgb);
	
	// fade off at horizon
	float dotty = dot(EYEDIR, vec3(0.0, 1.0, 0.0));
	dotty = max(0.0, dotty);
	skycolor = mix(albedo_dark.rgb, skycolor, dotty);
	COLOR = skycolor;
	
	// moon
	// SCREEN_UV something
	//float screen_dist = length(SCREEN_UV - vec2(960, 540));
	//screen_dist /= length(vec2(960, 540));
	
	/*
	float moon_proximity = dot(moon_pos, EYEDIR);
	moon_proximity = max(0.0, moon_proximity);
	float moon_mix = smoothstep(0.9975, 0.9977, moon_proximity);
	float moon_mix2 = smoothstep(0.975, 0.9975, moon_proximity);
	//if (moon_mix < 1.0) { moon_mix /= 2.0; }
	//this shit too dark
	vec3 moon_color = vec3(0.85, 0.75, 1.0);
	
	//glow
	COLOR = mix(skycolor, mix(skycolor, moon_color, 0.05), max(0.0, moon_mix2));
	//moon
	COLOR = mix(COLOR, moon_color, moon_mix);
	*/
	
//	if (SCREEN_UV.x > 0.5) {
//		COLOR = vec3(0.3, 0.1, 0.1);
//	}
}

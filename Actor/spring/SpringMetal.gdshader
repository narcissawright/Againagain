shader_type spatial;

uniform vec4 albedo : source_color;
uniform float roughness : hint_range(0,1);
uniform float specular;
uniform float metallic;

void fragment() {
	vec2 base_uv = UV;
	ALBEDO = albedo.rgb;
	METALLIC = metallic;
	ROUGHNESS = roughness;
	SPECULAR = specular;
	#include "res://Visual/DitherTransparency.gdshaderinc"
}

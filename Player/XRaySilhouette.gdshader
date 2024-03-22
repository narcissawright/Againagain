shader_type spatial;
render_mode depth_test_disabled, unshaded;

void fragment() {
	ALBEDO = vec3(0.0,0.0,0.5);
	ALPHA = 0.25;
	#include "res://Visual/DitherTransparency.gdshaderinc"
}
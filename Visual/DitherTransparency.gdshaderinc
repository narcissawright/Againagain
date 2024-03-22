	// Opacity Dithering...
	int x = int(FRAGCOORD.x / 2.0) % 4;
	int y = int(FRAGCOORD.y / 2.0) % 4;
	int index = x + y * 4;
	float limit = 0.0;
	
	// Dither pattern
	switch (index) {
		case 0:  limit = 0.0625; break;
		case 1:  limit = 0.5625; break;
		case 2:  limit = 0.1875; break;
		case 3:  limit = 0.6875; break;
		case 4:  limit = 0.8125; break;
		case 5:  limit = 0.3125; break;
		case 6:  limit = 0.9375; break;
		case 7:  limit = 0.4375; break;
		case 8:  limit = 0.25;   break;
		case 9:  limit = 0.75;   break;
		case 10: limit = 0.125;  break;
		case 11: limit = 0.625;  break;
		case 12: limit = 1.0;    break;
		case 13: limit = 0.5;    break;
		case 14: limit = 0.875;  break;
		case 15: limit = 0.375;  break;
	}

	// Depth Test
	float depth = FRAGCOORD.z;
	vec3 ndc = vec3(SCREEN_UV, depth) * 2.0 - 1.0;
	vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view.xyz /= view.w;
	float linear_depth = -view.z * 2.0; // this *2 is experiment
	if (linear_depth < limit) { discard; }
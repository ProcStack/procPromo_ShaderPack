float getSkyGrey(vec3 skyColor){
	return min(luma(skyColor.rgb),.35)*1.4;
}
float getSkyFogGrey(vec3 skyColor){
	return min(luma(skyColor.rgb),.35)*0.91; // 1.4 * 0.65 == 0.91
}
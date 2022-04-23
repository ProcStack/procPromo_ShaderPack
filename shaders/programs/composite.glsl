
#ifdef VSH

varying vec2 texcoord;

void main() {
	gl_Position = ftransform();
	texcoord = gl_MultiTexCoord0.xy;
}

#endif

#ifdef FSH
/* RENDERTARGETS: 4 */
// Shadow Smoothing Pass
//   Rewrite gbuffer originated shadow buffer

varying vec2 texcoord;
uniform sampler2D colortex6;
uniform sampler2D colortex7;
uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;

void main() {
  // Shadow Buffer; Water if enabled, Shadow otherwise
	vec4 waterShadowCd = texture2D(shadowtex0, texcoord);
  // Shadow Buffer; Shadow
	vec4 shadowCd = texture2D(shadowtex1, texcoord);
  
  // GBuffer; Calculated Shadow
	shadowCd = texture2D(colortex7, texcoord);
	gl_FragData[0] = vec4(shadowCd.rgb, 1.0);
}


#endif



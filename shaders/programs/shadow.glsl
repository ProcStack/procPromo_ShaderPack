// GBuffer - Shadow GLSL
// Written by Kevin Edzenga, ProcStack; 2022-2023
//
// Guided by Chocapic13's HighPerformance Toaster shader pack

#extension GL_EXT_gpu_shader4 : enable
	
#ifdef VSH


  #include "/shaders.settings"
  #include "utils/shadowCommon.glsl"

  uniform mat4 gbufferModelView;
  uniform mat4 gbufferProjection;
	uniform mat4 shadowProjection;
	uniform mat4 shadowProjectionInverse;
	uniform mat4 shadowModelView;
	uniform mat4 shadowModelViewInverse;
	
	uniform vec3 chunkOffset;

  in vec4 mc_Entity;
	in vec3 vaPosition;

  out vec2 texcoord;
  out vec4 color;
  out vec3 vShadowPos;
  out float vShadowDist;
  out float vIsLeaves;
  out float vIsTranslucent;


  void main() {
  
		vec4 position =  ftransform();
		//vec4 position =  gbufferProjection * gbufferModelView * vec4( vaPosition, 1.0 ) ;

    color=gl_Color;
    
    vec4 camDir = vec4(0.0);
    //biasToNDC( gbufferModelView, position, camDir );
    
    position = distortShadowShift( position );
    gl_Position = position;
    vShadowPos = position.xyz;
    
		vShadowDist = length( (gbufferProjection*vec4(vaPosition+chunkOffset,1.0)).xyz );
		vShadowDist = length( position );
		
    
    
    texcoord = gl_MultiTexCoord0.xy;
    
    vIsLeaves=0.0;
    
    // Leaves
    if ( SolidLeaves && (mc_Entity.x == 810 || mc_Entity.x == 8101) ){
      vIsLeaves = 1.0;
    }
		
    vIsTranslucent = 0.0;
		// Colored Translucent Blocks; stained glass, water, etc.
    if ( mc_Entity.x == 301 || mc_Entity.x == 703 ){
      vIsTranslucent = 1.0;
    }
    
  }

#endif

#ifdef FSH

layout(Location = 0) out vec4 outCd;
layout(Location = 1) out vec4 outData;

/* --
const int shadowcolor1Format = RG16;
 -- */

  #include "/shaders.settings"

  uniform sampler2D tex;
	uniform float far;

  in vec2 texcoord;
  in vec4 color;
  in vec3 vShadowPos;
  in float vShadowDist;
  in float vIsLeaves;
  in float vIsTranslucent;
	

  void main() {

    vec4 shadowCd = texture2D(tex,texcoord.xy);
		shadowCd.rgb*=color.rgb;

    shadowCd.a= min(1.0, shadowCd.a+vIsLeaves);
		
		if( shadowCd.a<0.01 ){
			discard;
		}
		
		shadowCd.a*=1.0-vIsTranslucent;
    
    outCd = shadowCd;
    outData = vec4( length(vShadowPos)/far, shadowCd.aaa );
    outData = vec4( vIsTranslucent, vShadowDist, 0.0, 0.0 );
    outData = vec4( vIsTranslucent, length(vShadowPos), 0.0, 0.0 );
  }

#endif

// Guided by Chocapic13's HighPerformance Toaster shader pack

#ifdef VSH

  #extension GL_EXT_gpu_shader4 : enable

  #include "/shaders.settings"
  #include "utils/shadowCommon.glsl"

  uniform mat4 gbufferModelView;
  uniform mat4 gbufferProjection;
	uniform vec3 chunkOffset;

  in vec4 mc_Entity;
	in vec3 vaPosition;

  out vec2 texcoord;
  out vec4 color;
  out float vBiasStretch;
  out vec3 vShadowPos;
  out float vShadowDist;
  out float vIsLeaves;


  void main() {
  
		vec4 position =  ftransform();

    color=gl_Color;
    
    vec4 camDir = vec4(0.0);
    //biasToNDC( gbufferModelView, position, camDir );
    
    position = biasShadowShift( position );
    gl_Position = position;
    vShadowPos = position.xyz;
    
		vShadowDist = length( position.xyz );
		
    vBiasStretch=camDir.w;
    
    
    texcoord = gl_MultiTexCoord0.xy;
    
    vIsLeaves=0.0;
    
    // Leaves
    if ( SolidLeaves && (mc_Entity.x == 810 || mc_Entity.x == 8101) ){
      vIsLeaves = 1.0;
    }
    
  }

#endif

#ifdef FSH

layout(Location = 0) out vec4 outCd;
layout(Location = 1) out vec4 outData;

/* --
const int shadowcolor1Format = R16F;
 -- */

  #include "/shaders.settings"

  uniform sampler2D tex;
	uniform float far;

  in vec2 texcoord;
  in vec4 color;
  in float vBiasStretch;
  in vec3 vShadowPos;
  in float vShadowDist;
  in float vIsLeaves;
	

  void main() {

    vec4 shadowCd = texture2D(tex,texcoord.xy);
		shadowCd.rgb*=color.rgb;

    shadowCd.a= min(1.0, shadowCd.a+vIsLeaves);
		
		if( shadowCd.a<0.01 ){
			discard;
		}
		
    #if ( DebugView >= 2 )
      shadowCd.rb -= vec2(vBiasStretch);
    #endif
    
    outCd = shadowCd;
    outData = vec4( length(vShadowPos)/far, shadowCd.aaa );
    outData = vec4( length(vShadowPos) );
  }

#endif

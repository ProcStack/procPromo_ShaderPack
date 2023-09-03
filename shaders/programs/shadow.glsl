
#ifdef VSH

  #extension GL_EXT_gpu_shader4 : enable

  #include "/shaders.settings"
  #include "utils/shadowCommon.glsl"

  uniform mat4 gbufferModelView;
  uniform mat4 gbufferPreviousModelView;
  uniform mat4 gbufferProjection;
  uniform mat4 shadowProjection;
  uniform mat4 shadowModelView;
  
  uniform vec3 cameraPosition;

  attribute vec4 mc_Entity;

  varying vec2 texcoord;
  varying vec4 color;
  varying float vBiasStretch;
  varying vec3 vShadowPos;
  varying float vIsLeaves;
  varying float vIsGlass;


  void main() {
  
    vec4 position = ftransform();

    color=gl_Color;
    
    vec4 camDir = vec4(0.0);
    //biasToNDC( gbufferModelView, position, camDir );
    
    position = biasShadowShift( position );
    gl_Position = position;
    vShadowPos = gl_Position.xyz;
    
    vBiasStretch=camDir.w;
    
    
    texcoord = gl_MultiTexCoord0.xy;
    
    vIsLeaves=0.0;
    vIsGlass=0.0;
    
    // Leaves
    if ( SolidLeaves && (mc_Entity.x == 101 || mc_Entity.x == 102) ){
      vIsLeaves = 1.0;
    }
		
    // Glass & Transparents
    if ( mc_Entity.x == 301 ){
      vIsGlass = 1.0;
    }
    
  }

#endif

#ifdef FSH

  #include "/shaders.settings"
  #include "utils/mathFuncs.glsl"

  uniform sampler2D tex;

  varying vec2 texcoord;
  varying vec4 color;
  varying float vBiasStretch;
  varying vec3 vShadowPos;
  varying float vIsLeaves;
  varying float vIsGlass;

  void main() {

    vec4 shadowCd = texture2D(tex,texcoord.xy) * color;

    shadowCd.a= min(1.0, shadowCd.a+vIsLeaves);
		
		if( shadowCd.a < .05 ){
			discard;
		}
		
		
  #if ( DebugView < 2 )
    shadowCd.rgb = mix(vec3(1.0), (1.0-(1.0-shadowCd.rgb)*.5), vIsGlass);
    shadowCd.a =  min(1.0, max( 0.0, (shadowCd.a*vIsGlass) + vIsLeaves ) )*.9+.1 ;
	#else
    shadowCd.a = vIsGlass;
	#endif
	
    #if ( DebugView >= 2 )
      shadowCd.rb -= vec2(vBiasStretch);
    #endif
    
    gl_FragData[0] = shadowCd;
  }

#endif

// Guided by Chocapic13's HighPerformance Toaster shader pack

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
    
    // Leaves
    if ( SolidLeaves && (mc_Entity.x == 810 || mc_Entity.x == 8101) ){
      vIsLeaves = 1.0;
    }
    
  }

#endif

#ifdef FSH

  #include "/shaders.settings"

  uniform sampler2D tex;

  varying vec2 texcoord;
  varying vec4 color;
  varying float vBiasStretch;
  varying vec3 vShadowPos;
  varying float vIsLeaves;

  void main() {

    vec4 shadowCd = texture2D(tex,texcoord.xy) * color;

    shadowCd.a= min(1.0, shadowCd.a+vIsLeaves);

    #if ( DebugView >= 2 )
      shadowCd.rb -= vec2(vBiasStretch);
    #endif
    
    gl_FragData[0] = shadowCd;
  }

#endif

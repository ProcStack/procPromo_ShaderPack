#version 450 compatibility

#define OVERWORLD
#define SHADOW

#define VSH


  #include "/shaders.settings"
  #include "/programs/utils/shadowCommon.glsl"

  uniform sampler2D gtexture;
  uniform mat4 modelViewMatrix;
  uniform mat4 gbufferModelView;
  uniform mat4 gbufferModelViewInverse;
  uniform mat4 projectionMatrix;
  uniform mat4 gbufferProjection;
  uniform mat4 gbufferProjectionInverse;
  uniform mat4 gbufferShadowProjection;
  uniform mat4 shadowProjection;
  uniform mat4 shadowProjectionInverse;
  uniform mat4 shadowModelView;
  uniform mat4 gbufferShadowModelView;
  uniform mat4 shadowModelViewInverse;
  uniform int blockEntityId;

  uniform vec3 chunkOffset;


  in vec3 vaPosition;
  in vec4 mc_Entity;
  in vec2 mc_midTexCoord;
  in vec4 vaColor;
  in vec2 vaUV0; // texture

  out vec2 texcoord;
  out vec4 color;
  out vec3 vShadowPos;
  out float vShadowDist;
  out float vIsLeaves;
  out float vIsTranslucent;


  void main() {

    vec3 basePos = vaPosition + chunkOffset ;
    //vec4 position = shadowProjection * shadowModelView * vec4(vaPosition + chunkOffset, 1.0);
    //vec4 position = gbufferProjection * gbufferModelView * vec4(vaPosition + chunkOffset, 1.0);
    //vec4 position = projectionMatrix * modelViewMatrix * vec4(vaPosition + chunkOffset, 1.0);
    //vec4 position = gbufferShadowProjection * gbufferShadowModelView * vec4(vaPosition + chunkOffset, 1.0);

    // Either work on optifine, not iris --
    vec4 position = gl_Vertex ;
    position = gl_ProjectionMatrix * gl_ModelViewMatrix * position;
    //vec4 position = gl_ProjectionMatrix * gl_ModelViewMatrix * vec4(vaPosition + chunkOffset, 1.0);
    //vec4 position = projectionMatrix * modelViewMatrix * vec4(vaPosition + chunkOffset, 1.0);
    
    //vec4 position = gbufferProjectionInverse * gbufferModelViewInverse * vec4(basePos, 1.0);
    //position = gbufferShadowProjection * gbufferShadowModelView * position;

    //texcoord = gl_MultiTexCoord0.xy;
    texcoord = vaUV0;
    vec2 midcoord=mc_midTexCoord;

    vec4 outCd = vaColor;

    //outCd = vec4( mixColor, 1.0);


    color=outCd;
    color = vaColor;

    vec4 camDir = vec4(0.0);
    //distortToNDC( gbufferModelView, position, camDir );

    position = distortShadowShift( position );


    /*vec2 outUV=position.xy;
    outUV.xy = abs(outUV.xy);
    //
    float pLen = outUV.x*.5;
    outUV.x = pow(pLen+shadowAxisBiasPosOffset, max(0.0,shadowAxisBiasOffset-pLen*shadowAxisBiasMult));
    pLen = outUV.y*.5;
    outUV.y = pow(pLen+shadowAxisBiasPosOffset, max(0.0,shadowAxisBiasOffset-pLen*shadowAxisBiasMult));
    position.xy /= outUV;*/
    //



    gl_Position = position;
    vShadowPos = position.xyz;

    //vShadowDist = length( (gbufferProjection*vec4(vaPosition+chunkOffset,1.0)).xyz );
    vShadowDist = length( position );




    vIsLeaves=0.0;

    // Leaves
    if ( SolidLeaves && (mc_Entity.x == 810 || mc_Entity.x == 8101) ){
      vIsLeaves = 1.0;
    }

    vIsTranslucent = 0.0;
    // Colored Translucent Blocks; stained glass, water, etc.
    if ( mc_Entity.x == 86 || mc_Entity.x == 703 ){
      vIsTranslucent = 1.0;
    }

    // Beacon Beams!!
    //if ( blockEntityId == 603  ){
    //  color.a = 0.0;
    //}

  }


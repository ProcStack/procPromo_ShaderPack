// GBuffer - Shadow GLSL
// Written by Kevin Edzenga, ProcStack; 2022-2023
//
// Guided by Chocapic13's HighPerformance Toaster shader pack

	
#ifdef VSH


  #include "/shaders.settings"
  #include "utils/shadowCommon.glsl"

  uniform sampler2D gcolor;
  uniform mat4 gbufferModelView;
  uniform mat4 gbufferProjection;
  uniform mat4 shadowProjection;
  uniform mat4 shadowProjectionInverse;
  uniform mat4 shadowModelView;
  uniform mat4 shadowModelViewInverse;
  uniform int blockEntityId;

  uniform vec3 chunkOffset;


  in vec3 vaPosition;
  in vec4 mc_Entity;
  in vec2 mc_midTexCoord;
  in vec4 vaColor;

  out vec2 texcoord;
  out vec2 texmidcoord;
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

    // Either work on optifine, not iris --
    //vec4 position = gl_ProjectionMatrix * gl_ModelViewMatrix * gl_Vertex;
    vec4 position = ftransform();


    texcoord = gl_MultiTexCoord0.xy;
    vec2 midcoord=mc_midTexCoord;

    vec4 outCd = gl_Color;

    float avgBlend = .5;

    ivec2 txlOffset = ivec2(2);
    vec3 mixColor;
    outCd = gl_Color*texture(gcolor, midcoord);
    vec4 tmpCd = outCd;
    mixColor = tmpCd.rgb;
    #if (BaseQuality > 1)
      tmpCd = outCd*textureOffset(gcolor, midcoord, ivec2(-txlOffset.x, txlOffset.y) );
      mixColor = mix( mixColor, tmpCd.rgb, avgBlend*tmpCd.a);
      tmpCd = outCd*textureOffset(gcolor, midcoord, ivec2(txlOffset.x, -txlOffset.y) );
      mixColor = mix( mixColor, tmpCd.rgb, avgBlend*tmpCd.a);
      #if (BaseQuality == 2)
        tmpCd = outCd*textureOffset(gcolor, midcoord, ivec2(-txlOffset.x, -txlOffset.y) );
        mixColor = mix( mixColor, tmpCd.rgb, avgBlend*tmpCd.a);
        tmpCd = outCd*textureOffset(gcolor, midcoord, ivec2(-txlOffset.x, txlOffset.y) );
        mixColor = mix( mixColor, tmpCd.rgb, avgBlend*tmpCd.a);
      #endif
    #endif
    //mixColor = mix( vec3(length(outCd.rgb)), mixColor, step(.1, length(mixColor)) );
    mixColor = mix( vec3(outCd.rgb), mixColor, step(.1, mixColor.r+mixColor.g+mixColor.b) );

    outCd = vec4( mixColor, outCd.a); // 1.0);

    //outCd = vec4( mixColor, 1.0);


    color=outCd;
    color = vaColor;
    color = gl_Color;

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

#endif

#ifdef FSH

layout(Location = 0) out vec4 outCd;
layout(Location = 1) out vec4 outData;

/* --
const int shadowcolor1Format = RG16;
 -- */

  #include "/shaders.settings"

	uniform sampler2D gcolor;
	uniform float far;

  in vec2 texcoord;
	in vec2 texmidcoord;
  in vec4 color;
  in vec3 vShadowPos;
  in float vShadowDist;
  in float vIsLeaves;
  in float vIsTranslucent;
	

  void main() {

    float outAlpha = texture2D(gcolor,texcoord.xy).a;
    vec4 shadowCd = color;

    shadowCd.a= min( 1.0, shadowCd.a * outAlpha + vIsLeaves );

    if( shadowCd.a<0.01 ){
      discard;
    }
		
		shadowCd.a*=1.0-vIsTranslucent;
    outCd = shadowCd;
    //outData = vec4( length(vShadowPos)/far, shadowCd.aaa );
    outData = vec4( length(vShadowPos)/far, length(vShadowPos), shadowCd.aa );
    //outData = vec4( vIsTranslucent, vShadowDist, 0.0, 0.0 );
    //outData = vec4( vIsTranslucent, length(vShadowPos), 0.0, 0.0 );
  }

#endif

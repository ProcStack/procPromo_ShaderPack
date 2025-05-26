#version 450 compatibility

#define OVERWORLD
#define SHADOW

#define FSH

layout(Location = 0) out vec4 outCd;
layout(Location = 1) out vec4 outData;

/* --
const int shadowcolor1Format = RG16;
 -- */

  #include "/shaders.settings"

	uniform sampler2D gtexture;
	uniform float far;

  in vec2 texcoord;
  in vec4 color;
  in vec3 vShadowPos;
  in float vShadowDist;
  in float vIsLeaves;
  in float vIsTranslucent;
	

  void main() {

    float outAlpha = texture2D(gtexture,texcoord.xy).a;
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

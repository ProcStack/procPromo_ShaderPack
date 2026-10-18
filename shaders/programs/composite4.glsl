// GBuffer - Composite #4 GLSL
//   Written by Kevin Edzenga, ProcStack; 2022-2023
//
// Reflective Surfaces; Water / Transparency

#ifdef VSH
  #include "utils/shadowCommon.glsl"

  uniform vec3 cameraPosition; 
  uniform float aspectRatio;
  uniform float viewWidth;
  uniform float viewHeight;

  varying vec2 vUv;
  varying vec3 vCamPos;
  varying vec4 vView;

  void main() {
    gl_Position = ftransform();
    vUv = gl_MultiTexCoord0.xy;
    vCamPos = cameraPosition;


    //vView = farViewDir.xyz / farViewDir.w;
    //vView =  (gl_Position.xyz/gl_Position.w)*.5+.5;
    vView =  gl_Position;
    vView.z = vView.z-1.0;
  }

#endif

#ifdef FSH
/* RENDERTARGETS: 9 */
// target - colortex9

/* COLORTEX9FORMAT:RGBA16 */

  #include "/shaders.settings"
  #include "utils/mathFuncs.glsl"
  #include "utils/texSamplers.glsl"

  uniform sampler2D colortex0; // Diffuse Pass
  uniform sampler2D colortex1; // Depth Pass
  uniform sampler2D colortex2; // Screen-space surface normal Pass

  uniform sampler2D gaux1;
  uniform vec2 texelSize;
  uniform sampler2D gdepth;
  uniform sampler2DShadow shadowtex0;
  uniform float far;

  uniform mat4 gbufferModelView;
  uniform mat4 gbufferModelViewInverse;
  uniform mat4 gbufferProjection;
  uniform mat4 gbufferProjectionInverse;
  uniform mat4 shadowModelView;
  uniform mat4 shadowProjection;
  uniform float eyeBrightnessFit;
  uniform int isEyeInWater;


  uniform vec3 sunPosition;
  uniform float rainStrength;
  uniform float moonPhaseMultCrepuscular;
  uniform float moonPhaseFit;
  uniform vec3 fogColor;
  uniform float dayNight;
  uniform float moonInf;
  uniform float sunMoonCrossFade;
  uniform float moonPhaseMultVar;


  varying vec2 vUv;
  varying vec3 vCamPos;
  varying vec4 vView;


  // -- -- -- -- -- -- --
  // -- Sample Helpers  -- --
  // -- -- -- -- -- -- -- -- --

  float jitter(vec2 coord, float seed) {
    return fract( sin(dot(coord, vec2(12.9898+seed, 78.233-seed*10.0))) * 43758.5453 )*.01-.005;
  }

  vec3 scatter(vec3 pos, float depth, float seed) {
    return fract(cos(pos*10.0+vec3(seed*234.2342) * depth )*1213.123124)*2.0-1.0;
  }

  vec3 reconstructViewPos(vec2 uv, float depth) {
    vec4 clip = vec4(uv * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
    vec4 view = gbufferProjectionInverse * clip;
    return view.xyz / view.w;
  }

  vec3 projectToScreen(vec3 viewPos) {
    vec4 clip = gbufferProjection * vec4(viewPos, 1.0);
    vec3 ndc = clip.xyz / clip.w;
    return vec3(ndc.xy * 0.5 + 0.5, ndc.z * 0.5 + 0.5);
  }

  // -- -- -- -- -- -- 
  // -- Doobie Doo! -- --
  // -- -- -- -- -- -- -- --

  void main() {

#if ReflectionQuality > 0
    vec3 viewProjectionNormal = normalize(vView.xyz);


    vec2 lightReflectionCdBase = texture2D(gaux1, vUv).rg; // Shadow Position and Depth
    float lightCdBase = lightReflectionCdBase.r; // Shadow Position and Depth
    float reflectionMask = step(0.0001, lightReflectionCdBase.g); // Reflective Surface Mask
    vec4 shadowPosDepthBase = texture2D(colortex1, vUv); // Shadow Position and Depth
    vec3 posBase = shadowPosDepthBase.rgb;
    float depthBase = shadowPosDepthBase.a;
    float isSky = clamp(smoothstep(.994, 0.9999, depthBase), 0.0, 1.0); // 0 foreground, 1 sky


    float sceneDepth = depthBase;
    float sceneInvDepth = 1.0-sceneDepth;

    vec3 viewPos = reconstructViewPos(vUv, sceneDepth);
    vec3 normal = normalize(texture2D(colortex2, vUv).xyz * 2.0 - 1.0);

    // Camera is at (0,0,0) in view space.
    vec3 rayDir = normalize(reflect( normalize(viewPos), normal ));

    vec3 rayPos = viewPos + normal * 0.05; // self-intersection bias
    float hit = 0.0;
    vec2 hitUv = vec2(0.0);
    float fade = 0.0;

    #if ReflectionQuality == 1
      const int maxSteps = 8;
      const float baseDist = 0.03;
      const float stepSize = 0.15;
    #elif ReflectionQuality == 2
      const int maxSteps = 18;
      const float baseDist = 0.04;
      const float stepSize = 0.12;
    #elif ReflectionQuality == 3
      const int maxSteps = 32;
      const float baseDist = 0.05;
      const float stepSize = 0.1;
    #endif
    for( int x = 0; x < maxSteps; ++x ){
      float dist = baseDist + float(x) * stepSize;
      float stepr = float(x) * stepSize+ 1.0;
      vec3 samplePos = rayPos + rayDir * sceneDepth*stepr - vec3(0.0, 0.1, 0.0);
      //vec3 samplePos = rayPos + rayDir * dist - vec3(0.0, 0.01, 0.0);
      vec3 projected = projectToScreen(samplePos);
      projected.x += jitter( vUv, dist )*sceneInvDepth;
      projected.y += jitter( vUv, dist+0.1 )*sceneInvDepth;

      if( projected.x < -0.30 || projected.x > 1.30 ||
        projected.y < -0.30 || projected.y > 1.30 ){
        break;
      }


      //float sceneSampleDepth = texture2D(depthtex0, projected.xy).r;
      float sceneSampleDepth = texture2D(colortex1, projected.xy).a;

      // With standard OpenGL projection, larger depth is farther away.
      // The ray hit geometry once it moves behind sampled scene depth.
      if( projected.z > sceneSampleDepth + 0.0015 ){
        hit = 1.0;
        hitUv = projected.xy;
        fade = 1.0-clamp((max( abs(projected.x-.5), abs(projected.y-.5) )-.45)*10.0, 0.0, 1.0);
        break;
      }
    }

    vec3 reflection = hit>0.5 ? texture2D(colortex0, hitUv).rgb : vec3(0.0);
    float fresnel = pow(1.0 - max(dot(normal, normalize(-viewPos)), 0.0), 3.0);

    vec4 outCd = vec4(reflection * reflectionMask * mix(0.1, 1.0, fresnel)*fade, hit);
    //outCd = vec4(vec3(reflectionMask), 1.0);
    //outCd = vec4(vec3(lightReflectionCdBase.b), 1.0);

    //outCd.rgb = normal;

#else
    vec4 outCd = vec4(1.0,1.0,1.0,0.0);
#endif
    //outCd = vec4(1.0,0.0,0.5,1.0);
    gl_FragData[0] = outCd;
    
  }


#endif



// GBuffer - Composite #4 GLSL
//   Written by Kevin Edzenga, ProcStack; 2022-2023
//
// Ambiance Volume / Crepuscular Rays
//   Currently runs at 40% resolution
//   Only runs in the Overworld
//     And other worlds marked `0`
//   Bypassed when shader setting `VolumeRayCount` is set to '0'

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
/* RENDERTARGETS: 10 */
// target - colortex10

/* COLORTEX9FORMAT:RGBA16 */
/*
const int colortex6Format = RGBA16F;
const int colortex9Format = RGBA16F;
*/

  #include "/shaders.settings"
  #include "utils/mathFuncs.glsl"
  #include "utils/shadowCommon.glsl"
  #include "utils/texSamplers.glsl"

  uniform sampler2D colortex1; // Bind 1
  uniform sampler2D colortex9; // Bind 17
  uniform vec2 texelSize;
  uniform float far;

  uniform mat4 gbufferModelView;
  uniform mat4 gbufferModelViewInverse;
  uniform mat4 gbufferProjection;
  uniform mat4 gbufferProjectionInverse;
  uniform mat4 shadowModelView;
  uniform mat4 shadowProjection;
  uniform float eyeBrightnessFit;

  uniform sampler2D gdepth;
  uniform sampler2D gaux1;
  uniform sampler2DShadow shadowtex0;

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


  // -- -- -- -- -- -- -- -- -- -- --
  // -- Shadow Sample Helper  -- --
  // -- -- -- -- -- -- -- -- -- -- -- -- --

  vec3 projectShadowLookup(vec3 viewPos) {
      vec3 worldPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;

      vec3 shadowPos = (shadowModelView * vec4(worldPos, 1.0)).xyz;

      shadowPos = projMAD(shadowProjection, shadowPos);

      vec4 warpedShadowPos = distortShadowShift(vec4(shadowPos, 1.0));

      vec3 lookup = warpedShadowPos.xyz * shadowPosMult + shadowPosOffset;
      lookup.z = 0.5 - min( 1.0, (shadowThreshBase + shadowThreshDist) * shadowThreshold );

      return lookup;
  }


  float jitter(vec2 coord, float depth, float seed) {
      return fract( sin(dot(coord, vec2(12.9898+depth+seed, 78.233-seed*10.0))) * 43758.5453 )*.1-.05;
  }

  vec3 scatter(vec3 pos, float depth, float seed) {
      return fract(cos(pos*10.0+vec3(seed*234.2342) * depth )*1213.123124)*2.0-1.0;
  }

  // -- -- -- -- -- -- 
  // -- Doobie Doo! -- --
  // -- -- -- -- -- -- -- --

  void main() {

#if VolumeRayCount > 0
    vec3 viewProjectionNormal = normalize(vView.xyz);


    float lightCdBase = texture2D(gaux1, vUv).r; // Shadow Position and Depth
    vec4 shadowPosDepthBase = texture2D(colortex1, vUv); // Shadow Position and Depth
    vec3 posBase = shadowPosDepthBase.rgb;
    float depthBase = shadowPosDepthBase.a;
    float isSky = clamp(smoothstep(.98, 0.9999, depthBase), 0.0, 1.0);

    // Unproject fullscreen-quad to camera-space-shadow ray
    //   Used when `isSky=1.0`
    vec3 farViewDir = ( mat3(shadowModelView) * mat3(gbufferModelViewInverse) * vView.xyz );

    vec4 outCd = vec4(0.0);

    vec3 shadowPosOffset = vec3(0.0);//fract(vCamPos.xyz)*.01;

    vec4 scenePosDepth = texture2D(gdepth, vUv);
    vec3 sceneWorldPos = scenePosDepth.rgb;
    float sceneDepth = scenePosDepth.a;
    //float hasGeometry = step(sceneDepth, 0.99999);

    vec4 sceneClip = vec4(vUv * 2.0 - 1.0, sceneDepth * 2.0 - 1.0, 1.0);
    vec4 sceneView = gbufferProjectionInverse * sceneClip;
    sceneView.xyz /= sceneView.w;

    // Strongest when looking toward the active sun/moon.
    //float forwardScatter = max(0.0,dot(normalize(sceneView.xyz), normalize(sunPosition))*.5+.5);
    //forwardScatter *= forwardScatter;//*forwardScatter;

    // Cheap per-pixel phase offset breaks marching bands.
    //float jitter = fract( sin(dot(gl_FragCoord.xy, vec2(12.9898+sceneDepth, 78.233))) * 43758.5453 )*.1;

    float rayLight = 0.0;

    // Multisample a base shadow value
    float reachMult = 1.0;
    int addToCount = 0;
    #if ShadowSampleCount == 2
      vec2 posOffset;
      float multiSampleLight = 0.0;
      for( int x=0; x<axisSamplesCount; ++x){
        posOffset = axisSamples[x]*reachMult*shadowMapTexelSize;
        vec3 shadowLookup = sceneWorldPos + vec3( posOffset, shadowVolume_FarBias*0.5 );
      
        multiSampleLight +=  texture(shadowtex0, shadowLookup);
      }
      multiSampleLight = multiSampleLight * axisSamplesFit;
      multiSampleLight = 1.0-(1.0-biasToOne(multiSampleLight, 4.0))*.85;
      rayLight = multiSampleLight*2.0;
      addToCount++;
    #elif ShadowSampleCount >= 3
      vec2 posOffset;
      float multiSampleLight = 0.0;
      for( int x=0; x<boxSamplesCount; ++x){
        posOffset = boxSamples[x]*reachMult*shadowMapTexelSize;
        
        vec3 shadowLookup = sceneWorldPos + vec3( posOffset, shadowVolume_FarBias*0.5 );
        multiSampleLight += texture(shadowtex0, shadowLookup);
      }
      multiSampleLight = multiSampleLight * boxSampleFit;
      multiSampleLight = 1.0-(1.0-biasToOne(multiSampleLight, 4.0))*.5;
      rayLight = multiSampleLight*2.0;
      addToCount++;
    #endif


    // Crepuscular ray march setup

    // Crepuscular rays min of .75 and max of .9995 of depth range
    vec3 shadowOrigin = (sceneWorldPos+shadowPosOffset-.5)*.98+.5;
    //shadowOrigin = vec3(.5,.65,.5);
    vec3 shadowTarget = (sceneWorldPos+shadowPosOffset-.5)*0.998+.5;

    //shadowOrigin = mix(  shadowOrigin, farViewDir*.5-.5, isSky);
    //shadowTarget = mix(  shadowTarget, farViewDir*.1-.5, isSky);

    shadowOrigin.z -= shadowVolume_NearBias;
    shadowTarget.z -= shadowVolume_FarBias;
    //float middleDistanceMask = min( 1.0, max(0.0,((sceneDepth-.75*(1.0-length(vView.xyz)*.42))*2.0)) * (1.0-max(0.0, ((sceneDepth-0.96)*20.80672268907563))));
    float middleDistanceMask = min( 1.0, (1.0-max(0.0, ((sceneDepth-0.96)*20.80672268907563))));
    float middleDistanceMaskInv =  1.0-middleDistanceMask;

    float volRayCountInv = 1.0 / float(VolumeRayCount);
    for (int x = 0; x < VolumeRayCount; ++x) {
        float stepFit = (float(x) + jitter(gl_FragCoord.xy, sceneDepth, float(x))) * volRayCountInv;
        stepFit = biasToOne(stepFit,1.0+sceneDepth*0.8);

        vec3 shadowLookup = mix(shadowOrigin, shadowTarget, stepFit*stepFit);
        //shadowLookup += scatter(shadowLookup, sceneDepth, float(x))*vec3(0.01,0.01,0.01);
        
        float lightVisibility = texture(shadowtex0, shadowLookup);
        //lightVisibility = clamp((lightVisibility-.5)*2.0+0.5, 0.0, 1.0);

        rayLight += lightVisibility ;
    }

    float rays = min(1.0, rayLight / float(VolumeRayCount) * 1.5);


    float moonAmbianceInf =  moonInf;
    float depthInf = 1.0-min(1.0,max(0.0, depthBase*depthBase-.9 - isSky)*6.2);
    depthInf = min(1.0,max(0.0, lightCdBase-.4)*2.5*depthInf ) * moonAmbianceInf;
    //depthInf = 1.0;
    
    float rayScalar = mix( 0.0, 1.0-moonPhaseMultVar, moonAmbianceInf);
    
    //float rays = min( 1.0, rayLight / float(VolumeRayCount)*max(isSky,middleDistanceMask) + max( rainStrength, middleDistanceMaskInv ) );
    //rays = min( 1.0, rays + isSky + rainStrength + middleDistanceMaskInv + max(0.0, 1.0-eyeBrightnessFit*1.5) + depthInf );
    //rays = mix( rays, rays*.2+.8, rayScalar );

    vec3 rayColor = fogColor*.5;
    outCd.rgb = mix( rayColor, vec3( 1.0 ), rays+(1.0-sunMoonCrossFade) );



#else
    vec4 outCd = vec4(1.0,1.0,1.0,0.0);
#endif
    
    gl_FragData[0] = outCd;
    
  }


#endif



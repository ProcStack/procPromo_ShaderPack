// GBuffer - Composite #5 GLSL
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
  uniform float sunAngle;

  varying vec2 vUv;
  varying vec3 vCamPos;
  varying vec4 vView;
  varying float sunPhaseMult;

  void main() {
    gl_Position = ftransform();
    vUv = gl_MultiTexCoord0.xy;
    vCamPos = cameraPosition;


    //vView = farViewDir.xyz / farViewDir.w;
    //vView =  (gl_Position.xyz/gl_Position.w)*.5+.5;
    vView =  gl_Position;
    vView.z = vView.z-1.0;

    // Sun Influence
    sunPhaseMult = step(sunAngle, .5);//1.0-max(0.0,sunAngle*2.0-1.0);
  }

#endif

#ifdef FSH
/* RENDERTARGETS: 10 */
// target - colortex10

/* COLORTEX10FORMAT:RGBA16 */
/*
const int colortex6Format = RGBA16F;
const int colortex10Format = RGBA16F;
*/

  #include "/shaders.settings"
  #include "utils/mathFuncs.glsl"
  #include "utils/shadowCommon.glsl"
  #include "utils/texSamplers.glsl"

  uniform sampler2D colortex0; // Diffuse Pass
  uniform sampler2D colortex1; // Depth Pass
  uniform sampler2D colortex2; // Normal Pass
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
  uniform int isEyeInWater;

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
  varying float sunPhaseMult;


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
    vec4 outCd = vec4(0.0);

#if VolumeRayCount > 0
    vec3 viewProjectionNormal = normalize(vView.xyz);


    vec2 lightOffsetCdBase = texture2D(gaux1, vUv).rb; // Depth and offset amount
    float lightCdBase = lightOffsetCdBase.r; // Depth
    float lightOffset = lightOffsetCdBase.g; // Offset amount
    float shadowSurfaceSunDot = texture2D(colortex2, vUv).a; // Shadow Position and Depth
    float lightValBase = texture2D(colortex9, vUv).r; // Shadow Position and Depth
    vec4 shadowPosDepthBase = texture2D(colortex1, vUv); // Shadow Position and Depth
    vec3 posBase = shadowPosDepthBase.rgb;
    float depthBase = shadowPosDepthBase.a;
    float isSky = clamp(smoothstep(.994, 0.9999, depthBase), 0.0, 1.0);

    // Unproject fullscreen-quad to camera-space-shadow ray
    //   Used when `isSky=1.0`
    vec3 farViewDir = ( mat3(shadowModelView) * mat3(gbufferModelViewInverse) * vView.xyz );


    vec3 shadowPosOffset = vec3(0.0);//fract(vCamPos.xyz)*.01;

    vec4 scenePosDepth = texture2D(gdepth, vUv);
    vec3 sceneWorldPos = scenePosDepth.rgb;
    float sceneDepth = scenePosDepth.a*scenePosDepth.a;
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
    float reachMult = 1.0+sceneDepth*1.75;
    vec2 posOffset = vec2(0.0);
    //float countDiv = float(VolumeRayCount);
    vec3 shadowLookup = sceneWorldPos + vec3( 0.0,0.0, -ambianceVolume_TargetBias );
    float multiSampleLight =  texture(shadowtex0, shadowLookup);
    float invDepth = 1.0-sceneDepth*sceneDepth;
    float localInvDepth = invDepth*1.1; // Remove close-to-cam depth shadow artifacts
    
    #if ShadowSampleCount == 1
      multiSampleLight = multiSampleLight;
      //multiSampleLight = 1.0-(1.0-biasToOne(multiSampleLight, 2.0))*.55;
      //rayLight = multiSampleLight*2.0;
      //countDiv += 1.0;
    #elif ShadowSampleCount == 2
      for( int x=0; x<axisSamplesCount; ++x ){
        posOffset = axisSamples[x]*reachMult*shadowMapTexelSize;
        
        shadowLookup = sceneWorldPos + vec3( posOffset, -ambianceVolume_TargetBias );
        multiSampleLight += texture(shadowtex0, shadowLookup);
      }
      multiSampleLight = multiSampleLight * axisSamplesFit;
      //multiSampleLight = 1.0-(1.0-biasToOne(multiSampleLight, 2.0))*.55;
      //rayLight = multiSampleLight*2.0;
      //countDiv += 1.0;
    #elif ShadowSampleCount >= 3
      for( int x=0; x<boxSamplesCount; ++x ){
        posOffset = boxSamples[x]*reachMult*shadowMapTexelSize;
        
        shadowLookup = sceneWorldPos + vec3( posOffset, -ambianceVolume_TargetBias );
        multiSampleLight += texture(shadowtex0, shadowLookup);
      }
      multiSampleLight = multiSampleLight * boxSampleFit;
      //multiSampleLight = 1.0-(1.0-biasToOne(multiSampleLight, 2.0))*.55;
      //rayLight = multiSampleLight*2.0;
      //countDiv += 1.0;
    #endif
    multiSampleLight=clamp((1.0-(1.0-biasToOne(multiSampleLight, 2.0))*.55)-.1+isSky, 0.0, 1.0);

    // Crepuscular ray march setup

    // Crepuscular rays min of .75 and max of .9995 of depth range
    vec3 shadowOrigin = (sceneWorldPos+shadowPosOffset-.5)*.98+.5;
    //shadowOrigin = vec3(.5,.65,.5);
    vec3 shadowTarget = (sceneWorldPos+shadowPosOffset-.5)*0.998+.5;


    //shadowOrigin = mix(  shadowOrigin, farViewDir*.5-.5, isSky);
    //shadowTarget = mix(  shadowTarget, farViewDir*.1-.5, isSky);

    shadowOrigin.z -= ambianceVolume_NearBias;
    shadowTarget.z -= ambianceVolume_FarBias;
    
    //float middleDistanceMask = min( 1.0, max(0.0,((sceneDepth-.75*(1.0-length(vView.xyz)*.42))*2.0)) * (1.0-max(0.0, ((sceneDepth-0.96)*20.80672268907563))));
    float distanceFade = clamp( (sceneDepth-0.95)*20.80672268907563, 0.0, 1.0);
    float middleDistanceMask = 1.0-distanceFade;
    float middleDistanceMaskInv =  distanceFade;

    rayLight = 1.0;
    //rayLight += shadowSurfaceSunDot*5.0;
    //countDiv += 5.0;
    //multiSampleLight += shadowSurfaceSunDot;

    float volRayCountInv = 1.0 / float(VolumeRayCount);
    //float localDepth = 1.0 + max( 0.0, sceneDepth*1.5-0.5 )*2.5;
    float localDepth = 1.0 + sceneDepth*10.0;
    float stepFit = 0.0;
    for (int x = 0; x < VolumeRayCount; ++x) {
      stepFit = (float(x) + jitter(gl_FragCoord.xy, sceneDepth, float(x))) * volRayCountInv;
      //stepFit = biasToOne(stepFit,1.2+max(sceneDepth,0.1)*20.8);
      //stepFit = biasToOne(stepFit,2.5+sceneDepth*20.8);
      stepFit = biasToOne(stepFit,localDepth);

      vec3 shadowLookup = mix(shadowOrigin, shadowTarget, stepFit*stepFit);
      //shadowLookup += scatter(shadowLookup, sceneDepth, float(x))*vec3(0.01,0.01,0.01);
      shadowLookup.z -= lightOffset + localInvDepth*.0005;// - clamp( (sceneDepth-0.7)*3.4, 0.0, 1.0)*.0025;
      float lightVisibility = texture(shadowtex0, shadowLookup);
      //lightVisibility = clamp((lightVisibility-.5)*2.0+0.5, 0.0, 1.0);

      rayLight += lightVisibility ;
    }

    float moonAmbianceInf =  moonInf;
    float depthInf = 1.0-min(1.0,max(0.0, depthBase*depthBase-.9 - isSky)*6.2);
    float depthDotInf = 1.0-min(1.0,max(0.0, depthBase-.65 - isSky)*4.2);
    float shadowBlend = clamp(biasToOne(depthBase*depthBase-.5), 0.0, 1.0);

    float rays = min(1.0, rayLight / float(VolumeRayCount) * 1.5 );
    rays = min( rays*1.3 , shadowSurfaceSunDot*.75+.25) * min(1.0,shadowSurfaceSunDot+(1.0-depthDotInf));
    rays = mix( multiSampleLight, rays, shadowBlend);


    //depthInf = mix( max(lightCdBase,isSky)*.62+.38, min(1.0,max(0.0, lightCdBase-.4)*2.5*depthInf ), moonAmbianceInf);
    //depthInf = mix( 1.0, min(1.0,max(0.0, lightCdBase-.4)*2.5*depthInf ), moonAmbianceInf);
    //depthInf = 1.0;
    
    float rayScalar = mix( 0.0, 1.0-moonPhaseMultVar, moonAmbianceInf);
    
    //float rays = min( 1.0, rayLight / float(VolumeRayCount)*max(isSky,middleDistanceMask) + max( rainStrength, middleDistanceMaskInv ) );
    //rays = min( 1.0, rays + isSky + rainStrength + middleDistanceMaskInv + max(0.0, 1.0-eyeBrightnessFit*1.5) + depthInf );
    float localEyeBrightness = clamp((eyeBrightnessFit-.5)*2.0+.5, 0.0, 1.0);
    rays = min( 1.0, mix(rays*.9+.1, rays*.2+.8, rayScalar)*lightCdBase + max(rainStrength*localEyeBrightness, middleDistanceMaskInv) );

    vec3 rayColor = fogColor*.5;
    float nightLighting = max(0.0, (lightCdBase-.4)*1.5)*moonInf * depthInf;
    outCd.rgb = mix( rayColor, vec3( 1.0 ), min(1.0, max(rays,isSky)+(1.0-sunMoonCrossFade)+(1.0-clamp(eyeBrightnessFit*2.0-.5,0.0,1.0)) + nightLighting ) );
    
    //outCd.rgb = vec3( multiSampleLight );
    //outCd.rgb *= vec3( mix( 0.0, lightCdBase, (1.0-sunPhaseMult*rayScalar)*eyeBrightnessFit) );
    //outCd.rgb = vec3( max(0.0, (lightCdBase-.4)*1.5)*moonInf );
    //outCd.rgb = vec3(rays);

    //float viewDot = 1.0-max(0.0,dot(vNormal.xyz, -normalize(vPos.xyz)));


#else
    outCd = vec4(1.0,1.0,1.0,0.0);
#endif
    
    gl_FragData[0] = outCd;
    
  }


#endif



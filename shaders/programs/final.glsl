
#ifdef VSH

uniform sampler2D gnormal;
uniform float aspectRatio;
uniform float viewWidth;
uniform float viewHeight;

uniform vec3 sunPosition;
uniform vec3 upPosition;

varying vec2 texcoord;
varying vec2 res;

varying vec3 sunVecNorm;
varying vec3 upVecNorm;
varying float dayNight;

void main() {
  
	sunVecNorm = normalize(sunPosition);
	upVecNorm = normalize(upPosition);
	dayNight = dot(sunVecNorm,upVecNorm);
  
	gl_Position = ftransform();
	texcoord = (gl_MultiTexCoord0).xy;
  
  res = vec2( 1.0/viewWidth, 1.0/viewHeight);
}
#endif

#ifdef FSH

/* --
const int gcolorFormat = RGBA8;
const int gdepthFormat = RGBA16; //it's to inacurrate otherwise
const int gnormalFormat = RGB10_A2;
const float eyeBrightnessHalflife = 4.0f;
 -- */
 
#include "/shaders.settings"

uniform sampler2D colortex0; // Diffuse Pass
uniform sampler2D colortex1; // Depth Pass
uniform sampler2D colortex2; // Normal Pass
//uniform sampler2D colortex4; // Light Pass


uniform sampler2D gaux1;
uniform sampler2D gaux2; // 40% Res Glow Pass
uniform sampler2D gaux3; // 20% Res Glow Pass
uniform sampler2D gaux4; // 20% Res Glow Pass
uniform sampler2D colortex8; // Known working from terrain gbuffer

uniform sampler2D gcolor;
uniform sampler2D gdepth;
uniform sampler2D gnormal;
uniform sampler2D composite;
uniform vec3 sunPosition;
uniform int isEyeInWater;
uniform float aspectRatio;
uniform float viewWidth;
uniform float viewHeight;
uniform float near;
uniform float far;

uniform float InTheEnd;

varying vec2 texcoord;

varying vec3 sunVecNorm;
varying vec3 upVecNorm;
varying float dayNight;
varying vec2 res;


// https://stackoverflow.com/questions/15095909/from-rgb-to-hsv-in-opengl-glsl
vec3 rgb2hsv(vec3 c)
{
    vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
    vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));

    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}
vec3 hsv2rgb(vec3 c)
{
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

const int boxSamplesCount = 8;
const vec2 boxSamples[8] = vec2[8](
                              vec2( -1.0, -1.0 ),
                              vec2( -1.0, 0.0 ),
                              vec2( -1.0, 1.0 ),

                              vec2( 0.0, -1.0 ),
                              vec2( 0.0, 1.0 ),

                              vec2( 1.0, -1.0 ),
                              vec2( 1.0, 0.0 ),
                              vec2( 1.0, 1.0 )
                            );


vec4 findEdges( sampler2D txDepth,  sampler2D txNormal, vec2 uv, vec2 txRes, float thresh){
  float depthCd = texture2D(txDepth, uv).r;
  vec3 normalCd = texture2D(txNormal, uv).rgb*2.0-1.0;
  //vec3 sampleHSV = rgb2hsv( sampleCd.rgb );
  float reachMult = min(1.0, depthCd*.8+.2);
  
  vec3 avgNormal = normalCd;
  
  float edgeOut = 0.0;
  float depthOut = 0.0;
  
  vec2 curUV;
  float curDepth;
  vec3 curNormal;
  float curInf;
  
  for( int x=0; x<boxSamplesCount; ++x){
    curUV =  uv + boxSamples[x]*txRes*reachMult ;
    
    curDepth = min(1.0, texture2D(txDepth, curUV).r);
    curNormal = texture2D(txNormal, curUV).rgb*2.0-1.0;
    curInf = step( abs(curDepth - depthCd), thresh );
    edgeOut = max( edgeOut, 1.0-abs(dot(normalCd, curNormal)*curInf) );
    depthOut = max( depthOut, abs(curDepth - depthCd) );
    
    curInf = max(edgeOut, step(0.005, depthOut)*.5 );
    curInf *= dot(avgNormal, curNormal)*.5+.5;
    //avgNormal = mix( avgNormal, curNormal, max(edgeOut, step(0.005, depthOut)*.5 ) );
    avgNormal = mix( avgNormal, curNormal, curInf );
    
  }
  depthOut = (1.0-depthOut)*step(0.075, depthOut); 
  
  edgeOut = max( edgeOut, depthOut );
  
  return vec4( normalize(avgNormal), edgeOut );
}



void main() {

  vec4 baseCd = texture2D(colortex0, texcoord);
  vec4 outCd = baseCd;
  float depth = texture2D(colortex1, texcoord).r;
  vec4 normal = texture2D(colortex2, texcoord);
  normal.rgb = normal.rgb*2.0-1.0;
  vec2 shadowCd = texture2D(gaux1, texcoord).xy;
  float shadow = shadowCd.x;
  float shadowDepth = shadowCd.y;

  //vec4 light = texture2D(colortex4, texcoord);
  //depth = (depth-near)/(far-near);
  
  // Glow Passes
  vec3 blurMidCd = texture2D(gaux2, texcoord*.4).rgb;
  vec3 blurLowCd = texture2D(gaux3, texcoord*.3).rgb;
  
  //depth = 1.0-(1.0-depth)*(1.0-depth);
  //depth *= depth;
  
  //shadowDepth = 1.0-(1.0-shadowDepth)*(1.0-shadowDepth);
  //shadowDepth *= shadowDepth;
  
  
  float dotToCam = max(0.0, dot(normal.rgb,vec3(0.0,0.0,1.0)));
  dotToCam = smoothstep(.5,.7, dotToCam+normal.a);

  
  vec4 avgNormalEdge = findEdges( colortex1, colortex2, texcoord, res*2.5*(depth)*EdgeShading, .9);
  vec3 avgNormal = avgNormalEdge.xyz;
  float edgePerc = avgNormalEdge.w;
  //edgePerc *= ((shadow*.5+.5)*min(1.0,depth+.3));
  //edgePerc *= min(1.0,depth+.3);//*(shadow*.3+.8);
  //edgePerc *= 1.0-(1.0-depth)*(1.0-depth);
  //edgePerc *= 1.0-min(1.0,max(0,isEyeInWater-1)*.35);
  edgePerc *= dotToCam*1.5;
  
  
	//const vec3 moonlight = vec3(0.5, 0.9, 1.8) * Moonlight;
  edgePerc = smoothstep(.4,.7,min(1.0,edgePerc));
#ifdef NETHER
  edgePerc *= .5;
#endif
  
#ifdef THE_END
    float sunNightInf = abs(dayNight)*.3;
    float sunInf = dot( avgNormal, sunVecNorm ) * max(0.0, dayNight);
    float moonInf = dot( avgNormal, vec3(1.0-sunVecNorm.x, sunVecNorm.yz) ) * max(0.0, -dayNight);
    vec3 colorHSV = rgb2hsv(outCd.rgb);
    
    float sunMoonValue = max(0.0, sunInf+moonInf) * edgePerc * sunNightInf * shadow;
    //float sunMoonValue = max(0.0, sunInf+moonInf) * sunNightInf;// * edgePerc;// * shadow;
    
    //colorHSV.b += sunMoonValue;
    colorHSV.b += sunMoonValue;//-(shadow*.2+depth*.2)*EdgeShading;
    //colorHSV.b *= 1.0*(shadow+.2);//+depth*.2)*EdgeShading;
    outCd.rgb = hsv2rgb(colorHSV);
    //outCd.rgb = mix( baseCd.rgb, mix(baseCd.rgb*1.5,outCd.rgb,shadow)*edgePerc, EdgeShading*.25+.5);
    outCd.rgb = mix( outCd.rgb, hsv2rgb(colorHSV), EdgeShading*.25+.75);
    //outCd.rgb = mix( baseCd.rgb, outCd.rgb, EdgeShading*.25+.5);

#endif

#ifdef NETHER
  //outCd.rgb *= outCd.rgb * vec3(.8,.6,.2) * edgePerc;// * (shadow*.3+.7);
  outCd.rgb =  mix(outCd.rgb, outCd.rgb * vec3(.75,.5,.2), edgePerc);// * (shadow*.3+.7);
#endif

#ifdef OVERWORLD
  float sunEdgeInf = dot( sunVecNorm, avgNormal )*.5+.5;
  outCd.rgb += outCd.rgb * (edgePerc*sunEdgeInf*.5);// * (shadow*.3+.7);
#endif
  

  
  vec3 outGlowCd = max(blurMidCd, blurLowCd);
  outCd.rgb += outGlowCd+outCd.rgb*(edgePerc-.3)*.25 * GlowBrightness;//*(outGlowCd*.5+.5);


	gl_FragColor = vec4(outCd.rgb,1.0);
}
#endif
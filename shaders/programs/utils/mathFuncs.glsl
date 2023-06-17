
#define PI 3.14159265358979323
#define TAU 6.2831853071958646

///https://stackoverflow.com/questions/15095909/from-rgb-to-hsv-in-opengl-glsl
vec3 rgb2hsv(vec3 c){
  vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
  vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
  vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));

  float d = q.x - min(q.w, q.y);
  float e = 1.0e-10;
  return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}
vec3 hsv2rgb(vec3 c){
  vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
  vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
  return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

// -- -- -- -- -- --

vec2 rotToUV(vec3 direction){
  vec2 uv = vec2(atan(direction.z, direction.x), asin(direction.y));
  uv *= vec2(0.1591, 0.3183);
  uv += 0.5;
  return uv;
}

vec3 addToGlowPass(vec3 baseCd, vec3 addCd){
  return max(baseCd, addCd);
}
// Human Eye Adjusted Luminance
float luma(vec3 color) {
	return dot(color,vec3(0.299, 0.587, 0.114));
}

float biasToOne( float value ){
  return 1.0-(1.0-value)*(1.0-value);
}
float biasToOne( float value, float bias ){
  return 1.0-(1.0-min(1.0,value*bias))*(1.0-min(1.0,value*bias));
}

// Return max vector component
float maxComponent(vec2 val){
  return max(val.x,val.y);
}
float maxComponent(vec3 val){
  return max(val.x,max(val.y,val.z));
}
float maxComponent(vec4 val){
  return max(val.x,max(val.y,max(val.z,val.w)));
}

// Add all of a vectors component values together
float addComponents(vec2 val){
  return val.x+val.y;
}
float addComponents(vec3 val){
  return val.x+val.y+val.z;
}
float addComponents(vec4 val){
  return val.x+val.y+val.z+val.w;
}

// -- -- -- -- -- --


#define LightBlackLevel 0.15    //[0.0 0.05 0.1 0.15 0.2 0.25 0.3 0.35 0.4 0.45 0.5 0.55 0.6 0.65 0.7 0.75 0.8 0.85 0.9 0.95 1.0]

#define LightWhiteLevel 1.0    //[0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]

// User Settings
//   Fit Black/White Levels
float shiftBlackLevels( float inCd ){
    return inCd*(1.0-LightBlackLevel) + LightBlackLevel;
}
vec3 shiftBlackLevels( vec3 inCd ){
    return inCd*(1.0-LightBlackLevel) + LightBlackLevel;
}

void boostPeaks( inout vec3 outCd ){
    float cdPeak = ( outCd.r * outCd.g * outCd.b );
    cdPeak = max(0.0, 1.0- cdPeak*5.0);
    float peakMult = mix( (cdPeak *LightWhiteLevel + (1.0-LightWhiteLevel)), 1.0, LightWhiteLevel );
    outCd *= peakMult;
}


// -- -- -- -- -- --

/*
//   Color Gamma Levels
vec3 gammaShift(vec3 inCd, float inShift){
  return pow( inCd, vec3(1.0/inShift) );
}
//   Color Peak Isolation
vec3 isolatePeaks(vec3 inCd){
  return inCd;
}
*/

// -- -- -- -- -- --

// Dev A-B Blending Functions
//
// I wrote a visualizer for the below 4 A-to-B math functions
//   Using the functions to animate a nyan cat
//   And display the corresponding blended 0-1 value in greyscale
// You can see it at my shadertoy -
//   https://www.shadertoy.com/view/ddlXD2

/*
float DeltaDivTo(float s1, float s2, float b){
  // Second from top
  float deltaTo = abs(((s1-b)-(s2-b)) / b) - b;
  //float deltaDivTo = abs((s1-b)*(s2-b) / b)-b;
  return deltaTo;
}

float SinTo(float s1, float s2, float p){
  // Top
  float sd = (s2-s1);
  float d = sd*p ;
  d = clamp(d, -1.0, 1.0) * PI ;
  float divTo = 1.0-cos( d );
  return divTo;
}

float LogPowTo(float s1, float s2, float j){  // j => 0.0 - 1.5
  float sd = (s2-s1);
  float logPowTo = 1.0-abs( log(pow(abs(sd),j)) );
  return logPowTo;
}

float PowTo(float s1, float s2, float k){  // k => 0.0 - 9.0
  float sd = (s2-s1);
  float powTo = pow(abs(sd),k);
  return powTo;
}
*/

// -- -- -- -- -- --

              
              
/*     
vec3 srgbToLinear(vec3 sRGB) {
  vec3 belowCutoff = sRGB * 0.07739938080495357 ;
  vec3 aboveCutoff = pow((sRGB + 0.055) * 0.9478672985781991, vec3(2.4) );
  
  return mix( belowCutoff, aboveCutoff, step(vec3(0.04045), sRGB) );
}    
*/


// Used in 'utils/texSamplers.glsl' diffuseSampleXYZ()
mat3 linearToXYZMat = mat3( vec3( 0.4124,  0.3576,  0.1805 ),
                            vec3( 0.2126,  0.7152,  0.0722 ),
                            vec3( 0.0193,  0.1192,  0.9505 ) );
vec3 linearToXYZ( vec3 lin ){
  return linearToXYZMat * lin ;
}


// CIELAB; the values, L 116 , color a,b  500 and 200
/*
vec3 xyzToLab( vec3 xyz ){

  // White Balancing
  vec3 labRefWhite = vec3( .95047, 1.0, 1.08883 );
  vec3 refXYZ = xyz / labRefWhite ;
  vec3 lab = vec3( 0.0, 0.0, 0.0 );
      //  1.16 * refXYZ.y - 0.016,
      //  5.00 * (refXYZ.x - refXYZ.y),
      //  2.00 * (refXYZ.y - refXYZ.z)
      //);
    
  // hmmm...
  if (refXYZ.y > 0.008856) {
    lab.x = 1.16 * pow(refXYZ.y, 1.0 / 3.0) - 0.16;
  } else {
    lab.x = 9.033 * refXYZ.y;
  }

  if (refXYZ.x > 0.008856) {
    refXYZ.x = pow(refXYZ.x, 1.0 / 3.0);
  } else {
    refXYZ.x = (7.787 * refXYZ.x) + (16.0 / 116.0);
  }

  if (refXYZ.y > 0.008856) {
    refXYZ.y = pow(refXYZ.y, 1.0 / 3.0);
  } else {
    refXYZ.y = (7.787 * refXYZ.y) + (16.0 / 116.0);
  }

  if (refXYZ.z > 0.008856) {
    refXYZ.z = pow(refXYZ.z, 1.0 / 3.0);
  } else {
    refXYZ.z = (7.787 * refXYZ.z) + (16.0 / 116.0);
  }

  lab.y = 5.0 * (refXYZ.x - refXYZ.y);
  lab.z = 2.0 * (refXYZ.y - refXYZ.z);
  
  return lab;
}


vec3 rgbToXYZ( vec3 rgb ){
  vec3 lin = srgbToLinear( rgb );
  vec3 xyz = linearToXYZ( lin );
  return xyz;
}

vec3 rgbToLab( vec3 rgb ){
  vec3 lin = srgbToLinear( rgb );
  vec3 xyz = linearToXYZ( lin );
  vec3 lab = xyzToLab( xyz );
  return lab;
}
*/



// -- -- -- -- -- --


/*
// Rotation Matrix Creation

    float wtMult = (worldTime*.1);//*.01+1.;
    float rotVal = 0;
    vec4 posVal = vec4( -.5, 0, 0, 1 );
    
    // rotVal = 90*3.14159265358979323/180;
    rotVal = -1.5707963267948966;
    //rotVal = wtMult;
    mat4 xRotMat = mat4( 
                vec4( 1, 0, 0, 0 ),
                vec4( 0, cos(rotVal), -sin(rotVal), 0 ),
                vec4( 0, sin(rotVal), cos(rotVal), 0 ),
                posVal
              );
    mat4 yRotMat = mat4( 
                vec4( cos(rotVal), 0, sin(rotVal), 0 ),
                vec4( 0, 1, 0, 0 ),
                vec4( -sin(rotVal), 0, cos(rotVal), 0 ),
                posVal
              );
    mat4 zRotMat = mat4( 
                vec4( cos(rotVal), -sin(rotVal), 0, 0 ),
                vec4( sin(rotVal), cos(rotVal), 0, 0 ),
                vec4( 0, 0, 1, 0 ),
                posVal
              );*/
              

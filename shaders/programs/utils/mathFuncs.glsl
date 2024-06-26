
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

// Give a value of `1` with an input of `0`
float safeSign( float val ){
	return ( step( 0.0, val ) * 2.0 - 1.0 );
}

// -- -- -- -- -- --

vec2 rotToUV(vec3 direction){
  vec2 uv = vec2(atan(direction.z, direction.x), asin(direction.y));
  uv *= vec2(0.1591, 0.3183);
  uv += 0.5;
  return uv;
}

vec3 addToGlowPass(vec3 baseCd, vec3 addCd){
  return max( baseCd, addCd );
}
// Human Eye Adjusted Luminance
float luma(vec3 color) {
  return dot( color, vec3(0.299, 0.587, 0.114) );
}

float biasToOne( float value ){
  return 1.0 - (1.0-value) * (1.0-value);
}
float biasToOne( float value, float bias ){
  return 1.0 - (1.0-min(1.0,value*bias)) * (1.0-min(1.0,value*bias));
}

float  sigmoid( float value ){
	return 1.0 / ( 1.0 + exp( -value ) );
}

// Return max vector component
float maxComponent(vec2 val){
  return max( val.x, val.y );
}
float maxComponent(vec3 val){
  return max( val.x, max(val.y, val.z ));
}
float maxComponent(vec4 val){
  return max( val.x, max(val.y, max(val.z, val.w )));
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


#define LightBlackLevel 0.1    //[0.0 0.05 0.1 0.15 0.2 0.25 0.3 0.35 0.4 0.45 0.5 0.55 0.6 0.65 0.7 0.75 0.8 0.85 0.9 0.95 1.0]

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
    float peakMult = mix( (cdPeak * LightWhiteLevel + (1.0-LightWhiteLevel)), 1.0, LightWhiteLevel );
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

// Used in 'utils/texSamplers.glsl' diffuseSampleXYZ()
mat3 linearToXYZMat = mat3( vec3( 0.4124,  0.3576,  0.1805 ),
                            vec3( 0.2126,  0.7152,  0.0722 ),
                            vec3( 0.0193,  0.1192,  0.9505 ) );
vec3 linearToXYZ( vec3 lin ){
  return linearToXYZMat * lin ;
}


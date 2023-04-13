
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


vec2 rotToUV(vec3 direction){
    vec2 uv = vec2(atan(direction.z, direction.x), asin(direction.y));
    uv *= vec2(0.1591, 0.3183);
    uv += 0.5;
    return uv;
}

vec3 addToGlowPass(vec3 baseCd, vec3 addCd){
  return max(baseCd, addCd);
}

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
// Top
float DeltaDivTo(float s1, float s2, float b){
  // Second from top
  float deltaTo = abs(((s1-b)-(s2-b)) / b) - b;
  //float deltaDivTo = abs((s1-b)*(s2-b) / b)-b;
  return deltaTo;
}
  
// Second
float SinTo(float s1, float s2, float p){
  // Top
  float sd = (s2-s1);
  float d = sd*p ;
  d = clamp(d, -1.0, 1.0) * PI ;
  float divTo = 1.0-cos( d );
  return divTo;
}
  
// Third
float LogPowTo(float s1, float s2, float j){  // j => 0.0 - 1.5
  float sd = (s2-s1);
  float logPowTo = 1.0-abs( log(pow(abs(sd),j)) );
  return logPowTo;
}

// Bottom
float PowTo(float s1, float s2, float k){  // k => 0.0 - 9.0
  float sd = (s2-s1);
  float powTo = pow(abs(sd),k);
  return powTo;
}
  

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
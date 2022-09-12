
vec2 limitUVs(vec2 uv){
  return clamp( uv, vec2(0.0), vec2(1.0) );
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


vec4 boxBlurSample( sampler2D tx, vec2 uv, vec2 texelRes){
  vec4 sampleCd = texture2D(tx, uv);
  
  vec2 curUV;
  vec2 curId;
  float curUVDist=0.0;
  vec4 curCd;
  vec3 curMix;
  float delta=0.0;
  for( int x=0; x<boxSamplesCount; ++x){
    curUV =  uv + boxSamples[x]*texelRes ;
		
    curCd = texture2D(tx, curUV);
    sampleCd = mix( sampleCd, curCd, .5);
  }
  return sampleCd;
}


vec3 directionBlurSample(vec3 sampleCd, sampler2D tx, vec2 uv, vec2 texelRes, int steps){
  vec2 curUV;
  vec2 curId;
  float curUVDist=0.0;
  vec3 curCd;
  vec3 curMix;
  float dist=0.0;
  float invDist=0.0;
  for( int x=0; x<steps; ++x){
    dist = float(x+1)/float(steps+1);
    invDist = 1.0-dist*dist;
    
    curUV =  uv + vec2( -1.0, -1.0 )*texelRes*dist ;
    curCd = texture2D(tx, curUV).rgb;
    sampleCd += curCd*invDist;
    curUV =  uv + vec2( 1.0, 1.0 )*texelRes*dist ;
    curCd = texture2D(tx, curUV).rgb;
    sampleCd += curCd*invDist;
  }
  return sampleCd;
}



//curUV = clamp( curUV, texcoordminmax.xy, texcoordminmax.zw);
//outCd.r= (texcoord.x-texcoordminmax.x)/(texcoordminmax.z-texcoordminmax.x);
//outCd.g= (texcoord.y-texcoordminmax.y)/(texcoordminmax.w-texcoordminmax.y);
vec4 diffuseSample( sampler2D tx, vec2 uv, vec4 uvLimits, vec2 texelRes, float resScalar){
  vec4 sampleCd = texture2D(tx, uv);
  vec3 sampleHSV = rgb2hsv( sampleCd.rgb );
  vec2 res = texelRes * resScalar;
  
  vec2 curUV;
  vec2 curId;
  float curUVDist=0.0;
  vec4 curCd;
  vec3 curMix;
  vec3 curHSV;
  float delta=0.0;
  float hit=0.0;
  float uvEdge=0.0;
  float maxDelta = 0.0;
  for( int x=0; x<boxSamplesCount; ++x){
    curUV =  uv + boxSamples[x]*res ;
    
		curUV = fract(curUV)*uvLimits.pq+uvLimits.st;//-vec2(0.,texelRes.y*3.);
		
    curCd = texture2D(tx, curUV);
    curHSV = rgb2hsv( curCd.rgb );
    curHSV = 1.0-abs( curHSV-sampleHSV );// * (DetailBluring*.15);
    
    delta = clamp( dot(sampleCd.rgb, curCd.rgb), 0.0, 1.0 );
    //delta = mix( delta, min(1.0,length(sampleCd.rgb - curCd.rgb)), .5);
    //delta = delta * length(sampleCd.rgb - curCd.rgb);
    //delta *= step(curHSV.r,.9)*step(.5,curHSV.g)*step(.5,curHSV.b);//*curHSV.b;
    //delta *= step(.85,curHSV.r)*step(.4,curHSV.b);
    delta *= curHSV.b;// *step(.6,curHSV.b);
    //delta *= step(.5,curHSV.r);
    delta *= curHSV.r*curHSV.g;//*curHSV.b;//*curHSV.b;
  //delta *= curHSV.g*.5;//curHSV.r*curHSV.g*curHSV.b;//*curHSV.b;
    delta *= delta * delta ;
    delta *= sampleCd.a * curCd.a;
    delta = clamp( delta, 0.0, 1.0 );
    
    //delta *= 1.0-step( curUV.x-texcoordminmax.x, texelSize.x );
    //delta *= 1.0-step(  texcoordminmax.z, curUV.x );
    //delta *= 1.0-step( curUV.y-texcoordminmax.y, texelSize.y );
    //delta *= 1.0-step(  texcoordminmax.w, curUV.y );
    
    curMix = curCd.rgb;
    sampleCd.rgb = mix( sampleCd.rgb, curMix, delta);
    maxDelta = max( maxDelta, delta );
  }
  sampleCd.rgb *= vec3(sampleHSV.b*.2+.8);
  //sampleCd.rgb = vec3( hit );

  return sampleCd;
}

vec4 diffuseNoLimit( sampler2D tx, vec2 uv, vec2 res){
  vec4 sampleCd = texture2D(tx, uv);
  vec3 sampleHSV = rgb2hsv( sampleCd.rgb );
  
  vec2 curUV;
  vec2 curId;
  float curUVDist=0.0;
  vec4 curCd;
  vec3 curMix;
  vec3 curHSV;
  float delta=0.0;
  float hit=0.0;
  float uvEdge=0.0;
  //float maxDelta = 0.0;
  for( int x=0; x<boxSamplesCount; ++x){
    curUV =  uv + boxSamples[x]*res ;
    
		
    curCd = texture2D(tx, curUV);
    curHSV = rgb2hsv( curCd.rgb );
    curHSV = 1.0-abs( curHSV-sampleHSV );// * (DetailBluring*.15);
    
    delta = clamp( dot(sampleCd.rgb, curCd.rgb), 0.0, 1.0 );
    //delta = mix( delta, length(sampleCd.rgb - curCd.rgb), .5);
    delta *= min(1.0, curHSV.r*curHSV.g + curHSV.b*.3-max(curHSV.r,curHSV.g)*.4);//*curHSV.b;
    delta *= min(1.0, curHSV.r*curHSV.g );//*curHSV.b;
  //delta *= curHSV.g*.5;//curHSV.r*curHSV.g*curHSV.b;//*curHSV.b;
    delta *= delta * delta ;
    delta *= sampleCd.a * curCd.a;
    delta = clamp( delta, 0.0, 1.0 );
    
    
    curMix = curCd.rgb;
    sampleCd.rgb = mix( sampleCd.rgb, curMix, delta);
    //maxDelta = max( maxDelta, delta );
  }
  sampleCd.rgb *= vec3(sampleHSV.b*.2+.8);


  return sampleCd;
}
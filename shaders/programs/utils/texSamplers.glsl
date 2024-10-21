
vec2 limitUVs(vec2 uv){
  return clamp( uv, vec2(0.0), vec2(1.0) );
}

const int axisSamplesCount = 4;
const float axisSamplesFit = 0.25; // 1/4;
const vec2 axisSamples[4] = vec2[4](
                              vec2( -1.0, 0.0 ),
                              vec2( 0.0, -1.0 ),
                              vec2( 0.0, 1.0 ),
                              vec2( 1.0, 0.0 )
                            );
                            
const int crossSamplesCount = 4;
const float crossSamplesFit = 0.25; // 1/4;
const vec2 crossSamples[4] = vec2[4](
                              vec2( -1.0, -1.0 ),
                              vec2( -1.0, 1.0 ),
                              vec2( 1.0, -1.0 ),
                              vec2( 1.0, 1.0 )
                            );
                            
const int boxSamplesCount = 8;
const float boxSampleFit = 0.125; // 1/8;
const vec2 boxSamples[8] = vec2[8](
                              vec2( -1.0, -1.0 ),
                              vec2( -1.0, 1.0 ),
                              vec2( 1.0, -1.0 ),
                              vec2( 1.0, 1.0 ),

                              vec2( -1.0, 0.0 ),
                              vec2( 0.0, -1.0 ),
                              vec2( 0.0, 1.0 ),
                              vec2( 1.0, 0.0 )
                            );
                            
const ivec2 boxFetchSamples[8] = ivec2[8](
                              ivec2( -1, -1 ),
                              ivec2( -1, 0 ),
                              ivec2( -1, 1 ),

                              ivec2( 0, -1 ),
                              ivec2( 0, 1 ),

                              ivec2( 1, -1 ),
                              ivec2( 1, 0 ),
                              ivec2( 1, 1 )
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
    curHSV = 1.0-abs( curHSV-sampleHSV );// * (DetailBlurring*.15);
    
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



void diffuseSampleXYZ( sampler2D tx, vec2 uv, vec4 uvLimits, vec2 texelRes, float resScalar, float shiftUVs, inout vec4 baseCd, inout vec4 sampleCd, inout float avgDelta ){
  baseCd = texture2D(tx, uv);
  sampleCd = baseCd ;

  // Flatten Black/White to 0; -1 to 1
  vec3 bwFlatten = vec3(1.200,0.930,1.20);
  vec3 sampleXYZ = linearToXYZ( sampleCd.rgb ) * bwFlatten;
  
  vec2 res = texelRes * resScalar;
  
  vec2 curUV;
  vec4 curCd;
  vec3 curXYZ;
  float delta=0.0;
  float maxDelta = 0.0;
  for( int x=0; x<boxSamplesCount; ++x){
    // I don't know why, there is a one texel offset in some textures
    //   Might be from optifine texture rotation
    //   grass, dirt, etc.
    curUV =  uv + boxSamples[x]*res - texelRes * shiftUVs ;
    
    curUV = fract(curUV)*uvLimits.pq+uvLimits.st;
    
    curCd = texture2D(tx, curUV);
    curXYZ = linearToXYZ( curCd.rgb ) * bwFlatten ;
    
    delta = clamp( dot(sampleXYZ, curXYZ.rgb), -1.0, 1.0 );
    delta = clamp( delta, 0.0, sampleCd.a * curCd.a );
    delta = smoothstep( .25, .85, delta )*.5;
    
    sampleCd.rgb = mix(  sampleCd.rgb, curCd.rgb,  delta);
    maxDelta = max( maxDelta, delta );
    avgDelta += delta;
  }

  avgDelta = min(1.0, maxDelta*boxSampleFit);
  
}








void diffuseSampleXYZFetch( sampler2D tx, vec2 uv, vec2 uvmid, vec2 texelRes, vec2 uvLimitPercent, float shiftUVs, float resScalar, inout vec4 baseCd, inout vec4 sampleCd, inout float avgDelta ){
  sampleCd = baseCd ;
  
  // Flatten Black/White to 0; -1 to 1
  vec3 bwFlatten = vec3(1.200,0.930,1.20);
  
  vec3 sampleXYZ = linearToXYZ( sampleCd.rgb ) * bwFlatten;
  // linearToXYZ( lin )
  vec2 res = texelRes * resScalar;
  
  
  
  float edgePixelSize =  (1.0/8.0);
  vec2 blendEdgeInf = vec2( (uv-uvmid)*(64.0*resScalar)+.5 );
  
  // To prevent blending neighboring atlas texture
  ivec4 edgeBlendInf = ivec4(0.0);
  edgeBlendInf.x = int( step( edgePixelSize, (blendEdgeInf.r)) );
  edgeBlendInf.y = int( step( edgePixelSize, (blendEdgeInf.g)) );
  edgeBlendInf.z = int( step( edgePixelSize, 1.0-(blendEdgeInf.r)) );
  edgeBlendInf.w = int( step( edgePixelSize, 1.0-(blendEdgeInf.g)) );
  
  // uvLimitPercent.x - Fix side of vertical half slabs
  // uvLimitPercent.y - Fix side of horizontal half slabs
  //vec2 faceEdgeLimits = vec2( edgePixelSize * 0.0545 ) * uvLimitPercent;
  vec2 faceEdgeLimits = vec2( edgePixelSize * 0.0545 ) * uvLimitPercent;
  
  ivec2 curOffset;
  vec2 curUV;
  float curUVDist=0.0;
  vec4 curCd;
  vec3 curXYZ;
  float delta=0.0;
  float maxDelta = 0.0;
  float minDelta = 0.0;
	
	int live = 1;
  for( int x=0; x<boxSamplesCount; ++x){
    curOffset = boxFetchSamples[x];

		//live = curOffset.x < 0 || curOffset.y < 0 || curOffset.y > 16 ? 0.0 : 1.0;
    //curOffset.x = curOffset.x < 0 ? curOffset.x*edgeBlendInf.x : curOffset.x*edgeBlendInf.z;
    //curOffset.y = curOffset.y < 0 ? curOffset.y*edgeBlendInf.y : curOffset.y*edgeBlendInf.w;
    
    // I don't know there is a one texel offset in some textures
    //   grass, dirt, etc.
    curUV = uv-uvmid + vec2(curOffset)*res - texelRes * shiftUVs ;
    live = curUV.x < -faceEdgeLimits.x || curUV.x > faceEdgeLimits.x || curUV.y < -faceEdgeLimits.y || curUV.y > faceEdgeLimits.y ? 0 : 1;
    
    curCd = textureOffset(tx, uv, curOffset*live);
		// Change RGB to XYZ
    curXYZ = linearToXYZ( curCd.rgb ) * bwFlatten ;
    
		// Detect difference in color & brightness with dot()
    delta = clamp( dot(sampleXYZ, curXYZ.rgb), -1.0, 1.0 );
    
		
    delta = clamp( delta, 0.0, sampleCd.a * curCd.a );
    delta = smoothstep( .25, .85, delta )*.5 *float(live);
    
    sampleCd.rgb = mix(  sampleCd.rgb, curCd.rgb,  delta );// *float(live);
    maxDelta = max( maxDelta, delta*live );
    avgDelta += delta*live;
  }

  avgDelta = min(1.0, avgDelta*boxSampleFit);
  //avgDelta = maxDelta;
  
  //sampleCd = baseCd;
  
  //sampleCd.rgb = mix( sampleCd.rgb, baseCd.rgb, min(1.0, length( sampleCd.rgb - baseCd.rgb )*5.0) );
  float infVal =  min(1.0, length( sampleCd.rgb - baseCd.rgb )*10.0) ;
  //sampleCd.rgb=vec3(maxDelta);
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
    curHSV = 1.0-abs( curHSV-sampleHSV );// * (DetailBlurring*.15);
    
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
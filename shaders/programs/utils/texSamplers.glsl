

const int axisSamplesCount = 4;
const vec2 axisSamples[4] = vec2[4](
                              vec2( -1.0, 0.0 ),
                              vec2( 0.0, -1.0 ),
                              vec2( 0.0, 1.0 ),
                              vec2( 1.0, 0.0 )
                            );
                            
const int crossSamplesCount = 4;
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
                              vec2( -1.0, 0.0 ),
                              vec2( -1.0, 1.0 ),

                              vec2( 0.0, -1.0 ),
                              vec2( 0.0, 1.0 ),

                              vec2( 1.0, -1.0 ),
                              vec2( 1.0, 0.0 ),
                              vec2( 1.0, 1.0 )
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

			
			
vec2 limitUVs(vec2 uv){
  return clamp( uv, vec2(0.0), vec2(1.0) );
}



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


void diffuseSampleXYZ( sampler2D tx, vec2 uv, vec4 uvLimits, vec2 texelRes, float resScalar, inout vec4 baseCd, inout vec4 sampleCd, inout float avgDelta ){
  baseCd = texture2D(tx, uv);
  sampleCd = baseCd ;
  vec3 boxAvg=baseCd.rgb;
  // Flatten Black/White to 0; -1 to 1
  vec3 bwFlatten = vec3(1.200,0.930,1.20);
  vec3 sampleXYZ = linearToXYZ( sampleCd.rgb ) * bwFlatten;
  // linearToXYZ( lin )
  vec2 res = texelRes * resScalar;
	
  vec2 curUV;
  vec2 curId;
  float curUVDist=0.0;
  vec4 curCd;
  vec3 curXYZ;
  vec3 curLab;
  float delta=0.0;
  float uvEdge=0.0;
  float maxDelta = 0.0;
  vec3 brightestCd = vec3(0.0);
  for( int x=0; x<boxSamplesCount; ++x){
    curUV =  uv + boxSamples[x]*res ;
    //curUV =  clamp(uv + boxSamples[x]*res, vec2(0.0), vec2(1.0) ) ;
    
		curUV = fract(curUV)*uvLimits.pq+uvLimits.st;
		
    curCd = texture2D(tx, curUV);
    curXYZ = linearToXYZ( curCd.rgb ) * bwFlatten ;
    
    delta = dot(normalize(sampleXYZ.rgb), normalize(curXYZ.rgb));
    delta = max(0.0,delta);//*delta;
    //delta = max(0.0,1.0-((1.0-delta)*5.20));//*delta;
    
    //delta *= 0.31-(length( sampleXYZ.rgb-curXYZ.rgb )*0.95);
    //delta = 0.09-smoothstep( delta, .15722, .87225 );
    //delta *= 0.51-(length( sampleXYZ.rgb-curXYZ.rgb )*2.35);
    //delta *= (0.71+resScalar)-(length( sampleXYZ.rgb-curXYZ.rgb )*2.35*(.5-resScalar*.5));
    //delta *= 0.50151-(length( sampleXYZ.rgb-curXYZ.rgb )*(1.5-resScalar));
    //delta *= resScalar;
    delta = clamp( delta, 0.0, sampleCd.a * curCd.a );
    delta = .4-smoothstep( delta, .15722, .87225 )*.4;
    
    //delta = step( sampleXYZ.g, curXYZ.g );
    
    //brightestCd = mix( brightestCd, curCd.rgb, step( curXYZ.g, sampleXYZ.g ) );
    sampleCd.rgb = mix(  sampleCd.rgb, curCd.rgb,  delta);
    maxDelta = max( maxDelta, delta );
    avgDelta += delta;
		boxAvg += curCd.rgb;
  }
  //sampleCd.rgb *= vec3(1.0-clamp( 1.0-length( sampleXYZ ), 0.0, .20 )*(maxDelta));

  //avgDelta = min(1.0, maxDelta*.075);
  avgDelta = min(1.0, maxDelta*boxSampleFit);
  
  //sampleCd.rgb = vec3(maxDelta);
  //sampleCd.rgb = vec3(avgDelta);
  //sampleCd.rgb = brightestCd;
  //sampleCd.rgb = sampleXYZ.rgb;
  //sampleCd.rgb = texture2D(tx, uv).rgb;
  
	boxAvg = min( vec3(1,1,1), boxAvg*boxSampleFit );
	sampleCd.rgb = boxAvg;//.rrr;
}








void diffuseSampleXYZFetch( sampler2D tx, vec2 uv, vec2 uvmid, vec2 texelRes, float resScalar, inout vec4 baseCd, inout vec4 sampleCd, inout float avgDelta ){
  sampleCd = baseCd ;
  vec3 boxAvg=baseCd.rgb;
	
  // Flatten Black/White to 0; -1 to 1
  vec3 bwFlatten = vec3(1.200,0.930,1.20);
	
  vec3 sampleXYZ = linearToXYZ( sampleCd.rgb ) * bwFlatten;
  // linearToXYZ( lin )
  vec2 res = texelRes * resScalar;
  
	
	
	float edgePixelSize =  (1.0/16.0);
	vec2 blendEdgeInf = vec2( (uv-uvmid)*64.0+.5 );
	
	// To prevent blending neighboring atlas texture
	ivec4 edgeBlendInf = ivec4(0.0);
	edgeBlendInf.x = int( step( edgePixelSize, (blendEdgeInf.r)) );
	edgeBlendInf.y = int( step( edgePixelSize, (blendEdgeInf.g)) );
	edgeBlendInf.z = int( step( edgePixelSize, 1.0-(blendEdgeInf.r)) );
	edgeBlendInf.w = int( step( edgePixelSize, 1.0-(blendEdgeInf.g)) );
	
	
	
  ivec2 curOffset;
  float curUVDist=0.0;
  vec4 curCd;
  vec3 curXYZ;
  float delta=0.0;
  float maxDelta = 0.0;
  float minDelta = 0.0;
  for( int x=0; x<boxSamplesCount; ++x){
		curOffset = boxFetchSamples[x];
		curOffset.x = curOffset.x < 0 ? curOffset.x*edgeBlendInf.x : curOffset.x*edgeBlendInf.z;
		curOffset.y = curOffset.y < 0 ? curOffset.y*edgeBlendInf.y : curOffset.y*edgeBlendInf.w;
		
		
		
    curCd = textureOffset(tx, uv, curOffset);
    curXYZ = linearToXYZ( curCd.rgb ) * bwFlatten ;
    
    delta = clamp( dot((sampleXYZ.rgb), (curXYZ.rgb)), -1.0, 1.0 );

    
		
		
    delta = clamp( delta, 0.0, sampleCd.a * curCd.a );
    delta = smoothstep( .25, .85, delta )*.5;
    
    sampleCd.rgb = mix(  sampleCd.rgb, curCd.rgb,  delta);
    maxDelta = max( maxDelta, delta );
    avgDelta += delta;
  }

  avgDelta = min(1.0, avgDelta*boxSampleFit);
  //avgDelta = maxDelta;
  
	
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


vec4 diffuseNoLimitFetch( sampler2D tx, vec2 uv, ivec2 res){
  vec4 sampleCd = texture2D(tx, uv);
  ///vec3 sampleHSV = rgb2hsv( sampleCd.rgb );
  
  ivec2 curOffset;
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
    curCd = textureOffset(tx, uv, boxFetchSamples[x]*res);
    
		//curHSV = rgb2hsv( curCd.rgb );
    //curHSV = 1.0-abs( curHSV-sampleHSV );// * (DetailBluring*.15);
    /*
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
		*/
  }
  //sampleCd.rgb *= vec3(sampleHSV.b*.2+.8);

  return sampleCd;
}












// Used in vertex stage block sampling 
// vec4 avgCd = atlasSampler( texture, uv, ivec2(2), .935, vColor );
vec4 atlasSampler( sampler2D tx, vec2 uv, ivec2 uvOffset, float avgBlend, vec4 baseCd ){
  
  vec4 mixColor;
  vec4 tmpCd;
  float avgDiv = 0.0;
  tmpCd = texture2D(tx, uv);
    mixColor = tmpCd;
    avgDiv += tmpCd.a;
		
  tmpCd = textureOffset(tx, uv, ivec2(-uvOffset.x, uvOffset.y) );
    mixColor = mix( mixColor, tmpCd, avgBlend*tmpCd.a);
    avgDiv += tmpCd.a;
		
  tmpCd = textureOffset(tx, uv, ivec2(uvOffset.x, -uvOffset.y) );
    mixColor = mix( mixColor, tmpCd, avgBlend*tmpCd.a);
    avgDiv += tmpCd.a;
		
  tmpCd = textureOffset(tx, uv, ivec2(-uvOffset.x, -uvOffset.y) );
    mixColor = mix( mixColor, tmpCd, avgBlend*tmpCd.a);
    avgDiv += tmpCd.a;
		
  tmpCd = textureOffset(tx, uv, ivec2(-uvOffset.x, uvOffset.y) );
    mixColor = mix( mixColor, tmpCd, avgBlend*tmpCd.a);
    avgDiv += tmpCd.a;
		
	// For when all samples fail
  mixColor = mix( baseCd, mixColor, step( 0.05, mixColor.a ) );
	return mixColor; 
	

}

  // Leaves
  vAlphaRemove = 0.0;
  if((mc_Entity.x == 810 || mc_Entity.x == 8101) && SolidLeaves ){
    vAvgColor = mc_Entity.x == 810 ? vColor * (vAvgColor.g*.5+.5) : vAvgColor;
    vColor = mc_Entity.x == 8101 ? vAvgColor*1.85 : vColor;
    
    
    vAlphaRemove = 1.0;
    shadowPos.w = -2.0;
  }
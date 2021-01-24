


float sceneSDF(vec3 p)
{
    float result = 1e10;

    float dist = 0.0;//getwaves(p.xz, ITERATIONS_RAYMARCH);

    float sphereDist = length(p)-(planet.radius-EPSILON);

    result = sphereDist;

    return result;
}



float shortestDistanceToSurface(vec3 eye, vec3 marchingDirection, float start, float end) {
    float depth = start;
    for (int i = 0; i < 32; i++)
    {
        vec3 p = eye + depth * marchingDirection;
        float dist = length(p)-(planet.radius-EPSILON);
        if (dist < EPSILON * length(p)) {
            return depth;
        }
        depth += dist;
        if (depth >= end) {
            return end;
        }
    }
    return end;

}





vec3 normal(vec3 p) {
    vec3 P = vec3(-4, 4, 0) * 0.01;

    return normalize(
        sceneSDF(p+P.xyy) *
        P.xyy + sceneSDF(p+P.yxy) *
        P.yxy + sceneSDF(p+P.yyx) *
        P.yyx + sceneSDF(p+P.xxx) *
        P.xxx
    );
}



// Cast shadow ray
float shadow(in vec3 eye, in vec3 dir) {
    float res = 1.0;
    float t = EPSILON;
    float ph = 1e10;

    for( int i=0; i<MAX_SHADOW_STEPS && t < camera.far; i++ )
    {
        vec3 p = eye + dir * t;
        float h = sceneSDF(p);
        if (h < 0.0){ return 0.0; }

        float y = h*h/(2.0*ph);
        float d = sqrt(h*h-y*y);
        res = min( res, 10.0*d/max(0.0,t-y) );

        t += h;
    }

    return res;
}



vec3 applyMaterials(float dist, vec3 eye, vec3 worldDir, float depth, vec3 screen)
{
		vec3 p = eye + dist * worldDir;

		vec3 col = screen;

    vec3 N = normalize(p);
		/* vec3 np = p * 20.0;
		N = normalize(N + getHashTex3(vec3(.0, np.y+cos(np.x)+sin(np.z), .0)).x*0.5); */


    depth = 1.0-clamp(dist/(planet.maxHeight/2.0), 0.0, 1.0); //ocean depth
		col *= depth;

		float ndl = max(0.0, dot(N, lightDir));

		float specComp = max(0.0, dot(N, normalize(lightDir + normalize(eye - p))));
		specComp = saturate(pow(specComp, 64.0)) / 5.0;


    return col * ndl + specComp;
}




vec3 Ocean(vec3 eye, vec3 dir, vec3 screen, float rdepth, float depth)
{
		if (depth >= 1.0){ return screen; }

		vec3 color = screen;

		vec2 oceanSphere = raySphere(planet.position, planet.radius, eye, dir);
		float distToOcean = oceanSphere.x;
		float distThroughOcean = oceanSphere.y;
		vec3 oceanPos = eye + dir * distToOcean;

		float oceanViewDepth = min(rdepth, oceanSphere.x);//min(distThroughOcean, rdepth - distToOcean);


		if (oceanViewDepth == rdepth){
			return screen;
		}

		color = applyMaterials(oceanViewDepth, eye, dir, rdepth, screen);
		//color = pow(vec3(oceanViewDepth/(planet.radius*5.0)), vec3(9.25, 9.5, 10.0));

    return color;
}



/* vec3 Ocean(vec3 rayPos, vec3 rayDir, vec3 screen, float sceneDepth)
{
	vec3 oceanCentre = planet.position;

	vec2 hitInfo = raySphere(oceanCentre, oceanRadius, rayPos, rayDir);
	float dstToOcean = hitInfo.x;
	float dstThroughOcean = hitInfo.y;
	vec3 rayOceanIntersectPos = rayPos + rayDir * dstToOcean - oceanCentre;

	// dst that view ray travels through ocean (before hitting terrain / exiting ocean)
	float oceanViewDepth = min(dstThroughOcean, sceneDepth - dstToOcean);


	if (oceanViewDepth > 0) {
		vec3 clipPlanePos = rayPos + i.viewVector * _ProjectionParams.y;

		float dstAboveWater = length(clipPlanePos - oceanCentre) - oceanRadius;

		float t = 1 - exp(-oceanViewDepth / planetScale * depthMultiplier);
		float alpha =  1-exp(-oceanViewDepth / planetScale * alphaMultiplier);
		vec4 oceanCol = lerp(colA, colB, t);

		float3 oceanSphereNormal = normalize(rayOceanIntersectPos);

		float2 waveOffsetA = float2(_Time.x * waveSpeed, _Time.x * waveSpeed * 0.8);
		float2 waveOffsetB = float2(_Time.x * waveSpeed * - 0.8, _Time.x * waveSpeed * -0.3);
		float3 waveNormal = triplanarNormal(rayOceanIntersectPos, oceanSphereNormal, waveNormalScale / planetScale, waveOffsetA, waveNormalA);
		waveNormal = triplanarNormal(rayOceanIntersectPos, waveNormal, waveNormalScale / planetScale, waveOffsetB, waveNormalB);
		waveNormal = normalize(lerp(oceanSphereNormal, waveNormal, waveStrength));
		//return float4(oceanNormal * .5 + .5,1);
		float diffuseLighting = saturate(dot(oceanSphereNormal, dirToSun));
		float specularAngle = acos(dot(normalize(dirToSun - rayDir), waveNormal));
		float specularExponent = specularAngle / (1 - smoothness);
		float specularHighlight = exp(-specularExponent * specularExponent);

		oceanCol *= diffuseLighting;
		oceanCol += specularHighlight * (dstAboveWater > 0) * specularCol;

		//return float4(oceanSphereNormal,1);
		float4 finalCol =  originalCol * (1-alpha) + oceanCol * alpha;
		return float4(finalCol.xyz, params.x);
	}


	return originalCol;
} */

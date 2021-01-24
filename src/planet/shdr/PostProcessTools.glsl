vec2 raySphere(vec3 sphereCentre, float sphereRadius, vec3 rayOrigin, vec3 rayDir)
{
	vec3 offset = rayOrigin - sphereCentre;
	float a = 1.0;
	float b = 2.0 * dot(offset, rayDir);
	float c = dot (offset, offset) - sphereRadius * sphereRadius;
	float d = b * b - 4.0 * a * c;

	if (d > 0.0) {
		float s = sqrt(d);
		float dstToSphereNear = max(0.0, (-b - s) / (2.0 * a));
		float dstToSphereFar = (-b + s) / (2.0 * a);

		// Ignore intersections that occur behind the ray
		if (dstToSphereFar >= 0.0) {
			return vec2(dstToSphereNear, dstToSphereFar - dstToSphereNear);
		}
	}
	// Ray did not intersect sphere
	return vec2(camera.far, 0.0);
}




vec3 toViewSpace(vec3 pos, vec3 dir, float dist)
{
    vec3 posIntersectInWorldSpace = vec3(pos + dist * dir);
    vec4 posInViewSpace = camera.view * vec4(posIntersectInWorldSpace, 1);
    return posInViewSpace.xyz;
}

float toWorldSpace(float depth)
{
		vec3 viewVector = (inverse(camera.projection) * vec4(vUV * 2.0 - 1.0, 0.0, -1.0)).xyz;
		viewVector = (inverse(camera.view) * vec4(viewVector, 0.0)).xyz;
		float viewLength = length(viewVector);
		return depth * viewLength;
}



vec3 rayDirection(float fieldOfView, vec2 size, vec2 fragCoord) {
    vec2 xy = (fragCoord*2.0) - size;
    float z = size.y / tan(fieldOfView / 2.0);
    return normalize(vec3(xy, -z));
}


mat4 viewMatrix(vec3 eye, vec3 direction, vec3 up) {
    vec3 f = -direction;
    vec3 s = normalize(cross(f, up));
    vec3 u = cross(s, f);
    return mat4(
        vec4(s, 0.0),
        vec4(u, 0.0),
        vec4(f, 0.0),
        vec4(0.0, 0.0, 0.0, 1)
    );
}


vec3 getFragmentRay(in vec2 fragCoord)
{
    vec3 viewDir = rayDirection(camera.fov, screenSize, fragCoord);
    mat4 viewToWorld = viewMatrix(camera.position, camera.direction, vec3(0.0, 1.0, 0.0));
    return (viewToWorld * vec4(viewDir, 0.0)).xyz;
}





vec3 getUVRayScreenSpace()
{
    mat4 invMat =  inverse(camera.transform);
    vec4 near = vec4((vUV.x - 0.5) * 2.0, (vUV.y - 0.5) * 2.0, -1, 1.0);
    vec4 far = vec4((vUV.x - 0.5) * 2.0, (vUV.y - 0.5) * 2.0, 1, 1.0);
    vec4 nearResult = invMat*near;
    vec4 farResult = invMat*far;
    nearResult /= nearResult.w;
    farResult /= farResult.w;
    vec3 dir = vec3(farResult - nearResult );
    return normalize(dir);
}










//anamorphic-ish flares from: https://www.shadertoy.com/view/MlsfRl
vec3 flares(sampler2D tex, vec2 uv, float threshold, float intensity, float stretch, float brightness)
{
    threshold = 1.0 - threshold;

    vec3 hdr = texture(tex, uv).rgb;
    hdr = vec3(floor(threshold+pow(hdr.r, 1.0)));

    float d = intensity; //200.;
    float c = intensity*stretch; //100.;

    //horizontal
    for (float i=c; i>-1.0; i--){
        float texL = texture(tex, uv+vec2(i/d, 0.0)).r;
        float texR = texture(tex, uv-vec2(i/d, 0.0)).r;
        hdr += floor(threshold+pow(max(texL,texR), 4.0))*(1.0-i/c);
    }

    hdr *= vec3(0.369,0.200,0.620); //tint
	return hdr*brightness;
}



vec3 ACESFilm(vec3 x)
{
    float a = 2.51;
    float b = 0.03;
    float c = 2.43;
    float d = 0.59;
    float e = 0.14;
    return (x*(a*x+b))/(x*(c*x+d)+e);
}




//Chromatic Abberation from: https://www.shadertoy.com/view/XlKczz
vec3 chromaticAbberation(sampler2D tex, vec2 uv, float amount)
{
    float aberrationAmount = amount/10.0;
   	vec2 distFromCenter = uv - 0.5;

    // stronger aberration near the edges by raising to power 3
    vec2 aberrated = aberrationAmount * pow(distFromCenter, vec2(3.0, 3.0));

    vec3 color = vec3(0.0);

    for (int i = 1; i <= 8; i++)
    {
        float weight = 1.0 / pow(2.0, float(i));
        color.r += texture(tex, uv - float(i) * aberrated).r * weight;
        color.b += texture(tex, uv + float(i) * aberrated).b * weight;
    }

    color.g = texture(tex, uv).g * 0.9961; // 0.9961 = weight(1)+weight(2)+...+weight(8);

    return color;
}



float SCurve (float value, float amount, float correction){
	float curve = 1.0;
    if (value < 0.5){ curve = pow(value, amount) * pow(2.0, amount) * 0.5; }
    else{ curve = 1.0 - pow(1.0 - value, amount) * pow(2.0, amount) * 0.5; }
    return pow(curve, correction);
}
vec3 contrast(vec3 color)
{
    return saturate(vec3(
        SCurve(color.r, 3.0, 1.0),
        SCurve(color.g, 4.0, 0.7),
        SCurve(color.b, 2.6, 0.6)
    ));
}



vec3 tex(vec2 p){
	return texture2D(textureSampler, p).rgb;
}



//from: https://www.shadertoy.com/view/4l2GWm
vec3 quincunxAA(vec2 fragCoord, float blur)
{
	vec3 pixelColor;
	pixelColor =  texture2D(textureSampler, (fragCoord + vec2( 0.0, 0.0)) / screenSize).rgb / 2.0;
	pixelColor += texture2D(textureSampler, (fragCoord + vec2( blur, blur)) / screenSize).rgb / 8.0;
	pixelColor += texture2D(textureSampler, (fragCoord + vec2( blur,-blur)) / screenSize).rgb / 8.0;
	pixelColor += texture2D(textureSampler, (fragCoord + vec2(-blur,-blur)) / screenSize).rgb / 8.0;
	pixelColor += texture2D(textureSampler, (fragCoord + vec2(-blur, blur)) / screenSize).rgb / 8.0;
	return pixelColor;
}




vec3 hdr(vec3 L)
{
    L = L * 0.4;
    L.r = L.r < 1.413 ? pow(L.r * 0.38317, 1.0 / 2.2) : 1.0 - exp(-L.r);
    L.g = L.g < 1.413 ? pow(L.g * 0.38317, 1.0 / 2.2) : 1.0 - exp(-L.g);
    L.b = L.b < 1.413 ? pow(L.b * 0.38317, 1.0 / 2.2) : 1.0 - exp(-L.b);
    return L;
}













//from: https://www.shadertoy.com/view/XdfXRX
vec3 lensflare(vec2 uv,vec2 pos)
{
	vec2 main = uv-pos;
	vec2 uvd = uv*(length(uv));

	float ang = atan(main.y, main.x);
	float dist=length(main); dist = pow(dist,.1);
	float n = 0.0;//noise(vec2((ang-TIME/9.0)*16.0,dist*32.0));

	float f0 = 1.0/(length(uv-pos)*16.0+1.0);
	f0 = pow(f0, 2.0);

	f0 = f0+f0*(sin((ang+1.0/18.0)*12.0)*.1+dist*.1+.8);

	float f2 = max(1.0/(1.0+32.0*pow(length(uvd+0.8*pos),2.0)),.0)*00.25;
	float f22 = max(1.0/(1.0+32.0*pow(length(uvd+0.85*pos),2.0)),.0)*00.23;
	float f23 = max(1.0/(1.0+32.0*pow(length(uvd+0.9*pos),2.0)),.0)*00.21;

	vec2 uvx = mix(uv,uvd,-0.5);

	float f4 = max(0.01-pow(length(uvx+0.4*pos),2.4),.0)*6.0;
	float f42 = max(0.01-pow(length(uvx+0.45*pos),2.4),.0)*5.0;
	float f43 = max(0.01-pow(length(uvx+0.5*pos),2.4),.0)*3.0;

	uvx = mix(uv,uvd,-.4);

	float f5 = max(0.01-pow(length(uvx+0.2*pos),5.5),.0)*2.0;
	float f52 = max(0.01-pow(length(uvx+0.4*pos),5.5),.0)*2.0;
	float f53 = max(0.01-pow(length(uvx+0.6*pos),5.5),.0)*2.0;

	uvx = mix(uv,uvd,-0.5);

	float f6 = max(0.01-pow(length(uvx-0.3*pos),1.6),.0)*6.0;
	float f62 = max(0.01-pow(length(uvx-0.325*pos),1.6),.0)*3.0;
	float f63 = max(0.01-pow(length(uvx-0.35*pos),1.6),.0)*5.0;

	vec3 c = vec3(.0);

	c.r+=f2+f4+f5+f6; c.g+=f22+f42+f52+f62; c.b+=f23+f43+f53+f63;
	c+=vec3(f0);

	return c;
}

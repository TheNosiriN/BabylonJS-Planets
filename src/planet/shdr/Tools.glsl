#ifndef PI
#define PI 3.14159265358979323846264338328
#define PHI 1.6180339887498948482045868343656
#endif




#define saturate(x) clamp(x, 0.0, 1.0)


vec2 index1Dto2D(int id, int width){
	return vec2(id % width, id / width);
}


//useful --- from: https://www.shadertoy.com/view/Xd3XDS
vec3 triplanarMap(sampler2D tex, vec3 p, vec3 n, float scale)
{
    p *= scale;

    return  (texture(tex,p.xy).rgb*n.z*n.z
            +texture(tex,p.zy).rgb*n.x*n.x
            +texture(tex,p.xz).rgb*n.y*n.y);
}


vec3 triplanarNormal(sampler2D tex, vec3 p, vec3 N, float strength, float scale)
{
    vec3 P = vec3(-4, 4, 0) * 0.01;

    vec3 B = vec3(
        triplanarMap(tex, p+P.xzz, N, scale).r,
        triplanarMap(tex, p+P.zxz, N, scale).r,
        triplanarMap(tex, p+P.zzx, N, scale).r
    ) - triplanarMap(tex, p, N, scale).r;

    B = (B-N*dot(B,N));
    return normalize(N+B*strength);
}


vec3 triplanarWeights(vec3 front, vec3 top, vec3 side, vec3 normal, float sharpness)
{
		vec3 weights = abs(normal);
		weights = abs(weights);
		weights = pow(weights, vec3(sharpness));
		weights = weights / (weights.x + weights.y + weights.z);

		front *= weights.z;
		side *= weights.x;
		top *= weights.y;

		return front+side+top;
}



float remap(float val, float OldMin, float OldMax, float NewMin, float NewMax){
    return (((val - OldMin) * (NewMax - NewMin)) / (OldMax - OldMin)) + NewMin;
}







float desample(float n, float a){
	return floor(n * pow(10.0, a)) / pow(10.0, a);
}
vec3 desample(vec3 n, float a){
	return vec3(
		desample(n.x, a), desample(n.y, a), desample(n.z, a)
	);
}
vec4 desample(vec4 n, float a){
	return vec4(
		desample(n.x, a), desample(n.y, a), desample(n.z, a), desample(n.w, a)
	);
}


vec2 vectorToSpherical(vec3 p)
{
	float theta = acos(clamp(p.z, -1.0, 1.0));
	float phi = atan(p.y, p.x);
  phi = phi < 0.0 ? phi + 2.0 * PI : phi;

	return vec2(theta, phi);
}

vec3 sphericalToVector(float u, float v)
{
	return vec3(cos(v) * sin(u), sin(v) * sin(u), cos(u));
}



vec2 UV( vec3 position ){
	return vec2( saturate(((atan(position.z, position.x) / 3.141592654) + 1.0) / 2.0), (0.5-(asin(position.y)/3.141592654)) );
}





mat4 rotationMatrix(vec3 axis, float angle)
{
    // taken from http://www.neilmendoza.com/glsl-rotation-about-an-arbitrary-axis/
    angle = radians(angle);
    axis = normalize(axis);
    float s = sin(angle);
    float c = cos(angle);
    float oc = 1.0 - c;

    return mat4(oc * axis.x * axis.x + c,           oc * axis.x * axis.y - axis.z * s,  oc * axis.z * axis.x + axis.y * s,  0.0,
                oc * axis.x * axis.y + axis.z * s,  oc * axis.y * axis.y + c,           oc * axis.y * axis.z - axis.x * s,  0.0,
                oc * axis.z * axis.x - axis.y * s,  oc * axis.y * axis.z + axis.x * s,  oc * axis.z * axis.z + c,           0.0,
                0.0,                                0.0,                                0.0,                                1.0);
}





#ifndef arrayTexture2D
vec4 arrayTexture2D(sampler2D arrayTexture, int index, int width)
{
	//ivec2 textureDimensions = textureSize(arrayTexture, 0);
  int x = index % width;//textureDimensions.x;
  int y = index / width;//textureDimensions.x;
  return texelFetch(arrayTexture, ivec2(x,y), 0);
}
#endif

precision highp float;


in vec3 position;
out vec3 outPosition;

uniform float radius;
uniform float maxHeight;

void main(void)
{
	vec3 p = normalize(position);
	float noiseVal = fbm(p).x;
	p *= radius + (noiseVal * radius * maxHeight);

	outPosition = p;
}

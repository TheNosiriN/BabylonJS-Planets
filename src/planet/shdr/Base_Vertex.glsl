precision highp float;

// Attributes
attribute vec3 position;
attribute vec3 normal;
attribute vec2 uv;

// Uniforms
uniform mat4 worldViewProjection;
uniform vec3 eyepos_lowpart;
uniform vec3 eyepos;

// Varying
varying vec3 vPosition;
varying vec3 vNormal;
varying vec2 vUV;

void main(void)
{
		vec3 p = position - eyepos;
		p -= eyepos_lowpart;

		vec4 outPosition = worldViewProjection * vec4(p, 1.0);
    gl_Position = outPosition;

    vUV = uv;
    vPosition = p;
    vNormal = normal;

		#define SHADOWDEPTH_NORMALBIAS
}

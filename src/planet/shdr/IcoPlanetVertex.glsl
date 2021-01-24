#extension GL_EXT_shader_texture_lod : enable
#extension GL_OES_standard_derivatives : enable


precision highp float;



// Attributes
attribute vec3 position;

// Uniforms
uniform mat4 worldViewProjection;
uniform vec3 cameraPosition;
uniform vec3 eyepos_lowpart;
uniform lowp float maxHeight;
uniform lowp float radius;
uniform vec3 eyepos;

// Varying
varying vec3 vPosition;
varying vec3 vNormal;



void main(void)
{
    vec3 transformedPosition = position;// - eyepos;
	//transformedPosition -= eyepos_lowpart;


    vec4 outPosition = worldViewProjection * vec4(transformedPosition, 1.0);
    gl_Position = outPosition;



    vPosition = transformedPosition;
}

precision highp float;

// Varying
varying vec3 vPosition;
varying vec3 vNormal;
varying vec2 vUV;

// Uniforms
uniform mat4 world;

// Refs
uniform vec3 lightDir;
uniform vec3 cameraPosition;
uniform sampler2D textureSampler;


float remap(float val, float OldMin, float OldMax, float NewMin, float NewMax){
    return (((val - OldMin) * (NewMax - NewMin)) / (OldMax - OldMin)) + NewMin;
}



void main(void) {
    // World values
    vec3 vPositionW = vec3(world * vec4(vPosition, 1.0));
    vec3 vNormalW = normalize(vec3(world * vec4(vNormal, 0.0)));
    vec3 viewDirectionW = normalize(cameraPosition - vPositionW);

    // Light
    vec3 lightVectorW = lightDir;
    vec3 color = vNormal;

    // diffuse
    float ndl = max(0., dot(vNormalW, lightVectorW));

		//fresnel
		float fresnelTerm = 1.0 - dot(viewDirectionW, vNormalW);
		fresnelTerm = 1.0+clamp(fresnelTerm, 0.0, 1.0);

    // Specular
    vec3 angleW = normalize(viewDirectionW + lightVectorW);

    gl_FragColor = vec4(ndl * clamp(color*fresnelTerm, 0.0, 1.0), 1.0);
}

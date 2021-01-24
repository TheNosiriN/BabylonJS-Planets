/*
 Precomputed Atmospheric Scattering
 Copyright (c) 2008 INRIA
 All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:
 1. Redistributions of source code must retain the above copyright
    notice, this list of conditions and the following disclaimer.
 2. Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in the
    documentation and/or other materials provided with the distribution.
 3. Neither the name of the copyright holders nor the names of its
    contributors may be used to endorse or promote products derived from
    this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
 LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
 THE POSSIBILITY OF SUCH DAMAGE.

 Author: Eric Bruneton
 Modified and ported to Unity by Justin Hawkins 2013
 Refactored and ported to WebGL by Chinomso Nosiri 2020
*/








#define SUN_DIR lightDir
#define SUN_INTENSITY 10.0

const float EARTH_RADIUS = 6360000.0;

#define SCALE (EARTH_RADIUS/planet.radius)
#define EARTH_POS (planet.position*SCALE)

#define Rg 6360000.0
#define Rt 6420000.0
#define RL 6421000.0
#define RES_R 32.0
#define RES_MU 128.0
#define RES_MU_S 32.0
#define RES_NU 8.0

const vec3 betaR = vec3(5.8e-3, 13.5e-3, 33.1e-3);//vec3(0.0058, 0.0135, 0.0331);
const vec3 betaM = vec3(21e-3);
const float mieG = 0.8;

const float EPSILON_ATMOSPHERE = 0.00001;
const float EPSILON_INSCATTER = 0.00001;

uniform sampler2D transmittance_texture;
uniform sampler3D scattering_texture;
uniform sampler2D irradiance_texture;




vec4 Texture4D(sampler3D table, float r, float mu, float muS, float nu)
{
   	float H = sqrt(Rt * Rt - Rg * Rg);
   	float rho = sqrt(r * r - Rg * Rg);

    float rmu = r * mu;
    float delta = rmu * rmu - r * r + Rg * Rg;
    vec4 cst = rmu < 0.0 && delta > 0.0 ? vec4(1.0, 0.0, 0.0, 0.5 - 0.5 / RES_MU) : vec4(-1.0, H * H, H, 0.5 + 0.5 / RES_MU);
    float uR = 0.5 / RES_R + rho / H * (1.0 - 1.0 / RES_R);
    float uMu = cst.w + (rmu * cst.x + sqrt(delta + cst.y)) / (rho + cst.z) * (0.5 - 1.0 / float(RES_MU));
    // better formula
    float uMuS = 0.5 / RES_MU_S + (atan(max(muS, -0.1975) * tan(1.26 * 1.1)) / 1.1 + (1.0 - 0.26)) * 0.5 * (1.0 - 1.0 / RES_MU_S);

    float lep = (nu + 1.0) / 2.0 * (RES_NU - 1.0);
    float uNu = floor(lep);
    lep = lep - uNu;

    return textureLod(table, vec3((uNu + uMuS) / RES_NU, uMu, uR), 0.0) * (1.0 - lep) + textureLod(table, vec3((uNu + uMuS + 1.0) / RES_NU, uMu, uR), 0.0) * lep;
}

vec3 GetMie(vec4 rayMie)
{
	// approximated single Mie scattering (cf. approximate Cm in paragraph "Angular precision")
	// rayMie.rgb=C*, rayMie.w=Cm,r
   	return rayMie.rgb * rayMie.w / max(rayMie.r, 1e-4) * (betaR.r / betaR);
}

float PhaseFunctionR(float mu)
{
	// Rayleigh phase function
    return (3.0 / (16.0 * PI)) * (1.0 + mu * mu);
}

float PhaseFunctionM(float mu)
{
	// Mie phase function
   	 return 1.5 * 1.0 / (4.0 * PI) * (1.0 - mieG*mieG) * pow(1.0 + (mieG*mieG) - 2.0*mieG*mu, -3.0/2.0) * (1.0 + mu * mu) / (2.0 + mieG*mieG);
}

vec3 Transmittance(float r, float mu)
{
	// transmittance(=transparency) of atmosphere for infinite ray (r,mu)
	// (mu=cos(view zenith angle)), intersections with ground ignored
   	float uR, uMu;
    uR = sqrt((r - Rg) / (Rt - Rg));
    uMu = atan((mu + 0.15) / (1.0 + 0.15) * tan(1.5)) / 1.5;

    return textureLod(transmittance_texture, vec2(uMu, uR), 0.0).rgb;
}

vec3 Transmittance(float r, float mu, float d) {
    vec3 result;
    float r1 = sqrt(r * r + d * d + 2.0 * r * mu * d);
    float mu1 = (r * mu + d) / r1;

    if (mu > 0.0) {
        result = min(Transmittance(r, mu) / Transmittance(r1, mu1), 1.0);
    } else {
        result = min(Transmittance(r1, -mu1) / Transmittance(r, -mu), 1.0);
    }
    return result;
}

vec3 TransmittanceWithShadow(float r, float mu)
{
	// transmittance(=transparency) of atmosphere for infinite ray (r,mu)
	// (mu=cos(view zenith angle)), or zero if ray intersects ground

	return mu < -sqrt(1.0 - (Rg / r) * (Rg / r)) ? vec3(0, 0, 0) : Transmittance(r, mu);
}

vec3 Irradiance(float r, float muS)
{
	float uR = (r - Rg) / (Rt - Rg);
	float uMuS = (muS + 0.2) / (1.0 + 0.2);

	return textureLod(irradiance_texture, vec2(uMuS, uR), 0.0).rgb;
}

vec3 SunRadiance(vec3 worldPos)
{
	vec3 worldV = normalize(worldPos + EARTH_POS); // vertical vector
	float r = length(worldPos + EARTH_POS);
	float muS = dot(worldV, SUN_DIR);

	return TransmittanceWithShadow(r, muS) * SUN_INTENSITY;
}

vec3 SkyIrradiance(float r, float muS)
{
	return Irradiance(r, muS) * SUN_INTENSITY;
}

vec3 SkyIrradiance(vec3 worldPos)
{
	vec3 worldV = normalize(worldPos + EARTH_POS); // vertical vector
	float r = length(worldPos + EARTH_POS);
	float muS = dot(worldV, SUN_DIR);

	return Irradiance(r, muS) * SUN_INTENSITY;
}

vec3 SkyRadiance(vec3 camera, vec3 viewdir, out vec3 extinction)
{
	// scattered sunlight between two points
	// camera=observer
	// viewdir=unit vector towards observed point
	// sundir=unit vector towards the sun
	// return scattered light

	camera += EARTH_POS;

   	vec3 result = vec3(0,0,0);
    float r = length(camera);
    float rMu = dot(camera, viewdir);
    float mu = rMu / r;
    float r0 = r;
    float mu0 = mu;

    float deltaSq = sqrt(rMu * rMu - r * r + Rt*Rt);
    float din = max(-rMu - deltaSq, 0.0);
    if (din > 0.0)
    {
       	camera += din * viewdir;
       	rMu += din;
       	mu = rMu / Rt;
       	r = Rt;
    }

    float nu = dot(viewdir, SUN_DIR);
    float muS = dot(camera, SUN_DIR) / r;

    vec4 inScatter = Texture4D(scattering_texture, r, rMu / r, muS, nu);
    extinction = Transmittance(r, mu);

    if(r <= Rt)
    {
        vec3 inScatterM = GetMie(inScatter);
        float phaseR = PhaseFunctionR(nu);
        float phaseM = PhaseFunctionM(nu);
        result = inScatter.rgb *
				(phaseR/vec3(5.8e-3, 1.35e-2, 3.31e-2)) * (betaR) +
				inScatterM * (phaseM/vec3(4e-3, 4e-3, 4e-3)) * (betaM);
    }
    else
    {
    	result = vec3(0,0,0);
    	extinction = vec3(1,1,1);
    }

    return result * SUN_INTENSITY;
}

vec3 InScattering(vec3 camera, vec3 _point, out vec3 extinction, float shaftWidth, vec3 screen)
{

	// single scattered sunlight between two points
	// camera=observer
	// point=point on the ground
	// sundir=unit vector towards the sun
	// return scattered light and extinction coefficient

	vec3 result = vec3(0, 0, 0);
	extinction = vec3(1, 1, 1);

	vec3 viewdir = _point - camera;
	float d = length(viewdir);
	viewdir = viewdir / d;
	float r = length(camera);

	if (r < 0.9 * Rg)
	{
		camera.y += Rg;
		_point.y += Rg;
		r = length(camera);
	}
	float rMu = dot(camera, viewdir);
	float mu = rMu / r;
	float r0 = r;
	float mu0 = mu;
	_point -= viewdir * clamp(shaftWidth, 0.0, d);

	float deltaSq = sqrt(rMu * rMu - r * r + Rt*Rt);
	float din = max(-rMu - deltaSq, 0.0);

	if (din > 0.0 && din < d)
	{
		camera += din * viewdir;
		rMu += din;
		mu = rMu / Rt;
		r = Rt;
		d -= din;
	}

	if (r <= Rt)
	{
		float nu = dot(viewdir, SUN_DIR);
		float muS = dot(camera, SUN_DIR) / r;

		vec4 inScatter;

		if (r < Rg + 600.0)
		{
			// avoids imprecision problems in aerial perspective near ground
			float f = (Rg + 600.0) / r;
			r = r * f;
			rMu = rMu * f;
			_point = _point * f;
		}


		//Temporary fix: seems to work so I'll just leave it
		vec3 tempP = length(_point) > Rt ? camera : _point;
		float r1 = length(tempP);
		float rMu1 = dot(_point, viewdir);
		float mu1 = rMu1 / r1;
		float muS1 = dot(tempP, SUN_DIR) / r1;
		////////////////////////////////


		if (mu > 0.0){
			extinction = min(Transmittance(r, mu) / Transmittance(r1, mu1), 1.0);
		}else{
			extinction = min(Transmittance(r1, -mu1) / Transmittance(r, -mu), 1.0);
		}


		const float EPS = 0.004;
		float lim = -sqrt(1.0 - (Rg / r) * (Rg / r));

		if (abs(mu - lim) < EPS)
		{
			float a = ((mu - lim) + EPS) / (2.0 * EPS);

			mu = lim - EPS;
			r1 = sqrt(r * r + d * d + 2.0 * r * d * mu);
			mu1 = (r * mu + d) / r1;

			vec4 inScatter0 = Texture4D(scattering_texture, r, mu, muS, nu);
			vec4 inScatter1 = Texture4D(scattering_texture, r1, mu1, muS1, nu);
			vec4 inScatterA = max(inScatter0 - inScatter1 * extinction.rgbr, 0.0);

			mu = lim + EPS;
			r1 = sqrt(r * r + d * d + 2.0 * r * d * mu);
			mu1 = (r * mu + d) / r1;

			inScatter0 = Texture4D(scattering_texture, r, mu, muS, nu);
			inScatter1 = Texture4D(scattering_texture, r1, mu1, muS1, nu);
			vec4 inScatterB = max(inScatter0 - inScatter1 * extinction.rgbr, 0.0);

			inScatter = mix(inScatterA, inScatterB, a);
		}
		else
		{
			vec4 inScatter0 = Texture4D(scattering_texture, r, mu, muS, nu);
			vec4 inScatter1 = Texture4D(scattering_texture, r1, mu1, muS1, nu);
			inScatter = max(inScatter0 - inScatter1 * extinction.rgbr, 0.0);
		}

		/* vec4 inScatter0 = Texture4D(scattering_texture, r, mu, muS, nu);
		vec4 inScatter1 = Texture4D(scattering_texture, r1, mu1, muS, nu);
		inScatter = max(inScatter0 - inScatter1 * extinction.rgbr, 0.0); */

		// avoids imprecision problems in Mie scattering when sun is below horizon
		inScatter.w *= smoothstep(0.00, 0.02, muS);
		/* inScatter.rgb += screen; */

		vec3 inScatterM = distance(camera, _point) < (Rt/10.0) ? vec3(0.0) : GetMie(inScatter);
		float phaseR = PhaseFunctionR(nu);
		float phaseM = PhaseFunctionM(nu);
		result = max(
			vec3(0.0), inScatter.rgb *
			(phaseR/vec3(5.8e-3, 1.35e-2, 3.31e-2)) * (betaR) +
			(phaseM/vec3(4e-3, 4e-3, 4e-3)) * (betaM) * inScatterM
		);
		result *= SUN_INTENSITY;
	}

	return result+screen;

}










bool intersectAtmosphere(vec3 camera, vec3 dir, out float offset, out float maxPathLength)
{
	 offset = 0.0;
	 maxPathLength = 0.0;

	 // vector from ray origin to center of the sphere
	 vec3 l = -camera;
	 float l2 = dot(l,l);
	 float s = dot(l,dir);
	 // adjust top atmosphere boundary by small epsilon to prevent artifacts
	 float r = Rt - EPSILON_ATMOSPHERE;
	 float r2 = r*r;

	 if(l2 <= r2)
	 {
		 // ray origin inside sphere, hit is ensured
		 float m2 = l2 - (s * s);
		 float q = sqrt(r2 - m2);
		 maxPathLength = s + q;

		 return true;
	 }
	 else if(s >= 0.0)
	 {
		 // ray starts outside in front of sphere, hit is possible
		 float m2 = l2 - (s * s);

		 if(m2 <= r2)
		 {
			 // ray hits atmosphere definitely
			 float q = sqrt(r2 - m2);
			 offset = s - q;
			 maxPathLength = (s + q) - offset;

			 return true;
		 }
	 }

 return false;
}


vec3 GetInscatteredLight(vec3 camera, vec3 surfacePos, vec3 viewDir, inout vec3 attenuation, inout float irradianceFactor, vec3 screen)
{
	vec3 inscatteredLight = vec3(0.0, 0.0, 0.0);
	vec4 inscatterSurface;

	 float offset;
	 float maxPathLength;

	 if(intersectAtmosphere(camera, viewDir, offset, maxPathLength))
	 {
		 float pathLength = distance(camera, surfacePos);
		// check if object occludes atmosphere

		if(pathLength > offset)
		{
			 float cameraHeight = length(camera);
			 float muOriginal = dot(normalize(camera), viewDir);
			 float originalPathLength = pathLength;

			 // offsetting camera
			 vec3 startPos = camera + offset * viewDir;
			 float startPosHeight = length(startPos);
			 pathLength -= offset;

			 // starting position of path is now ensured to be inside atmosphere
			 // was either originally there or has been moved to top boundary
			 float muStartPos = dot(startPos,viewDir) / startPosHeight;
			 float nuStartPos = dot(viewDir, lightDir);
			 float musStartPos = dot(startPos, lightDir) / startPosHeight;

			 // in-scattering for infinite ray (light in-scattered when
			 // no surface hit or object behind atmosphere)
			 vec4 inscatter = max(Texture4D(scattering_texture, startPosHeight, muStartPos, musStartPos, nuStartPos), 0.0);

 			 float surfacePosHeight = length(surfacePos);
			 float muEndPos = dot(surfacePos, viewDir) / surfacePosHeight;
			 float musEndPos = dot(surfacePos, lightDir) / surfacePosHeight;

			 // check if object hit is inside atmosphere
			 if(pathLength < maxPathLength)
			 {
				 // reduce total in-scattered light when surface hit
				 // within atmosphere
				 attenuation = Transmittance(startPosHeight, muStartPos, pathLength);

				 float muEndPos = dot(surfacePos, viewDir) / surfacePosHeight;
				 inscatterSurface = Texture4D(scattering_texture, surfacePosHeight, muEndPos, musEndPos, nuStartPos);
				 inscatter = max(inscatter-attenuation.rgbr*inscatterSurface, 0.0);
				 //inscatter = inscatter - inscatterSurface;
				 irradianceFactor = 1.0;
			}
			else
			{
				 // retrieve extinction factor for inifinte ray
				attenuation = min(Transmittance(startPosHeight, muStartPos), 1.0);
			}

			// avoids imprecision problems near horizon by interpolating between
			 // two points above and below horizon
			 float muHorizon = -sqrt(1.0 - (Rg / startPosHeight) * (Rg / startPosHeight));

			 if (abs(muStartPos - muHorizon) < EPSILON_INSCATTER)
			 {
				 float mu = muHorizon - EPSILON_INSCATTER;
				 float samplePosHeight = sqrt(startPosHeight*startPosHeight + pathLength*pathLength + 2.0 * startPosHeight * pathLength *mu);

				 float muSamplePos = (startPosHeight * mu + pathLength) / samplePosHeight;

				 vec4 inScatter0 = Texture4D(scattering_texture, startPosHeight, mu, musStartPos, nuStartPos);
				 vec4 inScatter1 = Texture4D(scattering_texture, samplePosHeight, muSamplePos, musEndPos, nuStartPos);
				 vec4 inScatterA = max(inScatter0-attenuation.rgbr * inScatter1,0.0);

				 mu = muHorizon + EPSILON_INSCATTER;
				 samplePosHeight = sqrt(startPosHeight * startPosHeight + pathLength * pathLength + 2.0 * startPosHeight * pathLength * mu);
				 muSamplePos = (startPosHeight * mu + pathLength) / samplePosHeight;

				 inScatter0 = Texture4D(scattering_texture, startPosHeight, mu, musStartPos, nuStartPos);
				 inScatter1 = Texture4D(scattering_texture, samplePosHeight, muSamplePos, musEndPos, nuStartPos);
				 vec4 inScatterB = max(inScatter0 - attenuation.rgbr * inScatter1, 0.0);
				 float t = ((muStartPos - muHorizon) + EPSILON_INSCATTER) / (2.0 * EPSILON_INSCATTER);

				 inscatter = mix(inScatterA, inScatterB, t);
			}

				 inscatter.w *= smoothstep(0.35, 0.7, musStartPos);

				 vec3 phaseR = (PhaseFunctionR(nuStartPos)/vec3(5.8e-3, 1.35e-2, 3.31e-2)) * betaR;
				 vec3 phaseM = (PhaseFunctionM(nuStartPos)/vec3(4e-3, 4e-3, 4e-3)) * betaM;
				 inscatteredLight = max(inscatter.rgb * phaseR + GetMie(inscatter) * phaseM, 0.0);
				 inscatteredLight *= SUN_INTENSITY;

		}
	}

	return inscatteredLight;
}















vec3 Atmosphere(vec3 eye, vec3 dir, vec3 screen, float rdepth, float depth)
{
	vec2 atmSphere = raySphere(planet.position, planet.radius+EPSILON, eye, dir);
	float sceneDepth = min(atmSphere.x, rdepth);

	vec3 wpos = (eye + dir * sceneDepth) * SCALE;

	vec3 extinction;
	float irradianceFactor;
	vec3 tmp = depth == 1.0 ? vec3(0.0) : wpos;
	/* vec3 scatter = InScattering(eye*SCALE, wpos, extinction, 1.0, screen); */
	vec3 scatter = GetInscatteredLight(eye*SCALE, wpos, dir, extinction, irradianceFactor, screen);
	vec3 reflected = ((SunRadiance(tmp)+SkyIrradiance(tmp))/(SUN_INTENSITY/2.0));// * (SUN_INTENSITY/2.0);
	/* reflected = smoothstep(0.0, 1.0, reflected); */
	reflected = pow(reflected, vec3(1.5));

	/* vec3 color = (screen * SunRadiance(tmp)) + scatter; */
	vec3 color = (screen * reflected) + scatter;//pow(screen, 1.0/scatter) + pow(scatter, vec3(1.5));

	return saturate(color);
}

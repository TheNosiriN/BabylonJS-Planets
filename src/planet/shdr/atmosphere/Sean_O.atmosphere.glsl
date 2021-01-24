precision highp float;






// and the steps (more looks better, but is slower)
// the primary step has the most effect on looks
const int PRIMARY_STEPS = 50; /* primary steps, affects quality the most */
const int LIGHT_STEPS = 4; /* light steps, how much steps in the light direction are taken */

const float EARTH_RADIUS = 6360000.0;
const float EARTH_ATMOS_RADIUS = 6420000.0;









vec3 calculate_scattering(
    vec3 start, 				// the start of the ray (the camera position)
    vec3 dir, 					// the direction of the ray (the camera vector)
    vec3 planet_pos,
    float max_dist, 			// the maximum distance the ray can travel (because something is in the way, like an object)
    vec3 scene_color,			// the color of the scene
    vec3 light_dir, 			// the direction of the light
    vec3 light_intensity,		// how bright the light is, affects the brightness of the atmosphere
    float planet_radius, 		// the radius of the planet
    float atmo_radius, 			// the radius of the atmosphere
    vec3 beta_ray, 				// the amount rayleigh scattering scatters the colors (for earth: causes the blue atmosphere)
    vec3 beta_mie, 				// the amount mie scattering scatters colors
    vec3 beta_absorption,   	// how much air is absorbed
    vec3 beta_ambient,			// the amount of scattering that always occurs, cna help make the back side of the atmosphere a bit brighter
    float g, 					// the direction mie scatters the light in (like a cone). closer to -1 means more towards a single direction
    float height_ray, 			// how high do you have to go before there is no rayleigh scattering?
    float height_mie, 			// the same, but for mie
    float height_absorption,	// the height at which the most absorption happens
    float absorption_falloff,	// how fast the absorption falls off from the absorption height
    int steps_i, 				// the amount of steps along the 'primary' ray, more looks better but slower
    int steps_l 				// the amount of steps along the light ray, more looks better but slower
){
    start -= planet_pos;

    // calculate the start and end position of the ray, as a distance along the ray
    // we do this with a ray sphere intersect
    float a = dot(dir, dir);
    float b = 2.0 * dot(dir, start);
    float c = dot(start, start) - (atmo_radius * atmo_radius);
    float d = (b * b) - 4.0 * a * c;

    // stop early if there is no intersect
    if (d < 0.0) return scene_color;

    // calculate the ray length
    vec2 ray_length = vec2(
        max((-b - sqrt(d)) / (2.0 * a), 0.0),
        min((-b + sqrt(d)) / (2.0 * a), max_dist)
    );



    // if the ray did not hit the atmosphere, return a black color
    if (ray_length.x > ray_length.y) return scene_color;

    // prevent the mie glow from appearing if there's an object in front of the camera
    bool allow_mie = max_dist > ray_length.y;

    // make sure the ray is no longer than allowed
    ray_length.y = min(ray_length.y, max_dist);
    ray_length.x = max(ray_length.x, 0.0);

    // get the step size of the ray
    float step_size_i = (ray_length.y - ray_length.x) / float(steps_i);

    // next, set how far we are along the ray, so we can calculate the position of the sample
    // if the camera is outside the atmosphere, the ray should start at the edge of the atmosphere
    // if it's inside, it should start at the position of the camera
    // the min statement makes sure of that
    float ray_pos_i = ray_length.x;

    // these are the values we use to gather all the scattered light
    vec3 total_ray = vec3(0.0); // for rayleigh
    vec3 total_mie = vec3(0.0); // for mie

    // initialize the optical depth. This is used to calculate how much air was in the ray
    vec3 opt_i = vec3(0.0);

    // also init the scale height, avoids some vec2's later on
    vec2 scale_height = vec2(height_ray, height_mie);

    // Calculate the Rayleigh and Mie phases.
    // This is the color that will be scattered for this ray
    // mu, mumu and gg are used quite a lot in the calculation, so to speed it up, precalculate them
    float mu = dot(dir, light_dir);
    float mumu = mu * mu;
    float gg = g * g;
    float phase_ray = 3.0 / (50.2654824574 /* (16 * pi) */) * (1.0 + mumu);
    float phase_mie = allow_mie ? 3.0 / (25.1327412287 /* (8 * pi) */) * ((1.0 - gg) * (mumu + 1.0)) / (pow(1.0 + gg - 2.0 * mu * g, 1.5) * (2.0 + gg)) : 0.0;

    // now we need to sample the 'primary' ray. this ray gathers the light that gets scattered onto it
    for (int i = 0; i < steps_i; ++i) {

        // calculate where we are along this ray
        vec3 pos_i = start + dir * (ray_pos_i + step_size_i * 0.5);

        // and how high we are above the surface
        float height_i = length(pos_i) - planet_radius;

        // now calculate the density of the particles (both for rayleigh and mie)
        vec3 density = vec3(exp(-height_i / scale_height), 0.0);

        // and the absorption density. this is for ozone, which scales together with the rayleigh,
        // but absorbs the most at a specific height, so use the sech function for a nice curve falloff for this height
        // clamp it to avoid it going out of bounds. This prevents weird black spheres on the night side
        density.z = clamp((1.0 / cosh((height_absorption - height_i) / absorption_falloff)) * density.x, 0.0, 1.0);
        density *= step_size_i;

        // Add these densities to the optical depth, so that we know how many particles are on this ray.
        opt_i += density;

        // Calculate the step size of the light ray.
        // again with a ray sphere intersect
        // a, b, c and d are already defined
        a = dot(light_dir, light_dir);
        b = 2.0 * dot(light_dir, pos_i);
        c = dot(pos_i, pos_i) - (atmo_radius * atmo_radius);
        d = (b * b) - 4.0 * a * c;

        // no early stopping, this one should always be inside the atmosphere
        // calculate the ray length
        float step_size_l = (-b + sqrt(d)) / (2.0 * a * float(steps_l));

        // and the position along this ray
        // this time we are sure the ray is in the atmosphere, so set it to 0
        float ray_pos_l = 0.0;

        // and the optical depth of this ray
        vec3 opt_l = vec3(0.0);

        // now sample the light ray
        // this is similar to what we did before
        for (int l = 0; l < steps_l; ++l) {

            // calculate where we are along this ray
            vec3 pos_l = pos_i + light_dir * (ray_pos_l + step_size_l * 0.5);

            // the heigth of the position
            float height_l = length(pos_l) - planet_radius;

            // calculate the particle density, and add it
            vec3 density_l = vec3(exp(-height_l / scale_height), 0.0);
            density_l.z = clamp((1.0 / cosh((height_absorption - height_l) / absorption_falloff)) * density_l.x, 0.0, 1.0);
            opt_l += density_l * step_size_l;

            // and increment where we are along the light ray.
            ray_pos_l += step_size_l;

        }

        // Now we need to calculate the attenuation
        // this is essentially how much light reaches the current sample point due to scattering
        vec3 attn = exp(-(beta_mie * (opt_i.y + opt_l.y) + beta_ray * (opt_i.x + opt_l.x) ));

        // accumulate the scattered light (how much will be scattered towards the camera)
        total_ray += density.x * attn;
        total_mie += density.y * attn;

        // and increment the position on this ray
        ray_pos_i += step_size_i;

    }

    // calculate how much light can pass through the atmosphere
    vec3 opacity = exp(-(beta_mie * opt_i.y + beta_ray * opt_i.x + beta_absorption * opt_i.z));

    // calculate and return the final color
		vec3 scattering = (
        phase_ray * beta_ray * total_ray // rayleigh color
        + phase_mie * beta_mie * total_mie // mie
        + opt_i.x * beta_ambient // and ambient
    );

    return scattering * light_intensity + scene_color * opacity; // now make sure the background is rendered correctly
}










vec3 Atmosphere(vec3 eye, vec3 dir, vec3 screen, float rdepth, float depth)
{
    vec2 atmSphere = raySphere(planet.position, planet.radius, eye, dir);
		float sceneDepth = min(atmSphere.x, rdepth);



    float ATMOS_RADIUS = (planet.radius*EARTH_ATMOS_RADIUS) / EARTH_RADIUS; /* radius of the atmosphere */

    // scattering coeffs
    vec3 RAY_BETA = (EARTH_ATMOS_RADIUS*vec3(3.8e-6, 13.5e-6, 33.1e-6)) / ATMOS_RADIUS; /* rayleigh, affects the color of the sky */
    vec3 MIE_BETA = (EARTH_ATMOS_RADIUS*vec3(4e-6)) / ATMOS_RADIUS; /* mie, affects the color of the blob around the sun */

    vec3 AMBIENT_BETA = vec3(0.0); /* ambient, affects the scattering color when there is no lighting from the sun */
    vec3 ABSORPTION_BETA = (EARTH_ATMOS_RADIUS*vec3(2.04e-5, 4.97e-5, 1.95e-6)) / ATMOS_RADIUS; /* what color gets absorbed by the atmosphere (Due to things like ozone) */

    float HEIGHT_RAY = (ATMOS_RADIUS*8e3) / EARTH_ATMOS_RADIUS; /* rayleigh height */
    float HEIGHT_MIE = (ATMOS_RADIUS*1.2e3) / EARTH_ATMOS_RADIUS; /* and mie */


    const float G = 0.5; /* mie scattering direction, or how big the blob around the sun is */
    // and the heights (how far to go up before the scattering has no effect)

    float HEIGHT_ABSORPTION = (ATMOS_RADIUS*30e3) / EARTH_ATMOS_RADIUS; /* at what height the absorption is at it's maximum */
    float ABSORPTION_FALLOFF = (ATMOS_RADIUS*3e3) / EARTH_ATMOS_RADIUS; /* how much the absorption decreases the further away it gets from the maximum height */



    // get the atmosphere color
    vec3 scattering = calculate_scattering(
        eye,				            // the position of the camera
        dir, 					        // the camera vector (ray direction of this pixel)
        planet.position,
        sceneDepth, 						// max dist, essentially the scene depth
        screen,						// scene color, the color of the current pixel being rendered
        lightDir,						// light direction
        vec3(40.0),						// light intensity, 40 looks nice
        planet.radius,                  // radius of the planet in meters
        ATMOS_RADIUS,                   // radius of the atmosphere in meters
        RAY_BETA,						// Rayleigh scattering coefficient
        MIE_BETA,                       // Mie scattering coefficient
        ABSORPTION_BETA,                // Absorbtion coefficient
        AMBIENT_BETA,					// ambient scattering, turned off for now. This causes the air to glow a bit when no light reaches it
        G,                          	// Mie preferred scattering direction
        HEIGHT_RAY,                     // Rayleigh scale height
        HEIGHT_MIE,                     // Mie scale height
        HEIGHT_ABSORPTION,				// the height at which the most absorption happens
        ABSORPTION_FALLOFF,				// how fast the absorption falls off from the absorption height
        PRIMARY_STEPS, 					// steps in the ray direction
        LIGHT_STEPS 					// steps in the light direction
    );


    vec3 color = scattering;

    return color;
}

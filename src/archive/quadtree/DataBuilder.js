let strt = "../../../../";
importScripts(
	strt+"src/Utils.js",
	strt+"src/planet/gen/quadtree/QuadTree.js",
	strt+"src/planet/gen/quadtree/PerlinNoise.js"
);



var Noise = {
	// octaves: 4,
	// amplitude: 0.1,
	// frequency: 10,
	// roughness: 7,
	// persistence: 0.2,
	// warpAmplitude: 1.25,
	// warpFrequency: 0.5,
};


var Observer = UTILS.Vector3([0]);
var Position = UTILS.Vector3([0]);


self.onmessage = function(e)
{
	Observer = e.data.observer;
	Position = e.data.position;

	if (Noise.seed != e.data.noise.seed){
		Noise = e.data.noise;
		Noise.noise = new SimplexNoise(Noise.seed);
	}

	//Noise.amplitude = 0.05 * e.data.radius;

	var data = buildMeshFromData(
		e.data.array,
		e.data.nodemap,
		e.data.radius
	);

	self.postMessage({meshData: makeSharedData(data), index: e.data.index});
}



function makeSharedData(data)
{
    let obj = {};
    obj.vertices = new Float32Array(new SharedArrayBuffer(4 * data.vertices.length));
		obj.normals = new Float32Array(new SharedArrayBuffer(4 * data.normals.length));
    obj.indices = new Float32Array(new SharedArrayBuffer(4 * data.indices.length));
    obj.vertices.set(data.vertices, 0);
		obj.normals.set(data.normals, 0);
    obj.indices.set(data.indices, 0);

    return obj;
}

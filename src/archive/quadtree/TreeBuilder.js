let strt = "../../../../";
importScripts(
	strt+"src/Utils.js",
	strt+"src/planet/gen/quadtree/QuadTree.js",
	strt+"src/planet/gen/quadtree/WorkerPool.js",
	strt+"src/planet/gen/quadtree/PerlinNoise.js"
);

UTILS.clearAllTimeoutsAndIntervals();





var Trees = [];
var NodeMap = [];
var LastIndexes = [];
var ArrayOfLevels = [];
var ArrayOfLevelHash = [];
var LastArrayOfLevelHash = [];

var Observer = UTILS.Vector3([0]);
var Position = UTILS.Vector3([0]);
var FrustumPlanes = [];
var Radius = 0;

var MaxLevel = 20;
var StartWidth = 4;

var currentHighestLevel = 0;


var Noise = {
	octaves: 4,
	amplitude: 0.1,
	frequency: 20,
	roughness: 7,
	persistence: 0.2,
	warpAmplitude: 1.25,
	warpFrequency: 0.5,
};



var DataBuilderPool = new WorkerPool("DataBuilder.js", 4);
DataBuilderPool.init();



self.onmessage = function(e)
{
		Observer = e.data.observer;
		Position = e.data.position;
		FrustumPlanes = e.data.frustumPlanes;
		// console.log(FrustumPlanes);
		// console.log(hh);

		if (e.data.create){
			Radius = e.data.radius;
			MaxLevel = e.data.maxLevels;
			//MaxLevel = UTILS.clamp(Math.floor(UTILS.remap(Radius, 1000, 7000, 2, 15)), 2, 15);

			Noise.amplitude = 0.05 * Radius;

			Noise.seed = e.data.seed || "RandomSeed";
			Noise.noise = new SimplexNoise(Noise.seed);
			createTrees();


			self.postMessage([]);
		}

		else if (e.data.update)
		{
			updateTrees();

			let d = {};
			d.update = true;
			d.indexes = [];

			if (e.data.requestTrees == true){
				d.trees = trees;
			}


			//reconfigure ArrayOfLevels
			for (var i=0; i<MaxLevel; i++){
				if (ArrayOfLevelHash[i] != null){
					if (ArrayOfLevelHash[i] - LastArrayOfLevelHash[i] != 0){ d.indexes.push(i); }
					if (i > currentHighestLevel){ currentHighestLevel = i; }
				}else{
					if (i <= currentHighestLevel){
						if (UTILS.checkArrayFor(i, LastIndexes) == false){ d.indexes.push(i); }
					}
					//d.indexes.push(i);
				}
			}
			LastIndexes = d.indexes.slice();
			//console.log(LastIndexes);

			// let tempNoise = JSON.parse(JSON.stringify(Noise, function(name, val){
			// 	if (name === 'noise'){ return undefined; }else{ return val }
			// }));

			d.array = new Array(d.indexes.length);
			for (var i=0; i<d.indexes.length; i++)
			{
				if (ArrayOfLevels[d.indexes[i]] == null){
					d.array[i] = new MeshData();
				}else{
					DataBuilderPool.addTask({
						message: {
							index: i,
							array: ArrayOfLevels[d.indexes[i]],
							nodemap: NodeMap,
							noise: {
								seed: Noise.seed,
								octaves: Noise.octaves,
								amplitude: Noise.amplitude,
								frequency: Noise.frequency,
								roughness: Noise.roughness,
								persistence: Noise.persistence,
								warpAmplitude: Noise.warpAmplitude,
								warpFrequency: Noise.warpFrequency
							},
							radius: Radius,
							observer: Observer,
							position: Position
						},
						callback: function(ret){
							d.array[ret.data.index] = ret.data.meshData;
						}
					});
				}
			}


			let checker = setInterval(function(){
				for (var i=0; i<d.indexes.length; i++){
					if (d.array[i] == null){ return; }
				}

				clearInterval(checker);

				self.postMessage(d);
			}, 10);

		}

};






function createTrees()
{
	ArrayOfLevels = [];
	for (var i=0; i<MaxLevel; i++){
		ArrayOfLevels[i] = new Array();
		ArrayOfLevelHash[i] = 0;
	}

	for (var i=0; i<UTILS.cubeDirections.length; i++)
	{
			Trees[i] = new QuadTree(
					UTILS.cubeDirections[i],
					Position, Radius,
					StartWidth, MaxLevel, Radius
			);
	}
}





function updateTrees()
{
	delete NodeMap; NodeMap = [];
	delete ArrayOfLevels; ArrayOfLevels = [];

	LastArrayOfLevelHash = ArrayOfLevelHash.slice();
	delete ArrayOfLevelHash; ArrayOfLevelHash = [];

	for (var i=0; i<Trees.length; i++)
	{
		QuadTree.Build(Observer, Trees[i]);
	}


	// var dataArray = [];
	// for (var i=0; i<ArrayOfLevels.length; i++)
	// {
	// 	var data = buildMeshFromData(ArrayOfLevels[i], NodeMap, Radius);
	// 	dataArray.push(data);
	// }

	//return {array: dataArray};
}

let strt = "../../../../";
importScripts(
	strt+"src/Utils.js",
	// strt+"src/planet/gen/quadtree/PerlinNoise.js"
);




const WINDOW_WIDTH = 1;
const WINDOW_HEIGHT = 1;

const PERMUTATION_TABLE_SIZE = 512;

var MeshData = null;
var StartRes = 5;
var MaxLevel = 18;
var CurrentLevel = 0;
var Radius = 10;
var MaxHeight = 1;
var Position = null;
var Frustumplanes = [];


// compute distance levels
var DistanceLevels = [];
var TriangleSizes = [];


// icosahedron
var Idx = [];
var IcoPoints = [];
var RecurseIdx = [];


var NoiseOpt = {

};



function Precompute(e)
{
    // compute distance levels
    // for (var i=1; i<MaxLevel; i++){

    // }

		NoiseOpt = e.properties;
		// NoiseOpt.noise = new SimplexNoise(e.seed);
		// NoiseOpt.noise = new PerlinNoise(makePermTable(e.seed, PERMUTATION_TABLE_SIZE).perm);


    for (var i=0; i<MaxLevel; i++){
        let ratio = StartRes;
        let size = StartRes/Math.pow(3, i/1.8);
        DistanceLevels[i] = ratio*size;
    }


    // construct icosahedron
    Idx = [
        0, 11, 5, 0, 5, 1, 0, 1, 7, 0, 7, 10, 0, 10, 11,
        1, 5, 9, 5, 11, 4, 11, 10, 2, 10, 7, 6, 10, 7, 6, 7, 1, 8,
        3, 9, 4, 3, 4, 2, 3, 2, 6, 3, 6, 8, 3, 8, 9,
        4, 9, 5, 2, 4, 11, 6, 2, 10, 8, 6, 7, 9, 8, 1
    ];

    let t = (1.0 + Math.sqrt(5.0)) / 2.0;
    IcoPoints = [
        UTILS.Vector3([ -1, t, 0 ]), UTILS.Vector3([ 1, t, 0 ]),
        UTILS.Vector3([ -1, -t, 0 ]), UTILS.Vector3([ 1, -t, 0 ]),
        UTILS.Vector3([ 0, -1, t ]), UTILS.Vector3([ 0, 1, t ]),
        UTILS.Vector3([ 0, -1, -t ]), UTILS.Vector3([ 0, 1, -t ]),
        UTILS.Vector3([ t, 0, -1 ]), UTILS.Vector3([ t, 0, 1 ]),
        UTILS.Vector3([ -t, 0, -1 ]), UTILS.Vector3([ -t, 0, 1 ]),
    ];

    RecurseIdx = [0, 3, 5, 5, 3, 4, 3, 1, 4, 5, 4, 2];
}




function Recurse(p1, p2, p3, center, level)
{
		if (level > CurrentLevel){ CurrentLevel = level; }

		//The Great Cull
		if (
        UTILS.Dot( UTILS.Multiply31(p1, 1 + MaxHeight), center ) < 0.85 &&
        UTILS.Dot( UTILS.Multiply31(p2, 1 + MaxHeight), center ) < 0.85 &&
        UTILS.Dot( UTILS.Multiply31(p3, 1 + MaxHeight), center ) < 0.85
    ){ return; }

    //let size = StartRes/Math.pow(2, level);


    //Post culling
    // if (level > 3){
    //     if (
    //         isPointInFrustum(Frustumplanes, UTILS.Multiply31(UTILS.Add33V(p1, Position), Radius)) == false &&
    //         isPointInFrustum(Frustumplanes, UTILS.Multiply31(UTILS.Add33V(p2, Position), Radius)) == false &&
    //         isPointInFrustum(Frustumplanes, UTILS.Multiply31(UTILS.Add33V(p3, Position), Radius)) == false
    //     ){
    //         return;
    //     }
    // }


    // The survivors after the cull
    let edges = [
        UTILS.Divide31(UTILS.Add33V(p1, p2), 2),
        UTILS.Divide31(UTILS.Add33V(p2, p3), 2),
        UTILS.Divide31(UTILS.Add33V(p3, p1), 2)
    ];
    let edgeDist = [];


    // Their distance is evaluated
    for (let i=0; i<3; i++){
				let distance = UTILS.distanceToPoint3DV( edges[i], center );
				edgeDist[i] = level > 3 ? distance > DistanceLevels[level] : false;
    }

    // Add Triangle
		if ( (edgeDist[0] && edgeDist[1] && edgeDist[2]) || level >= MaxLevel ){
			AddTriangle(p1, p2, p3);
			return;
		}


    // Recurse
    let p = [
        p1, p2, p3,
        edges[0], edges[1], edges[2]
    ];
    let valid = [ true, true, true, true ];

    if (edgeDist[0]){ p[3] = p1; valid[0] = false; } // skip triangle 0
    if (edgeDist[1]){ p[4] = p2; valid[2] = false; } // skip triangle 2
    if (edgeDist[2]){ p[5] = p3; valid[3] = false; } // skip triangle 3

		for (let i=0; i<4; i++){
			if (valid[i] == true){
				Recurse(
				    UTILS.Normalize( p[RecurseIdx[3 * i + 0]] ),
				    UTILS.Normalize( p[RecurseIdx[3 * i + 1]] ),
				    UTILS.Normalize( p[RecurseIdx[3 * i + 2]] ),
				    center, level+1
				);
			}
		}
}




function AddTriangle(p1, p2, p3)
{
    // let np1 = UTILS.Multiply31(p1, Radius + (SampleNoise(p1, NoiseOpt) * Radius * MaxHeight) );
    // let np2 = UTILS.Multiply31(p2, Radius + (SampleNoise(p2, NoiseOpt) * Radius * MaxHeight) );
    // let np3 = UTILS.Multiply31(p3, Radius + (SampleNoise(p3, NoiseOpt) * Radius * MaxHeight) );
		let np1 = UTILS.Multiply31(p1, Radius );
    let np2 = UTILS.Multiply31(p2, Radius );
    let np3 = UTILS.Multiply31(p3, Radius );

    MeshData.vertices.push(np3._x, np3._y, np3._z);
    MeshData.vertices.push(np2._x, np2._y, np2._z);
    MeshData.vertices.push(np1._x, np1._y, np1._z);

    let len = MeshData.vertices.length/3;
    MeshData.indices.push(len-3, len-2, len-1);
}



function Rebuild(center)
{
    delete MeshData;
    MeshData = new MeshDataClass();

		CurrentLevel = 0;

		for (let i=0; i < Idx.length/3; i++)
		{
			let p1 = UTILS.Normalize( IcoPoints[Idx[i * 3 + 0]] ); // triangle point 1
			let p2 = UTILS.Normalize( IcoPoints[Idx[i * 3 + 1]] ); // triangle point 2
			let p3 = UTILS.Normalize( IcoPoints[Idx[i * 3 + 2]] ); // triangle point 3
        Recurse(
					p1, p2, p3,
					center, 0, p1, p2, p3
        );
		}
}


function isPointInFrustum(planes, point)
{
    for (let i = 0; i < 6; i++) {
        if (UTILS.Dot(planes[i].normal, point) + planes[i].d < 0){
            return false;
        }
    }
    return true;
}




function makeSharedData(meshData)
{
		let obj = {};

		try {
			var a = SharedArrayBuffer;
		} catch (e) {
			console.log("SharedArrayBuffers are not supported/enabled in your browser/setup");

			obj.vertices = meshData.vertices;
			obj.indices = meshData.indices;

			return obj;
		}

    obj.vertices = new Float32Array(new SharedArrayBuffer(4 * meshData.vertices.length));
    obj.indices = new Float32Array(new SharedArrayBuffer(4 * meshData.indices.length));
    obj.vertices.set(meshData.vertices, 0);
    obj.indices.set(meshData.indices, 0);

    return obj;
}




self.onmessage = function(e)
{
    var state = e.data.state;

    switch (state)
    {
        case 0: // Setup worker
            // WINDOW_WIDTH = e.data.windowWidth;
            // WINDOW_HEIGHT = e.data.windowHeight;

            Precompute(e.data);

            postMessage({state: e.data.state});
        break;

        case 1: // Build Data
            let center = e.data.center || UTILS.Vector3([0]);
            Radius = e.data.radius || 10;
            Frustumplanes = e.data.frustumplanes;
            MaxHeight = e.data.maxHeight;
						Position = e.data.position;

            // WINDOW_WIDTH = e.data.windowWidth;
            // WINDOW_HEIGHT = e.data.windowHeight;

            Rebuild(center);
            let obj = makeSharedData(MeshData);

            postMessage({
                state: e.data.state,
                data: obj,
								level: CurrentLevel
            });
        break;
    }
}








class MeshDataClass
{
	constructor(v, i, u, n){
      this.vertices = v || [];
      this.indices = i || [];
  }
}

class MeshData
{
  constructor(v, i, u, n){
    this.vertices = v || [];
		this.verticesLow = [];
    this.indices = i || [];
    this.normals = n || [];
    this.uvs = u || [];
  }

	clone()
	{
		return new MeshData(
			this.vertices || [],
	    this.indices || [],
			this.uvs || [],
	    this.normals || []
		);
	}
}












/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////
//// QuadTree class
////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


class TreeInfo
{
	constructor()
	{
		this.position; this.size;
		this.startWidth; this.observer;
		this.maxLevels; this.maxDist;
		this.cubeFace;
	}
}


class QuadTree
{
    constructor(face, position, size, sw, levels, maxDist)
    {
				this.info = new TreeInfo();

				this.info.position = position || UTILS.Vector3([0]);
        this.info.size = size || 1;
        this.info.startWidth = sw || 2;

        this.info.observer = UTILS.Vector3([0]);
        this.info.maxLevels = levels || 4;
        this.info.maxDist = maxDist || this.info.size*2;
        this.info.cubeFace = face || UTILS.cubeDirections[0];
    }



		toSphereCoord(pos)
    {
        var percent = UTILS.Vector3([
            pos._x / this.info.size,
            pos._z / this.info.size, 0
        ]);
        percent = UTILS.calculatePointOnSphere(percent, this.info.cubeFace);
        percent = UTILS.Multiply31(percent, this.info.size + SampleNoise(percent, Noise)*Noise.amplitude);
        return percent;
    }



		recurse(position, size, level, index)
		{
			if (ArrayOfLevels[level-1] == null){ ArrayOfLevels[level-1] = new Array(); }
			if (ArrayOfLevelHash[level-1] == null){ ArrayOfLevelHash[level-1] = 0; }


			let sphereCoord = this.toSphereCoord( UTILS.Add31(position, size/2) );
			let realPos = UTILS.Add33([sphereCoord, Position]);
			let normal = UTILS.Normalize(sphereCoord);

			let dot = UTILS.Dot( normal, UTILS.Normalize(UTILS.Subtract33( Observer, Position )) );
			if (UTILS.clamp(dot, -1, 1) < 0.5){ return; }


			// let sc1 = this.toSphereCoord( UTILS.Vector3([position._x, 0, position._y]) );
			// let sc2 = this.toSphereCoord( UTILS.Vector3([position._x+size, 0, position._y]) );
			// let sc3 = this.toSphereCoord( UTILS.Vector3([position._x, 0, position._y+size]) );
			// let sc4 = this.toSphereCoord( UTILS.Vector3([position._x+size, 0, position._y+size]) );

			// if (
			// 	isPointInFrustum( FrustumPlanes, UTILS.Add33([sc1, Position]) ) == false &&
			// 	isPointInFrustum( FrustumPlanes, UTILS.Add33([sc2, Position]) ) == false &&
			// 	isPointInFrustum( FrustumPlanes, UTILS.Add33([sc3, Position]) ) == false &&
			// 	isPointInFrustum( FrustumPlanes, UTILS.Add33([sc4, Position]) ) == false
			// ){ return; }


			let dist = UTILS.distanceToPoint3DV(realPos, Observer )/this.info.maxDist;
			//let centerDist = UTILS.distanceToPoint3DV(Position, Observer)/this.info.maxDist;


			if (
				level >= this.info.maxLevels ||
				dist > 1/Math.pow(3, level/2) //1/Math.pow( level, UTILS.remap(level/2, 1, this.info.maxLevels*1.5, 2, 6) )
			){
				ArrayOfLevelHash[level-1] += ( (position._x/this.info.size)+""+(position._z/this.info.size) ).hashCode();
				ArrayOfLevels[level-1].push({
					position: position,
					size: size,
					level: level,
					index: index,
					face: this.info.cubeFace
				});
				return;
			}


			let w = 2;
			for (var x=0, i=0; x<w; x++){
					for (var y=0; y<w; y++, i++)
					{
							let pos = UTILS.Multiply31(
								UTILS.Divide31(UTILS.Vector3([x, 0, y]), w), size
							);
							pos = UTILS.Add33([position, pos]);

							this.recurse(
								pos, size/w,
								level + 1, i
							);

							NodeMap[pos._x+","+pos._z+","+(level+1)] = true;
					}
			}
		}



    static Build(observer, tree)
    {
				for (var x= -tree.info.startWidth/2, i=0; x<tree.info.startWidth/2; x++){
            for (var y= -tree.info.startWidth/2; y<tree.info.startWidth/2; y++, i++)
            {
                let pos = UTILS.Multiply31(
									UTILS.Divide31(UTILS.Vector3([x, 0, y]), tree.info.startWidth), tree.info.size
								);

								tree.recurse(
									pos, tree.info.size/tree.info.startWidth,
									1, i
								);
            }
        }
    }
}











/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////
//// Utility functions
////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


function makeData(position, size, direction, radius, level, face, data)
{
	makeGrid(
			data, position, 6,
			size, level, direction,
			radius, radius, face,
			data.vertices.length/3
	);
}



function buildMeshFromData(array, nodemap, radius)
{
	let data = new MeshData();
	for (var i=0; i<array.length; i++)
	{
		var cell = array[i];
		var index = {N:0, E:0, S:0, W:0};

		if (cell.level > 1){
			let up = nodemap[cell.position._x+","+(cell.position._z - cell.size)+","+cell.level];
			let down = nodemap[cell.position._x+","+(cell.position._z + cell.size)+","+cell.level];
			let left = nodemap[(cell.position._x - cell.size)+","+cell.position._z+","+cell.level];
			let right = nodemap[(cell.position._x + cell.size)+","+cell.position._z+","+cell.level];

			if (up != true){ index.S = 1; } // South
			if (down != true){ index.N = 1; } // North
			if (left != true){ index.W = 1; } // West
			if (right != true){ index.E = 1; } // East
		}

		makeData(
			cell.position, cell.size, index,
			radius, cell.level, cell.face,
			data
		);
	}

	return data;
}





function makeGrid(data, strt, detail, size, level, index, radius, totalWidth, cubeFace, indexOffset)
{
    radius = radius || 1;
    cubeFace = cubeFace || UTILS.cubeDirections[0];
    totalWidth = totalWidth || 1;
		//console.log(size);

		var getVertex = function(x, y){
			return vertex = UTILS.Vector3([
					( strt._x + ( (x * size) / detail )) / totalWidth,
					( strt._z + ( ((detail - y) * size) / detail )) / totalWidth, 0
			]);
		}

		var makeVertex = function(x, y){
			return UTILS.calculatePointOnSphere(getVertex(x,y), cubeFace);
		}

		var computeNormalFromNoise = function(v, f, depth)
		{
			let scx = makeVertex(x + 1/depth, y);
			let scy = makeVertex(x, y + 1/depth);
			let dfx = SampleNoise(scx, Noise);
			let dfy = SampleNoise(scy, Noise);

			let p = UTILS.Multiply31(v, f*Noise.amplitude + radius*depth);
			return UTILS.Normalize( UTILS.Cross(
				UTILS.Subtract33( UTILS.Multiply31(scx, dfx*Noise.amplitude + radius*depth), p),
				UTILS.Subtract33( UTILS.Multiply31(scy, dfy*Noise.amplitude + radius*depth), p)
			) );
		}

    for (y = 0; y <= detail; y++) {
        for (x = 0; x <= detail; x++)
        {
            let sphereCoord = makeVertex(x, y);
						let noise = SampleNoise(sphereCoord, Noise);

            let p = UTILS.Multiply31(sphereCoord, radius + noise*Noise.amplitude);

            data.vertices.push(
                p._x, p._y, p._z /// SPHERICAL COORD
            );

						let dist = UTILS.distanceToPoint3DV(UTILS.Add33([sphereCoord, Position]), Observer )/radius;
						//( (size/radius)*3000 )
						var n = computeNormalFromNoise(sphereCoord, noise, Math.pow( (size/radius)*3000, 1/(level) ) * 10);
            data.normals.push(n._x, n._y, n._z);

            data.uvs.push(x / detail, 1.0 - y / detail);

						// if (x <= detail-1 && y <= detail-1){
            //     var tWidth = detail;
						//
            //     data.indices.push((x + 1 + (y + 1) * (tWidth + 1)) + indexOffset);
            //     data.indices.push((x + 1 + y * (tWidth + 1)) + indexOffset);
            //     data.indices.push((x + y * (tWidth + 1)) + indexOffset);
						//
            //     data.indices.push((x + (y + 1) * (tWidth + 1)) + indexOffset);
            //     data.indices.push((x + 1 + (y + 1) * (tWidth + 1)) + indexOffset);
            //     data.indices.push((x + y * (tWidth + 1)) + indexOffset);
            // }

        }
    }



		resolveIndices(detail, data, index, indexOffset);



}




// from: https://www.babylonjs-playground.com/#f00M0U#39
function resolveIndices(detail, data, nDat, offset)
{
    for (y = 0; y < detail; y++) {
        for (x = 0; x < detail; x++)
        {
						if(nDat.N && y==0)
            {
                if(!nDat.W && x==0){
                    data.indices.push( (x + (y + 1) * (detail + 1)) + offset);
                    data.indices.push( (x + 1 + (y + 1) * (detail + 1)) + offset);
                    data.indices.push( (x + y * (detail + 1)) + offset);
                }

                data.indices.push( (x + 1 + (y + 1) * (detail + 1)) + offset);
                data.indices.push( (x + 2 + y * (detail + 1)) + offset);
                data.indices.push( (x + y * (detail + 1)) + offset);

                x++;
                if(x<detail-1){
                    data.indices.push( (x + (y+1) * (detail + 1)) + offset);
                    data.indices.push( (x + 1 + (y+1) * (detail + 1)) + offset);
                    data.indices.push( (x + 1 + (y) * (detail + 1)) + offset);

                    data.indices.push( (x + 1 + (y+1) * (detail + 1)) + offset);
                    data.indices.push( (x + 2 + (y+1) * (detail + 1)) + offset);
                    data.indices.push( (x + 1 + (y) * (detail + 1)) + offset);
                }

                if(!nDat.E && x == detail-1){
                    data.indices.push( (x + (y + 1) * (detail + 1)) + offset);
                    data.indices.push( (x + 1 + (y + 1) * (detail + 1)) + offset);
                    data.indices.push( (x + 1 + y * (detail + 1)) + offset);
                }
                continue
            }


            if(nDat.W && x==0)
            {
                if(!nDat.N && y==0){
                    data.indices.push( (x + 1 + (y + 1) * (detail + 1)) + offset);
                    data.indices.push( (x + 1 + y * (detail + 1)) + offset);
                    data.indices.push( (x + y * (detail + 1)) + offset);
                }
                if(nDat.N && y==1){
                    data.indices.push( (x + (y + 1) * (detail + 1)) + offset);
                    data.indices.push( (x + 1 + y * (detail + 1)) + offset);
                    data.indices.push( (x + (y - 1) * (detail + 1)) + offset);
                }
                if(y<detail-1){
                    if(y%2==0){
                        data.indices.push( (x + (y) * (detail + 1)) + offset);
                        data.indices.push( (x + (y+2) * (detail + 1)) + offset);
                        data.indices.push( (x + 1 + (y+1) * (detail + 1)) + offset);
                    }else{
                        data.indices.push( (x + (y+1) * (detail + 1)) + offset);
                        data.indices.push( (x + 1 + (y+1) * (detail + 1)) + offset);
                        data.indices.push( (x + 1 + (y) * (detail + 1)) + offset);

                        data.indices.push( (x + (y+1) * (detail + 1)) + offset);
                        data.indices.push( (x + 1 + (y+2) * (detail + 1)) + offset);
                        data.indices.push( (x + 1 + (y+1) * (detail + 1)) + offset);
                    }
                }
                if(!nDat.S && y== detail-1){
                    data.indices.push( (x + 1 + (y + 1) * (detail + 1)) + offset);
                    data.indices.push( (x + 1 + y * (detail + 1)) + offset);
                    data.indices.push( (x +  (y + 1) * (detail + 1)) + offset);
                }
                continue
            }


            if(nDat.E && x==detail-1)
            {
                if(!nDat.N && y==0){
                    data.indices.push( (x + y * (detail + 1)) + offset);
                    data.indices.push( (x + (y + 1) * (detail + 1)) + offset);
                    data.indices.push( (x + 1 + y * (detail + 1)) + offset);
                }

                if(nDat.N && y==1){
                    data.indices.push( (x + 1 + (y - 1) * (detail + 1)) + offset);
                    data.indices.push( (x + y * (detail + 1)) + offset);
                    data.indices.push( (x + 1 + (y + 1) * (detail + 1)) + offset);
                }

                if(y<detail && y > 0){
                    if(y%2==0){
                    data.indices.push( (x + (y) * (detail + 1)) + offset);
                    data.indices.push( (x + (y+1) * (detail + 1)) + offset);
                    data.indices.push( (x + 1 + (y) * (detail + 1)) + offset);

                    data.indices.push( (x + (y-1) * (detail + 1)) + offset);
                    data.indices.push( (x + (y) * (detail + 1)) + offset);
                    data.indices.push( (x + 1 + (y) * (detail + 1)) + offset);

                    }else{
                        data.indices.push( (x + (y) * (detail + 1)) + offset);
                        data.indices.push( (x + 1 + (y+1) * (detail + 1)) + offset);
                        data.indices.push( (x + 1 + (y-1) * (detail + 1)) + offset);
                    }
                }
                if(!nDat.S && y == detail-1){
                    data.indices.push( (x + (y + 1) * (detail + 1)) + offset);
                    data.indices.push( (x + 1 + (y + 1) * (detail + 1)) + offset);
                    data.indices.push( (x + y * (detail + 1)) + offset);
                }

                if(nDat.S && y == detail-2){
                    data.indices.push( (x  + (y + 1) * (detail + 1)) + offset);
                    data.indices.push( (x + 1 + (y + 2) * (detail + 1)) + offset);
                    data.indices.push( (x + 1 + y * (detail + 1)) + offset);
                }


                continue
            }

            if(nDat.S && y== detail-1 ){
                if(!nDat.W && x==0){
                    data.indices.push( (x + y * (detail + 1)) + offset);
                    data.indices.push( (x + (y + 1) * (detail + 1)) + offset);
                    data.indices.push( (x + 1 + y * (detail + 1)) + offset);
                }

                if(x>0 && x < detail - 1){
                    data.indices.push( (x + 1 + (y + 1) * (detail + 1)) + offset);
                    data.indices.push( (x  + y * (detail + 1)) + offset);
                    data.indices.push( (x - 1 + (y + 1) * (detail + 1)) + offset);
                    x++;

                    data.indices.push( (x  + (y + 1)  * (detail + 1)) + offset);
                    data.indices.push( (x + 1 + y * (detail + 1)) + offset);
                    data.indices.push( (x + y * (detail + 1)) + offset);

                    data.indices.push( (x  + (y + 1)  * (detail + 1)) + offset);
                    data.indices.push( (x + y * (detail + 1)) + offset);
                    data.indices.push( (x - 1 + y * (detail + 1)) + offset);
                }


                if(!nDat.E){
                    if(x == detail-1){
                        data.indices.push( (x + 1 + (y + 1) * (detail + 1)) + offset);
                        data.indices.push( (x + 1 + y * (detail + 1)) + offset);
                        data.indices.push( (x + y * (detail + 1)) + offset);
                    }
                    if(x == detail-2){
                        data.indices.push( (x + 2 + (y + 1) * (detail + 1)) + offset);
                        data.indices.push( (x + 1 + y * (detail + 1)) + offset);
                        data.indices.push( (x + (y + 1) * (detail + 1)) + offset);
                    }
                }

                if(nDat.E){
                    if(x == detail-2){
                        data.indices.push( (x + 2 + (y + 1) * (detail + 1)) + offset);
                        data.indices.push( (x + 1 + y * (detail + 1)) + offset);
                        data.indices.push( (x + (y + 1) * (detail + 1)) + offset);
                    }
                }
                continue
            }

            if(y%2==0){
                //ODD ROW
                if(x%2==0){
                    //ODD COL
                    data.indices.push( (x + 1 + (y + 1) * (detail + 1)) + offset);
                    data.indices.push( (x + 1 + y * (detail + 1)) + offset);
                    data.indices.push( (x + y * (detail + 1)) + offset);

                    data.indices.push( (x + (y + 1) * (detail + 1)) + offset);
                    data.indices.push( (x + 1 + (y + 1) * (detail + 1)) + offset);
                    data.indices.push( (x + y * (detail + 1)) + offset);
                }else{
                    //EVEN COL
                    data.indices.push( (x + y * (detail + 1)) + offset);
                    data.indices.push( (x + (y + 1) * (detail + 1)) + offset);
                    data.indices.push( (x + 1 + y * (detail + 1)) + offset);

                    data.indices.push( (x + (y + 1) * (detail + 1)) + offset);
                    data.indices.push( (x + 1 + (y + 1) * (detail + 1)) + offset);
                    data.indices.push( (x + 1 + y * (detail + 1)) + offset);
                }
            }else{
                //EVEN ROW
                if(x%2==0){
                    //ODD COL
                    data.indices.push( (x + y * (detail + 1)) + offset);
                    data.indices.push( (x + (y + 1) * (detail + 1)) + offset);
                    data.indices.push( (x + 1 + y * (detail + 1)) + offset);

                    data.indices.push( (x + (y + 1) * (detail + 1)) + offset);
                    data.indices.push( (x + 1 + (y + 1) * (detail + 1)) + offset);
                    data.indices.push( (x + 1 + y * (detail + 1)) + offset);
                }else{
                    //EVEN COL
                    data.indices.push( (x + 1 + (y + 1) * (detail + 1)) + offset);
                    data.indices.push( (x + 1 + y * (detail + 1)) + offset);
                    data.indices.push( (x + y * (detail + 1)) + offset);

                    data.indices.push( (x + (y + 1) * (detail + 1)) + offset);
                    data.indices.push( (x + 1 + (y + 1) * (detail + 1)) + offset);
                    data.indices.push( (x + y * (detail + 1)) + offset);
                }
            }
        }
    }
}






function isPointInFrustum(frustumPlanes, point)
{
    for (let i = 0; i < 6; i++) {
        if (UTILS.planeDotCoordinate(frustumPlanes[i], point) < 0) {
						return false;
        }
    }
    return true;
}

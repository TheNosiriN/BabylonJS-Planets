
const PERMUTATION_TABLE_SIZE = 512;
const PERMUTATION_TEXTURE_HEIGHT = 16;
const PERMUTATION_TEXTURE_WIDTH = 32;
const HASH_TEXTURE_WIDTH = 256;
const MAX_LEVELS = 18;


var IcoWorker = new Worker("src/planet/gen/icosahedron/Worker.js");
var IcoWorkerUser = null;

class Planet extends BABYLON.TransformNode
{
	constructor(p, scene)
	{
		super(p.name || "Earth", scene);

		this.position = p.position || new BABYLON.Vector3.Zero();

		this.observer = new BABYLON.Vector3.Zero();
		this.lastCenter = new BABYLON.Vector3.Zero();

    this.radius = p.radius || 10;
    this.maxHeight = p.maxHeight || 0.0025;

		this.birthName = this.position.x + ", " + this.position.y + ", " + this.position.z;
		this.blankSphere = null;
		this.isRunning = false;

		this.seed = p.seed || this.name+"("+this.birthName+")";
		this.seedHash = this.seed.hashCode();
		this.noise = makePermTable(this.seed, PERMUTATION_TABLE_SIZE);

		this.properties = {
			octaves: 5,
			frequency: 10.0,
			amplitude: 1.0,
			roughness: 4.0,
			persistence: 0.4,
		};




		this.material = new BABYLON.ShaderMaterial(this.name, scene, {
				vertex: "IcoPlanet",
				fragment: "IcoPlanet",
		},{
				attributes: ["position"],
				uniforms: [
						"world", "worldView", "worldViewProjection",
						"view", "projection", "viewProjection", "time",
						"cameraPosition", "eyepos", "eyepos_lowpart"
				],
				samplers: [
						"hashTexture", "grassTexture", "rockTexture",
						"permutationTexture"
				]
		});


		this.material.setInt("SEED", this.seedHash);
		this.material.setFloat("radius", this.radius);
		this.material.setFloat("maxHeight", this.maxHeight);

		this.material.setInt("octaves", this.properties.octaves);
		this.material.setFloat("frequency", this.properties.frequency);
		this.material.setFloat("amplitude", this.properties.amplitude);
		this.material.setFloat("roughness", this.properties.roughness);
		this.material.setFloat("persistence", this.properties.persistence);
		this.material.setFloat("warpAmplitude", this.properties.warpAmplitude);
		this.material.setFloat("warpFrequency", this.properties.warpFrequency);

		setFeedbackUniformInt("SEED", this.seedHash);
		setFeedbackUniformFloat("radius", this.radius);
		setFeedbackUniformFloat("maxHeight", this.maxHeight);

		setFeedbackUniformInt("octaves", this.properties.octaves);
		setFeedbackUniformFloat("frequency", this.properties.frequency);
		setFeedbackUniformFloat("amplitude", this.properties.amplitude);
		setFeedbackUniformFloat("roughness", this.properties.roughness);
		setFeedbackUniformFloat("persistence", this.properties.persistence);
		setFeedbackUniformFloat("warpAmplitude", this.properties.warpAmplitude);
		setFeedbackUniformFloat("warpFrequency", this.properties.warpFrequency);


		this.hashTexture = new BABYLON.CustomProceduralTexture(this.name, "Hash", HASH_TEXTURE_WIDTH, scene);
		this.hashTexture.delayLoad();
		this.hashTexture.setInt("SEED", this.seedHash);
		this.material.setTexture("hashTexture", this.hashTexture);



		for (var i=0; i<GRASS_ONE_TEXTURE.length; i++){
			this.material.setTexture("grassTexture["+i+"]", GRASS_ONE_TEXTURE[i]);
			this.material.setTexture("rockTexture["+i+"]", ROCK_ONE_TEXTURE[i]);
		}


		this.permutationTexture = new BABYLON.RawTexture(
			this.noise.perm, PERMUTATION_TEXTURE_WIDTH, PERMUTATION_TEXTURE_HEIGHT,
			BABYLON.Engine.TEXTUREFORMAT_R, scene, false, false,
      BABYLON.Texture.LINEAR_LINEAR, BABYLON.Engine.TEXTURETYPE_UNSIGNED_BYTE
		);
		this.material.setTexture("permutationTexture", this.permutationTexture);



		this.hashTexture.onGeneratedObservable.addOnce(function()
		{
			this.createPlanet();
			this.hashTexture.isEnabled = false;
		}.bind(this));

	}


	createBlankSphere()
	{
		this.blankSphere = BABYLON.MeshBuilder.CreateSphere("blank", {diameter: this.radius*2, segments: 32}, this.getScene());
		this.blankSphere.material = this.material;
		this.blankSphere.material.zOffset = 2;
		this.blankSphere.parent = this;
	}


	createPlanet()
	{
		// this.isRunning = true;
		// useDedicatedIcosahedronWorker(this, this.getScene());
		this.checkIfRunning();
		console.log(this.name+"-("+this.birthName+") was created");
	}
	updatePlanet()
	{
		this.checkIfRunning();
	}


	checkIfRunning()
	{
		if (UTILS.distanceToPoint3DV(this.position, this.lastCenter) < 2){
			this.isRunning = true;
			if (IcoWorkerUser != null && IcoWorkerUser != this){
				IcoWorkerUser.isRunning = false;
				IcoWorkerUser.checkIfRunning();
				IcoWorkerUser = null;
			}
		}else{
			this.isRunning = false;
			// console.log("not running");
		}

		if (this.isRunning == false){
			if (this.blankSphere == null){
				if (this.mesh != null){ this.mesh.dispose(); }
				this.mesh = null;
				IcoWorkerUser = null;
				this.createBlankSphere();
			}
		}else{
			if (IcoWorkerUser == null) {
				if (this.blankSphere != null){ this.blankSphere.dispose(); }
				if (this.mesh != null){ this.mesh.dispose(); }
				this.blankSphere = null;
				this.mesh = null;
				useDedicatedIcosahedronWorker(this, this.getScene());
			}
		}
	}


	setObserver(obs)
	{
		this.observer = obs.clone();

		obs = obs.subtract(this.getAbsolutePosition());
    obs = obs.divide(new BABYLON.Vector3().setAll(this.radius));

    if (this.lastCenter.equals(obs)){ return; }
    this.lastCenter = obs.clone();
	}

	setPosition(pos)
	{
		this.position = pos.clone();

		var v = this.getAbsolutePosition().multiply(new BABYLON.Vector3(-1,-1,-1));
		var dX = UTILS.SplitDouble(v.x), dY = UTILS.SplitDouble(v.y), dZ = UTILS.SplitDouble(v.z);

		if (this.material != null){
			this.material.setVector3("eyepos", new BABYLON.Vector3(dX[0], dY[0], dZ[0]) );
			this.material.setVector3("eyepos_lowpart", new BABYLON.Vector3(dX[1], dY[1], dZ[1]) );
		}
	}

	setLightDirection(direction)
	{
		if (planet.material != null){
        planet.material.setVector3("lightDir", direction);
    }
	}

	setWireframe(bool)
	{
		if (this.material != null){
			this.material.wireframe = bool;
		}
	}
}










var IN_TRANSFORM_BUFFER = null;
var OUT_TRANSFORM_BUFFER = null;
var FEEDBACK_TRANSFORM_BUFFER = null;
function setFeedbackUniformInt(name, value){ COMP_GL.uniform1i(COMP_GL.getUniformLocation(COMP_GL_PROGRAM, name), value); }
function setFeedbackUniformFloat(name, value){ COMP_GL.uniform1f(COMP_GL.getUniformLocation(COMP_GL_PROGRAM, name), value); }

function useTransformFeedback(gl, dataIn, dataOut, planet)
{
	const VERTEX_COUNT = dataIn.length;
	gl.useProgram(COMP_GL_PROGRAM);
	gl.enable(gl.RASTERIZER_DISCARD);

	//input
  //let inputBuffer = gl.createBuffer();
	if (IN_TRANSFORM_BUFFER == null){ IN_TRANSFORM_BUFFER = gl.createBuffer(); }
  gl.bindBuffer(gl.ARRAY_BUFFER, IN_TRANSFORM_BUFFER);
  gl.bufferData(gl.ARRAY_BUFFER, dataIn, gl.STATIC_DRAW);

  //output
  //let resultBuffer = gl.createBuffer();
	if (OUT_TRANSFORM_BUFFER == null){ OUT_TRANSFORM_BUFFER = gl.createBuffer(); }

  // Create a TransformFeedback object
  //var transformFeedback = gl.createTransformFeedback();
	if (FEEDBACK_TRANSFORM_BUFFER == null){ FEEDBACK_TRANSFORM_BUFFER = gl.createTransformFeedback(); }
  gl.bindTransformFeedback(gl.TRANSFORM_FEEDBACK, FEEDBACK_TRANSFORM_BUFFER);

  gl.bindBufferBase(gl.TRANSFORM_FEEDBACK_BUFFER, 0, OUT_TRANSFORM_BUFFER);
  gl.bufferData(gl.TRANSFORM_FEEDBACK_BUFFER, VERTEX_COUNT * Float32Array.BYTES_PER_ELEMENT, gl.STATIC_DRAW);


  // Attribute position
  const inputAttribLocation = gl.getAttribLocation(COMP_GL_PROGRAM, 'position');

  gl.enableVertexAttribArray(inputAttribLocation);
  gl.bindBuffer(gl.ARRAY_BUFFER, IN_TRANSFORM_BUFFER);
  gl.vertexAttribPointer(
      inputAttribLocation, // index
      3, // size
      gl.FLOAT, // type
      gl.FALSE, // normalized?
      0, // stride
      0 // offset
  );


  // Activate the transform feedback
  gl.beginTransformFeedback(gl.POINTS);
  gl.drawArrays(gl.POINTS, 0, Math.floor(VERTEX_COUNT/3));
  gl.endTransformFeedback();


  // Read back
  gl.getBufferSubData(
      gl.TRANSFORM_FEEDBACK_BUFFER, // target
      0, // srcByteOffset
      dataOut, // dstData
  );

	gl.disable(gl.RASTERIZER_DISCARD);
}











function useDedicatedIcosahedronWorker(planet, scene)
{
	IcoWorkerUser = planet;

	function makeMesh(meshData){
			if (IcoWorkerUser.mesh == null){
				IcoWorkerUser.mesh = new BABYLON.Mesh("t", scene);
				IcoWorkerUser.mesh.material = IcoWorkerUser.material;
				IcoWorkerUser.mesh.parent = IcoWorkerUser;
			}
			if (meshData.vertices.length > 0){
				useTransformFeedback(COMP_GL, meshData.vertices, meshData.vertices, IcoWorkerUser);
				IcoWorkerUser.mesh.setVerticesData(BABYLON.VertexBuffer.PositionKind, meshData.vertices);
				IcoWorkerUser.mesh.setIndices(meshData.indices, null, false);
			}
	}




	function sendToWorker(state){
			switch (state)
		  {
		      case 0:
		          IcoWorker.postMessage({
		              state: state,
									seed: IcoWorkerUser.seed,
									properties: IcoWorkerUser.properties,
									hashTexture: UTILS.getTextureData(IcoWorkerUser.hashTexture)
		          });
		      break;

		      case 1:
							// let prev = scene.activeCamera.fov;
							// scene.activeCamera.fov = UTILS.degrees_to_radians(180);
							// scene.updateTransformMatrix();
		          // let frustumplanes = BABYLON.Frustum.GetPlanes(scene.getTransformMatrix());
							// scene.activeCamera.fov = prev;

		          IcoWorker.postMessage({
		              state: state,
		              center: IcoWorkerUser.lastCenter,
		              radius: IcoWorkerUser.radius,
		              maxHeight: IcoWorkerUser.maxHeight,
		              position: IcoWorkerUser.position,
		              //frustumplanes: frustumplanes,
									direction: scene.activeCamera.getForwardRay(1).direction
		              // windowWidth: IcoWorkerUser.getScene().activeCamera.viewport.width,
		              // windowHeight: IcoWorkerUser.getScene().activeCamera.viewport.height
		          });
		      break;
		  }
	}


	sendToWorker(0);

  IcoWorker.onmessage = function(e)
  {
      switch (e.data.state)
      {
					case 0:
							// use retained version of planet and not the updated version
							if (planet.isRunning){ sendToWorker(1); }
					break;

					case 1:
							if (planet.isRunning){
								makeMesh(e.data.data);

								debug({
									vertexCount: e.data.data.vertices.length/3,
									currentLevel: e.data.level
								});

	              sendToWorker(1);
							}
          break;
      }
  }
}












var vertCount = document.getElementById("vertCount");
var level = document.getElementById("level");
function debug(p)
{
	vertCount.innerHTML = "Vertex Count: "+p.vertexCount;
	level.innerHTML = "Current Level: "+p.currentLevel;
}

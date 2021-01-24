
(window.oldWorkers || []).forEach(w => w.terminate());
UTILS.clearAllTimeoutsAndIntervals();





const RENDER_WIDTH = 0;//1920;
const RENDER_HEIGHT = 0;//1080;




var game = {
	engine: new BABYLON.Engine(canvas, false, {
		// useHighPrecisionMatrix: true,
		// useHighPrecisionFloats: true
	}),
	delta: 0,
	objects: {},
	mouseDX: 0,
	mouseDY: 0
}


function preload()
{
	//console.log(window.navigator.hardwareConcurrency);
	game.dsm = new BABYLON.DeviceSourceManager(game.engine);

}



var postProcessEffect;
var depthRenderer;
function postload()
{
	depthRenderer = game.scene.enableDepthRenderer(game.camera, false, true);

	postProcessEffect = new BABYLON.PostProcess(
      "SOCA",
      "PostProcess",
      [
					"warpFrequency",
	        "TIME", "lightDir",
					"octaves", "frequency",
	        "screenSize", "RADIUS",
					"amplitude", "roughness",
	        "camera.far", "camera.near",
	        "camera.world", "camera.view",
					"persistence", "warpAmplitude",
	        "camera.projection", "camera.transform",
	        "camera.position", "camera.direction", "camera.fov",
					"planet.radius", "planet.position", "planet.maxHeight"
      ], [
					"single_mie_scattering_texture",
					"transmittance_texture",
					"permutationTexture",
					"irradiance_texture",
					"scattering_texture",
					"depthMap"
			], 1.0, game.camera, 0, game.engine, false,
			`
					#define assert(x)
					#define TEMPLATE(x)
					#define TEMPLATE_ARGUMENT(x)
					#define RADIANCE_API_ENABLED
					#define COMBINED_SCATTERING_TEXTURES
			`
  );
	postProcessEffect.renderTargetSamplingMode = BABYLON.Texture.NEAREST_LINEAR_MIPLINEAR


  postProcessEffect.onApply = function(effect)
  {
      effect.setFloat("TIME", game.time);

      effect.setFloat("planet.radius", planet.radius);
			effect.setFloat("planet.maxHeight", planet.maxHeight);
			effect.setVector3("planet.position", planet.getAbsolutePosition());

			effect.setInt("octaves", planet.properties.octaves);
			effect.setFloat("frequency", planet.properties.frequency);
			effect.setFloat("amplitude", planet.properties.amplitude);
			effect.setFloat("roughness", planet.properties.roughness);
			effect.setFloat("persistence", planet.properties.persistence);
			effect.setFloat("warpAmplitude", planet.properties.warpAmplitude);
			effect.setFloat("warpFrequency", planet.properties.warpFrequency);

			effect.setVector3("lightDir", light.direction.multiply(new BABYLON.Vector3(-1,-1,-1)));

      effect.setTexture("depthMap", depthRenderer.getDepthMap());

      effect.setVector2("screenSize", new BABYLON.Vector2(postProcessEffect.width, postProcessEffect.height));

      //effect.setVector3("camera.position", game.universeNode.getAbsolutePosition().multiply(new BABYLON.Vector3(-1,-1,-1)));
			effect.setVector3("camera.position", game.scene.activeCamera.globalPosition);
      effect.setVector3("camera.direction", game.scene.activeCamera.getForwardRay(1).direction);

      effect.setFloat("camera.fov", game.camera.fov);
      effect.setFloat("camera.far", game.camera.maxZ);
      effect.setFloat("camera.near", game.camera.minZ);

      effect.setMatrix('camera.view', game.scene.activeCamera.getViewMatrix());
      effect.setMatrix('camera.projection', game.scene.activeCamera.getProjectionMatrix());
      effect.setMatrix('camera.world', game.scene.activeCamera.getWorldMatrix());
      effect.setMatrix('camera.transform', game.scene.activeCamera.getTransformationMatrix());

			effect.setTexture("irradiance_texture", IRRADIANCE_TEXTURE);
			effect.setTexture("scattering_texture", SCATTERING_TEXTURE);
			effect.setTexture("transmittance_texture", TRANSMITTANCE_TEXTURE);
			effect.setTexture("single_mie_scattering_texture", SINGLE_MIE_SCATTERING_TEXTURE);
			effect.setTexture("permutationTexture", planet.permutationTexture);
  }
}










var box, observer;
var planet;
var light;
var sun;

function create()
{
	game.time = 0.0;

	game.universeNode = new BABYLON.TransformNode();



	//game.camera = new BABYLON.ArcRotateCamera("camera", BABYLON.Tools.ToRadians(90), BABYLON.Tools.ToRadians(65), 30, BABYLON.Vector3.Zero(), game.scene);
	game.camera = new BABYLON.FreeCamera("camera", new BABYLON.Vector3(0,0,0), game.scene);
	game.camera.attachControl(canvas, true);

	// game.camera = new BABYLON.UniversalCamera("camera", new BABYLON.Vector3.Zero(), game.scene);
  // game.camera.inputs.clear();

	//game.scene.render();

	game.camera.minZ = 0.01;
	game.camera.maxZ = 7000000;


	planet = new Planet({
		name: "Earth",
		position: new BABYLON.Vector3(0,0,0),
		radius: 1000//100000//6371000
	}, game.scene);


	light = new BABYLON.DirectionalLight("dirLight", BABYLON.Vector3.Normalize(new BABYLON.Vector3(0, -0.1, -1.0)), game.scene);
	light.intensity = 0.7;

	//sun properties
  sun = BABYLON.MeshBuilder.CreateDisc("sun", {radius: planet.radius/4.0, arc: 1, tessellation: 64, sideOrientation: BABYLON.Mesh.DEFAULTSIDE}, game.scene);
  sun.infiniteDistance = true;
  sun.billboardMode = BABYLON.Mesh.BILLBOARDMODE_ALL;
  var sunMat = new BABYLON.StandardMaterial("sun", game.scene);
	sunMat.emissiveColor = new BABYLON.Color3(100, 100, 100);
  sunMat.disableLighting = true;
  sun.material = sunMat;


	let ll = new BABYLON.PointLight("sunLight", sun.position, game.scene);
	ll.parent = sun;




	box = BABYLON.MeshBuilder.CreateBox("box", {size: 1}, game.scene);
	box.position = new BABYLON.Vector3(0, 0, 7);
	observer = new BABYLON.Vector3(0,0,0);



	//planet.parent = game.universeNode;

	document.getElementById("wireframe").onclick = function(){
		planet.material.wireframe = !planet.material.wireframe;
	};

	// observer = UTILS.sphericalToVector(planet.radius, theta, phi, true);
	// planet.position = observer.multiply(new BABYLON.Vector3(-1,-1,-1));

	game.camera.position = UTILS.sphericalToVector(planet.radius*1.001, theta, phi, true);//1.051
	box.position = game.camera.position.clone();

	planet.setObserver( new BABYLON.Vector3(0,0,0) );


	transform = new BABYLON.TransformNode("p");
 	transform2 = new BABYLON.TransformNode("hh");

  transform2.parent = transform;
  transform2.position.z = -planet.radius*10.0;
	transform2.position.y = -planet.radius;

	transform.rotation.y += 0.16;
}







let divFps = document.getElementById("fps");
let cameraInfo = document.getElementById("cameraInfo");
var startRecording = false;
var keyboard = null;
const timeSpeed = 0.01;
var phi=90, theta=90;

var transform;
var transform2;
function step()
{
	game.time += timeSpeed;
	game.delta = game.engine.getDeltaTime();
	divFps.innerHTML = "|  "+game.engine.getFps().toFixed() + " fps  |";

	//cameraInfo.innerHTML = "pos: "+(game.camera.position)+"\ndir: "+(game.camera.getDirection(new BABYLON.Vector3.Up()));



	// transform.rotation.y = (transform.rotation.y + 0.0015) % (Math.PI*2);
	// transform.rotation.x = (transform.rotation.x + 0.0015) % (Math.PI*2);

	light.setDirectionToTarget(transform2.getAbsolutePosition());
	sun.position = light.direction.multiply(new BABYLON.Vector3().setAll(-planet.radius*50));

	//updateCamera();
	//updateUniverseNode();


	// observer = UTILS.sphericalToVector(planet.radius, theta, phi, true);
	// planet.position = observer.multiply(new BABYLON.Vector3(-1,-1,-1));
	//
	// theta = (theta + 1/planet.radius) % 360;
	// phi = (phi + 1/planet.radius) % 360;


	// game.camera.upVector = UTILS.lerp3(
	// 	game.camera.upVector, UTILS.sphereNormal(new BABYLON.Vector3(0,0,0).subtract(planet.getAbsolutePosition())),
	// 	1-UTILS.clamp(UTILS.remap(
	// 		UTILS.distanceToPoint3DV(planet.getAbsolutePosition(), new BABYLON.Vector3(0,0,0)),
	// 		planet.radius*1.5, planet.radius*3, 0, 1
	// 	), 0, 1)
	// );


	// box.alignWithNormal(UTILS.toPlanetUp(box.up, box.getAbsolutePosition(), observer, planet));
	// game.camera.upVector = box.up;

	//planet.setPosition(game.universeNode.position);
	planet.setObserver( game.scene.activeCamera.globalPosition );
	planet.setLightDirection(light.direction.multiply(new BABYLON.Vector3(-1,-1,-1)));
	planet.updatePlanet();

}





function updateUniverseNode()
{
	game.universeNode.position = game.universeNode.position.subtract(game.camera.position);
	game.camera.position = new BABYLON.Vector3(0,0,0);
}



var mouseSensitivity = 0.005;
var cameraSpeed = 0.0075;
var mouseMin = -75, mouseMax = 90;

var mouseX = 0, mouseY = 0;
function updateCamera()
{
		mouseX += game.mouseDX * mouseSensitivity * game.delta;
		mouseY += game.mouseDY * mouseSensitivity * game.delta;
		mouseY = UTILS.clamp(mouseY, mouseMin, mouseMax);

		game.camera.rotation = UTILS.lerp3(
        game.camera.rotation,
        new BABYLON.Vector3(
            BABYLON.Tools.ToRadians(mouseY),
            BABYLON.Tools.ToRadians(mouseX), 0
        ), cameraSpeed*game.delta
    );
}









window.addEventListener("DOMContentLoaded", function(){
    game.canvas = document.getElementById("canvas");
		game.engine.setSize(RENDER_WIDTH > 0 ? RENDER_WIDTH : window.innerWidth, RENDER_HEIGHT > 0 ? RENDER_HEIGHT : window.innerHeight);

    game.scene = new BABYLON.Scene(game.engine);
    game.scene.clearColor = new BABYLON.Color3.Black();

		loadResources(function()
		{
			preload();
	    create();
			postload();

			setupPointerLock();
	    // game.scene.detachControl();

	    game.scene.registerBeforeRender(function(){
					step();

					game.mouseDX = 0;
					game.mouseDY = 0;
	    });


			game.scene.registerAfterRender(function(){
					// postStep();
			});


			game.engine.runRenderLoop(function(){
	        game.scene.render();
	    });
		}, game.scene);
});

// the canvas/window resize event handler
window.addEventListener('resize', function(){
    game.engine.setSize(RENDER_WIDTH > 0 ? RENDER_WIDTH : window.innerWidth, RENDER_HEIGHT > 0 ? RENDER_HEIGHT : window.innerHeight);
});





//mouse lock
// Configure all the pointer lock stuff
function setupPointerLock()
{
    // register the callback when a pointerlock event occurs
    document.addEventListener('pointerlockchange', changeCallback, false);
    document.addEventListener('mozpointerlockchange', changeCallback, false);
    document.addEventListener('webkitpointerlockchange', changeCallback, false);

    // when element is clicked, we're going to request a
    // pointerlock
    canvas.onclick = function(){
        canvas.requestPointerLock =
            canvas.requestPointerLock ||
            canvas.mozRequestPointerLock ||
            canvas.webkitRequestPointerLock
        ;

        // Ask the browser to lock the pointer)
        canvas.requestPointerLock();
    };

}

var mouseMove = function(e)
{
    var movementX = e.movementX ||
            e.mozMovementX ||
            e.webkitMovementX ||
            0;

    var movementY = e.movementY ||
            e.mozMovementY ||
            e.webkitMovementY ||
            0;

		game.mouseDX = movementX;
		game.mouseDY = movementY;


		//updateCamera();
}

// called when the pointer lock has changed. Here we check whether the
// pointerlock was initiated on the element we want.
function changeCallback(e)
{
    if (document.pointerLockElement === canvas ||
        document.mozPointerLockElement === canvas ||
        document.webkitPointerLockElement === canvas
    ){
        // we've got a pointerlock for our element, add a mouselistener
        document.addEventListener("mousemove", mouseMove, false);
    } else {
        // pointer lock is no longer active, remove the callback
        document.removeEventListener("mousemove", mouseMove, false);
    }
};










// new test
// https://playground.babylonjs.com/#ACS28V#11
// https://playground.babylonjs.com/#76KW28#5

//shader
// https://cyos.babylonjs.com/#LP6PKE#4
// https://www.babylonjs-playground.com/#J8TKE6#17

// tps
// https://www.babylonjs-playground.com/#G703DZ#87


//planet shader
// https://playground.babylonjs.com/#H7SXJ7#23 //custom pbr
// https://cyos.babylonjs.com/#49TTWL#3
// https://cyos.babylonjs.com/#GV5MFS //atmospheric scattering 1
// https://cyos.babylonjs.com/#GV5MFS#9 //atmospheric scattering 2
// https://playground.babylonjs.com/#LY3FVX#4 atm scattering

// https://cyos.babylonjs.com/#74KX30

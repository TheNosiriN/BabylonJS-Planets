
const EPSILON = 0.01;


class CinematicCamera extends BABYLON.TargetCamera
{
	constructor(name, scene)
	{
		super(name, new BABYLON.Vector3(0,0,0), scene);
		// this.setTarget(new BABYLON.Vector3(0,0,0));

		this.path = null;
		this.pathDistance = 0;
	}

	setPoints(points, resolution, up)
	{
		let curve = BABYLON.Curve3.CreateCatmullRomSpline(points, resolution, false);
		this.path = new BABYLON.Path3D(curve.getPoints(), up);
		this.Increment(0);
	}

	Increment(speed)
	{
		if (this.path != null){
			let normal = this.path.getNormalAt(this.pathDistance, true);
			let tangent = this.path.getTangentAt(this.pathDistance, true);
			let binormal = this.path.getBinormalAt(this.pathDistance, true);

			this.position = this.path.getPointAt(this.pathDistance);
			// this.rotation = BABYLON.Vector3.RotationFromAxis(binormal, normal, tangent); //correct
			// this.rotation = BABYLON.Vector3.RotationFromAxis(tangent, normal, binormal);
			// this.upVector = normal;
			this.setTarget(this.path.getPointAt(UTILS.clamp(this.pathDistance+EPSILON, 0, 1)));

			this.pathDistance += speed;
			this.pathDistance = Math.min(Math.max(this.pathDistance, 0.0), 1.0-EPSILON);
		}
	}
}


BABYLON.CinematicCamera = CinematicCamera;

 #version 130 
uniform vec4 eye;
uniform vec4 ambient;
uniform vec4[20] objects;
uniform vec4[20] objColors;
uniform vec4[10] lightsDirection;
uniform vec4[10] lightsIntensity;
uniform vec4[10] lightsPosition;
uniform ivec4 sizes; //{number of objects , number of lights , width, hight}  

in vec3 position1; //Pixels in the picture

vec3 calc_intersection_with_plane(vec3 sourcePoint, vec3 v, vec4 plane){
	vec3 point_on_plane;
	vec3 norm_v = normalize(v);
	vec3 norm_plane = normalize(plane.xyz);
	if (plane.z != 0){
		point_on_plane = vec3(0, 0, -plane.w/norm_plane.z);	
	} else if (plane.y != 0){
		point_on_plane = vec3(0, -plane.w/norm_plane.y, 0);	
	} else if (plane.x != 0){
		point_on_plane = vec3(-plane.w/norm_plane.x, 0, 0);
	} else {
		if (plane.w == 0){
			point_on_plane = vec3(0, 0, 0);
		} 
		//Add a case if a plane is illegal
	}
	vec3 Q0P0 = (point_on_plane - sourcePoint)/dot(norm_v, norm_plane);
	float t = dot(norm_plane, Q0P0);
	vec3 intersection_point = sourcePoint + t*norm_v;
	if (point_on_plane.xyz == vec3(-10, -10, -10)){
		intersection_point = vec3(-10, -10, -10);
	}
	return (intersection_point);									
}

vec3 calc_intersection_with_sphere(vec3 sourcePoint, vec3 v, vec4 sphere){
	float t1,t2, sol;
	vec3 norm_v = normalize(v);
	float a = 1.0;
	float b = dot(2*norm_v, (sourcePoint - sphere.xyz));
	float c = pow(length(sourcePoint - sphere.xyz), 2) - pow(sphere.w, 2);
	float b24ac = pow(b, 2) - 4*a*c;
	b24ac = sqrt(b24ac);
	t1 = (-b + b24ac)/(2*a);
	t2 = (-b - b24ac)/(2*a);
	if (t1 < 0){
		if (t2 < 0){
			sol = 500000000;
		}
		else {
			sol = t2;
		}
	} else {
		if (t2 < 0){
			sol = t1;
		}
		else {
			sol = (t1 > t2) ? t2 : t1;
		}
	}
	return (sourcePoint + norm_v*sol);
}

vec4 intersection(vec3 sourcePoint, vec3 v)
{
	float min_dist = 10; //dist is 1-0.
	vec3 intersection_point = vec3(0);
	vec4 index_and_intersection = vec4(0);
	int index_of_obj = -1;
	for(int i = 0; i < sizes[0]; i++){ //Iterate through objects to find the min intersection.
		if (objects[i].w < 0){
			//plane
			intersection_point = calc_intersection_with_plane(sourcePoint, v,objects[i]);
		} else {
			//sphere
			intersection_point = calc_intersection_with_sphere(sourcePoint, v, objects[i]);
		//	if (distance(intersection_point, objects[i].xyz) - objects[i].w > 0.0001){ //If distance is greater than the radius
			//	intersection_point = vec3(-10, -10, -10);
			//}
		}
		if (intersection_point != vec3(-10, -10, -10) && distance(sourcePoint, intersection_point) < min_dist){
			min_dist = distance(sourcePoint, intersection_point);
			index_and_intersection = vec4(i, intersection_point);
		}
	}
	return index_and_intersection;
}

vec4 draw_plane(vec3 intersection_point, vec4 plane, int index){
	vec4 ret_vec  = objColors[index];
	if ((intersection_point.x < 0 && intersection_point.y > 0) || 
		(intersection_point.x > 0 && intersection_point.y < 0)){
		if ((mod(int(1.5*intersection_point.x),2) != mod(int(1.5*intersection_point.y),2)) ){
			ret_vec	*= 0.5; //Change this with the lights.
		}
	}
	else if ((mod(int(1.5*intersection_point.x),2) == mod(int(1.5*intersection_point.y),2)) ){
		ret_vec	*= 0.5;
	}
	return ret_vec;
}






vec4 colorCalc( vec4 intersectionPoint, vec4 K_A)
{

	float S_I = 1;
	vec3 normal = normalize(intersectionPoint.yzw - objects[int(intersectionPoint)].xyz); //a normal to the sphere, i only incorporated colorCalc to spheres as of now, will probably need to recieve normal as a parameter for generalization with planes
    vec4 color = vec4(0);
	vec4 I_E = vec4(0);
	//vec3 K_S = vec3(0.7);
	vec4 I_D = vec4(0); //diffusion shit from equation
	color +=K_A; //I = I_E + K_A*I_A
	for (int i = 0; i < sizes[1]; i++){
		S_I = 1;
		if(intersection(intersectionPoint.yzw,(lightsPosition[i].xyz - intersectionPoint.yzw)) == vec4(0)){ //this is the shadow part, wasnt sure how to check if there is intersection so it doesnt work
		S_I = 0;
		}
		I_D.x += K_A.x*(dot(normal,(-normalize(-lightsPosition[i].xyz + intersectionPoint.xyz)))*(lightsIntensity[i].x)); //sigma for each color component
		//       ^^^ - from Tamir's instruction as viewed in the document, i assumed K_D from the formula is K_D, if you think its wrong change it.
		I_D.y += K_A.y*(dot(normal,(-normalize(-lightsPosition[i].xyz + intersectionPoint.xyz)))*(lightsIntensity[i].y));
		I_D.z += K_A.z*(dot(normal,(-normalize(-lightsPosition[i].xyz + intersectionPoint.xyz)))*(lightsIntensity[i].z));
		I_D.w += K_A.w*(dot(normal,(-normalize(-lightsPosition[i].xyz + intersectionPoint.xyz)))*(lightsIntensity[i].w));

	}
	if(S_I == 0)
	{return vec4(0);} // an if that proves that the if in line 122 doesnt work, also used for testing it
	color += I_D*S_I;
    return color;
}

/*
	find intersection -> meaning that we will want to find the relevent pixel affiliated with a specific shape.
	find color -> according to phong model.
	draw the thing.
*/

void main()
{	
	vec4 color = vec4(0);
	vec4 intersection_index_point = intersection(eye.xyz, position1 - eye.xyz);
	if (objects[int(intersection_index_point.x)].w < 0){
		color = draw_plane(intersection_index_point.yzw, 
			objects[int(intersection_index_point.x)], 
				int(intersection_index_point.x));
	}
	else {
		color = colorCalc(intersection_index_point,  objColors[int(intersection_index_point.x)]);
	}
	gl_FragColor = color;
}
 


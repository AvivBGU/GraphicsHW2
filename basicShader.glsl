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
const float FPI_PRECISION = 0.0001;

vec4 calc_intersection_with_plane(vec3 sourcePoint, vec3 direction, vec4 plane){
	vec3 point_on_plane;
	vec3 norm_direction = normalize(direction);
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
	vec3 Q0P0 = (point_on_plane - sourcePoint)/dot(norm_direction, norm_plane);
	float t = dot(norm_plane, Q0P0);
	vec4 intersection_point = vec4(sourcePoint + t*norm_direction, 0);
	if (t <= FPI_PRECISION){
		intersection_point = vec4(0,0,0,-1);
	}
	return (intersection_point);									
}

vec4 calc_intersection_with_sphere(vec3 sourcePoint, vec3 direction, vec4 sphere){
	float t1,t2, sol;
	vec3 norm_direction = normalize(direction);
	vec4 returned_point = vec4(0,0,0,-1);
	float a = 1.0;
	float b = dot(2*norm_direction, (sourcePoint - sphere.xyz));
	float c = pow(length(sourcePoint - sphere.xyz), 2) - pow(sphere.w, 2);
	float b24ac = pow(b, 2) - 4*a*c;
	b24ac = sqrt(b24ac);
	t1 = (-b + b24ac)/(2*a);
	t2 = (-b - b24ac)/(2*a);
	if (t1 < 0){
		if (t2 < 0){
			return returned_point;
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
	if (sol <= FPI_PRECISION){
			return returned_point;
		}
	returned_point.xyz = sourcePoint + norm_direction*sol;
	if (!(distance(returned_point.xyz, sphere.xyz) - sphere.w >= 0.0001)){
		returned_point.w = 0;
	}
	return returned_point;
}

vec4 intersection(vec3 sourcePoint, vec3 v, int index) {
	float min_dist = 100000; //dist is 1-0.
	vec4 intersection_point = vec4(0);
	vec4 intersection_and_index = vec4(0,0,0,-1);
	int index_of_obj = -1;
	for(int i = 0; i < sizes[0]; i++){ //Iterate through objects to find the min intersection.
		if (objects[i].w < 0){
			//plane
			intersection_point = calc_intersection_with_plane(sourcePoint, v,objects[i]);
		} else {
			//sphere
			intersection_point = calc_intersection_with_sphere(sourcePoint, v, objects[i]);
		}
		if (intersection_point.w != -1 && distance(sourcePoint, intersection_point.xyz) < min_dist){
			min_dist = distance(sourcePoint, intersection_point.xyz);
			intersection_and_index = vec4(intersection_point.xyz, i);
		}
	}
	return intersection_and_index;
}

vec3 colorCalc(vec4 view_point,  vec4 intersectionPoint, vec3 K_A, int recursion_counter) {
	float S_I = 1;
	int positional_light_index = 0;
	vec3 color = vec3(0);
	vec3 I_E = vec3(0);
	vec3 Sigma = vec3(0); 
	vec3 Temp_Sigma = vec3(0);
	vec3 K_S = vec3(0.7, 0.7, 0.7);
	vec3 L_vec_to_light = vec3(0);
	vec3 R_reflected = vec3(0);
	vec3 normal = vec3(0);
	vec3 K_D = vec3(K_A);
	float DL_positional_light_calc = 0;
	if (objects[int(intersectionPoint.w)].w > 0){
		normal = normalize(intersectionPoint.xyz - objects[int(intersectionPoint.w)].xyz);
	} else { //A plane
		normal = -normalize(objects[int(intersectionPoint.w)].xyz);
		
		if ((intersectionPoint.x < 0 && intersectionPoint.y > 0) || (intersectionPoint.x > 0 && intersectionPoint.y < 0)){
			if ((mod(int(1.5*intersectionPoint.x),2) != mod(int(1.5*intersectionPoint.y),2)) ){
				K_D *= 0.5;
			} 
		}   else if ((mod(int(1.5*intersectionPoint.x),2) == mod(int(1.5*intersectionPoint.y),2)) ){
				K_D *= 0.5;
			}
	} //Calculate normal to a plane.

	color += I_E + K_A*ambient.xyz; //I = I_E + K_A*I_A
	for (int i = 0; i < sizes[1]; i++){
		S_I = 1.0;
		if (lightsDirection[i].w != 0.0){ //Checks if the light is positional or sun-like
			L_vec_to_light = normalize(lightsPosition[positional_light_index].xyz - intersectionPoint.xyz);
			if (dot(normalize(lightsDirection[i].xyz), -L_vec_to_light) <= lightsPosition[positional_light_index++].w){
				S_I = 0;
			} else {} //Check if the spot is in the cone of the spotlight. BETA
			
		} else {
			L_vec_to_light = -normalize(lightsDirection[i].xyz);
		}
		
		//Checks if a given point is obstructed.
		vec4 intersection_check = intersection(intersectionPoint.xyz, L_vec_to_light, int(intersectionPoint.w));
		if (intersection_check.w  > -1){
			S_I = 0;
		}
		
		Temp_Sigma += clamp(K_D*(dot(normal, L_vec_to_light)), 0, 1);
		R_reflected = normalize(reflect(L_vec_to_light, normal));
		Temp_Sigma += clamp(K_S*(pow(dot(normalize(intersectionPoint.xyz-view_point.xyz), R_reflected), 
						objColors[int(intersectionPoint.w)].w)), 0, 1);
		Temp_Sigma *= lightsIntensity[i].xyz;
		Temp_Sigma *= S_I;
		Sigma += clamp(Temp_Sigma,0 ,1);
	}
	color += clamp(Sigma, 0, 1);
    return clamp(color, 0, 1);
}

vec3 recursive_colorCalc(vec4 view_point,  vec4 intersectionPoint, vec3 K_A, int recursion_counter){
	if (recursion_counter > 5){
		return vec3(0);
	} else {
		return colorCalc(view_point, intersectionPoint, K_A, recursion_counter++);
	}
}

void main()
{	
	vec3 color = vec3(0);
	vec4 intersection_index_point = intersection(eye.xyz, position1 - eye.xyz, -1);
	color = colorCalc(eye, intersection_index_point,  objColors[int(intersection_index_point.w)].xyz, 0);
	gl_FragColor = vec4(color, 1);
}
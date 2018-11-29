 #version 130 
uniform vec4 eye;
uniform vec4 ambient;
uniform vec4[20] objects;
uniform vec4[20] objColors;
uniform vec4[10] lightsDirection;
uniform vec4[10] lightsIntensity;
uniform vec4[10] lightsPosition;
uniform ivec4 sizes; //{number of objects , number of lights , num of reflective objects, hight}  
uniform vec4[10] objReflective;

in vec3 position1; //Pixels in the picture
const float FPI_PRECISION = 0.001;
vec3 recursive_colorCalc(vec4 view_point,  vec4 intersectionPoint, vec3 K_A, int recursion_counter);

//------------------------------------------------Intersection Logic START----------------------------------------------

vec4 calc_intersection_with_plane(vec3 sourcePoint, vec3 direction, vec4 plane){
	vec4 intersection_point = vec4(0,0,0,-1);
	vec3 norm_direction = normalize(direction);
	vec3 norm_plane = normalize(plane.xyz);
	float denominator = dot(norm_plane, norm_direction);
	float t = 0.0;
	float nominator = 0.0;
	if (denominator > FPI_PRECISION){
		nominator = dot(sourcePoint, norm_plane) + plane.w;
		t = -nominator/denominator;	
		if (t > FPI_PRECISION){
			intersection_point = vec4(sourcePoint + t*norm_direction, 0);
		}
	}
	return (intersection_point);			//Find out why it works.			
}

vec4 calc_intersection_with_sphere(vec3 sourcePoint, vec3 direction, vec4 sphere){
	float t1,t2, sol;
	vec3 norm_direction = normalize(direction);
	vec4 returned_point = vec4(0,0,0,-1);
	float a = 1.0;
	float b = dot(2*norm_direction, (sourcePoint - sphere.xyz));
	float c = pow(length(sourcePoint - sphere.xyz), 2) - pow(sphere.w, 2);
	float b24ac = pow(b, 2) - 4*a*c;
	if (b24ac < FPI_PRECISION){
		return returned_point;
	}
	b24ac = sqrt(b24ac);
	t1 = (-b + b24ac)/(2*a);
	t2 = (-b - b24ac)/(2*a);
	if (t1 < FPI_PRECISION){
		if (t2 < FPI_PRECISION){
			return returned_point;
		}
		else {
			sol = t2;
		}
	} else {
		if (t2 < FPI_PRECISION){
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

vec4 intersection(vec4 sourcePoint, vec3 v, int index) {
	float min_dist = 100000; //dist is 1-0.
	vec4 intersection_point = vec4(0);
	vec4 intersection_and_index = vec4(0,0,0,-1);
	int index_of_obj = -1;
	for(int i = 0; i < sizes[0]; i++){ //Iterate through objects to find the min intersection.
		if (objects[i].w < 0){
			//plane
			intersection_point = calc_intersection_with_plane(sourcePoint.xyz, v, objects[i]);
		} else {
			//sphere
			intersection_point = calc_intersection_with_sphere(sourcePoint.xyz, v, objects[i]);
		}
		if (intersection_point.w > -1 && distance(sourcePoint.xyz, intersection_point.xyz) < min_dist){
			min_dist = distance(sourcePoint.xyz, intersection_point.xyz);
			intersection_and_index = vec4(intersection_point.xyz, i);
		}
	}
	return intersection_and_index;
}

//------------------------------------------------Intersection Logic END----------------------------------------------


//------------------------------------------------Light Logic START----------------------------------------------


vec4 calc_normal(vec4 intersectionPoint) {
	vec4 normal = vec4(0,0,0,1);
	if (objects[int(intersectionPoint.w)].w > 0){
		normal.xyz = normalize(intersectionPoint.xyz - objects[int(intersectionPoint.w)].xyz);
	} else { //A plane
		normal.xyz = -normalize(objects[int(intersectionPoint.w)].xyz);
		if ((intersectionPoint.x < 0 && intersectionPoint.y > 0) || (intersectionPoint.x > 0 && intersectionPoint.y < 0)){
			if ((mod(int(1.5*intersectionPoint.x),2) != mod(int(1.5*intersectionPoint.y),2)) ){
				normal.w = 0.5;
			} 
		}   else if ((mod(int(1.5*intersectionPoint.x),2) == mod(int(1.5*intersectionPoint.y),2)) ){
				normal.w = 0.5;
			}
	} //Calculate normal to a plane.
	return normal;
}



vec4 calc_vec_to_light(vec4 intersectionPoint, vec4 light, vec4 light_pos){
	vec4 L_vec_to_light = vec4(0,0,0,1);
	if (light.w != 0.0){ //Checks if the light is positional or sun-like
		L_vec_to_light.xyz = normalize(light_pos.xyz - intersectionPoint.xyz);
		if (dot(normalize(light.xyz), -L_vec_to_light.xyz) <= light_pos.w){
			L_vec_to_light.w = 0;
		} else {} //Check if the spot is in the cone of the spotlight.
			
	} else {
		L_vec_to_light.xyz = -normalize(light.xyz);
	}
	return L_vec_to_light;
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
	vec4 L_vec_to_light_container = vec4(0);
	vec3 R_reflected = vec3(0);
	vec4 normal = vec4(calc_normal(intersectionPoint));
	vec3 K_D = vec3(K_A)*normal.w;
	color += I_E + K_A*ambient.xyz; //I = I_E + K_A*I_A
	for (int i = 0; i < sizes[1]; i++){
		S_I = 1.0;
		L_vec_to_light_container = calc_vec_to_light(intersectionPoint, lightsDirection[i], 
									lightsPosition[positional_light_index++]);
		L_vec_to_light = L_vec_to_light_container.xyz;
		S_I *= L_vec_to_light_container.w;
		//Checks if a given point is obstructed.
		vec4 partial_intersection = vec4(intersectionPoint.xyz, 2);
		vec4 intersection_check = intersection(partial_intersection, L_vec_to_light, int(intersectionPoint.w));
		if (intersection_check.w  > -1){ //Stops a positional light from being obstructed from a plane behind it.
			if(lightsDirection[i].w == 1.0 &&
					(distance(intersectionPoint.xyz,lightsPosition[positional_light_index - 1].xyz) - 
						distance(intersectionPoint.xyz,intersection_check.xyz) > FPI_PRECISION )){
				S_I = 0;
			}
			else {
				if(lightsDirection[i].w == 0.0)
					S_I = 0;
				}
		}
		R_reflected = normalize(reflect(L_vec_to_light, normal.xyz));
		Temp_Sigma += clamp(K_D*(dot(normal.xyz, L_vec_to_light)), 0, 1);
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



//------------------------------------------------Light Logic END----------------------------------------------

void main()
{	
	vec3 color = vec3(0);
	vec4 modified_eye = vec4(eye.xyz, 1); //1 means it's a viewpoint.
	vec4 intersectionPoint = intersection(modified_eye, normalize(position1 - eye.xyz), -1);
	color = colorCalc(eye, intersectionPoint,  objColors[int(intersectionPoint.w)].xyz, 0);
	vec4 anti_aliasing_intersection_index_point = vec4(0);
	vec3 anti_aliasing = vec3(0);
 	vec3 anti_aliasing_position = vec3(0);
	if (position1.x != 0 && position1.y != 0){
		for (int i = -1; i < 2; i++){
			for (int j = -1; j < 2; j++){
				if (i == 0 && j == 0){
					continue;
				}
				anti_aliasing_position = vec3(position1);
				anti_aliasing_position.x += i*(FPI_PRECISION);
				anti_aliasing_position.y += j*(FPI_PRECISION);
				anti_aliasing_intersection_index_point = 
						intersection(eye, normalize(anti_aliasing_position - eye.xyz), -1);
				anti_aliasing += (4.0/32.0)*colorCalc(eye, anti_aliasing_intersection_index_point, 
										objColors[int(intersectionPoint.w)].xyz, 0);
			}
		}
	}
	color = anti_aliasing;
	gl_FragColor = vec4(color, 1);
}
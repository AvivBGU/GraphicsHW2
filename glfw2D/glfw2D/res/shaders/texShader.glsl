 #version 130 

uniform vec4 eye;
uniform vec4 ambient;
uniform vec4[20] objects;
uniform vec4[20] objColors;
uniform vec4[10] lightsDirection;
uniform vec4[10] lightsIntensity;
uniform vec4[10] lightPosition;
uniform ivec4 sizes; //{number of objects , number of lights , width, hight}  

in vec3 position1;

float intersection(vec3 sourcePoint,vec3 v)
{
    
    return 0;
    
}

vec3 colorCalc( vec3 intersectionPoint)
{
    vec3 color = vec3(1,0,1);
    
    return color;
}

void main()
{  
 
   gl_FragColor = vec4(0.5, 0.8, 0.487, 0.42223);  
}
 


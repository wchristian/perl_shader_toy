#version 150

uniform float time;
uniform vec2 view;
uniform vec2 mouse;
vec2 pixel_pos;
out vec4 gl_FragColor;
uniform sampler2D distortion;

vec3 mod289(vec3 x) {
  return x - floor(x * (1.0 / 289.0)) * 289.0;
}

vec2 mod289(vec2 x) {
  return x - floor(x * (1.0 / 289.0)) * 289.0;
}

vec3 permute(vec3 x) {
  return mod289(((x*34.0)+1.0)*x);
}

float snoise(vec2 v)
  {
  const vec4 C = vec4(0.211324865405187,  // (3.0-sqrt(3.0))/6.0
                      0.366025403784439,  // 0.5*(sqrt(3.0)-1.0)
                     -0.577350269189626,  // -1.0 + 2.0 * C.x
                      0.024390243902439); // 1.0 / 41.0
// First corner
  vec2 i  = floor(v + dot(v, C.yy) );
  vec2 x0 = v -   i + dot(i, C.xx);

// Other corners
  vec2 i1;
  //i1.x = step( x0.y, x0.x ); // x0.x > x0.y ? 1.0 : 0.0
  //i1.y = 1.0 - i1.x;
  i1 = (x0.x > x0.y) ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
  // x0 = x0 - 0.0 + 0.0 * C.xx ;
  // x1 = x0 - i1 + 1.0 * C.xx ;
  // x2 = x0 - 1.0 + 2.0 * C.xx ;
  vec4 x12 = x0.xyxy + C.xxzz;
  x12.xy -= i1;

// Permutations
  i = mod289(i); // Avoid truncation effects in permutation
  vec3 p = permute( permute( i.y + vec3(0.0, i1.y, 1.0 ))
      + i.x + vec3(0.0, i1.x, 1.0 ));

  vec3 m = max(0.5 - vec3(dot(x0,x0), dot(x12.xy,x12.xy), dot(x12.zw,x12.zw)), 0.0);
  m = m*m ;
  m = m*m ;

// Gradients: 41 points uniformly over a line, mapped onto a diamond.
// The ring size 17*17 = 289 is close to a multiple of 41 (41*7 = 287)

  vec3 x = 2.0 * fract(p * C.www) - 1.0;
  vec3 h = abs(x) - 0.5;
  vec3 ox = floor(x + 0.5);
  vec3 a0 = x - ox;

// Normalise gradients implicitly by scaling m
// Approximation of: m *= inversesqrt( a0*a0 + h*h );
  m *= 1.79284291400159 - 0.85373472095314 * ( a0*a0 + h*h );

// Compute final noise value at P
  vec3 g;
  g.x  = a0.x  * x0.x  + h.x  * x0.y;
  g.yz = a0.yz * x12.xz + h.yz * x12.yw;
  return 130.0 * dot(m, g);
}

float dist_to_metaball( vec3 pos_on_ray, float ball_x, float ball_y, float ball_z ) {

   vec3 ball_pos1 = vec3( ball_x-1, ball_y, ball_z )+vec3(0.12)*vec3(sin(time*13),cos(time*13),0);
   vec3 ball_pos2 = vec3( ball_x, ball_y-1, ball_z )+vec3(0.11)*vec3(sin(time*12),0,cos(time*12));
   vec3 ball_pos3 = vec3( ball_x+.25, ball_y+.25, ball_z )+vec3(0.13)*vec3(0,sin(time*11),cos(time*11));
   float dist = 1/length ( pos_on_ray - ball_pos1 ) + 1/length ( pos_on_ray - ball_pos2 )+ 1/length ( pos_on_ray - ball_pos3 );
   dist = 1/dist+0.32;
   return dist;
}

float dist_to_ball_at_single( vec3 pos_on_ray, float ball_x, float ball_y, float ball_z ) {
   vec3 ball_pos = vec3( ball_x, ball_y, ball_z );
   float dist = length ( pos_on_ray - ball_pos );
   return dist;
}
   
float dist_to_ball_at( vec3 pos_on_ray, float ball_x, float ball_y, float ball_z ) {
   vec3 ball_pos = vec3( ball_x, ball_y, ball_z );
    vec3 c = vec3(5);
   ball_pos = mod(ball_pos,c );
   vec3 fake_pos = mod(pos_on_ray,c)-0.5*c;
   float dist = length ( fake_pos - ball_pos );
   return dist;
}

vec3 rotate_vector( vec3 vector, vec3 around, float degr ) {
   
   vec4 q = normalize( vec4( around, tan(radians(degr/2+90)) ) );
   vec3 temp = cross(q.xyz, vector) + q.w * vector;
   vector = (cross(temp, -q.xyz) + dot(q.xyz,vector) * q.xyz + q.w * temp);
   
   return vector;
}

float noise_for( vec3 p, float scale, float amplitude ) {
   float col_val = snoise(p.xz/scale)*amplitude;
   return col_val;
}

float sample_text_by_pos( vec3 p, float scale, float amplitude ) {
   vec2 plane_coord = cos(p.xz/scale)/2 + 0.5;
   vec4 col = texture2D(distortion, plane_coord);
   float col_val = length(col.rgb);
   col_val *= amplitude;
   return col_val;
}

float rand(vec2 coordinate) {
    return fract(sin(dot(coordinate.xy, vec2(12.9898, 78.233))) * 43758.5453);
}

float sdPlane( vec3 p, vec3 n, float origin_distance ) {
   n = normalize(n);
   //origin_distance += sample_text_by_pos( p, 16, 8 );
   origin_distance += noise_for( p, 4, 1 );
   origin_distance += noise_for( p, 0.5, 0.125 );
   //origin_distance += sample_text_by_pos( p, 8, 4 );
   //origin_distance += sample_text_by_pos( p, 4, 2 );
   //origin_distance += sample_text_by_pos( p, 0.125, 0.0625 );
   //origin_distance += rand( p.xy )/4000;
   return dot(p,n) + origin_distance;
}

float scene( vec3 pos_on_ray, vec3 cam_pos ) {
   float plane = sdPlane( pos_on_ray, vec3( 0,1,0 ), 1 );

   float dist = 99999;
      float imp_time = 5*time;
      vec3 light_imp_pos = cam_pos+vec3(10*sin(imp_time),5*sin(imp_time*4),10*cos(imp_time));
   dist = min( dist, dist_to_ball_at_single( pos_on_ray, light_imp_pos.x, light_imp_pos.y, light_imp_pos.z ));
   dist -= 1; // blob size
   dist = min( dist, dist_to_metaball( pos_on_ray, 5+time,  3.5, -3 ) );
   dist = min( dist, dist_to_ball_at( pos_on_ray,  0,  0, 5 ) );
   //dist = min( dist, dist_to_ball_at_single( pos_on_ray,  3.0, -2.5, 5.0 ) );
   //dist = min( dist, dist_to_ball_at_single( pos_on_ray,  -4.0, 0.0, 6.0 ) );
   dist -= 0.5; // blob size
   dist = min(dist,plane);
   
   return dist;
}

vec3 gen_normals( vec3 pos_on_ray, vec3 cam_pos ) {

   vec2 weights = vec2( 0.001, 0.0 );
   vec3 normals = normalize(
      vec3(
         scene( pos_on_ray + weights.xyy,cam_pos ) - scene( pos_on_ray - weights.xyy,cam_pos ),
         scene( pos_on_ray + weights.yxy,cam_pos ) - scene( pos_on_ray - weights.yxy,cam_pos ),
         scene( pos_on_ray + weights.yxx,cam_pos ) - scene( pos_on_ray - weights.yxx,cam_pos )
      )
   );

   return normals;
}

vec4 add_light( vec4 colour, vec4 light_colour, vec3 light_pos, float light_strength, vec3 pos_on_ray, vec3 normal ) {
   vec3 light_to_target = light_pos - pos_on_ray;
   float light_distance = length( light_to_target );
   float light_strength_left = 1 /  pow(light_distance / light_strength, 2);

   vec3 tolight = normalize( light_pos - pos_on_ray );
   float diff = max( 0.0, dot( normal, tolight ) * light_strength_left );
      
   colour += vec4( diff ) * light_colour;
   
   vec3 reflected = normalize ( reflect ( tolight, normal ) );
   float spec = max( 0.0, pow( dot( reflected, normalize( pos_on_ray ) ), 10.0 ) * light_strength_left );
   colour += vec4( spec * 0.6 );
   
   return colour;
}

void main() {
	vec2 mousy = mouse / view;
   vec2 cam_center = gl_FragCoord.xy - view / 2;
   float zoom = 300;
   vec3 ray = normalize(vec3( cam_center, zoom ));
   
   ray = rotate_vector( ray, vec3( -1, 0, 0 ), 180*mousy.y-90 );
   ray = rotate_vector( ray, vec3( 0, -1, 0 ), 180*mousy.x-90 );

   int iteration_max = 45;
   int iterations = 0;
   float dist_to_closest = 1000.0;
   vec3 cam_pos = vec3( 2+time,5,0 );
   vec3 pos_on_ray = cam_pos;
   float view_range = 125;
   float allowed_error = 0.1;

   while (
         iterations++ <= iteration_max
      && dist_to_closest > allowed_error
      //&& length(pos_on_ray) < view_range
   ) {
      dist_to_closest = scene( pos_on_ray, cam_pos );
      pos_on_ray += dist_to_closest * ray;
   }

   if ( iterations < iteration_max && length(pos_on_ray) < view_range ) {
      vec3 normal = gen_normals( pos_on_ray, cam_pos );
      vec4 colour = vec4(0.2,0,0.2,1);
   
      vec4 light_imp_colour = vec4( 1, 1, 1, 1.0 );
      float imp_time = 5*time;
      vec3 light_imp_pos = cam_pos+vec3(10*sin(imp_time),5*sin(imp_time*4),10*cos(imp_time));
      float light_imp_strength = 5;
      colour = add_light( colour, light_imp_colour, light_imp_pos, light_imp_strength, pos_on_ray,normal );
   
      vec4 light_colour = vec4( 1, 1, 1, 1.0 );
      vec3 light_pos = cam_pos+vec3(50*sin(imp_time*1.2),0,50*cos(imp_time*1.2));
      float light_strength = 5;
      colour = add_light( colour, light_colour, light_pos, light_strength, pos_on_ray,normal );
      
      vec4 sun_colour = vec4( 0.75, 0.75, 0.35, 1 );
      vec3 sun_pos = vec3( 20, 500000000.0, 3.0 );
      float sun_strength = 500000000;
      colour = add_light( colour, sun_colour, sun_pos, sun_strength, pos_on_ray,normal );

      float fog_depth = 15;
      gl_FragColor = colour/max(1,(length(pos_on_ray-cam_pos)/fog_depth));
   }
   else {
      gl_FragColor = vec4( 0 );
   }
}

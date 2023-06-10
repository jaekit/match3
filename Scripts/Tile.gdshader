shader_type canvas_item;


uniform sampler2D base_texture;
uniform sampler2D modifier_texture;
uniform sampler2D modifier_texture_2;
uniform sampler2D outline_texture;

uniform int type;

// rainbow
uniform float strength: hint_range(0., 1.) = 1.0;
uniform float speed: hint_range(0., 10.) = 0.4;
uniform float angle: hint_range(0., 360.) = 45.0;

// shine
uniform vec4 shine_color : hint_color = vec4(1.0);
uniform float shine_speed : hint_range(0.0, 10.0, 0.1) = 10.0;
uniform float shine_size : hint_range(0.01, 1.0, 0.01) = 0.01;


bool equals(vec4 a, vec4 b) {
	//if (a.a == 0.0) {
	//	return true;
	//}
	float margin = 0.1;
	return abs(a.x - b.x) < margin && abs(a.y - b.y) < margin && abs(a.z - b.z) < margin;
}


vec4 rainbow(vec2 uv, vec4 base) {
	float hue = uv.x * cos(radians(angle)) - uv.y * sin(radians(angle));
	hue = fract(hue + fract(TIME  * speed));
	float x = 1. - abs(mod(hue / (1./ 6.), 2.) - 1.);
	vec3 rainbow;
	if(hue < 1./6.){
		rainbow = vec3(1., x, 0.);
	} else if (hue < 1./3.) {
		rainbow = vec3(x, 1., 0);
	} else if (hue < 0.5) {
		rainbow = vec3(0, 1., x);
	} else if (hue < 2./3.) {
		rainbow = vec3(0., x, 1.);
	} else if (hue < 5./6.) {
		rainbow = vec3(x, 0., 1.);
	} else {
		rainbow = vec3(1., 0., x);
	}
	return mix(base, vec4(rainbow, base.a), strength);
}


void fragment() {
	vec4 base = texture(base_texture, UV);
	vec4 outline = texture(outline_texture, UV);
	vec4 modifier;
	if (type == 2) {
		modifier = texture(modifier_texture, UV);
	} else if (type == 4) {
		modifier = texture(modifier_texture_2, UV);
	}
	
	if (base.a == 0.0) {
		COLOR = vec4(0.0);
	} else if (type == 8) {
		//if (equals(base, vec4(0.0, 0.0, 0.0, 1.0))) {
		if (outline.a > 0.0) {
			COLOR = rainbow(UV, base); // rainbow outline
		} else {
			COLOR = base;
		}
	} else if (type == 16) {
		if (equals(base, vec4(0.0))) {
			COLOR = base;
		} else {
			COLOR = rainbow(UV, base);
		}
	}
	else if ((type == 2 || type == 4) && modifier.a != 0.0) {
		if (outline.a > 0.0) {
			COLOR = base; // normal outline
		} else {
			//COLOR.rgb = mix(modifier.rgb, base.rgb, 0.5);
			COLOR = base;
			COLOR.a = 0.2;
		}
	} else {
		COLOR = base;
	}
	//float shine = step(1.0 - shine_size * 0.5, 0.5 + 0.5 * sin(UV.x - UV.y + TIME * shine_speed));
	//COLOR.rgb = mix(COLOR.rgb, shine_color.rgb, shine * shine_color.a);
}

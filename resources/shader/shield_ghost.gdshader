shader_type canvas_item;

// 护盾虚影：采样玩家精灵轮廓，叠加 fresnel 边缘发光 + 半透明填充
// intensity 驱动整体显隐（0 = 完全透明不可见）

uniform vec4 shield_color : source_color = vec4(0.45, 0.7, 1.0, 1.0);
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float fill_alpha : hint_range(0.0, 1.0) = 0.5;
uniform float rim_power : hint_range(0.5, 4.0) = 2.0;
uniform float rim_width : hint_range(0.05, 0.6) = 0.25;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float silhouette = tex.a;

	// 径向距离（基于精灵自身的 UV 空间），用于 fresnel 边缘
	vec2 centered = UV * 2.0 - 1.0;
	float dist = length(centered);

	// 边缘发光：越靠近精灵边缘（dist 越大）越亮
	float rim = smoothstep(1.0 - rim_width, 1.0, dist);
	rim = pow(rim, rim_power);

	// 整体填充（低透明度，覆盖整个精灵轮廓）+ 边缘高光
	float glow = fill_alpha + rim * 0.85;

	// 只在精灵有像素的地方显示，整体受 intensity 控制
	float alpha = silhouette * glow * intensity;

	COLOR = vec4(shield_color.rgb, alpha * shield_color.a);
}

shader_type canvas_item;

// 形状类型: 0 = 圆形 (Circle), 1 = 扇形 (Sector), 2 = 矩形/方形 (Box)
uniform int shape_type : hint_range(0, 2) = 0;

// 填充模式: 0 = 中心向外辐射 (Radial), 1 = 从左到右线性推进 (Linear Left-to-Right)
uniform int fill_mode : hint_range(0, 1) = 0;

// 颜色设置
uniform vec4 bg_color : source_color = vec4(1.0, 0.3, 0.3, 0.4);
uniform vec4 fill_color : source_color = vec4(1.0, 0.12, 0.12, 0.4);

// 核心控制参数
uniform float progress : hint_range(0.0, 1.0) = 0.0;        // 倒计时进度 (0.0 到 1.0)
uniform float sector_angle : hint_range(1.0, 360.0) = 90.0; // 扇形角度 (仅在 shape_type=1 生效)
uniform float edge_feather : hint_range(0.001, 0.05) = 0.015; // 边缘抗锯齿羽化

// 渐变控制
uniform bool dynamic_fill_gradient = true; // true: 推进前沿最不透明, 向后渐变淡出
uniform float fill_center_alpha_ratio : hint_range(0.0, 0.5) = 0.05; // 填充最弱处的保底透明度比例

void fragment() {
    vec2 uv = UV - vec2(0.5);
    float dist = 0.0;
    float shape_mask = 1.0;

    // 1. 几何外形遮罩与底色分布计算
    if (shape_type == 0) {
        dist = length(uv) * 2.0;
        shape_mask = 1.0 - smoothstep(1.0 - edge_feather, 1.0, dist);
    } else if (shape_type == 1) {
        dist = length(uv) * 2.0;
        shape_mask = 1.0 - smoothstep(1.0 - edge_feather, 1.0, dist);
        
        float angle = degrees(abs(atan(uv.x, -uv.y)));
        float half_angle = sector_angle * 0.5;
        shape_mask *= (1.0 - smoothstep(half_angle - 1.0, half_angle, angle));
    } else if (shape_type == 2) {
        vec2 abs_uv = abs(uv) * 2.0;
        dist = max(abs_uv.x, abs_uv.y);
        shape_mask = 1.0 - smoothstep(1.0 - edge_feather, 1.0, dist);
    }

    // 底色渐变 (中心透明, 外边框明显)
    float bg_alpha = dist * bg_color.a;
    vec4 current_bg = vec4(bg_color.rgb, bg_alpha);

    // 2. 根据填充模式计算充能判定坐标
    float fill_coord = dist; // 默认中心向外 (0.0 到 1.0)
    if (fill_mode == 1) {
        fill_coord = UV.x;  // 从左到右线性填充 (0.0 到 1.0)
    }

    // 3. 填充层计算
    float fill_mask = 0.0;
    vec4 current_fill = current_bg;

    if (progress > 0.0) {
        // 推进边界羽化遮罩
        fill_mask = 1.0 - smoothstep(progress - edge_feather, progress, fill_coord);
        
        // 渐变计算: 前沿(progress处)为1.0, 起始端(中心或最左侧)逐渐变为0.0
        float fill_ratio = dynamic_fill_gradient ? (fill_coord / max(progress, 0.0001)) : fill_coord;
        fill_ratio = clamp(fill_ratio, 0.0, 1.0);
        
        // 混合透明度
        float min_alpha = fill_color.a * fill_center_alpha_ratio;
        float fill_alpha = mix(min_alpha, fill_color.a, fill_ratio);
        
        current_fill = vec4(fill_color.rgb, fill_alpha);
    }

    // 混合并应用外形裁剪
    vec4 final_color = mix(current_bg, current_fill, fill_mask);
    COLOR = vec4(final_color.rgb, final_color.a * shape_mask);
}
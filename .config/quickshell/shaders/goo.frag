#version 440

// Two glass shapes — the pill and the panel leaving it — drawn as one surface.
// Each is a rounded box SDF, joined by a neck that pinches at the waist as
// they part and snaps at `reach`, like a cell dividing; a smooth minimum
// rounds the joins. Shading copies Glass.qml: tint, top sheen, 1px border, a rim lit
// on top and shaded at the bottom. Compile with:
//     /usr/lib/qt6/bin/qsb --qt6 -o goo.frag.qsb goo.frag

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 res;        // item size, px
    vec4 rectA;      // pill:  x, y, w, h (px, item-local)
    vec4 rectB;      // panel: x, y, w, h
    float radA;
    float radB;
    float reach;     // gap at which the neck between them snaps, px
    vec4 tintA;      // straight (not premultiplied) rgba
    vec4 tintB;
    vec4 borderCol;
    vec4 rimTopCol;
    vec4 rimBottomCol;
};

float box(vec2 p, vec4 r, float rad) {
    vec2 h = r.zw * 0.5;
    rad = min(rad, min(h.x, h.y));
    vec2 q = abs(p - (r.xy + h)) - h + rad;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - rad;
}

float smin(float a, float b, float kk) {
    kk = max(kk, 1e-3);
    float h = max(kk - abs(a - b), 0.0) / kk;
    return min(a, b) - h * h * kk * 0.25;
}

// Gap between the bottom of the pill and the top of the panel, and how far
// along the split is: 0 touching, 1 at `reach`, where the neck snaps.
float sep() { return rectB.y - (rectA.y + rectA.w); }
float split() { return clamp(sep() / reach, 0.0, 1.0); }

// The neck: a column of glass from inside the pill to inside the panel whose
// width follows a pinched profile — full at both ends, narrowing in the
// middle as the split goes on, until the waist closes and the two halves pull
// back into their bodies. That waist is what reads as a cell dividing.
float neck(vec2 p) {
    float g = sep();
    if (g <= 0.0)
        return 1e4;
    float t = split();
    if (t >= 1.0)
        return 1e4;

    float cx = 0.5 * ((rectA.x + rectA.z * 0.5) + (rectB.x + rectB.z * 0.5));
    float y0 = rectA.y + rectA.w - rectA.w * 0.5;
    float y1 = rectB.y + min(rectB.w * 0.5, 24.0);
    float hgt = max(y1 - y0, 1.0);
    float h = clamp((p.y - y0) / hgt, 0.0, 1.0);

    // Starts as wide as most of the pill, fades in over the first few px so
    // nothing pops when they first part, and the stubs retract once it snaps.
    float w0 = rectA.z * 0.5 * 0.82 * mix(1.0, 0.55, t);
    w0 *= smoothstep(0.0, 6.0, g) * (1.0 - smoothstep(0.82, 1.0, t));
    float waist = pow(1.0 - t, 1.6);
    float hw = w0 * (1.0 - (1.0 - waist) * 4.0 * h * (1.0 - h));

    return max(abs(p.x - cx) - hw, max(y0 - p.y, p.y - y1));
}

// How soft the joins are where the neck meets each body.
float fillet() { return 16.0 * smoothstep(0.0, 8.0, sep()); }

float shape(vec2 p) {
    float body = min(box(p, rectA, radA), box(p, rectB, radB));
    return smin(body, neck(p), fillet());
}

// Glass.qml's sheen: white, 0.14 at the top edge, 0.04 by 55%, gone at 34px.
float sheen(float dy) {
    if (dy < 0.0)
        return 0.0;
    float t = clamp(dy / 34.0, 0.0, 1.0);
    return t < 0.55 ? mix(0.14, 0.04, t / 0.55) : mix(0.04, 0.0, (t - 0.55) / 0.45);
}

vec4 over(vec4 top, vec4 bottom) {   // both premultiplied
    return top + bottom * (1.0 - top.a);
}

void main() {
    vec2 p = qt_TexCoord0 * res;
    float dA = box(p, rectA, radA);
    float dB = box(p, rectB, radB);
    float d = shape(p);

    float cover = clamp(0.5 - d, 0.0, 1.0);
    if (cover <= 0.0) {
        fragColor = vec4(0.0);
        return;
    }

    // Which body this pixel belongs to, softly: the neck blends the two.
    float w = clamp(0.5 + 0.5 * (dA - dB) / 24.0, 0.0, 1.0);
    vec4 tint = mix(tintA, tintB, w);
    vec4 c = vec4(tint.rgb * tint.a, tint.a);

    float s = mix(sheen(p.y - rectA.y), sheen(p.y - rectB.y), w);
    c = over(vec4(vec3(s), s), c);

    // Surface normal from the field, for the lit/shaded rim.
    vec2 e = vec2(1.0, 0.0);
    vec2 n = normalize(vec2(shape(p + e.xy) - shape(p - e.xy),
                            shape(p + e.yx) - shape(p - e.yx)) + 1e-6);

    // Border: the outermost pixel. Rim: the one inside it.
    float ring0 = clamp(1.0 - abs(d + 0.5), 0.0, 1.0);
    float ring1 = clamp(1.0 - abs(d + 1.5), 0.0, 1.0);
    float lit = clamp(-n.y, 0.0, 1.0);
    float shade = clamp(n.y, 0.0, 1.0);

    float rt = rimTopCol.a * ring1 * lit;
    c = over(vec4(rimTopCol.rgb * rt, rt), c);
    float rb = rimBottomCol.a * ring1 * shade;
    c = over(vec4(rimBottomCol.rgb * rb, rb), c);
    float bd = borderCol.a * ring0;
    c = over(vec4(borderCol.rgb * bd, bd), c);

    fragColor = c * cover * qt_Opacity;
}

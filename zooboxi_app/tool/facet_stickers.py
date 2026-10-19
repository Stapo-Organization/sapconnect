# Zooboxi facet stickers — drawn in the character library's language:
# thick maroon outline, flat fills, one white gloss, round kawaii shapes.
O = '#4A2320'      # outline (sampled from the characters)
SW = 3.2
CREAM = '#FFF6E8'
ORANGE = '#F2A04A'
STRIPE = '#D9792B'
PINK = '#F59A9A'
TEAL = '#429D9C'
TEAL_L = '#8FD0CC'
CORAL = '#D46856'
AMBER = '#F4BE2C'
BLUE = '#6FA3E8'
BLUE_D = '#3F74C9'
GREEN = '#7CC46F'
GREEN_D = '#4E9A45'
GREY = '#C9CFD6'
BROWN = '#B8773F'
BROWN_L = '#E0A96A'
RED = '#E4574B'

S = f'stroke="{O}" stroke-width="{SW}" stroke-linejoin="round" stroke-linecap="round"'
S2 = f'stroke="{O}" stroke-width="2.4" stroke-linejoin="round" stroke-linecap="round"'
GL = 'fill="#FFFFFF" opacity="0.85"'


def eyes_happy(cx, cy, dx=7, s=1.0):
    return (f'<path d="M{cx-dx-3*s} {cy} q{3*s} {-3.4*s} {6*s} 0" fill="none" {S2}/>'
            f'<path d="M{cx+dx-3*s} {cy} q{3*s} {-3.4*s} {6*s} 0" fill="none" {S2}/>')


def eyes_dot(cx, cy, dx=7, r=2.6):
    return (f'<circle cx="{cx-dx}" cy="{cy}" r="{r}" fill="{O}"/><circle cx="{cx+dx}" cy="{cy}" r="{r}" fill="{O}"/>'
            f'<circle cx="{cx-dx+0.9}" cy="{cy-0.9}" r="0.9" fill="#fff"/><circle cx="{cx+dx+0.9}" cy="{cy-0.9}" r="0.9" fill="#fff"/>')


def cat_head(scale=1.0, fur=ORANGE, age='adult'):
    # 64 viewbox, centered
    ear = (f'<path d="M14 26 L16 9 L29 19 Z" fill="{fur}" {S}/><path d="M50 26 L48 9 L35 19 Z" fill="{fur}" {S}/>'
           f'<path d="M17.5 21 L18.5 13.5 L24.5 18.5 Z" fill="{PINK}"/><path d="M46.5 21 L45.5 13.5 L39.5 18.5 Z" fill="{PINK}"/>')
    head = f'<ellipse cx="32" cy="35" rx="21" ry="18" fill="{fur}" {S}/>'
    muzzle = f'<ellipse cx="32" cy="41" rx="11" ry="8" fill="{CREAM}"/>'
    stripes = (f'<path d="M27 18.5 q1 4 0 6 M32 17.5 v7 M37 18.5 q-1 4 0 6" fill="none" stroke="{STRIPE}" stroke-width="2.4" stroke-linecap="round"/>')
    nose = f'<path d="M29.8 38.5 h4.4 l-2.2 2.6 z" fill="{PINK}" {S2}/>'
    mouth = f'<path d="M32 41 q-2 3 -4.5 1.5 M32 41 q2 3 4.5 1.5" fill="none" {S2}/>'
    wh = (f'<path d="M12 38 l7 1 M12 43 l7 -1 M52 38 l-7 1 M52 43 l-7 -1" fill="none" stroke="{O}" stroke-width="1.6" stroke-linecap="round"/>')
    gloss = f'<ellipse cx="22" cy="27" rx="3.2" ry="2" {GL} transform="rotate(-30 22 27)"/>'
    if age == 'kitten':
        e = eyes_dot(32, 33, 8, 3.4)
        extra = f'<circle cx="21" cy="40" r="2.6" fill="{PINK}" opacity="0.7"/><circle cx="43" cy="40" r="2.6" fill="{PINK}" opacity="0.7"/>'
    elif age == 'senior':
        e = (f'<circle cx="24.5" cy="33" r="5.4" fill="#fff" fill-opacity="0.35" {S2}/><circle cx="39.5" cy="33" r="5.4" fill="#fff" fill-opacity="0.35" {S2}/>'
             f'<path d="M29.9 33 h4.2" {S2}/><path d="M22 33.5 q2.5 -2 5 0 M37 33.5 q2.5 -2 5 0" fill="none" {S2}/>')
        extra = ''
    else:
        e = eyes_happy(32, 33, 7.5)
        extra = ''
    body = ear + head + muzzle + stripes + e + nose + mouth + wh + gloss + extra
    if scale != 1.0:
        return f'<g transform="translate({32-32*scale} {34-34*scale}) scale({scale})">{body}</g>'
    return body


def dog_head(scale=1.0, age='adult'):
    fur = BROWN_L
    ears = (f'<path d="M15 20 q-9 2 -8 16 q1 8 7 7 q4 -1 5 -9 z" fill="{BROWN}" {S}/>'
            f'<path d="M49 20 q9 2 8 16 q-1 8 -7 7 q-4 -1 -5 -9 z" fill="{BROWN}" {S}/>')
    head = f'<path d="M14 32 q0 -18 18 -18 q18 0 18 18 q0 17 -18 17 q-18 0 -18 -17z" fill="{fur}" {S}/>'
    muzzle = f'<ellipse cx="32" cy="40" rx="10" ry="7.5" fill="{CREAM}"/>'
    patch = f'<path d="M38 20 q7 1 8 9 q-6 1 -9 -3 z" fill="{BROWN}" opacity="0.55"/>'
    nose = f'<ellipse cx="32" cy="37.5" rx="3.6" ry="2.6" fill="{O}"/><ellipse cx="31" cy="36.8" rx="1.1" ry="0.7" fill="#fff"/>'
    mouth = f'<path d="M32 40 q-2 3 -5 1.5 M32 40 q2 3 5 1.5" fill="none" {S2}/>'
    tongue = f'<path d="M30 42.5 q2 4 4 0" fill="{PINK}" {S2}/>'
    gloss = f'<ellipse cx="22" cy="24" rx="3.2" ry="2" {GL} transform="rotate(-30 22 24)"/>'
    if age == 'puppy':
        e = eyes_dot(32, 30, 8, 3.4)
        extra = f'<circle cx="21" cy="37" r="2.6" fill="{PINK}" opacity="0.7"/><circle cx="43" cy="37" r="2.6" fill="{PINK}" opacity="0.7"/>'
    elif age == 'senior':
        e = (f'<circle cx="24.5" cy="30" r="5.4" fill="#fff" fill-opacity="0.35" {S2}/><circle cx="39.5" cy="30" r="5.4" fill="#fff" fill-opacity="0.35" {S2}/>'
             f'<path d="M29.9 30 h4.2" {S2}/><path d="M22 30.5 q2.5 -2 5 0 M37 30.5 q2.5 -2 5 0" fill="none" {S2}/>')
        extra = f'<path d="M26 45.5 q6 3 12 0" fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round"/>'
    else:
        e = eyes_happy(32, 30, 7.5)
        extra = ''
    body = ears + head + patch + muzzle + e + nose + mouth + tongue + gloss + extra
    if scale != 1.0:
        return f'<g transform="translate({32-32*scale} {32-32*scale}) scale({scale})">{body}</g>'
    return body


ICONS = {}

# ── life stage ──
ICONS['kitten'] = cat_head(0.86, age='kitten')
ICONS['cat_adult'] = cat_head(1.0)
ICONS['cat_senior'] = cat_head(1.0, fur='#E8B77E', age='senior')
ICONS['puppy'] = dog_head(0.86, age='puppy')
ICONS['dog_adult'] = dog_head(1.0)
ICONS['dog_senior'] = dog_head(1.0, age='senior')

# ── food form ──
ICONS['dry'] = (
    f'<path d="M8 32 h48 q-2 20 -24 20 q-22 0 -24 -20z" fill="{TEAL}" {S}/>'
    f'<path d="M14 36 q2 10 12 12" fill="none" stroke="#fff" stroke-width="2.4" stroke-linecap="round" opacity="0.7"/>'
    + ''.join(f'<path d="M{x} {y} q4 -4 8 0 q-4 4 -8 0z" fill="{BROWN_L}" {S2} transform="rotate({r} {x+4} {y})"/>'
              for x, y, r in [(13, 29, -10), (22, 25, 15), (31, 28, -5), (40, 25, 20), (47, 29, -15), (27, 20, 5), (36, 19, -20)])
)
ICONS['wet'] = (
    f'<rect x="12" y="20" width="40" height="30" rx="5" fill="{GREY}" {S}/>'
    f'<rect x="12" y="27" width="40" height="15" fill="{CORAL}" stroke="{O}" stroke-width="2.4"/>'
    f'<ellipse cx="32" cy="20" rx="20" ry="5" fill="#E6EAEE" {S}/>'
    f'<path d="M27 19 q5 -4 10 0" fill="none" {S2}/>'
    f'<path d="M26 34.5 q3 -3 6 0 q3 3 6 0" fill="none" stroke="#fff" stroke-width="2.4" stroke-linecap="round"/>'
    f'<rect x="15" y="44" width="10" height="3" rx="1.5" fill="#fff" opacity="0.8"/>'
)
ICONS['pouch'] = (
    f'<path d="M16 12 h32 l-2 40 q-14 5 -28 0z" fill="{AMBER}" {S}/>'
    f'<path d="M16 17 h32" stroke="{O}" stroke-width="2.4"/>'
    f'<path d="M20 12 l2 -4 M26 12 l2 -4 M32 12 l2 -4 M38 12 l2 -4" {S2}/>'
    f'<circle cx="32" cy="33" r="8" fill="{CREAM}" {S2}/>'
    f'<path d="M28.5 33 q3.5 -3 7 0 q-3.5 3 -7 0" fill="{CORAL}"/>'
    f'<rect x="20" y="21" width="4" height="22" rx="2" fill="#fff" opacity="0.7"/>'
)
ICONS['treat'] = (
    f'<path d="M14 26 q-6 -6 0 -11 q5 -4 9 2 l18 18 q6 -4 9 1 q4 6 -3 9 q2 7 -5 7 q-5 -1 -3 -7 l-18 -18 q-6 3 -8 -1z" fill="{BROWN_L}" {S}/>'
    f'<path d="M20 18 l18 18" stroke="#fff" stroke-width="2.4" stroke-linecap="round" opacity="0.7"/>'
)

# ── diet / health ──
ICONS['grain_free'] = (
    f'<path d="M32 54 V22" {S}/>'
    + ''.join(f'<ellipse cx="{32+dx}" cy="{y}" rx="4" ry="7" fill="{AMBER}" {S2} transform="rotate({r} {32+dx} {y})"/>'
              for dx, y, r in [(-6, 26, -30), (6, 26, 30), (-6, 36, -30), (6, 36, 30), (0, 16, 0)])
    + f'<circle cx="32" cy="32" r="24" fill="none" stroke="{RED}" stroke-width="5"/>'
    f'<path d="M15 15 L49 49" stroke="{RED}" stroke-width="5" stroke-linecap="round"/>'
)
ICONS['sterilised'] = (
    f'<path d="M32 8 l20 7 v14 q0 16 -20 26 q-20 -10 -20 -26 v-14z" fill="{TEAL}" {S}/>'
    f'<path d="M32 42 q-12 -7 -12 -14 q0 -6 6 -6 q4 0 6 4 q2 -4 6 -4 q6 0 6 6 q0 7 -12 14z" fill="#fff" {S2}/>'
    f'<path d="M18 17 q0 12 4 18" fill="none" stroke="#fff" stroke-width="2.4" stroke-linecap="round" opacity="0.6"/>'
)
ICONS['urinary'] = (
    f'<path d="M32 7 q18 20 18 32 a18 18 0 0 1 -36 0 q0 -12 18 -32z" fill="{BLUE}" {S}/>'
    f'<path d="M22 38 q0 -6 5 -12" fill="none" stroke="#fff" stroke-width="3" stroke-linecap="round" opacity="0.8"/>'
    + eyes_happy(32, 40, 6) + f'<path d="M29 46 q3 3 6 0" fill="none" {S2}/>'
)
ICONS['hairball'] = (
    f'<path d="M46 44 q10 2 10 9 q0 4 -5 5" fill="none" {S}/>'
    f'<circle cx="30" cy="32" r="19" fill="{CORAL}" {S}/>'
    f'<clipPath id="yb"><circle cx="30" cy="32" r="17.4"/></clipPath>'
    f'<g clip-path="url(#yb)" fill="none" stroke="{O}" stroke-width="1.9" stroke-linecap="round" opacity="0.75">'
    f'<path d="M8 30 q22 -18 44 -6 M8 38 q22 -18 44 -6 M8 46 q22 -18 44 -6"/>'
    f'<path d="M20 8 q-10 22 4 48 M30 12 q-8 18 6 42"/></g>'
    f'<ellipse cx="22" cy="22" rx="3.8" ry="2.2" {GL} transform="rotate(-35 22 22)"/>'
)
ICONS['light'] = (
    f'<path d="M14 26 h36 l4 26 h-44z" fill="{GREEN}" {S}/>'
    f'<rect x="10" y="20" width="44" height="7" rx="3.5" fill="{GREEN_D}" {S}/>'
    f'<circle cx="32" cy="40" r="8.5" fill="#fff" {S2}/>'
    f'<path d="M32 40 l-3.5 -5" {S2}/><circle cx="32" cy="40" r="1.6" fill="{O}"/>'
    f'<path d="M26 12 q6 -6 12 0" fill="none" {S2}/><path d="M29 14.5 q3 -3 6 0" fill="none" {S2}/>'
    f'<path d="M17 31 v14" stroke="#fff" stroke-width="2.6" stroke-linecap="round" opacity="0.6"/>'
)
ICONS['indoor'] = (
    f'<path d="M10 30 L32 10 L54 30 V52 H10Z" fill="{AMBER}" {S}/>'
    f'<path d="M6 32 L32 8 L58 32" fill="none" stroke="{CORAL}" stroke-width="6" stroke-linecap="round" stroke-linejoin="round"/>'
    f'<path d="M6 32 L32 8 L58 32" fill="none" stroke="{O}" stroke-width="{SW}" stroke-linecap="round" stroke-linejoin="round" transform="translate(0 -3.4)" opacity="0"/>'
    f'<path d="M24 52 V38 q8 -8 16 0 V52" fill="{CREAM}" {S2}/>'
    f'<path d="M27 40 l2 -5 3 3 3 -3 2 5" fill="{ORANGE}" {S2}/>'
)
ICONS['hypo'] = (
    f'<path d="M12 52 q-2 -34 40 -40 q4 38 -40 40z" fill="{GREEN}" {S}/>'
    f'<path d="M14 50 q14 -18 30 -30" fill="none" {S}/>'
    f'<path d="M20 38 q-1 -8 8 -16" fill="none" stroke="#fff" stroke-width="2.4" stroke-linecap="round" opacity="0.7"/>'
)
ICONS['digest'] = (
    f'<circle cx="32" cy="34" r="20" fill="{PINK}" {S}/>'
    f'<path d="M22 30 q5 -6 10 0 q5 6 10 0" fill="none" stroke="#fff" stroke-width="3" stroke-linecap="round"/>'
    + eyes_happy(32, 38, 6) + f'<path d="M29 44 q3 3 6 0" fill="none" {S2}/>'
    f'<path d="M32 14 v-6 M26 16 l-3 -5 M38 16 l3 -5" {S2}/>'
)
ICONS['vet'] = (
    f'<rect x="10" y="16" width="44" height="36" rx="8" fill="#fff" {S}/>'
    f'<path d="M24 16 v-4 q0 -3 3 -3 h10 q3 0 3 3 v4" fill="none" {S}/>'
    f'<path d="M28 24 h8 v8 h8 v8 h-8 v8 h-8 v-8 h-8 v-8 h8z" fill="{RED}" {S2} transform="translate(0 -2)"/>'
)

# ── protein / flavour ──
ICONS['chicken'] = (
    f'<path d="M36 8 q16 2 18 18 q1 12 -10 16 l-8 3 l-7 -7 l3 -8 q4 -11 4 -22z" fill="{BROWN_L}" {S}/>'
    f'<path d="M29 38 l-12 12" stroke="{O}" stroke-width="7" stroke-linecap="round"/>'
    f'<path d="M29 38 l-12 12" stroke="{CREAM}" stroke-width="3.6" stroke-linecap="round"/>'
    f'<circle cx="14" cy="49" r="4.4" fill="{CREAM}" {S2}/><circle cx="18" cy="54" r="4.4" fill="{CREAM}" {S2}/>'
    f'<ellipse cx="42" cy="18" rx="4" ry="2.4" {GL} transform="rotate(35 42 18)"/>'
)
ICONS['salmon'] = (
    f'<path d="M8 32 q14 -18 34 -8 l12 -10 v36 l-12 -10 q-20 10 -34 -8z" fill="{CORAL}" {S}/>'
    f'<path d="M22 26 q-4 6 0 12" fill="none" {S2}/>'
    f'<circle cx="15" cy="29" r="2.4" fill="{O}"/><circle cx="15.8" cy="28.2" r="0.8" fill="#fff"/>'
    f'<path d="M28 30 q4 -3 8 0 M28 36 q4 -3 8 0" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round" opacity="0.8"/>'
)
ICONS['tuna'] = (
    f'<path d="M8 32 q14 -16 34 -8 l12 -10 v36 l-12 -10 q-20 10 -34 -8z" fill="{BLUE_D}" {S}/>'
    f'<path d="M10 34 q14 12 32 4" fill="#DDE7F3" stroke="none"/>'
    f'<path d="M8 32 q14 -16 34 -8 l12 -10 v36 l-12 -10 q-20 10 -34 -8z" fill="none" {S}/>'
    f'<circle cx="15" cy="29" r="2.4" fill="{O}"/><circle cx="15.8" cy="28.2" r="0.8" fill="#fff"/>'
    f'<path d="M24 22 l4 -6 4 5" fill="{BLUE_D}" {S2}/>'
)
ICONS['lamb'] = (
    ''.join(f'<circle cx="{x}" cy="{y}" r="8" fill="#fff" {S}/>' for x, y in [(18, 26), (32, 18), (46, 26), (16, 40), (48, 40), (32, 46)])
    + f'<circle cx="32" cy="32" r="14" fill="#fff" stroke="none"/>'
    f'<ellipse cx="32" cy="34" rx="9" ry="11" fill="#6B4A3A" {S2}/>'
    + eyes_happy(32, 32, 4, 0.7) + f'<path d="M30 39 q2 2 4 0" fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round"/>'
)
ICONS['beef'] = (
    f'<path d="M14 22 q10 -14 28 -8 q14 6 12 20 q-2 16 -20 18 q-18 2 -24 -10 q-4 -10 4 -20z" fill="{RED}" {S}/>'
    f'<path d="M20 24 q8 -8 20 -4 q8 4 7 12" fill="none" stroke="#fff" stroke-width="3.4" stroke-linecap="round" opacity="0.9"/>'
    f'<circle cx="36" cy="36" r="5" fill="{CREAM}" {S2}/>'
)
ICONS['duck'] = (
    f'<circle cx="30" cy="30" r="18" fill="{AMBER}" {S}/>'
    f'<path d="M44 30 q14 -2 14 5 q-6 5 -15 3z" fill="{ORANGE}" {S}/>'
    + eyes_dot(30, 26, 7, 2.6) +
    f'<ellipse cx="22" cy="20" rx="3.6" ry="2.2" {GL} transform="rotate(-35 22 20)"/>'
    f'<circle cx="20" cy="34" r="2.6" fill="{PINK}" opacity="0.8"/>'
)

# ── misc facets ──
ICONS['price'] = (
    f'<path d="M34 8 h18 v18 l-24 24 q-3 3 -6 0 l-12 -12 q-3 -3 0 -6z" fill="{AMBER}" {S}/>'
    f'<circle cx="44" cy="17" r="3.4" fill="#fff" {S2}/>'
    f'<path d="M22 32 l10 -10" stroke="#fff" stroke-width="3" stroke-linecap="round" opacity="0.8"/>'
)
ICONS['brand'] = (
    f'<path d="M32 6 l6 6 h8 v8 l6 6 -6 6 v8 h-8 l-6 6 -6 -6 h-8 v-8 l-6 -6 6 -6 v-8 h8z" fill="{TEAL}" {S}/>'
    f'<path d="M32 20 l3.6 7.4 8 1 -5.8 5.6 1.4 8 -7.2 -3.8 -7.2 3.8 1.4 -8 -5.8 -5.6 8 -1z" fill="#fff" {S2}/>'
)
ICONS['size_s'] = dog_head(0.55)
ICONS['size_m'] = dog_head(0.78)
ICONS['size_l'] = dog_head(1.0)
ICONS['express'] = (
    f'<path d="M36 6 L14 36 h14 l-4 22 L50 26 H35z" fill="{AMBER}" {S}/>'
    f'<path d="M30 16 L21 30" stroke="#fff" stroke-width="3" stroke-linecap="round" opacity="0.8"/>'
)
ICONS['sale'] = (
    f'<circle cx="32" cy="32" r="22" fill="{CORAL}" {S}/>'
    f'<path d="M24 42 L40 22" stroke="#fff" stroke-width="3.6" stroke-linecap="round"/>'
    f'<circle cx="25" cy="25" r="4" fill="#fff"/><circle cx="39" cy="39" r="4" fill="#fff"/>'
)
ICONS['bundle'] = (
    f'<path d="M10 24 h44 v28 h-44z" fill="{BROWN_L}" {S}/>'
    f'<path d="M6 16 h52 v9 h-52z" fill="{CORAL}" {S}/>'
    f'<path d="M28 16 v36 h8 v-36" fill="{AMBER}" {S2}/>'
    f'<path d="M32 16 q-10 -12 -14 -4 q-2 5 14 4 q16 1 14 -4 q-4 -8 -14 4z" fill="{AMBER}" {S2}/>'
)
ICONS['star'] = (
    f'<path d="M32 7 l7.4 15.4 16.6 2.2 -12.2 11.6 3 16.6 -14.8 -8 -14.8 8 3 -16.6 -12.2 -11.6 16.6 -2.2z" fill="{AMBER}" {S}/>'
    f'<path d="M24 26 l4 -1" stroke="#fff" stroke-width="3" stroke-linecap="round"/>'
)
ICONS['instock'] = (
    f'<path d="M8 22 l24 -12 24 12 v24 l-24 12 -24 -12z" fill="{BROWN_L}" {S}/>'
    f'<path d="M8 22 l24 12 24 -12 M32 34 v24" fill="none" {S}/>'
    f'<circle cx="46" cy="44" r="10" fill="{GREEN}" {S2}/>'
    f'<path d="M41.5 44 l3 3 5.5 -6" fill="none" stroke="#fff" stroke-width="2.8" stroke-linecap="round" stroke-linejoin="round"/>'
)
ICONS['country'] = (
    f'<circle cx="32" cy="32" r="22" fill="{BLUE}" {S}/>'
    f'<path d="M18 22 q6 -2 10 2 q2 6 -4 8 q-4 4 0 10 q-6 -2 -8 -10 q-2 -6 2 -10z M36 14 q8 2 12 10 q-6 2 -8 -2 q-6 0 -4 -8z M40 36 q6 -2 8 4 q-2 8 -8 10 q-4 -6 0 -14z" fill="{GREEN}" {S2}/>'
    f'<ellipse cx="22" cy="18" rx="3.4" ry="2" {GL} transform="rotate(-35 22 18)"/>'
)

ICONS['milk'] = (
    f'<path d="M24 8 h16 v6 l4 8 v28 q0 4 -4 4 h-16 q-4 0 -4 -4 v-28 l4 -8z" fill="#fff" {S}/>'
    f'<path d="M20 30 h24 v20 q0 4 -4 4 h-16 q-4 0 -4 -4z" fill="{BLUE}" opacity="0.35"/>'
    f'<path d="M24 14 h16" {S2}/>'
    f'<path d="M26 34 q6 4 12 0" fill="none" {S2}/>'
    + eyes_happy(32, 28, 5, 0.8) +
    f'<rect x="24" y="36" width="3" height="12" rx="1.5" fill="#fff" opacity="0.9"/>'
)
ICONS['brush'] = (
    f'<rect x="10" y="12" width="44" height="18" rx="9" fill="{CORAL}" {S}/>'
    f'<path d="M16 30 v10 M22 30 v12 M28 30 v12 M34 30 v12 M40 30 v12 M46 30 v10" {S2}/>'
    f'<path d="M26 12 q6 -6 12 0" fill="none" {S}/>'
    f'<rect x="16" y="16" width="14" height="4" rx="2" fill="#fff" opacity="0.7"/>'
    f'<path d="M12 50 q8 -4 12 2 q6 -6 12 0 q6 -4 12 2" fill="none" stroke="{BROWN_L}" stroke-width="3" stroke-linecap="round"/>'
)
ICONS['carrier'] = (
    f'<rect x="8" y="20" width="48" height="32" rx="8" fill="{TEAL}" {S}/>'
    f'<path d="M22 20 v-6 q0 -4 4 -4 h12 q4 0 4 4 v6" fill="none" {S}/>'
    f'<rect x="18" y="28" width="28" height="18" rx="5" fill="{CREAM}" {S2}/>'
    f'<path d="M25 28 v18 M32 28 v18 M39 28 v18" stroke="{O}" stroke-width="2"/>'
    f'<path d="M22 40 q3 -3 6 0" fill="none" {S2}/>'
)
ICONS['picky'] = (
    f'<path d="M8 36 h48 q-2 16 -24 16 q-22 0 -24 -16z" fill="{AMBER}" {S}/>'
    f'<path d="M26 14 q0 -6 6 -6 q7 0 7 6 q0 5 -5 7 q-2 1 -2 4" fill="none" stroke="{CORAL}" stroke-width="4.4" stroke-linecap="round"/>'
    f'<circle cx="32" cy="31" r="2.6" fill="{CORAL}"/>'
    f'<path d="M14 40 q2 7 10 9" fill="none" stroke="#fff" stroke-width="2.4" stroke-linecap="round" opacity="0.7"/>'
)
ICONS['odour'] = (
    f'<path d="M18 50 q-6 -18 10 -28 q14 -8 26 -12 q-2 20 -14 30 q-10 8 -22 10z" fill="{GREEN}" {S}/>'
    f'<path d="M20 48 q8 -14 24 -28" fill="none" {S2}/>'
    f'<path d="M8 22 q4 -4 8 0 q4 4 8 0 M6 32 q4 -4 8 0" fill="none" stroke="{BLUE}" stroke-width="3" stroke-linecap="round"/>'
)
ICONS['carton'] = (
    f'<path d="M8 24 h48 v28 h-48z" fill="{BROWN_L}" {S}/>'
    f'<path d="M8 24 l6 -10 h36 l6 10" fill="{BROWN}" {S}/>'
    f'<path d="M26 24 v10 l6 -3 6 3 v-10" fill="#fff" {S2}/>'
    f'<rect x="14" y="40" width="14" height="6" rx="2" fill="#fff" opacity="0.8"/>'
)
ICONS['piece'] = (
    f'<rect x="20" y="16" width="24" height="36" rx="5" fill="{GREY}" {S}/>'
    f'<rect x="20" y="24" width="24" height="18" fill="{TEAL}" stroke="{O}" stroke-width="2.4"/>'
    f'<ellipse cx="32" cy="16" rx="12" ry="3.4" fill="#E6EAEE" {S}/>'
    f'<path d="M27 33 q2.5 -3 5 0 q2.5 3 5 0" fill="none" stroke="#fff" stroke-width="2.4" stroke-linecap="round"/>'
)
ICONS['fish_any'] = ICONS['salmon'].replace(CORAL, '#9FB7C9')

ICONS['pate'] = (
    f'<path d="M8 36 h48 q-2 16 -24 16 q-22 0 -24 -16z" fill="{TEAL}" {S}/>'
    f'<path d="M14 36 q2 -14 18 -16 q16 2 18 16z" fill="{BROWN_L}" {S}/>'
    f'<path d="M22 28 q4 -4 9 -3" fill="none" stroke="#fff" stroke-width="2.6" stroke-linecap="round" opacity="0.8"/>'
    f'<path d="M26 16 q2 -4 6 -2 q3 -5 7 -1" fill="none" {S2}/>'
)
ICONS['gravy'] = (
    f'<path d="M8 32 h48 q-2 20 -24 20 q-22 0 -24 -20z" fill="{TEAL}" {S}/>'
    f'<ellipse cx="32" cy="32" rx="22" ry="5" fill="{BROWN}" {S2}/>'
    f'<rect x="20" y="24" width="9" height="8" rx="2.5" fill="{BROWN_L}" {S2}/><rect x="33" y="23" width="10" height="8" rx="2.5" fill="{BROWN_L}" {S2}/>'
    f'<path d="M44 14 q4 5 0 8 q-4 -3 0 -8z" fill="{BROWN}" {S2}/>'
)
ICONS['jelly'] = (
    f'<path d="M14 26 l18 -10 18 10 v18 l-18 10 -18 -10z" fill="{PINK}" fill-opacity="0.85" {S}/>'
    f'<path d="M14 26 l18 10 18 -10 M32 36 v18" fill="none" {S2}/>'
    f'<path d="M20 30 v8" stroke="#fff" stroke-width="3" stroke-linecap="round" opacity="0.8"/>'
    f'<circle cx="40" cy="42" r="3" fill="{BROWN_L}"/>'
)
ICONS['turkey'] = (
    ''.join(f'<ellipse cx="{32+dx}" cy="{26+dy}" rx="6" ry="13" fill="{c}" {S2} transform="rotate({r} 32 40)"/>'
            for dx, dy, r, c in [(0, -6, -60, CORAL), (0, -6, -30, AMBER), (0, -6, 0, CORAL), (0, -6, 30, AMBER), (0, -6, 60, CORAL)])
    + f'<ellipse cx="32" cy="42" rx="13" ry="12" fill="{BROWN}" {S}/>'
    f'<circle cx="32" cy="30" r="7" fill="{BROWN_L}" {S2}/>'
    + eyes_dot(32, 29, 3, 1.4) +
    f'<path d="M31 32 l3 2 -3 2z" fill="{AMBER}" {S2}/>'
)
ICONS['shrimp'] = (
    f'<path d="M46 14 q12 12 2 26 q-10 12 -26 10 q-10 -2 -12 -10 q8 4 18 0 q10 -6 6 -18 q-2 -6 -8 -8z" fill="{CORAL}" {S}/>'
    f'<path d="M40 22 q4 6 0 12 M33 36 q2 6 -2 10 M24 44 q-2 4 -6 4" fill="none" {S2}/>'
    f'<circle cx="44" cy="18" r="2.2" fill="{O}"/>'
    f'<path d="M48 12 q6 -6 10 -4 M46 12 q2 -8 6 -8" fill="none" {S2}/>'
)
ICONS['tooth'] = (
    f'<path d="M20 12 q6 -4 12 0 q6 -4 12 0 q8 6 4 18 q-2 8 -4 18 q-1 6 -5 6 q-3 0 -4 -8 q-1 -6 -3 -6 q-2 0 -3 6 q-1 8 -4 8 q-4 0 -5 -6 q-2 -10 -4 -18 q-4 -12 4 -18z" fill="#fff" {S}/>'
    f'<path d="M24 20 q2 -4 6 -4" fill="none" stroke="{TEAL_L}" stroke-width="3" stroke-linecap="round"/>'
    f'<path d="M48 8 l2 -4 2 4 4 2 -4 2 -2 4 -2 -4 -4 -2z" fill="{AMBER}" {S2}/>'
)
ICONS['moon'] = (
    f'<path d="M40 8 a22 22 0 1 0 16 34 a18 18 0 1 1 -16 -34z" fill="{AMBER}" {S}/>'
    f'<path d="M22 44 q3 2 6 0" fill="none" {S2}/><path d="M16 36 q2 -2 4 0 M26 38 q2 -2 4 0" fill="none" {S2}/>'
    f'<path d="M50 14 l1.5 -3 1.5 3 3 1.5 -3 1.5 -1.5 3 -1.5 -3 -3 -1.5z" fill="#fff" {S2}/>'
)
ICONS['price_low'] = ICONS['price'] + f'<path d="M50 40 v14 M44 48 l6 6 6 -6" fill="none" stroke="{GREEN_D}" stroke-width="3.4" stroke-linecap="round" stroke-linejoin="round"/>'
ICONS['price_high'] = ICONS['price'] + f'<path d="M50 54 v-14 M44 46 l6 -6 6 6" fill="none" stroke="{CORAL}" stroke-width="3.4" stroke-linecap="round" stroke-linejoin="round"/>'


# ── «كل المنتجات»: the pets and the shelves ──
# ── species ──
ICONS['bird'] = (
    f'<path d="M10 40 q-6 -4 -4 -12 q6 2 10 8z" fill="{GREEN_D}" {S}/>'
    f'<ellipse cx="30" cy="36" rx="20" ry="17" fill="{GREEN}" {S}/>'
    f'<path d="M22 40 q8 10 20 2 q-6 -10 -20 -2z" fill="{GREEN_D}" {S2}/>'
    f'<ellipse cx="34" cy="42" rx="8" ry="6" fill="{CREAM}" opacity="0.9"/>'
    f'<path d="M26 20 q2 -8 8 -8 q-1 4 2 7" fill="{GREEN}" {S2}/>'
    f'<circle cx="38" cy="30" r="3.2" fill="{O}"/><circle cx="39" cy="29" r="1.1" fill="#fff"/>'
    f'<path d="M47 30 q7 1 7 5 q-4 1 -7 -1z" fill="{AMBER}" {S2}/>'
    f'<circle cx="44" cy="37" r="2.4" fill="{PINK}" opacity="0.75"/>'
    f'<path d="M24 53 v5 M34 53 v5" {S2}/>'
    f'<ellipse cx="20" cy="28" rx="3.2" ry="2" {GL} transform="rotate(-30 20 28)"/>'
)
ICONS['small'] = (   # rabbit
    f'<path d="M22 28 q-6 -18 -1 -22 q6 -2 9 20z" fill="#F4EEE8" {S}/>'
    f'<path d="M42 28 q6 -18 1 -22 q-6 -2 -9 20z" fill="#F4EEE8" {S}/>'
    f'<path d="M23.5 22 q-3 -10 -0.5 -13 q2 1 4 12z" fill="{PINK}"/>'
    f'<path d="M40.5 22 q3 -10 0.5 -13 q-2 1 -4 12z" fill="{PINK}"/>'
    f'<ellipse cx="32" cy="40" rx="19" ry="16" fill="#F4EEE8" {S}/>'
    + eyes_dot(32, 37, 7.5, 3.0) +
    f'<path d="M30 43 h4 l-2 2.2z" fill="{PINK}" {S2}/>'
    f'<path d="M32 45 q-2 3 -4.5 1.5 M32 45 q2 3 4.5 1.5" fill="none" {S2}/>'
    f'<circle cx="21" cy="44" r="2.6" fill="{PINK}" opacity="0.7"/><circle cx="43" cy="44" r="2.6" fill="{PINK}" opacity="0.7"/>'
    f'<ellipse cx="22" cy="32" rx="3.2" ry="2" {GL} transform="rotate(-30 22 32)"/>'
)
ICONS['all'] = (     # a paw on a teal tag — «كل المتجر»
    f'<rect x="8" y="8" width="48" height="48" rx="16" fill="{TEAL}" {S}/>'
    f'<ellipse cx="32" cy="38" rx="10" ry="8.5" fill="#fff" {S2}/>'
    + ''.join(f'<ellipse cx="{x}" cy="{y}" rx="4.4" ry="5.4" fill="#fff" {S2} transform="rotate({r} {x} {y})"/>'
              for x, y, r in [(19, 27, -20), (27, 20, -8), (37, 20, 8), (45, 27, 20)]) +
    f'<ellipse cx="18" cy="15" rx="4" ry="2.2" {GL} transform="rotate(-30 18 15)"/>'
)

# ── departments ──
ICONS['food'] = ICONS['dry']
ICONS['litter'] = (
    f'<path d="M8 30 h48 l-5 20 q-1 4 -5 4 h-28 q-4 0 -5 -4z" fill="{BLUE}" {S}/>'
    f'<path d="M14 30 q4 -8 10 -4 q4 -8 10 -2 q6 -6 10 0 q6 -2 6 6" fill="#F3E2C4" {S}/>'
    + ''.join(f'<circle cx="{x}" cy="{y}" r="1.6" fill="{BROWN_L}"/>' for x, y in [(20, 28), (28, 26), (36, 27), (44, 28), (32, 23)]) +
    f'<path d="M40 8 l10 16" stroke="{O}" stroke-width="{3.2}" stroke-linecap="round"/>'
    f'<path d="M44 20 l12 -4 2 8 -10 4z" fill="{AMBER}" {S2}/>'
    f'<path d="M14 36 h36" stroke="#fff" stroke-width="2.4" stroke-linecap="round" opacity="0.7"/>'
)
ICONS['toy'] = (     # yarn ball + mouse tail feel
    f'<circle cx="30" cy="34" r="19" fill="{CORAL}" {S}/>'
    f'<path d="M14 26 q16 4 30 -8 M12 36 q20 2 36 -12 M16 46 q18 -2 30 -20 M24 52 q12 -8 20 -26" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round" opacity="0.75"/>'
    f'<path d="M22 18 q-6 14 4 34" fill="none" {S2}/>'
    f'<path d="M48 44 q8 4 6 10 q-2 5 -8 4" fill="none" {S}/>'
    f'<ellipse cx="21" cy="24" rx="3.2" ry="2" {GL} transform="rotate(-30 21 24)"/>'
)
ICONS['bed'] = (
    f'<path d="M6 40 q0 -14 26 -14 q26 0 26 14 v6 q0 8 -8 8 h-36 q-8 0 -8 -8z" fill="{TEAL}" {S}/>'
    f'<path d="M14 42 q0 -8 18 -8 q18 0 18 8 v2 h-36z" fill="{TEAL_L}" {S2}/>'
    f'<path d="M20 36 q0 -12 12 -12 q12 0 12 12" fill="{ORANGE}" {S2}/>'
    f'<path d="M24 30 l-1 -7 5 4 M40 30 l1 -7 -5 4" fill="{ORANGE}" {S2}/>'
    f'<path d="M26 31 q2 -2 4 0 M34 31 q2 -2 4 0" fill="none" {S2}/>'
    f'<path d="M44 16 h6 l-6 6 h6 M50 8 h4 l-4 4 h4" fill="none" {S2}/>'
    f'<ellipse cx="12" cy="40" rx="3" ry="1.8" {GL} transform="rotate(-30 12 40)"/>'
)
ICONS['collar'] = (
    f'<ellipse cx="32" cy="28" rx="22" ry="14" fill="none" stroke="{O}" stroke-width="10"/>'
    f'<ellipse cx="32" cy="28" rx="22" ry="14" fill="none" stroke="{RED}" stroke-width="6.4"/>'
    + ''.join(f'<circle cx="{x}" cy="{y}" r="1.4" fill="#fff"/>' for x, y in [(14, 22), (22, 16), (42, 16), (50, 22)]) +
    f'<path d="M32 42 v4" {S2}/>'
    f'<circle cx="32" cy="52" r="7.5" fill="{AMBER}" {S}/>'
    f'<path d="M29 51 q3 3 6 0" fill="none" {S2}/>'
    f'<ellipse cx="29.5" cy="49" rx="2" ry="1.2" {GL}/>'
)
ICONS['bowl'] = (
    f'<ellipse cx="32" cy="30" rx="24" ry="7" fill="{BROWN_L}" {S}/>'
    + ''.join(f'<path d="M{x} {y} q3 -3 6 0 q-3 3 -6 0z" fill="{BROWN}" {S2}/>' for x, y in [(18, 28), (27, 26), (36, 27), (42, 30), (24, 31)]) +
    f'<path d="M8 30 q2 20 24 22 q22 -2 24 -22 q-6 7 -24 7 q-18 0 -24 -7z" fill="{CORAL}" {S}/>'
    f'<ellipse cx="32" cy="44" rx="3.4" ry="2.8" fill="#fff"/>' + ''.join(f'<circle cx="{x}" cy="{y}" r="1.5" fill="#fff"/>' for x, y in [(27.5, 40.5), (30.5, 38.6), (33.5, 38.6), (36.5, 40.5)]) +
    f'<path d="M14 38 q3 6 8 8" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round" opacity="0.7"/>'
)
ICONS['groom'] = ICONS['brush']
ICONS['health'] = ICONS['vet']
ICONS['house'] = (   # cage / house
    f'<path d="M10 28 l22 -18 22 18z" fill="{CORAL}" {S}/>'
    f'<rect x="14" y="28" width="36" height="26" rx="3" fill="{AMBER}" {S}/>'
    f'<path d="M26 54 v-12 q6 -6 12 0 v12z" fill="{O}"/>'
    f'<circle cx="32" cy="21" r="3" fill="#fff" {S2}/>'
    f'<ellipse cx="19" cy="33" rx="2.8" ry="1.8" {GL} transform="rotate(-30 19 33)"/>'
)


def svg(name, size=64):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="{size}" height="{size}">'
            f'{ICONS[name]}</svg>')


def write_dart(path):
    import re
    out = ["// GENERATED by tool/facet_stickers.py — do not edit by hand.",
           "// Facet stickers drawn in the character library's language: maroon",
           "// outline, flat fills, one white gloss. Run `python3 tool/facet_stickers.py --dart`.",
           "", "const Map<String, String> facetStickerSvgs = {"]
    for k, body in ICONS.items():
        body = re.sub(r'(<clipPath id="[^"]+">.*?</clipPath>)', r'<defs>\1</defs>', body)
        out.append(f"  '{k}': r'''<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 64 64\">{body}</svg>''',")
    out.append("};")
    open(path, 'w').write("\n".join(out) + "\n")


if __name__ == '__main__' and '--dart' in __import__('sys').argv:
    import os
    write_dart(os.path.join(os.path.dirname(__file__), '..', 'lib', 'core', 'icons', 'facet_stickers.g.dart'))
elif __name__ == '__main__':
    import os
    out = os.path.join(os.path.dirname(__file__), 'icons')
    os.makedirs(out, exist_ok=True)
    cells = ''
    for n in ICONS:
        open(os.path.join(out, n + '.svg'), 'w').write(svg(n))
        cells += f'<div style="display:flex;flex-direction:column;align-items:center;gap:4px;font:12px sans-serif">{svg(n, 72)}<span>{n}</span></div>'
    open(os.path.join(os.path.dirname(__file__), 'icons_sheet.html'), 'w').write(
        f'<html><body style="margin:0;background:#F8F9F7"><div style="display:grid;grid-template-columns:repeat(8,110px);gap:14px;padding:16px">{cells}</div></body></html>')
    print(len(ICONS))

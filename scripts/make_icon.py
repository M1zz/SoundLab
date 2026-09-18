import math, sys
from PIL import Image, ImageDraw, ImageFilter

S = 4096  # supersample, downscale to 1024
out = sys.argv[1]

def lerp(a, b, t): return tuple(int(a[i] + (b[i]-a[i])*t) for i in range(3))

# background: diagonal gradient deep navy -> violet
bg = Image.new("RGB", (S, S))
top, bot = (18, 16, 48), (58, 22, 92)
px = bg.load()
grad = Image.linear_gradient("L").resize((S, S))
bg = Image.composite(Image.new("RGB", (S, S), bot), Image.new("RGB", (S, S), top), grad)

# soft glow in center
glow = Image.new("L", (S, S), 0)
ImageDraw.Draw(glow).ellipse((S*0.18, S*0.22, S*0.82, S*0.86), fill=110)
glow = glow.filter(ImageFilter.GaussianBlur(S*0.12))
bg = Image.composite(Image.new("RGB", (S, S), (255, 120, 80)), bg, glow.point(lambda v: int(v*0.35)))

# spectrum bars
stops = [(255, 149, 0), (255, 70, 120), (175, 82, 222), (50, 200, 255)]
def color_at(t):
    t = max(0, min(1, t)) * (len(stops)-1)
    i = min(int(t), len(stops)-2)
    return lerp(stops[i], stops[i+1], t - i)

n = 11
margin = S * 0.17
span = S - 2*margin
gap = span / n
bw = gap * 0.56
cy = S * 0.5
bars = Image.new("RGB", (S, S), (0, 0, 0))
mask = Image.new("L", (S, S), 0)
md = ImageDraw.Draw(mask)
bd = ImageDraw.Draw(bars)
for i in range(n):
    x = margin + gap*i + (gap-bw)/2
    t = i/(n-1)
    env = math.exp(-((t-0.5)**2)/0.09)
    h = S * (0.08 + 0.52*env*(0.72 + 0.28*math.sin(i*2.3)**2))
    box = (x, cy-h/2, x+bw, cy+h/2)
    md.rounded_rectangle(box, radius=bw/2, fill=255)
    bd.rectangle(box, fill=color_at(t))

# bar glow
g2 = mask.filter(ImageFilter.GaussianBlur(S*0.03)).point(lambda v: int(v*0.55))
bg = Image.composite(bars.filter(ImageFilter.GaussianBlur(S*0.03)), bg, g2)
bg = Image.composite(bars, bg, mask)

# sine wave line across
line = Image.new("L", (S, S), 0)
ld = ImageDraw.Draw(line)
pts = []
for k in range(0, 2001):
    u = k/2000
    x = S*0.08 + u*S*0.84
    a = math.sin(math.pi*u)**1.5
    y = cy + math.sin(u*math.pi*5) * S*0.13 * a
    pts.append((x, y))
r = S*0.009
for k in range(len(pts)-1):
    (x0,y0),(x1,y1) = pts[k], pts[k+1]
    for j in range(4):
        f=j/4; x=x0+(x1-x0)*f; y=y0+(y1-y0)*f
        ld.ellipse((x-r,y-r,x+r,y+r), fill=255)
x,y=pts[-1]; ld.ellipse((x-r,y-r,x+r,y+r), fill=255)
lg = line.filter(ImageFilter.GaussianBlur(S*0.012)).point(lambda v: int(v*0.6))
bg = Image.composite(Image.new("RGB", (S, S), (255, 255, 255)), bg, lg)
bg = Image.composite(Image.new("RGB", (S, S), (255, 250, 240)), bg, line)

bg.resize((1024, 1024), Image.LANCZOS).save(out)

import sys, os, subprocess, html
from PIL import Image
D = sys.argv[1]; OUT = sys.argv[2]
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
os.makedirs(OUT, exist_ok=True)

slides = [
  ("01-prompter", "6.jpg", "Free · No ads", "Read your script.<br><g>Look at the camera.</g>", "Big, smooth text that scrolls at exactly your pace."),
  ("02-customise", "9.jpg", "Make it yours", "Customise<br><g>every detail</g>", "Size, weight, spacing, alignment and width, with every option free."),
  ("03-colours", "8.jpg", "Your look, your rig", "Any colour.<br><g>Any setup.</g>", "Colour presets or your own · Mirror &amp; flip for glass rigs · Picture-in-picture"),
  ("04-included", None, "Everything included", "Free. No ads.<br><g>Nothing locked.</g>", ""),
  ("05-focus", "7.jpg", "Distraction-free", "Big text.<br><g>Zero clutter.</g>", "Controls fade away while you read, so it's just you and your words."),
  ("06-modes", "3.jpg", "Five reading modes", "Your mode.<br><g>Your pace.</g>", "Continuous, single line, paragraph, manual and subtitle, with speed set in seconds per line."),
  ("07-editor", "5.jpg", "Import or write", "Bring any script.<br><g>Time it.</g>", "Import PDF, Word, SRT, TXT or Markdown, then edit with live word count and speaking time."),
  ("08-about", "4.jpg", "Open source", "Made with care.<br><g>Free forever.</g>", "No subscriptions, no sign-up, no tracking. MIT licensed."),
]

CSS = """
*{margin:0;box-sizing:border-box}
html,body{width:1080px;height:1920px;overflow:hidden}
body{font-family:-apple-system,"SF Pro Display","Helvetica Neue",Arial,sans-serif;color:#eef2ff;
 background:
  radial-gradient(900px 700px at 100% 0%,rgba(122,92,255,.42),transparent 62%),
  radial-gradient(800px 700px at 0% 100%,rgba(46,197,246,.22),transparent 62%),
  linear-gradient(180deg,#0b1640 0%,#08112f 55%,#060d26 100%);
 position:relative}
body::before{content:"";position:absolute;inset:0;
 background-image:radial-gradient(rgba(160,185,255,.10) 1.5px,transparent 1.5px);background-size:44px 44px;
 -webkit-mask-image:linear-gradient(180deg,#000,transparent 45%);}
.head{position:absolute;left:0;right:0;top:118px;text-align:center;padding:0 70px;z-index:2}
.kicker{display:inline-flex;align-items:center;gap:12px;font-size:28px;font-weight:700;letter-spacing:.14em;text-transform:uppercase;
 color:#c3b3ff;padding:12px 24px;border-radius:999px;border:1.5px solid rgba(171,149,255,.4);background:rgba(122,92,255,.14)}
.kicker img{width:34px;height:34px;border-radius:9px}
h1{font-size:92px;line-height:1.02;letter-spacing:-.035em;font-weight:800;margin-top:34px}
g{background:linear-gradient(110deg,#2ec5f6,#3d7bff 50%,#8b6cff);-webkit-background-clip:text;color:transparent}
.sub{font-size:34px;line-height:1.38;color:#b4bfe3;font-weight:500;margin:26px auto 0;max-width:900px}
.phone{position:absolute;left:50%;transform:translateX(-50%);top:600px;z-index:1;
 padding:18px;border-radius:78px;background:linear-gradient(160deg,#2a3a7a,#0c1438 60%,#1a2560);
 box-shadow:0 0 0 2px rgba(170,195,255,.22),0 60px 120px -30px rgba(0,0,0,.85),0 0 160px -20px rgba(122,92,255,.55)}
.phone img{display:block;border-radius:60px;width:100%;height:100%;object-fit:cover;object-position:top}
.glow{position:absolute;left:50%;bottom:-120px;width:900px;height:500px;transform:translateX(-50%);
 background:radial-gradient(closest-side,rgba(61,123,255,.35),transparent);z-index:0}
/* included slide */
.big{position:absolute;left:0;right:0;top:500px;display:flex;flex-direction:column;align-items:center;gap:0;z-index:2}
.logo{width:230px;height:230px;border-radius:56px;box-shadow:0 40px 100px -20px rgba(122,92,255,.85);margin-bottom:70px}
.list{list-style:none;padding:0;display:grid;gap:24px;width:800px}
.lockup{position:absolute;left:0;right:0;bottom:120px;display:flex;justify-content:center;align-items:center;gap:22px;font-size:44px;font-weight:800;letter-spacing:-.02em;z-index:2}
.lockup img{width:84px;height:84px;border-radius:21px;box-shadow:0 20px 50px -14px rgba(122,92,255,.8)}
.list li{display:flex;align-items:center;gap:28px;font-size:46px;font-weight:700;padding:28px 36px;border-radius:30px;
 background:linear-gradient(180deg,rgba(20,34,89,.9),rgba(16,28,74,.55));border:1.5px solid rgba(160,185,255,.18)}
.list li span.ic{width:62px;height:62px;flex:none;border-radius:50%;display:grid;place-items:center;
 background:linear-gradient(135deg,#2ec5f6,#7a5cff);font-size:36px;color:#fff}
.list li small{display:block;font-size:28px;font-weight:500;color:#a7b3d9;margin-top:4px}
"""

def phone_box(img):
    w, h = Image.open(os.path.join(D, img)).size
    avail_h = 1920 - 600 - 56 - 36   # phone top at 600px, 56px bottom margin, 36px bezel
    inner_h = avail_h
    inner_w = round(inner_h * w / h)
    if inner_w > 700:
        inner_w = 700; inner_h = round(700 * h / w)
    return inner_w + 36, inner_h + 36

for name, img, kicker, title, sub in slides:
    if img:
        pw, ph = phone_box(img)
        body = f"""
<div class="head">
  <div class="kicker"><img src="logo.png">{kicker}</div>
  <h1>{title}</h1>
  <p class="sub">{sub}</p>
</div>
<div class="glow"></div>
<div class="phone" style="width:{pw}px;height:{ph}px"><img src="{img}"></div>"""
    else:
        items = [
          ("✓","Every feature free","No subscriptions, no paywalls, no limits"),
          ("✓","No ads","Nothing covers your script"),
          ("✓","No sign-up","Open the app and start reading"),
          ("✓","No tracking","Works offline, stays on your phone"),
          ("✓","Camera &amp; floating window","Record yourself or read over any app"),
          ("✓","Open source","Transparent, MIT licensed"),
        ]
        lis = "".join(f'<li><span class="ic">{i}</span><div>{a}<small>{b}</small></div></li>' for i,a,b in items)
        body = f"""
<div class="head">
  <div class="kicker"><img src="logo.png">{kicker}</div>
  <h1>{title}</h1>
</div>
<div class="big"><ul class="list">{lis}</ul></div>
<div class="lockup"><img src="logo.png">Teleprompter</div>
<div class="glow"></div>"""
    page = f'<!doctype html><html><head><meta charset="utf-8"><style>{CSS}</style></head><body>{body}</body></html>'
    hp = os.path.join(D, name + ".html")
    open(hp, "w").write(page)
    png = os.path.join(OUT, name + ".png")
    subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars",
                    "--force-device-scale-factor=1", "--window-size=1080,1920",
                    "--virtual-time-budget=1000", f"--screenshot={png}", "file://" + hp],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
    im = Image.open(png).convert("RGB"); im.save(png, optimize=True)
    print(name, im.size, round(os.path.getsize(png)/1e6, 2), "MB")

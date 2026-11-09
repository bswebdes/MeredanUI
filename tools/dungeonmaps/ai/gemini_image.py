"""Gemini image generation (Nano Banana Pro) for mUI dungeon maps: gemini_image.py <out.png> <model> <prompt.txt> <img1> [img2 ...]. Key: ~/.config/gemini/key"""
import sys, json, base64, urllib.request, os, time
out, model, promptf, imgs = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4:]
key = open(os.path.expanduser('~/.config/gemini/key')).read().strip()
parts = [{"text": open(promptf).read()}]
for p in imgs:
    parts.append({"inline_data": {"mime_type": "image/png", "data": base64.b64encode(open(p, 'rb').read()).decode()}})
body = {"contents": [{"parts": parts}],
        "generationConfig": {"responseModalities": ["TEXT", "IMAGE"], "imageConfig": {"aspectRatio": "3:2", "imageSize": "2K"}}}
req = urllib.request.Request(f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent",
                             data=json.dumps(body).encode(), headers={"Content-Type": "application/json", "x-goog-api-key": key})
t = time.time()
try:
    r = json.load(urllib.request.urlopen(req, timeout=300))
except urllib.error.HTTPError as e:
    print('HTTP', e.code, e.read().decode()[:500]); sys.exit(1)
n = 0
for part in r['candidates'][0]['content']['parts']:
    if 'inlineData' in part:
        n += 1; fn = out if n == 1 else out.replace('.png', f'_{n}.png')
        open(fn, 'wb').write(base64.b64decode(part['inlineData']['data'])); print('bild', fn)
    elif 'text' in part and not part.get('thought'):
        print('text:', part['text'][:300])
print('usage', r.get('usageMetadata'), round(time.time() - t), 's')

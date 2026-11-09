"""side-by-side: Blizzard art (left) vs our map (right) for given inst floors"""
import sys, re, os, subprocess, numpy as np
from PIL import Image
src=open('wmomap.py').read().replace('\nmain()\n','\n'); W={}; exec(compile(src,'w','exec'),W)
lua=open('/home/benja/wow-addons/MeredanUI/Map/DungeonMapData.lua',encoding='utf-8').read()
inst=int(sys.argv[1]); out=sys.argv[2]
m=re.search(r'^    \[%d\] = \{(.*?)^    \},'%inst,lua,re.M|re.S)
fl=re.findall(r'tiles = \{ ([\d, ]+) \}',m.group(1))
rows=[]
for fi,t in enumerate(fl,1):
    ids=[int(x) for x in t.split(',')]; img=np.zeros((768,1024,4),np.uint8)
    for k,f in enumerate(ids):
        p=f'cache/{f}.bin'
        if not os.path.exists(p): subprocess.run(['curl','-s','-A','MeredanUI','-o',p,f'https://wago.tools/api/casc/{f}?version=1.60.1.70862'])
        w,h,px=W['decode_blp'](open(p,'rb').read()); a=np.frombuffer(bytes(px),np.uint8).reshape(h,w,4)
        img[(k//4)*256:(k//4)*256+h,(k%4)*256:(k%4)*256+w]=a
    b=Image.fromarray(img[:668,:1002,:3]).resize((600,400))
    o=Image.open(f'maps/{inst}_{fi}.png'); bg=Image.new('RGBA',o.size,(20,20,20,255)); bg.alpha_composite(o); o=bg.convert('RGB').resize((600,400))
    r=Image.new('RGB',(1210,400),(60,60,60)); r.paste(b,(0,0)); r.paste(o,(610,0)); rows.append(r)
c=Image.new('RGB',(1210,len(rows)*410),(60,60,60))
for k,r in enumerate(rows): c.paste(r,(0,k*410))
c.save(out)

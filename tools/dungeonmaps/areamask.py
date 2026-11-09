import struct, json, os, subprocess, sys, csv
BUILD="1.60.1.70862"; TILE=1600/3; CH=TILE/16
inst=sys.argv[1]; d=f'new/{inst}'
area=[x for x in csv.DictReader(open('ej/Area.csv',encoding='utf-8')) if x['ContinentID']==inst]
ids={int(x['ID']) for x in area}
wdt=json.load(open(f'{d}/info.json'))
# need root ADT fdids: re-read WDT MAID
import glob
maid=None
for fn in glob.glob(f'{d}/*.bin'):
    b=open(fn,'rb').read(12)
    if b[:4]==b'REVM':
        data=open(fn,'rb').read(); o=0
        while o+8<=len(data):
            t=data[o:o+4][::-1].decode('latin1'); n=struct.unpack('<I',data[o+4:o+8])[0]
            if t=='MAID': maid=data[o+8:o+8+n]; break
            o+=8+n
        if maid: break
cells=[]
for i in range(4096):
    v=struct.unpack('<8I',maid[i*32:(i+1)*32])
    if not v[0]: continue
    tx,ty=i%64,i//64
    p=f'{d}/{v[0]}.bin'
    if not os.path.exists(p): subprocess.run(['curl','-s','-A','MeredanUI','-o',p,f'https://wago.tools/api/casc/{v[0]}?version={BUILD}'])
    data=open(p,'rb').read(); o=0
    while o+8<=len(data):
        t=data[o:o+4][::-1].decode('latin1'); n=struct.unpack('<I',data[o+4:o+8])[0]
        if t=='MCNK':
            ix,iy=struct.unpack('<II',data[o+12:o+20]); aid=struct.unpack('<I',data[o+8+0x34:o+8+0x38])[0]
            if aid in ids: cells.append((tx*TILE+ix*CH, ty*TILE+iy*CH, aid))
        o+=8+n
if cells:
    xs=[c[0] for c in cells]; zs=[c[1] for c in cells]
    print(inst,'chunks',len(cells),'bbox X',round(min(xs)),round(max(xs)+CH),'Z',round(min(zs)),round(max(zs)+CH))
else: print(inst,'no chunks')
json.dump(cells,open(f'{d}/cells.json','w'))

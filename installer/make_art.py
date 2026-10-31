import sys, numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter
OUT='/home/claude/mci/art/'; import random; LOGO='/home/claude/mc/site/public/icons/icon-512.png'
F='/usr/share/fonts/opentype/inter/Inter-%s.otf'
S=2  # рисуем в 2x
def font(w,sz): return ImageFont.truetype(F%w, int(sz*S))
def hexc(h): return tuple(int(h[i:i+2],16) for i in (1,3,5))
BG=hexc('#050814'); PANEL=hexc('#0a0f21')
def canvas(w,h,col): return Image.new('RGB',(w*S,h*S),col)
def glow(im,cx,cy,r,col,strength=1.0):
    a=np.asarray(im).astype(np.float32)
    h,w=a.shape[:2]; y,x=np.mgrid[0:h,0:w]
    d=np.sqrt((x-cx*S)**2+(y-cy*S)**2)/(r*S)
    k=np.clip(1-d,0,1)**2*strength
    for c in range(3): a[:,:,c]+= (col[c]-a[:,:,c]*0)*k*0.55
    return Image.fromarray(np.clip(a,0,255).astype(np.uint8))
def logo_tile(size,radius=0.24):
    L=Image.open(LOGO).convert('RGB').resize((size*S,size*S),Image.LANCZOS)
    m=Image.new('L',L.size,0); ImageDraw.Draw(m).rounded_rectangle([0,0,L.width-1,L.height-1],radius=int(radius*L.width),fill=255)
    return L,m
def paste_logo(im,x,y,size):
    L,m=logo_tile(size); im.paste(L,(x*S,y*S),m)
    d=ImageDraw.Draw(im); d.rounded_rectangle([x*S,y*S,(x+size)*S,(y+size)*S],radius=int(.24*size*S),outline=(60,110,255),width=S)
def text(im,xy,t,w,sz,col,anchor='la'):
    ImageDraw.Draw(im).text((xy[0]*S,xy[1]*S),t,font=font(w,sz),fill=col,anchor=anchor)
def save(im,name,w,h):
    im.resize((w*S,h*S),Image.LANCZOS).save(OUT+name,'BMP') if False else im.save(OUT+name,'BMP')
def vgrad(im,y0,y1,c0,c1):
    a=np.asarray(im).astype(np.float32)
    for y in range(int(y0*S),int(y1*S)):
        t=(y-y0*S)/max(1,(y1-y0)*S); a[y,:,:]=np.array(c0)*(1-t)+np.array(c1)*t
    return Image.fromarray(a.astype(np.uint8))
def dots(im,w,h,step=26,col=(24,34,70),r=1):
    d=ImageDraw.Draw(im)
    for x in range(step//2,w,step):
        for y in range(step//2,h,step): d.ellipse([(x-r)*S,(y-r)*S,(x+r)*S,(y+r)*S],fill=col)

def stars(im,w,h,n,seed,maxa=150):
    rnd=random.Random(seed); d=ImageDraw.Draw(im)
    for _ in range(n):
        x,y=rnd.uniform(0,w),rnd.uniform(0,h); r=rnd.choice([.6,.8,1,1.3]); k=rnd.uniform(.25,1)
        c=(int(90+120*k),int(120+110*k),255); d.ellipse([(x-r)*S,(y-r)*S,(x+r)*S,(y+r)*S],fill=tuple(int(v*maxa/255*k+BG[i]*(1-k*maxa/255)) for i,v in enumerate(c)))
def chip(im,x,y,label,col):
    f=font('SemiBold',11); w=int(ImageDraw.Draw(im).textlength(label,font=f)/S)+26
    ov=Image.new('RGB',im.size,(0,0,0)); m=Image.new('L',im.size,0); md=ImageDraw.Draw(m)
    md.rounded_rectangle([x*S,y*S,(x+w)*S,(y+28)*S],radius=14*S,fill=70)
    md.rounded_rectangle([x*S,y*S,(x+w)*S,(y+28)*S],radius=14*S,outline=170,width=S)
    ov=Image.new('RGB',im.size,col); im.paste(ov,(0,0),m)
    ImageDraw.Draw(im).text(((x+13)*S,(y+14)*S),label,font=f,fill=(225,232,255),anchor='lm'); return w+10
# --- hero (страница приветствия) 610x416: сверху афиша, ниже мягкое свечение
W,H=610,416
im=canvas(W,H,BG)
im=glow(im,120,40,300,(30,70,255),1.0); im=glow(im,520,30,260,(130,60,255),0.9); im=glow(im,330,150,220,(20,160,255),0.5)
im=glow(im,600,420,200,(40,80,255),0.35)
# затемнение к низу, чтобы пузыри читались
a=np.asarray(im).astype(np.float32)
for y in range(im.height):
    t=min(1,max(0,(y/S-70)/110)); a[y]=a[y]*(1-t)+np.array(BG)*t
im=Image.fromarray(a.astype(np.uint8)); dots(im,W,160,24,(30,44,96))
paste_logo(im,28,22,84)
text(im,(130,32),'MinoChat',"Bold",34,(240,240,255))
text(im,(131,76),'Мессенджер нового поколения',"Medium",13.5,(150,170,255))
stars(im,W,170,70,3)
cx=131
for lab,col in [('Чаты',(47,107,255)),('Звонки',(0,200,255)),('Группы',(150,80,255)),('Стикеры',(236,72,153))]: cx+=chip(im,cx,98,lab,col)
text(im,(131,140),'Приложение для Windows  ·  работает в трее',"Regular",11.5,(130,145,200))
save(im,'bg_a.bmp',W,H)

# --- фон остальных страниц
im=canvas(W,H,BG); im=glow(im,590,10,230,(40,80,255),0.45); im=glow(im,20,420,230,(120,60,255),0.35)
dots(im,W,H,28,(14,20,44)); stars(im,W,H,60,7,110)
save(im,'bg_b.bmp',W,H)

# --- боковая панель: верх (логотип) и низ
sw=250
top=canvas(sw,84,PANEL); top=glow(top,40,30,170,(30,70,255),0.9); top=glow(top,230,0,120,(130,60,255),0.5)
paste_logo(top,16,18,46); text(top,(72,19),'MinoChat',"Bold",16.5,(240,240,255)); text(top,(73,45),'установка',"Medium",10.5,(139,138,168))
save(top,'side_top.bmp',sw,84)
bot=canvas(sw,126,PANEL); bot=glow(bot,40,150,200,(30,70,255),0.8); bot=glow(bot,240,150,160,(130,60,255),0.5)
d=ImageDraw.Draw(bot); d.line([(18*S,10*S),((sw-18)*S,10*S)],fill=(28,38,76),width=S)
text(bot,(18,22),'Версия 4.0',"SemiBold",11,(200,205,240)); text(bot,(18,42),'speeky-a0653.web.app',"Regular",9.5,(110,120,165))
text(bot,(18,92),'Сделано с ♥ для общения',"Regular",9.5,(139,138,168))
save(bot,'side_bot.bmp',sw,126)

# --- шапка (акцентная линия)
im=canvas(W,3,BG); a=np.asarray(im).astype(np.float32)
cols=[(47,107,255),(0,200,255),(150,80,255)]
for x in range(a.shape[1]):
    t=x/a.shape[1]*2; i=min(1,int(t)); f=t-i
    c=np.array(cols[i])*(1-f)+np.array(cols[i+1])*f; a[:,x,:]=c
save(Image.fromarray(a.astype(np.uint8)),'accent.bmp',W,3)

# --- аватарки (круглые, с градиентом и буквой)
def avatar(name,c0,c1,letter=None,logo=False,bgc=PANEL):
    D=40; im=canvas(D,D,bgc)
    if logo:
        L,m=logo_tile(D,0.5); im.paste(L,(0,0),m)
    else:
        g=np.zeros((D*S,D*S,3),np.float32)
        for y in range(D*S):
            t=y/(D*S); g[y,:,:]=np.array(c0)*(1-t)+np.array(c1)*t
        gi=Image.fromarray(g.astype(np.uint8)); m=Image.new('L',gi.size,0); ImageDraw.Draw(m).ellipse([0,0,gi.width-1,gi.height-1],fill=255)
        im.paste(gi,(0,0),m); text(im,(D/2,D/2+.5),letter,"Bold",17,(255,255,255),'mm'); ImageDraw.Draw(im).ellipse([0,0,D*S-1,D*S-1],outline=tuple(min(255,int(v*1.2)) for v in c1),width=2*S)
    save(im,name,D,D)
avatar('av0.bmp',0,0,logo=True)
for i,(c0,c1,l) in enumerate([((6,178,182),(40,120,255),'П'),((245,158,11),(244,90,60),'Н'),((236,72,153),(150,70,255),'У'),((16,185,129),(52,211,153),'Г')],1):
    avatar('av%d.bmp'%i,c0,c1,l)
# для шапки и баблов - тот же логотип на фоне CPANEL
# --- бейдж «готово»
D=96; im=canvas(D+60,D+40,BG); im=glow(im,(D+60)/2,(D+40)/2,70,(20,200,140),1.0)
d=ImageDraw.Draw(im); cx,cy=(D+60)//2*S,(D+40)//2*S; r=34*S
d.ellipse([cx-r,cy-r,cx+r,cy+r],fill=(16,185,129),outline=(110,240,200),width=2*S)
d.line([(cx-14*S,cy+1*S),(cx-4*S,cy+11*S),(cx+16*S,cy-10*S)],fill=(255,255,255),width=6*S,joint='curve')
for p in [(cx-14*S,cy+1*S),(cx-4*S,cy+11*S),(cx+16*S,cy-10*S)]: d.ellipse([p[0]-3*S,p[1]-3*S,p[0]+3*S,p[1]+3*S],fill=(255,255,255))
rnd=random.Random(5)
for _ in range(26):
    ang=rnd.uniform(0,6.283); rr=rnd.uniform(44,70); px=cx+int(np.cos(ang)*rr*S); py=cy+int(np.sin(ang)*rr*S*.8); q=rnd.choice([2,3,4])
    d.ellipse([px-q,py-q,px+q,py+q],fill=rnd.choice([(52,211,153),(110,240,200),(47,107,255),(236,72,153),(245,158,11)]))
save(im,'ok.bmp',D+60,D+40)
print('ok')

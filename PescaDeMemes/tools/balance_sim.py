# Simulación de balance de Pesca de Memes (réplica de FishingService.generateDive / rollRarity / pickMeme / Value).
import random, math, statistics, sys
PLOT=float(sys.argv[1]) if len(sys.argv)>1 else 0.08  # = GameConfig.PlotIncomeRate
PRICES=[float(x) for x in sys.argv[2].split(',')] if len(sys.argv)>2 else None
R = {  # rarity: order, odds, base, xp
 'COMMON':(1,60,40,10),'UNCOMMON':(2,25,150,20),'RARE':(3,10,600,45),'EPIC':(4,4,2500,100),
 'MYTHIC':(5,1.5,9000,180),'LEGENDARY':(6,0.6,25000,300),'SECRET':(7,0.02,200000,1200),'GOD':(8,0,2000000,5000)}
ORDER=['COMMON','UNCOMMON','RARE','EPIC','MYTHIC','LEGENDARY','SECRET','GOD']
M=[('NoobFeliz','COMMON',1,6,0),('PerroBonk','COMMON',2,8,0),('Stonks','COMMON',1,7,0),('Sospechoso','UNCOMMON',5,20,0),
 ('PatoInfinito','UNCOMMON',5,25,0),('GatoPianista','RARE',20,60,0),('Moai','EPIC',90,250,0),('GigaChad','LEGENDARY',200,900,200),
 ('GatoPop','MYTHIC',40,180,100),('Platano','MYTHIC',30,150,100),('Hamster','MYTHIC',25,120,100),
 ('Tiburon','SECRET',300,1500,300),('Capibara','SECRET',200,1000,300),('Cocodrilo','SECRET',400,2000,400)]
# precios por defecto = Config/Rods.lua (VS 0.2)
RODS=[('Palo',0,12,1,50,6,1.0,1,1),('Bambu',400,25,1,80,7,1.02,1,1),('Fibra',2500,50,2,150,10,1.05,1,1),('Pirata',12000,90,2,200,12,1.07,2,1),
 ('Turbo',40000,150,3,300,16,1.1,1,1),('Coral',120000,250,3,400,19,1.14,1,1),('Abisal',400000,400,4,600,25,1.2,1,1),
 ('Glaciar',1.2e6,700,4,600,26,1.26,1,1),('Volcanica',3e6,1100,5,600,27,1.32,1,1.5),('CyberNeon',7.5e6,1700,5,600,28,1.38,1,1),
 ('Dragon',18e6,2500,6,600,29,1.45,1,2.5),('Galactica',45e6,3500,6,600,30,1.52,1,1),('Arcoiris',100e6,5000,7,600,31,1.6,2.5,1),
 ('Diamante',220e6,7000,7,600,32,1.68,3,1),('Brainrot',500e6,10000,8,600,33,1.77,1,2),('Divina',1.2e9,15000,8,600,35,1.88,3,3)]
if PRICES:
    RODS=[(r[0],PRICES[i])+r[2:] for i,r in enumerate(RODS)]
LAYERS=[(0,1),(50,5),(150,15),(300,30)]
def unlocked(level):
    for frm,req in LAYERS:
        if level<req: return frm
    return 600
def exists(r,d): return any(m[1]==r and m[4]<=d for m in M)
def roll_rarity(luck,d):
    w={r:(R[r][1]*luck**(R[r][0]-1) if exists(r,d) else 0) for r in ORDER}
    x=random.random()*sum(w.values())
    for r in ORDER:
        x-=w[r]
        if x<=0 and w[r]>0: return r
    return 'COMMON'
def pick(r,d):
    o=R[r][0]
    for k in range(o,0,-1):
        c=[m for m in M if m[1]==ORDER[k-1] and m[4]<=d]
        if c: return random.choice(c)
    return M[0]
def weight(m,gm):
    if random.random()<0.04*gm: return m[3]*(1.3+3.7*random.random()**2)
    return m[2]+(m[3]-m[2])*random.random()**2.2
def value(m,w,g): return max(1,math.floor(R[m[1]][2]*(w/((m[2]+m[3])/2))**0.85*(3 if g else 1)))
def dive(rod,level):
    name,price,cap,hooks,maxd,speed,luck,gold,giant=rod
    md=min(maxd,unlocked(level)); span=md-2.5
    n=max(6,min(40,math.floor(md/speed*1.6)))
    base=luck*(1+0.4*0.7)
    memes=[]
    for i in range(n):
        d=2+span*(i+1-random.uniform(0.1,0.9))/n
        m=pick(roll_rarity(base*(1+d/600),d),d)
        w=weight(m,giant); g=random.random()<0.01*gold
        memes.append((value(m,w,g),w,m))
    # el jugador va a por los más valiosos que puede sacar (≤1.5× su capacidad), y gana el 75 % de las peleas
    ok=[x for x in memes if x[1]<=cap*1.5]
    ok.sort(key=lambda x:-x[0])
    got=[]
    for x in ok:
        if len(got)>=hooks: break
        if x[1]>cap and random.random()>0.75: continue
        if random.random()<0.85: got.append(x)  # a veces se le escapa al pasar
    secs=1.4+md/speed+1.2+3+5*len([g for g in got if g[1]>cap])+6  # bajar + fondo + subir + peleas + lanzar/tarjeta
    return sum(g[0] for g in got), sum(R[g[2][1]][3] for g in got), secs, got
def xp_for(l): return 60+(l-1)*40+4*(l-1)**2
random.seed(7)
total=0
print(f"{'caña':10} {'precio':>9} {'nivel':>5} {'🪙/inmersión':>13} {'seg':>5} {'🪙/min venta':>12} {'parcela/min':>11} {'min a la siguiente':>18}")
level=1; xp=0
for i,rod in enumerate(RODS):
    # nivel realista al llegar a esta caña: simulamos experiencia acumulada abajo
    vals=[];secs=[];xps=[];best8=[]
    for _ in range(400):
        v,x,s,got=dive(rod,level); vals.append(v); secs.append(s); xps.append(x); best8+= [g[0] for g in got]
    cpd=statistics.mean(vals); sec=statistics.mean(secs); cpm=cpd/sec*60
    best8.sort(reverse=True); plot=sum(best8[:8])*PLOT  # 8 mejores expuestos, PLOT por minuto
    nxt=RODS[i+1][1] if i+1<len(RODS) else None
    mins=(nxt/(cpm+plot*0.5)) if nxt else 0  # la parcela cuenta a medias (se va llenando)
    print(f"{rod[0]:10} {rod[1]:>9.0f} {level:>5} {cpd:>13.0f} {sec:>5.0f} {cpm:>12.0f} {plot:>11.0f} {mins:>18.1f}")
    # avanzar nivel durante ese tiempo
    total+=mins
    xpm=statistics.mean(xps)/sec*60
    xp+=xpm*mins
    while xp>=xp_for(level): xp-=xp_for(level); level+=1
print(f"TOTAL hasta la Divina: {total/60:.1f} h")

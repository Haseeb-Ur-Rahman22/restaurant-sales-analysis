import numpy as np, pandas as pd
rng = np.random.default_rng(42)   # fixed seed = reproducible

TARGET_LINES = 1_000_000

# ---------- menu (unchanged from original) ----------
menu = pd.read_csv("/mnt/user-data/uploads/Restaurant_items.csv")
ids = menu["menu_item_id"].to_numpy()
price = dict(zip(menu["menu_item_id"], menu["price"]))
idx_of = {mid:i for i,mid in enumerate(ids)}

# ---------- branches (clear ranking) ----------
branches = ["Banjara Hills","Gachibowli","Charminar","Mehdipatnam","Attapur"]
branch_w = np.array([0.25,0.24,0.19,0.17,0.15])
# per-branch platform mix (IT hubs skew aggregator, old city skews local)
plat = ["local","Swiggy","Zomato"]
branch_plat = {
 "Banjara Hills":[0.34,0.34,0.32],
 "Gachibowli":  [0.32,0.35,0.33],
 "Charminar":   [0.55,0.23,0.22],
 "Mehdipatnam": [0.45,0.28,0.27],
 "Attapur":     [0.44,0.29,0.27],
}
# payment given platform
pay_given = {"local":[0.55,0.45], "Swiggy":[0.03,0.97], "Zomato":[0.03,0.97]}  # cash, online
# status given platform
stat = ["complete","cancelled","refunded"]
stat_given = {"local":[0.95,0.03,0.02], "Swiggy":[0.86,0.09,0.05], "Zomato":[0.85,0.10,0.05]}

# ---------- dates with growth + weekend + seasonality ----------
dates = pd.date_range("2024-01-01","2025-12-31",freq="D")
dw = np.ones(len(dates))
dw *= np.where(dates.year==2025, 1.7, 1.0)                 # 2025 growth
dw *= np.where(dates.weekday>=5, 1.35, 1.0)                # weekend lift
month_factor = {3:1.25, 4:1.10, 12:1.15}                  # Ramadan/festive/year-end
dw *= np.array([month_factor.get(m,1.0) for m in dates.month])
dw /= dw.sum()

# ---------- dayparts ----------
dayparts = ["breakfast","lunch","snack","dinner","latenight"]
dp_w = np.array([0.16,0.30,0.15,0.32,0.07])
dp_hours = {"breakfast":[7,8,9,10],"lunch":[12,13,14,15],"snack":[16,17,18],
            "dinner":[19,20,21,22],"latenight":[23,0,1]}

# ---------- item popularity: two profiles ----------
day_w = {101:.05,102:.05,103:.05,104:.05,105:.05,
 106:3.0,107:2.2,108:1.0,109:1.1,110:0.8,
 111:2.6,112:2.0,113:1.1,114:1.2,115:1.2,116:0.7,
 117:1.8,118:1.4,119:0.7,120:0.7,121:1.8,122:1.0,123:1.3,
 124:1.0,125:1.0,126:0.6,127:1.1,
 128:2.8,129:1.6,130:1.1,131:1.2,132:1.0}
morn_w = {101:3.0,102:2.0,103:2.4,104:2.2,105:2.2,
 106:0.4,107:0.3,108:0.2,109:0.25,110:0.15,
 111:0.2,112:0.2,113:0.2,114:0.2,115:0.2,116:0.2,
 117:1.2,118:1.5,119:0.3,120:0.3,121:0.3,122:0.3,123:0.3,
 124:0.2,125:0.2,126:0.2,127:0.2,
 128:3.5,129:1.2,130:0.4,131:0.5,132:0.8}
day_p  = np.array([day_w[m]  for m in ids]); day_p/=day_p.sum()
morn_p = np.array([morn_w[m] for m in ids]); morn_p/=morn_p.sum()

# ---------- generate orders ----------
N = 460_000
ipo = rng.choice([1,2,3,4,5,6], size=N, p=[0.34,0.30,0.18,0.10,0.05,0.03])
b_i   = rng.choice(len(branches), size=N, p=branch_w)
# platform depends on branch
p_i = np.empty(N, dtype=int)
for bi,bn in enumerate(branches):
    mask = b_i==bi
    p_i[mask] = rng.choice(3, size=mask.sum(), p=branch_plat[bn])
# payment depends on platform
pay_i = np.empty(N,dtype=int)
for pi,pn in enumerate(plat):
    mask=p_i==pi; pay_i[mask]=rng.choice(2,size=mask.sum(),p=pay_given[pn])
# status depends on platform
st_i = np.empty(N,dtype=int)
for pi,pn in enumerate(plat):
    mask=p_i==pi; st_i[mask]=rng.choice(3,size=mask.sum(),p=stat_given[pn])
# date + daypart + time
d_i  = rng.choice(len(dates), size=N, p=dw)
dp_i = rng.choice(len(dayparts), size=N, p=dp_w)
hh = np.array([rng.choice(dp_hours[dayparts[x]]) for x in range(len(dayparts))], dtype=object)
hour = np.empty(N,dtype=int)
for x in range(len(dayparts)):
    mask=dp_i==x; hour[mask]=rng.choice(dp_hours[dayparts[x]], size=mask.sum())
minute=rng.integers(0,60,N); second=rng.integers(0,60,N)

# order-level strings
odate = pd.Series(pd.to_datetime(dates[d_i])).dt.strftime("%d-%m-%Y").to_numpy()
tstamp = pd.to_datetime(dict(year=[2000]*N,month=[1]*N,day=[1]*N,hour=hour,minute=minute,second=second))
otime = tstamp.dt.strftime("%I:%M:%S %p").to_numpy()

# ---------- expand to line items ----------
order_id = np.repeat(np.arange(1,N+1), ipo)
L = order_id.size
rep = lambda a: np.repeat(a, ipo)
odate_l=rep(odate); otime_l=rep(otime)
branch_l=np.array(branches)[rep(b_i)]
plat_l=np.array(plat)[rep(p_i)]
pay_l=np.array(["cash","online"])[rep(pay_i)]
stat_l=np.array(stat)[rep(st_i)]
dp_l=rep(dp_i)

# item id per line: morning profile only for breakfast daypart
item_l=np.empty(L,dtype=int)
mmask = dp_l==0  # breakfast
item_l[mmask]  = rng.choice(ids, size=mmask.sum(), p=morn_p)
item_l[~mmask] = rng.choice(ids, size=(~mmask).sum(), p=day_p)
qty_l = rng.choice([1,2,3,4,5], size=L, p=[0.45,0.30,0.15,0.07,0.03])

# ---------- truncate to exactly 1,000,000 ----------
L = TARGET_LINES
df = pd.DataFrame({
 "order_details_id": np.arange(1,L+1),
 "order_id": order_id[:L],
 "order_date": odate_l[:L],
 "order_time": otime_l[:L],
 "item_id": item_l[:L],
 "Payment Method": pay_l[:L],
 "Platform": plat_l[:L],
 "Branch": branch_l[:L],
 "Quantity": qty_l[:L],
 "Order Status": stat_l[:L],
})
df.to_csv("Restaurant_Orders.csv", index=False)
menu.to_csv("Restaurant_items.csv", index=False)
print("rows:", len(df), "orders:", df.order_id.nunique())

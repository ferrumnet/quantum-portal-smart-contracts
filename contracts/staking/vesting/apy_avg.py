import time

SEC_IN_Y = 3600*24*365

BASE_T = int(time.time())

def DT(days):
    return 24*3600*days

def T(days):
    return BASE_T + DT(days)

def days(dt):
    return int(dt / 3600 / 24)

def dt(t):
    return days(t-BASE_T)

def apy(dt, a, total):
    apy = SEC_IN_Y * a / (dt * total)
    print(f'APY if rew {a:5.0f} is given on: {days(dt):3} for total {total:5}: {apy:.3f}')
    return apy

# Rate moved to a different date
def r2(dt2, dt1, r1):
    return dt2 * r1 / dt1

def test1():
    total = 1000
    rew = 200
    apy(DT(365), 100, 100) # 1.00
    apy(DT(60), 100, 100) # 1.00
    apy(DT(60), rew, total) # ~300

    apy(DT(365), r2(DT(60), DT(365), rew), total) # 0.33

def staking_apy(stakes, t, rew):
    # Stakes is [(t, amount)]
    sv = sum([pv for (_,pv) in stakes if pv > 0])
    svf = sum([pv for (_,pv) in stakes])
    avg_t = sum([1.0* pt * pv for (pt, pv) in stakes if pv > 0]) / sv
    print('T IS ',avg_t,  days(avg_t-BASE_T))
    return apy(t-avg_t, rew, svf)

def test_stk():
    stakes = [(T(0), 200)]
    apy0 = staking_apy(stakes, T(365), 200)
    print(f'Staking using APY 365: {apy0:.4f} vs {apy(DT(365), 100, 100)}')
    stakes = [(T(365-60), 1000)]
    apy0 = staking_apy(stakes, T(365), 200)
    print(f'Staking using APY 60: {apy0:.4f} vs {apy(DT(60), 200, 1000):.4f}')

    stakes = [
        (T(30), 100),
        (T(31), 50),
        (T(32), 200),
        (T(34), 50)
    ]
    print("1. STAKE ARE ", stakes)
    apy1 = staking_apy(stakes, T(365+30), 100)
    print(f'1. Staking using APY: {apy1:.4f}')
    stakes = [
        (T(30), 100),
        (T(90), 50),
        (T(160), 200),
        (T(190), 50)
    ]
    print("2. STAKE ARE ", stakes)
    apy1 = staking_apy(stakes, T(365+30), 100)
    print(f'2. Staking using APY: {apy1:.4f}')

def test_stk_neg():
    stakes = [
        (T(50), 100),
        (T(100), 100),
    ]
    print("1. STAKE ARE ", stakes)
    apy1 = staking_apy(stakes, T(300), 100)
    print(f'1. Staking using APY: {apy1:.4f}')

    stakes = [
        (T(50), 100),
        (T(100), 100),
        (T(150), -100),
    ]
    print("2. STAKE ARE ", stakes)
    apy1 = staking_apy(stakes, T(300), 100)
    print(f'2. Staking using APY: {apy1:.4f}')

    stakes = [
        (T(50), 100),
        (T(100), 100),
        (T(150), -100),
        (T(200), -50),
    ]
    print("3. STAKE ARE ", stakes)
    apy1 = staking_apy(stakes, T(300), 100)
    print(f'3. Staking using APY: {apy1:.4f}')


#test1()
#test_stk()
test_stk_neg()
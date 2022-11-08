import time

"""
The vesting algorithm for open staking:

Problem definition

1. Define vesting periods
2. Each vesting period has a time, set reward amount, and can be pro-rated.
3. At the time of takeRewards, user will receive rewards from the last period completely, plus pro-rated
   reward for the next period (if any).
4. Any unspentRewards from each period (rewards that are not spent due to pro-rated reward taking) can be
   claimed back by the admin.
5. Actual APY can be calculated
"""

class VestingItem:
   def __init__(self, end_time, reward_amount, has_apy, locked):
        self.end_time = end_time
        self.reward_amount = reward_amount
        self.has_apy = has_apy
        self.locked = locked

def apy_rew(base_time, now, apy, amount):
  # Note for prod, you need to consider the real year in seconds
  YEAR_IN_SECONDS = 60 # 365
  return int(amount * apy * (now - base_time) / YEAR_IN_SECONDS)

class StakeState:
    def __init__(self, vesting, max_apy):
        self.vesting = vesting
        self.max_apy = max_apy
        self.let_go_rew = 0 # Total reward let go by users
        self.stake_end = 0

    def take_reward(self, pool_share, dt, amount = 0):
        """
        Stretch until the appropriate time, calculate piecewise rewards.
        """
        i = 0
        rew = 0
        v = self.vesting[0]
        last_time = self.stake_end
        while v.end_time <= dt and i < len(self.vesting):
          rew += pool_share * v.reward_amount
          # print(f'At period {i} - total rew is {v.reward_amount}, user rew: {rew}')
          last_time = v.end_time
          i += 1
          if i < len(self.vesting):
            v = self.vesting[i] # TODO: Test last period maturity

        # Partial take
        if v.end_time > dt and v.has_apy: # Do not pay anything if this period is not pro-rated
          # print(f'Last period {i} - apy {v.apy}')
          rew += pool_share * v.reward_amount
          # print(f'At period {i} - total rew is {v.reward_amount}, user rew: {rew}')
          let_go_rew = pool_share * v.reward_amount * (v.end_time - dt) / (v.end_time - last_time)
          rew -= let_go_rew
          self.let_go_rew += let_go_rew

        if self.max_apy > 0 and amount > 0 and rew > 0:
          # Dont give out more than the max_apy
          rew_max_apy = apy_rew(self.stake_end, dt, self.max_apy, amount)
          print(f'Max reward exists {self.max_apy}. Max rew allowed for this amount is {rew_max_apy}. We are giving out {rew}')
          if rew > rew_max_apy:
            self.let_go_rew += rew - rew_max_apy
            rew = rew_max_apy
        return rew


TEN_MIN = 10

vesting = []

def setup_s():
  base_time = 0 
  vesting.clear()
  vesting.append(VestingItem(base_time + TEN_MIN * 1, 100, False, True))
  vesting.append(VestingItem(base_time + TEN_MIN * 2, 100, True, False))
  vesting.append(VestingItem(base_time + TEN_MIN * 3, 100, False, False))
  return StakeState(vesting, 0)

def test1():
  # Vesting: 100 for the first 10 min, 20% afterwards and another 100 for the last period.
  # last period cannot have APY. Because there is no end time in sight...
  st = setup_s()
  rew = st.take_reward(0.5, 5) # Should be 0
  print('>> st.take_reward(0.5, 5)', rew)

  rew = st.take_reward(0.5, 12.5) # Should be 62.5: 100 * 0.5 + 100 * 0.5 * 0.25 -- Let go of some 
  print('>> st.take_reward(0.5, 12.5)[62.5]', rew)

  rew = st.take_reward(0.25, 15) # Should be 37.5: 100 * 0.25 + 100 * 0.25 * 0.5 -- Let go of some
  print('>> st.take_reward(0.25, 15)[37.5]', rew)

  rew = st.take_reward(0.125, 25) # Should be 25: 100 * 0.125 + 100 * 0.125
  print('>> st.take_reward(0.125, 25)[25]', rew)

  rew = st.take_reward(0.125, 35) # Should be 37.5: 100 * 0.125 * 3
  print('>> st.take_reward(0.125, 25)[37.5]', rew)

  print('amount left to be taked out by admin', st.let_go_rew)

def test2():
  st = setup_s()
  st.max_apy = 0.1 # Maximum give out 10% reward annualized
  amount = 1000

  rew = st.take_reward(0.5, 5, amount) # Should be 0
  print('>> st.take_reward(0.5, 5)', rew, st.let_go_rew)

  rew = st.take_reward(0.5, 12.5, amount) # Should be 62.5: 100 * 0.5 + 100 * 0.5 * 0.25 -- Let go of some 
  print('>> st.take_reward(0.5, 12.5)[62.5]', rew, st.let_go_rew)

  rew = st.take_reward(0.25, 15, amount) # Should be 37.5: 100 * 0.25 + 100 * 0.25 * 0.5 -- Let go of some
  print('>> st.take_reward(0.25, 15)[37.5]', rew, st.let_go_rew)

  rew = st.take_reward(0.125, 25, amount) # Should be 25: 100 * 0.125 + 100 * 0.125
  print('>> st.take_reward(0.125, 25)[25]', rew, st.let_go_rew)

  rew = st.take_reward(0.125, 35, amount) # Should be 37.5: 100 * 0.125 * 3
  print('>> st.take_reward(0.125, 35)[37.5]', rew, st.let_go_rew)

  print('amount left to be taked out by admin', st.let_go_rew)

def test3():
  st = setup_s()
  vesting[2].has_apy = True

  rew = st.take_reward(0.5, 5) # Should be 0
  print('>> st.take_reward(0.5, 5)', rew, st.let_go_rew)

  rew = st.take_reward(0.5, 12.5) # Should be 62.5: 100 * 0.5 + 100 * 0.5 * 0.25 -- Let go of some 
  print('>> st.take_reward(0.5, 12.5)[62.5]', rew, st.let_go_rew)

  rew = st.take_reward(0.25, 15) # Should be 37.5: 100 * 0.25 + 100 * 0.25 * 0.5 -- Let go of some
  print('>> st.take_reward(0.25, 15)[37.5]', rew, st.let_go_rew)

  rew = st.take_reward(0.125, 25) # Should be 31.25: 100 * 0.125 * 2 + 100 * 0.125 * 0.5
  print('>> st.take_reward(0.125, 25)[25]', rew, st.let_go_rew)

  rew = st.take_reward(0.125, 35) # Should be 37.5: 100 * 0.125 * 3
  print('>> st.take_reward(0.125, 25)[37.5]', rew, st.let_go_rew)

  print('amount left to be taked out by admin', st.let_go_rew)

# test1()
test2()
test3()

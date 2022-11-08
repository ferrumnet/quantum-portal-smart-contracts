# Quantum Portal Initial Design

## Concepts

- The Portal
- The Portal Management
- The Price Oracle
- The PoA Logic
- The NPoS Logic
- The value-constrained NPoS logic

## The Portal

Our goal is to run a method on a remote chain using assets on the local chain. This is in a away similart to how ether is sent to smart contract methods, except this works for ERC20 tokens instead. Lets say we want to call the method `stake` of contract `stakeContract` on the FRM chain with `BAT` on Ethereum.

On the eth side, we call the portal contract (pre-allocated). Portal takes the BAT token and registers the event on what need to be done on the FRM side.

On the FRM side, a miner will mine the ETH->FRM block. At this point, the eth side BAT is in the `stakeContract` account on the FRM side. Keep in mind the acutal BAT token is only aviale on the ETH network, but the `stakingContract` on the FRM side is now allowed to allocat it in the way it wants. On the FRM side the accounting of the ETH BAT balance can be modified, until eventually a withdraw is generated on the eth side where the BAT will be sent out of the contract.

Example:

p.eth:
 -> stakeContract(id, 100 BAT)

p.frm:
 -> Balance [stakeContract] + 100 BAT (pending)

On the FRM side, when a block is mined, 100 ETH BAT goes into the stakingContract account (as pending), however, this needs to be commited to be accepted.

The stakingContract should call the commit before it can utilize the blanace.

Example:

```

constract stakingContract {
  ...
  function stake(id address) external {
     [address msgSender, uint256 amount] = Potal.receive(); // This will move the balance into commited
     ...
     if (actionFailed) {
         Portal.revert(); // Reverts the transaction of this specific context.
     }
  }
  ...
}

```

Example 2:

Multi-chain token

```
constract MultiChainToken is ERC20 {
  ...
  // Mints on mint chain and burns on burn chain, keeping the total supply same
  // Note: in this example we assume the remote token contract has the same address.
  // TODO: Run this using a two-phase commit.
  function mintAndBurn(uint mintChain, uint burnChain, uint amount, uint fee) onlyOwner {
    if (mintChain == block.chainid) { _mint(amount); } else {
        bytes method = abi.encodeWithSelector(MultiChainToken.mint.selector, (amount));
        Portal.run(fee, mintChain, address(this), method); // The fee is base fee charged on this side. Covers enough to fail the tx on the other side.
        // Portal.runPaidFee(fee, feePayerSig, mintChain, method); to allow others pay the fee?
    }
    if (burnChain == block.chainid) { _burn(amount); } else {
        bytes method = abi.encodeWithSelector(MultiChainToken.burn.selector, (amount));
        Portal.run(fee, burnChain, method);
    }
  }

  // Only to be called by the Portal
  function mint(uint amount) external {
      (uint senderNet, address msgSender) = Portal.msgSender();
      require(msgSender == address(this) && senderNet = FRM_CHAIN_ID, "Not allowed");
      // Optionally expect an owner signature, for more security.
      _mint(amount);
  }

  function burn(uint amount) external {
      (uint senderNet, address msgSender) = Portal.msgSender();
      require(msgSender == address(this) && senderNet = FRM_CHAIN_ID, "Not allowed");
      _burn(amount);
  }
  ...
}
```

## Challenge: How to incentivise validators?

- They need to be paid fees, but where do the fees come from?
  - 1. Smart contract vendors can pay the fee (an escrow account where the miner can take fee). Problem with this approach is that the block is mined on the remote chain. Fee is best to be payable on the remote chain).
  - What if there is not enough fee? Or even enough fee to pay for the rejection? Miner needs to bear the cost in ETH. Could be quiet expensive.
  - Solution charge a minimum fee on the local side. (Based on gas price on the target network?). And miner charges the base fee (on the client side).


- Solutions?
  - Miners do not run txs (no revert or anything). 
    - Pro: Much simpler miner
    - Con: Someone has to do it anyway! We cannot run txs out of order, so such it!
  - Miner pays the fee:
    - Fee collected on the source call (estimated gasLimit provided)
    - Miner calls the sub-tx with the gasLimit (Extra gas is added to the contracts balance?). Challenge is that the external methods should be designed to consume predictable amount of gas (we provide a utility)! Dust is paid to the contract balance.

  - Gas calculator lib. Stores recent price for FRM vs base currency.


## Challenge: Estimate remote gas

Remote gas is hard to estimate, to simplify we can provide a facility for the developers to estimate gas. A tx that will run, but at the end, fail. E.g. GasEstimator -> Portal -> call. Estimator will fail, hence rollback changes to the base. Portal catches the failure. Estimating gas on this method will give us a good idea of the gas required. Then we need to estimate how much FRM would that be.

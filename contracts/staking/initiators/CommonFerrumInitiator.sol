// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "../library/StakingBasics.sol";
import "../BaseStakingV2.sol";
import "../interfaces/IStakeV2.sol";

abstract contract CommonFerrumInitiator is BaseStakingV2 {
  using StakeFlags for uint16;
  uint32 constant DEFAULT_FEE = 100;
  uint32 constant OpenFeeRate = 1000; // 1%
  address constant OpenFeeTarget = address(0); // TODO: Get from owner
  uint32 constant TWENTY_FOUR_HOURS = 3600*24;

  function createMinimal(
    address id,
    address baseToken,
    string calldata name,
    uint32 hardConfigDeadline,
    uint256 cap,
    address adminAddress,
    address allocator,
    bytes32 salt,
    bytes calldata signature,
    uint32 signatureLifetime) internal {
    require(id != address(0), "CFI: Bad ID");
    StakingBasics.StakeInfo storage info = stakings[id];
    require(stakings[id].stakeType == Staking.StakeType.None, "CFI: Already exists");
    signatureForId(
      id, Staking.StakeType.Timed, creationSigner, salt, signature, signatureLifetime);
    // creator to be moved to somewhere else?
    require(baseToken != address(0), "CFI: Bad base token");
    require(hardConfigDeadline == 0 || hardConfigDeadline > block.timestamp, "CFI: Config already closed");

    info.stakeType = Staking.StakeType.Unset;
    baseInfo.baseToken[id] = baseToken;
    baseInfo.name[id] = name;
    info.configHardCutOff = hardConfigDeadline;
    baseInfo.cap[id] = cap;
    info.flags = info.flags.withFlag(StakeFlags.Flag.IsAllocatable, allocator != address(0));
    if (adminAddress != address(0)) {
      admins[id][adminAddress] = StakingBasics.AdminRole.StakeAdmin;
    }
    extraInfo.allocators[id] = allocator;
  }

  function timed(
    address id,
    uint32 contribStart,
    uint32 contribEnd,
    uint32 endOfLife,
    address feeTarget,
    address[] calldata allowedRewardTokens,
    bool tokenizable,
    address sweepTarget) onlyAdmin(id) internal {
    StakingBasics.StakeInfo storage info = stakings[id];
    require(info.stakeType == Staking.StakeType.Unset, "CFI: Type already configured or not there");
    require(contribEnd > contribStart, "CFI: Invalid contrib time");
    require(contribEnd > block.timestamp, "CFI: Contrib already closed");
    require(endOfLife == 0 || endOfLife > contribEnd, "CFI: Contrib already closed");
    require(block.timestamp < info.configHardCutOff, "CFI: Config timed out");

    info.stakeType = Staking.StakeType.Timed;
    info.restrictedRewards = allowedRewardTokens.length > 0;

    info.flags = info.flags
      .withFlag(StakeFlags.Flag.IsBaseSweepable, sweepTarget != address(0))
      .withFlag(StakeFlags.Flag.IsRewardSweepable, true)
      .withFlag(StakeFlags.Flag.IsTokenizable, tokenizable)
      .withFlag(StakeFlags.Flag.IsFeeable, feeTarget != address(0));
    info.contribStart = contribStart;
    info.contribEnd = contribEnd;
    info.endOfLife = endOfLife;
    setAllowedRewardTokens(id, allowedRewardTokens);
  }

  function openEnded(
    address id,
    address baseToken,
    string memory name,
    uint32 hardConfigDeadline,
    uint256 cap,
    uint32 feeRateX10000,
    address feeTarget,
    address[] memory allowedRewardTokens,
    bool tokenizable,
    address adminAddress,
    address allocator,
    address sweepTarget,
    bytes32 salt,
    bytes calldata signature,
    uint32 signatureLifetime
  ) public {
    require(id != address(0), "CFI: Bad ID");
    StakingBasics.StakeInfo storage info = stakings[id];
    require(info.stakeType == Staking.StakeType.Unset, "CFI: Type already configured or not there");
    signatureForId(id, Staking.StakeType.Timed, creationSigner, salt, signature, signatureLifetime);
    require(baseToken != address(0), "CFI: Bad base token");
    require(hardConfigDeadline > block.timestamp, "CFI: Config already closed");
    require(feeTarget == address(0) || feeRateX10000 > 0, "CFI: Fee target without fee");

    baseInfo.cap[id] = cap;
    baseInfo.baseToken[id] = baseToken;
    info.stakeType = Staking.StakeType.OpenEnded;
    info.restrictedRewards = allowedRewardTokens.length > 0;

    info.flags = info.flags
      .withFlag(StakeFlags.Flag.IsBaseSweepable, sweepTarget != address(0))
      .withFlag(StakeFlags.Flag.IsRewardSweepable, true)
      .withFlag(StakeFlags.Flag.IsTokenizable, tokenizable)
      .withFlag(StakeFlags.Flag.IsFeeable, feeTarget != address(0))
      .withFlag(StakeFlags.Flag.IsCustomFeeable, feeRateX10000 > 0)
      .withFlag(StakeFlags.Flag.IsAllocatable, allocator != address(0))
      .withFlag(StakeFlags.Flag.IsMandatoryLocked, true);
    info.configHardCutOff = hardConfigDeadline;
    baseInfo.name[id] = name;
    setAllowedRewardTokens(id, allowedRewardTokens);
  }

  function publicStaking (
    address id, string memory name, address baseToken, uint32 minApy,
    bytes calldata signature,
    uint32 signatureLifetime
  ) external {
    address[] memory _addr = new address[](1);
    _addr[0] = baseToken;
    // openEnded(
    //   id, baseToken, name, 0, 0, OpenFeeRate, OpenFeeTarget,
    //   _addr, false, address(0), address(0), address(0), signature, signatureLifetime, stakings);
    StakingBasics.StakeInfo storage info = stakings[id];
    // info.minApy = minApy;

    // Set mandatory locked to 48 hours
    // setLockInfo(id, TWENTY_FOUR_HOURS, TWENTY_FOUR_HOURS * 2);
  }

  // function publicSale (
  //   address id,
  //   string calldata name,
  //   address saleToken,
  //   address buyToken,
  //   uint32 contribStart,
  //   uint32 contribEnd,
  //   uint32 hardConfigDeadline,
  //   bool tokenizable,
  //   address adminAddress,
  //   address allocator,
  //   address sweepTarget,
  //   bytes calldata signature,
  //   uint32 signatureLifetime,
  //   mapping(address => StakingBasics.StakeInfo) storage stakings
  // ) external {
  //   StakingBasics.StakeInfo storage info = stakings[id];
  //   require(info.id == address(0), "CFI: Already exists");
  //   SignatureHelper.signatureForId(id, Staking.StakeType.PublicSale, signature, signatureLifetime);
  //   require(contribStart > block.timestamp, "CFI: Contrib start in past");
  //   require(contribEnd > contribStart, "CFI: Invalid contrib time");
  //   require(contribEnd > block.timestamp, "CFI: Contrib already closed");
  //   require(id != address(0), "CFI: Bad ID");
  //   require(buyToken != address(0), "CFI: Bad buy token");
  //   require(saleToken != address(0), "CFI: Bad sale token");
  //   require(hardConfigDeadline > block.timestamp, "CFI: Config already closed");
  //   require(sweepTarget != address(0), "CFI: No sweep address provided");
  //   require(allocator != address(0), "CFI: allocator must be provided");

  //   info.id = id;
  //   info.baseToken = buyToken;
  //   info.stakeType = Staking.StakeType.PublicSale;
  //   info.restrictedRewards = true;
  //   info.isBaseSweepable = sweepTarget != address(0);
  //   info.isRewardSweepable = true;
  //   info.isTokenizable = tokenizable;
  //   info.isAllocatable = allocator != address(0);
  //   info.isRecordKeepingOnly = true; // This means there is no unstake.
  //   info.contribStart = contribStart;
  //   info.contribEnd = contribEnd;
  //   info.configHardCutOff = hardConfigDeadline;
  //   info.name = name;
  //   // IStakingState(this).setAllowedRewardTokens([saleToken]);
  // }

  function signatureByIdSignerAddress(
    address id, Staking.StakeType stakeType, bytes calldata signature, uint32 signatureLifetime
    ) external view returns (address signer) {
  }
}

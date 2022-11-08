// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "../common/signature/MultiSigLib.sol";
import "hardhat/console.sol";

contract Playground {

	struct V { uint32 v; address a; }
	function log() external view {
		uint32 v = 0x88;
		V memory vv = V({ v: v, a: address(this) });
		console.logBytes(abi.encodePacked(v, address(this)));
		console.logBytes(abi.encode(v, address(this)));
		console.log("AND %s", targetKey(v, address(this)));
	}

	function targetKey(uint32 chainId, address _address) internal view returns (uint256) {
		console.log("ADDR ISO 1 %s", uint256( uint160(_address)) );
		console.log("ADDR ISO 2 %s", uint256( uint256(chainId) << 160) );
		console.log("ADDR ISO 2 %s", uint256(chainId));
		console.log("ADDR ISO 2 %s", uint256(chainId) * 2**160);
		return uint256(chainId) << 160 | uint160(_address);
	}

    function blockIdx(uint64 chainId, uint64 nonce) external pure returns (uint256) {
        return (uint256(chainId) << 64) + nonce;
    }

	function testMultiSig(bytes memory multiSig,
		bytes32[] memory rs,
		bytes32[] memory ss,
		uint8[] memory vs
	) external view returns (MultiSigLib.Sig[] memory sigs) {
		sigs = MultiSigLib.parseSig(multiSig);
		for (uint i=0; i<sigs.length; i++) {
			console.log("-------------------- {} ", sigs.length);
			console.logBytes32(sigs[i].r);
			console.logBytes32(sigs[i].s);
			console.log("{}", sigs[i].v);
			require(rs[i] == sigs[i].r, "Mismatch R");
			require(ss[i] == sigs[i].s, "Mismatch S");
			require(vs[i] == sigs[i].v, "Mismatch V");
		}
	}
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./IBridgeRoutingTable.sol";
import "foundry-contracts/contracts/contracts/common/SafeAmount.sol";

/**
 @notice This contract is a helper for bridge V12. Ported to the QPN.
 The data chain (FRM) can only manage the routing updates.
 TODO: Make this a multi-chain contract.
*/
contract BridgeRoutingTable is IBridgeRoutingTable {
    uint256 constant MAX_FEE_X10k = 0.8 * 10000;

    /*
		routingTable:
		  id, chainId, withdrawConfig
			----------------------------------------
	*/
    mapping(address => mapping(uint256 => TokenWithdrawConfig))
        public routingTable;
    mapping(address => uint256[]) public configuredChainIds;
    mapping(address => address) public routingIds;

    constructor() {}

    /**
     @notice return routing table for a token
     @return id The routing ID
     @return _chainIds The configured chain Ids
     @return _configs The configured routes
     */
    function getRoutingTable(address token
    ) external view returns (
            address id,
            uint256[] memory _chainIds,
            TokenWithdrawConfig[] memory _configs
        ) {
        id = routingIds[token];
        _configs = new TokenWithdrawConfig[](configuredChainIds[id].length);
        _chainIds = configuredChainIds[id];
        for (uint256 i = 0; i < _chainIds.length; i++) {
            _configs[i] = routingTable[id][_chainIds[i]];
        }
    }

    /**
     @notice Returns the routing config for the given token.
     @return config The routing config. Empty if none.
     */
    function tryWithdrawConfig(address token
    ) external view returns (TokenWithdrawConfig memory config) {
        address id = routingIds[token];
        config = routingTable[id][block.chainid];
    }

    /**
     @notice Returns the routing config for the given token.
     @return config The routing config. Throws if none.
     */
    function withdrawConfig(address token
    ) external view override returns (TokenWithdrawConfig memory config) {
        address id = routingIds[token];
        require(id != address(0), "BRT: not found");
        config = routingTable[id][block.chainid];
        require(config.targetToken != address(0), "BRT: no config");
    }

    /**
     @notice Does nothing if a given route exists, and throws otherwise.
     @param sourceToken The source token
     @param targetChainId The target chain ID
     @param targetToken The target token
     */
    function verifyRoute(
        address sourceToken,
        uint256 targetChainId,
        address targetToken
    ) external view override {
        require(sourceToken != address(0), "BRT: sourceToken required");
        require(targetChainId != 0, "BRT: targetChainId required");
        require(targetToken != address(0), "BRT: targetToken required");
        address id = routingIds[sourceToken];
        require(id != address(0), "BRT: not found");
        require(
            routingTable[id][targetChainId].targetToken == targetToken,
            "BRT: no route"
        );
    }

    /**
     @notice Returns the routes configured for a token
     @param sourceToken The source token
     @return _routes The configured route
     */
    function routes(address sourceToken
    ) external view returns (TokenWithdrawConfig[] memory _routes) {
        require(sourceToken != address(0), "BRT: token required");
        address id = routingIds[sourceToken];
        require(id != address(0), "BRT: token not configured");
        uint256[] memory chainIds = configuredChainIds[id];
        _routes = new TokenWithdrawConfig[](chainIds.length);
        for (uint256 i = 0; i < chainIds.length; i++) {
            _routes[i] = routingTable[id][chainIds[i]];
        }
    }

    /**
     @notice Updates fee for an existing route
     @dev One multi-sig signed message can run against all chains to avoid
        the need of separate configuration per chain.
     @param id The routing ID
     @param chainIds List of chain IDs to be updated
     @param fees The fees. A 0 fee means default fee.
     @param noFees Use 1 to disable fee. 
     @param salt The signature salt
     @param timeout Signature expiry
     @param expectedGroupId Expected group ID for the signature
     @param multiSignature The multisig encoded signature
     */
    function updateFees(
        address id,
        uint256[] memory chainIds,
        uint64[] memory fees,
        uint8[] memory noFees,
        bytes32 salt,
        uint256 timeout,
        uint64 expectedGroupId,
        bytes memory multiSignature
    ) external {
        require(id != address(0), "BRT: id required");
        require(fees.length == chainIds.length, "BRT: provide one fee per chain");
        require(noFees.length == chainIds.length, "BRT: provide one noFee per chain");
        require(salt != 0, "BRT: salt required");
        require(block.timestamp < timeout, "BRT: expired");
        require(multiSignature.length != 0, "BRT: multiSignature required");
        // bytes32 digest = keccak256(
        //     abi.encode(
        //         CONTRACT_SALT,
        //         keccak256("UpdateFees"),
        //         id,
        //         chainIds,
        //         fees,
        //         noFees,
        //         salt,
        //         timeout
        //     )
        // );
        // verifySalt(digest, salt, expectedGroupId, multiSignature);
        for (uint256 i = 0; i < chainIds.length; i++) {
            require(routingTable[id][chainIds[i]].targetToken != address(0), "BRT: token or chain not configured");
            require(fees[i] <= MAX_FEE_X10k, "BRT: fee too large");
            routingTable[id][chainIds[i]].feeX10000 = fees[i];
            require(noFees[i] == 0 || noFees[i] == 1, "BRT: noFee must be 1 or 0");
            routingTable[id][chainIds[i]].noFee = noFees[i];
        }
    }

    /**
     @notice Adds one or many routes to an existing routing ID or creates a new one
     @dev One multi-sig signed message can run against all chains to avoid
        the need of separate configuration per chain.
     @param id The routing ID
     @param chainIds List of chain IDs to be updated
     @param configs The routing configs.
     @param salt The signature salt
     @param timeout Signature expiry
     @param expectedGroupId Expected group ID for the signature
     @param multiSignature The multisig encoded signature
     */
    function addRoutes(
        address id,
        uint256[] memory chainIds,
        TokenWithdrawConfig[] memory configs,
        bytes32 salt,
        uint256 timeout,
        uint64 expectedGroupId,
        bytes memory multiSignature
    ) external {
        require(id != address(0), "BRT: id required");
        require(chainIds.length == configs.length, "BRT: provide one config per chain");
        require(salt != 0, "BRT: salt required");
        require(block.timestamp < timeout, "BRT: expired");
        require(multiSignature.length != 0, "BRT: multiSignature required");
        // bytes32 digest = keccak256(
        //     abi.encode(
        //         CONTRACT_SALT,
        //         keccak256("AddRoutes"),
        //         id,
        //         chainIds,
        //         configs,
        //         salt,
        //         timeout
        //     )
        // );
        // verifySalt(digest, salt, expectedGroupId, multiSignature);
        address current = address(0);
        for (uint256 i = 0; i < chainIds.length; i++) {
            require(routingTable[id][chainIds[i]].targetToken == address(0), "BRT: cannot update table. Try deleting first.");
            current = configs[i].targetToken;
            address _currentRoutingId = routingIds[current];
            require(_currentRoutingId == address(0), "BRT: token is already configured. Delete first.");
            routingIds[current] = id;
            TokenWithdrawConfig memory twc = configs[i];
            require(
                twc.targetToken != address(0),
                "PWC: targetToken is required"
            );
            require(twc.feeX10000 <= MAX_FEE_X10k, "BRT: fee too large");
            require(twc.noFee == 0 || twc.noFee == 1, "BRT: noFee must be 0 or 1");
            routingTable[id][chainIds[i]] = twc;
            // Update the configured network list
            configuredChainIds[id].push(chainIds[i]);
        }
        require(current != address(0), "BRT: no target for this chain");
    }

    /**
     @notice Removes one or many routes.
     @dev One multi-sig signed message can run against all chains to avoid
        the need of separate configuration per chain.
     @param id The routing ID
     @param chainIds List of chain IDs to be updated
     @param salt The signature salt
     @param timeout Signature expiry
     @param expectedGroupId Expected group ID for the signature
     @param multiSignature The multisig encoded signature
     */
    function removeRoutes(
        address id,
        uint256[] memory chainIds,
        bytes32 salt,
        uint256 timeout,
        uint64 expectedGroupId,
        bytes memory multiSignature
    ) external {
        // bytes32 digest = keccak256(
        //     abi.encode(
        //         CONTRACT_SALT,
        //         keccak256("RemoveRoute"),
        //         id,
        //         chainIds,
        //         salt,
        //         timeout
        //     )
        // );
        // verifySalt(digest, salt, expectedGroupId, multiSignature);
        for (uint256 i = 0; i < chainIds.length; i++) {
            if (routingTable[id][chainIds[i]].targetToken != address(0)) {
                // console.log("DELETING A ROUTE", chainIds[i]);
                deleteRoute(id, chainIds[i]);
            }
        }
    }

    // /**
    //  @notice Verifies the salt is unique
    //  @param digest The digest
    //  @param salt The salt
    //  @param expectedGroupId The expected group ID. Provide Zero to ignore
    //  @param multiSignature The signature
    //  */
    // function verifySalt(bytes32 digest, bytes32 salt, uint64 expectedGroupId, bytes memory multiSignature 
    // ) private {
    //     require(!usedHashes[salt], "BRT: salt already used");
    //     require(
    //         tryVerifyDigest(digest, expectedGroupId, multiSignature),
    //         "BRT: Invalid signature"
    //     );
    //     usedHashes[salt] = true;
    // }

    /**
     @notice Deletes a route
     @param id The route id
     @param chainId The chain ID
     */
    function deleteRoute(address id, uint256 chainId
    ) private {
        uint256 len = configuredChainIds[id].length;
        uint256 idx = findChainIdIdx(id, chainId);
        // console.log("CURRENT IDX", idx);
        configuredChainIds[id][idx] = configuredChainIds[id][len - 1];
        configuredChainIds[id].pop();
        delete routingTable[id][chainId];
        // console.log("NEW LEN", configuredChainIds[id].length);
    }

    /**
     @notice Finds a chain ID index
     @param id The route id
     @param chainId The chain ID
     @return The index of chain or throws if not found
     */
    function findChainIdIdx(address id, uint256 chainId
    ) private view returns (uint256) {
        for (uint256 j = 0; j < configuredChainIds[id].length; j++) {
            if (configuredChainIds[id][j] == chainId) {
                return j;
            }
        }
        revert("BRT: chainId not configured");
    }
}

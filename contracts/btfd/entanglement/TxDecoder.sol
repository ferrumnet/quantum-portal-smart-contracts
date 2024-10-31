// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library TxDecoder {
    struct Input {
        bytes32 addr;
        uint256 amount;
    }

    struct Output {
        bytes32 addr;
        uint256 amount;
    }

    /**
     * @notice Parses the retrieved transaction data.
     * @param data The raw transaction data.
     * @return blockNumber The block number.
     * @return timestamp The timestamp.
     * @return inputs The transaction inputs.
     * @return outputs The transaction outputs.
     * @return encodedCall The encoded call data.
     */
    function parseRetrieveTx(bytes memory data)
        internal
        pure
        returns (
            uint256 blockNumber,
            uint256 timestamp,
            Input[] memory inputs,
            Output[] memory outputs,
            bytes memory encodedCall
        )
    {
        uint256 offset = 0;

        // Parse blockNumber (uint256, 32 bytes)
        require(data.length >= offset + 32, "Data too short for blockNumber");
        blockNumber = bytesToUint256(data, offset);
        offset += 32;

        // Parse timestamp (uint256, 32 bytes)
        require(data.length >= offset + 32, "Data too short for timestamp");
        timestamp = bytesToUint256(data, offset);
        offset += 32;

        // Parse number of inputs (uint32, 4 bytes)
        require(data.length >= offset + 4, "Data too short for number of inputs");
        uint32 numInputs = bytesToUint32(data, offset);
        offset += 4;

        // Parse inputs
        inputs = new Input[](numInputs);
        for (uint256 i = 0; i < numInputs; i++) {
            // Parse address length (uint32, 4 bytes)
            require(data.length >= offset + 4, "Data too short for input address length");
            uint32 addrLen = bytesToUint32(data, offset);
            offset += 4;

            // Ensure address length is exactly 32 bytes
            require(addrLen == 32, "Input address length must be 32 bytes");

            // Parse address (32 bytes)
            require(data.length >= offset + 32, "Data too short for input address");
            bytes32 addr = bytesToBytes32(data, offset);
            offset += 32;

            // Parse amount (uint256, 32 bytes)
            require(data.length >= offset + 32, "Data too short for input amount");
            uint256 amount = bytesToUint256(data, offset);
            offset += 32;

            inputs[i] = Input({addr: addr, amount: amount});
        }

        // Parse number of outputs (uint32, 4 bytes)
        require(data.length >= offset + 4, "Data too short for number of outputs");
        uint32 numOutputs = bytesToUint32(data, offset);
        offset += 4;

        // Parse outputs
        outputs = new Output[](numOutputs);
        for (uint256 i = 0; i < numOutputs; i++) {
            // Parse address length (uint32, 4 bytes)
            require(data.length >= offset + 4, "Data too short for output address length");
            uint32 addrLen = bytesToUint32(data, offset);
            offset += 4;

            // Ensure address length is exactly 32 bytes
            require(addrLen == 32, "Output address length must be 32 bytes");

            // Parse address (32 bytes)
            require(data.length >= offset + 32, "Data too short for output address");
            bytes32 addr = bytesToBytes32(data, offset);
            offset += 32;

            // Parse amount (uint256, 32 bytes)
            require(data.length >= offset + 32, "Data too short for output amount");
            uint256 amount = bytesToUint256(data, offset);
            offset += 32;

            outputs[i] = Output({addr: addr, amount: amount});
        }

        // Parse encoded call length (uint32, 4 bytes)
        require(data.length >= offset + 4, "Data too short for encoded call length");
        uint32 encodedCallLen = bytesToUint32(data, offset);
        offset += 4;

        // Parse encoded call (encodedCallLen bytes)
        require(data.length >= offset + encodedCallLen, "Data too short for encoded call");
        encodedCall = new bytes(encodedCallLen);
        for (uint256 i = 0; i < encodedCallLen; i++) {
            encodedCall[i] = data[offset + i];
        }
        offset += encodedCallLen;

        // Ensure all data has been consumed
        require(offset == data.length, "Extra data at the end");
    }

    function bytesToUint32(bytes memory b, uint256 offset) internal pure returns (uint32 result) {
        require(b.length >= offset + 4, "Not enough bytes for uint32");
        assembly {
            let word := mload(add(add(b, 32), offset))
            result := shr(224, word) // Shift right by 224 bits (256 - 32)
        }
    }

    function bytesToUint256(bytes memory b, uint256 offset) internal pure returns (uint256 result) {
        require(b.length >= offset + 32, "Not enough bytes for uint256");
        assembly {
            result := mload(add(add(b, 32), offset))
        }
    }

    function bytesToBytes32(bytes memory b, uint256 offset) internal pure returns (bytes32 result) {
        require(b.length >= offset + 32, "Not enough bytes for bytes32");
        assembly {
            result := mload(add(add(b, 32), offset))
        }
    }
}

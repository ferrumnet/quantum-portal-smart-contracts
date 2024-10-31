// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library TxDecoder {
    struct Input {
        bytes32 addr;
        uint64 amount;
    }

    struct Output {
        bytes32 addr;
        uint64 amount;
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
            uint64 blockNumber,
            uint64 timestamp,
            Input[] memory inputs,
            Output[] memory outputs,
            bytes memory encodedCall
        )
    {
        uint256 offset = 0;

        // Ensure data length is sufficient for blockNumber, timestamp, and numInputs
        require(data.length >= offset + 8 + 8 + 4, "Data too short");

        // Parse blockNumber (uint64, 8 bytes)
        blockNumber = bytesToUint64(data, offset);
        offset += 8;

        // Parse timestamp (uint64, 8 bytes)
        timestamp = bytesToUint64(data, offset);
        offset += 8;

        // Parse number of inputs (uint32, 4 bytes)
        uint32 numInputs = bytesToUint32(data, offset);
        offset += 4;

        // Parse inputs
        inputs = new Input[](numInputs);
        for (uint256 i = 0; i < numInputs; i++) {
            // Ensure sufficient data for address length
            require(data.length >= offset + 4, "Data too short for input address length");

            // Parse address length (uint32, 4 bytes)
            uint32 addrLen = bytesToUint32(data, offset);
            offset += 4;

            // Ensure address length is exactly 32 bytes
            require(addrLen == 32, "Input address length must be 32 bytes");

            // Ensure sufficient data for address
            require(data.length >= offset + 32, "Data too short for input address");

            // Parse address (32 bytes)
            bytes32 addr = bytesToBytes32(data, offset);
            offset += 32;

            // Ensure sufficient data for amount
            require(data.length >= offset + 8, "Data too short for input amount");

            // Parse amount (uint64, 8 bytes)
            uint64 amount = bytesToUint64(data, offset);
            offset += 8;

            inputs[i] = Input({addr: addr, amount: amount});
        }

        // Ensure sufficient data for numOutputs
        require(data.length >= offset + 4, "Data too short for number of outputs");

        // Parse number of outputs (uint32, 4 bytes)
        uint32 numOutputs = bytesToUint32(data, offset);
        offset += 4;

        // Parse outputs
        outputs = new Output[](numOutputs);
        for (uint256 i = 0; i < numOutputs; i++) {
            // Ensure sufficient data for address length
            require(data.length >= offset + 4, "Data too short for output address length");

            // Parse address length (uint32, 4 bytes)
            uint32 addrLen = bytesToUint32(data, offset);
            offset += 4;

            // Ensure address length is exactly 32 bytes
            require(addrLen == 32, "Output address length must be 32 bytes");

            // Ensure sufficient data for address
            require(data.length >= offset + 32, "Data too short for output address");

            // Parse address (32 bytes)
            bytes32 addr = bytesToBytes32(data, offset);
            offset += 32;

            // Ensure sufficient data for amount
            require(data.length >= offset + 8, "Data too short for output amount");

            // Parse amount (uint64, 8 bytes)
            uint64 amount = bytesToUint64(data, offset);
            offset += 8;

            outputs[i] = Output({addr: addr, amount: amount});
        }

        // Ensure sufficient data for encodedCall length
        require(data.length >= offset + 4, "Data too short for encoded call length");

        // Parse encoded call length (uint32, 4 bytes)
        uint32 encodedCallLen = bytesToUint32(data, offset);
        offset += 4;

        // Ensure sufficient data for encodedCall
        require(data.length >= offset + encodedCallLen, "Data too short for encoded call");

        // Parse encoded call (encodedCallLen bytes)
        encodedCall = sliceBytes(data, offset, encodedCallLen);
        offset += encodedCallLen;

        // Ensure all data has been consumed
        require(offset == data.length, "Extra data at the end");
    }

    function bytesToUint32(bytes memory data, uint256 offset) internal pure returns (uint32) {
        require(data.length >= offset + 4, "Data too short for uint32");
        uint32 result;
        assembly {
            result := mload(add(add(data, 0x4), offset))
        }
        // Convert from big-endian to little-endian
        result =
            ((result & 0xFF000000) >> 24) |
            ((result & 0x00FF0000) >> 8) |
            ((result & 0x0000FF00) << 8) |
            ((result & 0x000000FF) << 24);
        return result;
    }

    function bytesToUint64(bytes memory data, uint256 offset) internal pure returns (uint64) {
        require(data.length >= offset + 8, "Data too short for uint64");
        uint64 result;
        assembly {
            result := mload(add(add(data, 0x8), offset))
        }
        // Convert from big-endian to little-endian
        result =
            ((result & 0xFF00000000000000) >> 56) |
            ((result & 0x00FF000000000000) >> 40) |
            ((result & 0x0000FF0000000000) >> 24) |
            ((result & 0x000000FF00000000) >> 8) |
            ((result & 0x00000000FF000000) << 8) |
            ((result & 0x0000000000FF0000) << 24) |
            ((result & 0x000000000000FF00) << 40) |
            ((result & 0x00000000000000FF) << 56);
        return result;
    }

    function bytesToBytes32(bytes memory data, uint256 offset) internal pure returns (bytes32 result) {
        require(data.length >= offset + 32, "Data too short for bytes32");
        assembly {
            result := mload(add(add(data, 0x20), offset))
        }
    }

    function sliceBytes(
        bytes memory data,
        uint256 start,
        uint256 length
    ) internal pure returns (bytes memory) {
        require(data.length >= start + length, "Not enough bytes to slice");
        bytes memory result = new bytes(length);
        for (uint256 i = 0; i < length; i++) {
            result[i] = data[start + i];
        }
        return result;
    }
}

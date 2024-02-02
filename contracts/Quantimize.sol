// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

contract Quantimize {
    mapping(string => address) public hashToUser;
    mapping(address => RandomInfo[]) public results;

    struct RandomInfo {
        string id;
        string description;
        string randomType;
        //address whiteListedAddresses;
        uint[][] input;
        uint[] result;
    }

    function getSumMinMax(
        uint256[] calldata inputArray
    ) public view returns (uint256[] memory) {
        // indexes meaning
        // 0 length
        // 1 sum
        // 2 min value - default 0
        // 3 max value - default 0
        uint256 totalLength = inputArray[0];
        uint256 totalSum = inputArray[1];
        uint256 minValue = inputArray[2];
        uint256 maxValue = inputArray[3];

        if (minValue > 0) {
            totalSum -= inputArray[2] * totalLength;
        }

        uint256[] memory result = new uint256[](totalLength);

        for (uint256 i = 0; i < totalLength; i++) {
            uint256 randomNumber = uint256(
                keccak256(
                    abi.encodePacked(
                        block.timestamp,
                        block.prevrandao,
                        block.coinbase,
                        blockhash(block.number - 1),
                        i
                    )
                )
            );

            if (i != totalLength - 1 && maxValue > 0) {
                result[i] = (randomNumber % totalSum) % (maxValue);
            } else {
                result[i] = totalSum;
            }
            totalSum -= result[i];
        }

        if (minValue > 0) {
            for (uint256 i = 0; i < totalLength; i++) {
                result[i] += minValue;
            }
        }

        return result;
    }

    function getShifts(
        uint256 numberOfShifts,
        uint256[][] calldata preferedShifts,
        uint256[][] calldata blackListedShifts
    ) public returns (uint256[] memory result) {
        uint256[] memory result = new uint256[](numberOfShifts);
        // leftovers

        for (uint256 i = 0; i < numberOfShifts; i++) {
            if (blackListedShifts[i].length == numberOfShifts) {
                result[i] = 0; // random number
            }
        }

        for (uint256 i = 0; i < numberOfShifts; i++) {
            if (preferedShifts[i].length == 1) {
                result[i] = 0; // random number
            }
        }

        for (uint256 i = 0; i < numberOfShifts; i++) {
            if (preferedShifts[i].length > 0) {
                result[i] = 0; // random number
            }
        }
    }

    function getChestItems(
        string[] memory items,
        uint[] memory odds,
        bool multi
    ) public view returns (string[] memory selectedItems) {
        uint256 randomNumber = (uint256(
            keccak256(
                abi.encodePacked(
                    block.timestamp,
                    block.prevrandao,
                    block.coinbase,
                    blockhash(block.number - 1)
                )
            )
        ) % 10000) + 1;

        if (multi == true) {
            uint256 counter = 0;
            for (uint i = 0; i < items.length; i++) {
                if (randomNumber < odds[i]) {
                    counter += 1;
                }
            }
            selectedItems = new string[](counter);
            counter = 0;
            for (uint i = 0; i < items.length; i++) {
                if (randomNumber < odds[i]) {
                    selectedItems[counter] = items[i];
                    counter += 1;
                }
            }
        } else {
            selectedItems = new string[](1);
            for (uint i = 0; i < items.length; i++) {
                if (randomNumber < odds[i]) {
                    selectedItems[0] = items[i];
                }
            }
        }
    }
}

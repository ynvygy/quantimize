//SPDX-License-Identifier: MIT
pragma solidity 0.8.22;
import "@api3/airnode-protocol/contracts/rrp/requesters/RrpRequesterV0.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title Example contract that uses Airnode RRP to access QRNG services
contract Quantimize is RrpRequesterV0, Ownable {
    event RequestedUint256(bytes32 indexed requestId);
    event ReceivedUint256(bytes32 indexed requestId, uint256 response);
    event RequestedUint256Array(bytes32 indexed requestId, uint256 size);
    event ReceivedUint256Array(bytes32 indexed requestId, uint256[] response);
    event WithdrawalRequested(
        address indexed airnode,
        address indexed sponsorWallet
    );

    address public airnode; // The address of the QRNG Airnode
    bytes32 public endpointIdUint256; // The endpoint ID for requesting a single random number
    bytes32 public endpointIdUint256Array; // The endpoint ID for requesting an array of random numbers
    address public sponsorWallet; // The wallet that will cover the gas costs of the request
    uint256 public _qrngUint256; // The random number returned by the QRNG Airnode
    uint256[] public _qrngUint256Array; // The array of random numbers returned by the QRNG Airnode

    mapping(bytes32 => bool) public expectingRequestWithIdToBeFulfilled;

    mapping(bytes32 => address) public hashToUser;
    mapping(address => RandomInfo[]) public results;

    struct RandomInfo {
        bytes32 id;
        string description;
        string randomType;
        //address whiteListedAddresses;
        string[] input;
        uint[] odds;
        string[] result;
        bool status;
    }

    constructor(address _airnodeRrp) RrpRequesterV0(_airnodeRrp) {}

    function getItems(
        string[] memory items,
        uint[] memory odds,
        bool multi
    ) public {
        bytes32 requestId = airnodeRrp.makeFullRequest(
            airnode,
            endpointIdUint256,
            address(this),
            sponsorWallet,
            address(this),
            this.fulfillUint256.selector,
            ""
        );

        string[] memory selectedItems;
        RandomInfo memory randomInfoInstance = RandomInfo({
            id: requestId,
            description: "to be completed",
            randomType: "chestItem",
            input: items,
            odds: odds,
            result: selectedItems,
            status: multi
        });

        results[msg.sender].push(randomInfoInstance);

        hashToUser[requestId] = msg.sender;

        expectingRequestWithIdToBeFulfilled[requestId] = true;
        emit RequestedUint256(requestId);
    }

    /// @notice Sets the parameters for making requests
    function setRequestParameters(
        address _airnode,
        bytes32 _endpointIdUint256,
        bytes32 _endpointIdUint256Array,
        address _sponsorWallet
    ) external {
        airnode = _airnode;
        endpointIdUint256 = _endpointIdUint256;
        endpointIdUint256Array = _endpointIdUint256Array;
        sponsorWallet = _sponsorWallet;
    }

    /// @notice To receive funds from the sponsor wallet and send them to the owner.
    receive() external payable {
        payable(owner()).transfer(msg.value);
        emit WithdrawalRequested(airnode, sponsorWallet);
    }

    /// @notice Called by the Airnode through the AirnodeRrp contract to
    /// fulfill the request
    function fulfillUint256(
        bytes32 requestId,
        bytes calldata data
    ) external onlyAirnodeRrp {
        require(
            expectingRequestWithIdToBeFulfilled[requestId],
            "Request ID not known"
        );
        expectingRequestWithIdToBeFulfilled[requestId] = false;
        uint256 qrngUint256 = abi.decode(data, (uint256));
        _qrngUint256 = qrngUint256;
        // Do what you want with `qrngUint256` here...
        string[] memory selectedItems;
        address userAddress = hashToUser[requestId];

        RandomInfo[] storage randomInfos = results[userAddress];
        RandomInfo memory foundInfo;
        for (uint256 i = 0; i < randomInfos.length; i++) {
            if (randomInfos[i].id == requestId) {
                foundInfo = randomInfos[i];
                break;
            }
        }

        if (foundInfo.status == true) {
            uint256 counter = 0;
            for (uint i = 0; i < foundInfo.input.length; i++) {
                if (qrngUint256 < foundInfo.odds[i]) {
                    counter += 1;
                }
            }
            selectedItems = new string[](counter);
            counter = 0;
            for (uint i = 0; i < foundInfo.input.length; i++) {
                if (qrngUint256 < foundInfo.odds[i]) {
                    selectedItems[counter] = foundInfo.input[i];
                    counter += 1;
                }
            }
        } else {
            selectedItems = new string[](1);
            for (uint i = 0; i < foundInfo.input.length; i++) {
                if (qrngUint256 < foundInfo.odds[i]) {
                    selectedItems[0] = foundInfo.input[i];
                    break;
                }
            }
        }

        emit ReceivedUint256(requestId, qrngUint256);
    }

    /// @notice Getter functions to check the returned value.
    function getRandomNumber() public view returns (uint256) {
        return _qrngUint256;
    }

    function getLastResult() public view returns (string[] memory) {
        RandomInfo[] storage randomInfos = results[msg.sender];
        RandomInfo memory foundInfo = randomInfos[randomInfos.length];
        return foundInfo.result;
    }

    /// @notice To withdraw funds from the sponsor wallet to the contract.
    function withdraw() external onlyOwner {
        airnodeRrp.requestWithdrawal(airnode, sponsorWallet);
    }
}

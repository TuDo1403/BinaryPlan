// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IBinaryPlan {
    struct Account {
        address directReferrer;
        uint96 leftVolume;
        uint8 leftHeight;
        uint8 rightHeight;
        uint16 directPercentage;
        uint96 rightVolume;
        uint96 maxVolume;
    }

    struct Bonus {
        uint16 directRate;
        uint16 branchRate;
    }

    function init(address root_) external;

    function getTree(
        address root
    ) external view returns (address[] memory tree);

    function addReferrer(
        address referrer,
        address referree,
        bool isLeft
    ) external;

    function updateVolume(address account, uint96 volume) external;

    function withdrawableAmt(address account_) external view returns (uint256);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IBinaryPlan {
    struct Account {
        address directReferrer;
        uint8 leftHeight;
        uint8 rightHeight;
        uint256 leftBonus;
        uint256 rightBonus;
        uint256 maxVolume;
    }

    struct Bonus {
        uint128 directRate;
        uint128 branchRate;
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

    function updateVolume(address account, uint256 volume) external;

    function withdrawableAmt(address account_) external view returns (uint256);
}

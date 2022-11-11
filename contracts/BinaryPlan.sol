// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import "./internal/Base.sol";

import "./interfaces/IBinaryPlan.sol";

contract BinaryPlan is Base, IBinaryPlan, Initializable {
    uint256 public constant PERCENTAGE_FRACTION = 10_000;
    uint256 public constant MAXIMUM_BONUS_PERCENTAGE = 3_000_000;

    IAuthority public immutable cachedAuthority;

    Bonus public bonusRate;
    mapping(address => uint256) public indices;
    mapping(address => Account) public accounts;
    mapping(uint256 => address) public binaryHeap;

    constructor(IAuthority authority_) payable Base(authority_, 0) {
        cachedAuthority = authority_;
    }

    function init(address root_) external initializer {
        binaryHeap[1] = root_;
        indices[root_] = 1;
        __updateAuthority(cachedAuthority);
        _checkRole(Roles.FACTORY_ROLE, msg.sender);

        Bonus memory bonus = bonusRate;
        bonus.branchRate = 300;
        bonus.directRate = 600;
        bonusRate = bonus;
    }

    function root() external view returns (address) {
        return binaryHeap[1];
    }

    function getTree(address root_)
        external
        view
        returns (address[] memory tree)
    {
        Account memory account = accounts[root_];
        uint256 level = account.leftHeight >= account.rightHeight
            ? account.leftHeight
            : account.rightHeight;
        uint256 length = 1 << (level + 1);
        tree = new address[](length);
        __traversePreorder(root_, 1, tree);
    }

    function __traversePreorder(
        address root_,
        uint256 idx,
        address[] memory addrs
    ) private view {
        if (root_ == address(0)) return;

        addrs[idx] = root_;

        __traversePreorder(
            binaryHeap[__leftChildIndexOf(root_)],
            idx << 1,
            addrs
        );
        __traversePreorder(
            binaryHeap[__rightChildIndexOf(root_)],
            (idx << 1) + 1,
            addrs
        );
    }

    function addReferrer(
        address referrer,
        address referree,
        bool isLeft
    ) external onlyRole(Roles.OPERATOR_ROLE) {
        require(
            referree != referrer &&
                referree != address(0) &&
                referrer != address(0),
            "BINARY_PLAN: INVALID_ARGUMENT"
        );
        require(indices[referrer] != 0, "BINARY_PLAN: NON_EXISTED_REF");
        require(indices[referree] == 0, "BINARY_PLAN: EXISTED_IN_TREE");

        uint256 position = isLeft
            ? __emptyLeftChildIndexOf(referrer)
            : __emptyRightChildIndexOf(referrer);

        binaryHeap[position] = referree;

        indices[referree] = position;
        accounts[referree].directReferrer = referrer;

        accounts[referrer].directPercentage += bonusRate.directRate;

        address leaf = referree;
        address root_ = __parentOf(leaf);

        bool updateHeight = true;
        if (isLeft && accounts[root_].leftHeight != 0) updateHeight = false;
        else if (accounts[root_].rightHeight != 0) updateHeight = false;

        Account memory rootAccount;
        while (root_ != address(0)) {
            rootAccount = accounts[root_];
            unchecked {
                if (__isLeftBranch(leaf, root_)) {
                    if (updateHeight) ++rootAccount.leftHeight;
                    ++rootAccount.numLeftLeaves;
                } else {
                    if (updateHeight) ++rootAccount.rightHeight;
                    ++rootAccount.numRightLeaves;
                }
                if (
                    rootAccount.numLeftLeaves + rootAccount.numRightLeaves ==
                    1 << __levelOf(indices[root_])
                ) ++rootAccount.numBalancedLevel;
            }

            accounts[root_] = rootAccount;

            leaf = root_;
            root_ = __parentOf(leaf);
        }
    }

    function updateVolume(address account, uint96 volume) external {
        Account memory _account = accounts[account];
        if (_account.maxVolume < volume) _account.maxVolume = volume;
        accounts[account] = _account;

        address leaf = account;
        address root_ = __parentOf(leaf);

        while (root_ != address(0)) {
            if (__isLeftBranch(leaf, root_))
                accounts[root_].leftVolume += volume;
            else accounts[root_].rightVolume += volume;

            leaf = root_;
            root_ = __parentOf(leaf);
        }
    }

    function withdrawableAmt(address account_) public view returns (uint256) {
        Account memory account = accounts[account_];

        uint256 branchRate = bonusRate.branchRate;

        uint256 percentageFraction = PERCENTAGE_FRACTION;
        uint256 maxReceived = (account.maxVolume * MAXIMUM_BONUS_PERCENTAGE) /
            percentageFraction;
        uint256 bonusPercentage = account.directPercentage +
            (branchRate * account.numBalancedLevel);
        uint256 bonus = account.leftVolume < account.rightVolume
            ? account.rightVolume
            : account.leftVolume;
        uint256 received = (bonus * bonusPercentage) / percentageFraction;

        return maxReceived > received ? received : maxReceived;
    }

    function __isLeftBranch(address leaf, address root_)
        private
        view
        returns (bool)
    {
        uint256 leafIndex = indices[leaf];
        uint256 numPath = __levelOf(leafIndex) - __levelOf(indices[root_]) - 1; // x levels requires x - 1 steps
        return (leafIndex >> numPath) & 0x1 == 0;
    }

    function __parentOf(address account_) private view returns (address) {
        return binaryHeap[indices[account_] >> 1];
    }

    function __emptyLeftChildIndexOf(address account_)
        private
        view
        returns (uint256 idx)
    {
        if (account_ == address(0)) return 1;
        while (account_ != address(0))
            account_ = binaryHeap[__leftChildIndexOf(account_)];

        return idx;
    }

    function __emptyRightChildIndexOf(address account_)
        private
        view
        returns (uint256 idx)
    {
        if (account_ == address(0)) return 1;
        while (account_ != address(0))
            account_ = binaryHeap[__rightChildIndexOf(account_)];

        return idx;
    }

    function __leftChildIndexOf(address account_)
        private
        view
        returns (uint256)
    {
        return (indices[account_] << 1);
    }

    function __rightChildIndexOf(address account_)
        private
        view
        returns (uint256)
    {
        unchecked {
            return (indices[account_] << 1) + 1;
        }
    }

    function __addLeft(address referrer, address referree) private {
        uint256 referreeIndex = __leftChildIndexOf(referrer);
        binaryHeap[referreeIndex] = referree;
        indices[referree] = referreeIndex;
    }

    function __addRight(address referrer, address referree) private {
        uint256 referreeIndex = __rightChildIndexOf(referrer);
        binaryHeap[referreeIndex] = referree;
        indices[referree] = referreeIndex;
    }

    function __levelOf(uint256 x) private pure returns (uint8 r) {
        if (x == 0) return 0;

        if (x >= 0x100000000000000000000000000000000) {
            x >>= 128;
            r += 128;
        }
        if (x >= 0x10000000000000000) {
            x >>= 64;
            r += 64;
        }
        if (x >= 0x100000000) {
            x >>= 32;
            r += 32;
        }
        if (x >= 0x10000) {
            x >>= 16;
            r += 16;
        }
        if (x >= 0x100) {
            x >>= 8;
            r += 8;
        }
        if (x >= 0x10) {
            x >>= 4;
            r += 4;
        }
        if (x >= 0x4) {
            x >>= 2;
            r += 2;
        }
        if (x >= 0x2) r += 1;
    }
}

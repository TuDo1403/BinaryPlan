// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

contract ERC721Staking is
    UUPSUpgradeable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeERC20Upgradeable for IERC20Upgradeable;

    // Interfaces for ERC20 and ERC721
    IERC20Upgradeable public rewardsToken;
    IERC721Upgradeable public nftCollection;

    // Staker info
    struct Staker {
        // Amount of ERC721 Tokens staked
        uint256 amountStaked;
        // Last time of details update for this User
        uint256 timeOfLastUpdate;
        // Calculated, but unclaimed rewards for the User. The rewards are
        // calculated each time the user writes to the Smart Contract
        uint256 unclaimedRewards;
    }

    bytes32 public constant VERSION = 0x0;
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    // Rewards per hour per token deposited in wei.
    // Rewards are cumulated once every hour.
    uint256 private rewardsPerHour = 100000;

    // Mapping of User Address to Staker info
    mapping(address => Staker) public stakers;
    // Mapping of Token Id to staker. Made for the SC to remeber
    // who to send back the ERC721 Token to.
    mapping(uint256 => address) public stakerAddress;
    mapping(address => uint256[]) public stakedIds;

    address[] public stakersArray;

    function initialize(IERC721Upgradeable nft_, IERC20Upgradeable rewardToken_)
        external
        initializer
    {
        nftCollection = nft_;
        rewardsToken = rewardToken_;

        address sender = _msgSender();
        _grantRole(OPERATOR_ROLE, sender);
        _grantRole(UPGRADER_ROLE, sender);
        _grantRole(DEFAULT_ADMIN_ROLE, sender);

        __ReentrancyGuard_init_unchained();
    }

    // Function to receive Ether. msg.data must be empty
    receive() external payable {}

    // Fallback function is called when msg.data is not empty
    fallback() external payable {}

    function withdraw() external onlyRole(OPERATOR_ROLE) {
        //payable(msg.sender).transfer(address(this).balance);
        (bool ok, ) = _msgSender().call{value: address(this).balance}("");
        require(ok, "TRANSFER FAILED");
    }

    // If address already has ERC721 Token/s staked, calculate the rewards.
    // For every new Token Id in param transferFrom user to this Smart Contract,
    // increment the amountStaked and map msg.sender to the Token Id of the staked
    // Token to later send back on withdrawal. Finally give timeOfLastUpdate the
    // value of now.
    function stake(uint256[] calldata _tokenIds) external nonReentrant {
        if (stakers[msg.sender].amountStaked > 0) {
            uint256 rewards = calculateRewards(msg.sender);
            stakers[msg.sender].unclaimedRewards += rewards;
        } else {
            stakersArray.push(msg.sender);
        }
        uint256 len = _tokenIds.length;
        for (uint256 i; i < len; ++i) {
            require(
                nftCollection.ownerOf(_tokenIds[i]) == msg.sender,
                "Can't stake tokens you don't own!"
            );
            nftCollection.transferFrom(msg.sender, address(this), _tokenIds[i]);
            stakerAddress[_tokenIds[i]] = msg.sender;
        }
        stakers[msg.sender].amountStaked += len;
        stakers[msg.sender].timeOfLastUpdate = block.timestamp;

        uint256 length = _tokenIds.length;
        for (uint256 i; i < length; ) {
            stakedIds[msg.sender].push(_tokenIds[i]);
            unchecked {
                ++i;
            }
        }
    }

    function getStakedIds(address account_)
        external
        view
        returns (uint256[] memory)
    {
        return stakedIds[account_];
    }

    // Check if user has any ERC721 Tokens Staked and if he tried to withdraw,
    // calculate the rewards and store them in the unclaimedRewards and for each
    // ERC721 Token in param: check if msg.sender is the original staker, decrement
    // the amountStaked of the user and transfer the ERC721 token back to them
    function unStake(uint256[] calldata _tokenIds) external nonReentrant {
        Staker memory staker = stakers[msg.sender];
        require(staker.amountStaked != 0, "You have no tokens staked");
        uint256 rewards = calculateRewards(msg.sender);
        staker.unclaimedRewards += rewards;
        uint256 len = _tokenIds.length;
        uint256 tokenId;

        IERC721Upgradeable nft = nftCollection;
        for (uint256 i; i < len; ) {
            tokenId = _tokenIds[i];
            require(stakerAddress[tokenId] == msg.sender);

            delete stakerAddress[tokenId];

            nft.safeTransferFrom(address(this), msg.sender, tokenId);

            unchecked {
                ++i;
            }
        }

        staker.amountStaked -= len;
        staker.timeOfLastUpdate = block.timestamp;
        stakers[msg.sender] = staker;

        address stakerAddr;
        uint256 stakerLength;
        unchecked {
            stakerLength = stakersArray.length - 1;
        }

        for (uint256 i; i < len; ) {
            stakerAddr = stakersArray[i];
            if (stakerAddr == msg.sender) {
                stakersArray[stakerLength] = stakerAddr;
                stakersArray.pop();
            }
            unchecked {
                ++i;
            }
        }
    }

    // Calculate rewards for the msg.sender, check if there are any rewards
    // claim, set unclaimedRewards to 0 and transfer the ERC20 Reward token
    // to the user.
    function claimRewards() external {
        uint256 rewards = calculateRewards(msg.sender) +
            stakers[msg.sender].unclaimedRewards;
        require(rewards > 0, "You have no rewards to claim");
        stakers[msg.sender].timeOfLastUpdate = block.timestamp;
        stakers[msg.sender].unclaimedRewards = 0;
        rewardsToken.safeTransfer(msg.sender, rewards);
    }

    // Set the rewardsPerHour variable
    // Because the rewards are calculated passively, the owner has to first update the rewards
    // to all the stakers, witch could result in very heavy load and expensive transactions
    function setRewardsPerHour(uint256 _newValue)
        public
        onlyRole(OPERATOR_ROLE)
    {
        address[] memory _stakers = stakersArray;
        uint256 len = _stakers.length;
        for (uint256 i; i < len; ++i) {
            address user = _stakers[i];
            stakers[user].unclaimedRewards += calculateRewards(user);
            stakers[msg.sender].timeOfLastUpdate = block.timestamp;
        }
        rewardsPerHour = _newValue;
    }

    //////////
    // View //
    //////////

    function userStakeInfo(address _user)
        public
        view
        returns (uint256 _tokensStaked, uint256 _availableRewards)
    {
        return (stakers[_user].amountStaked, availableRewards(_user));
    }

    function availableRewards(address _user) internal view returns (uint256) {
        if (stakers[_user].amountStaked == 0) {
            return stakers[_user].unclaimedRewards;
        }
        uint256 _rewards = stakers[_user].unclaimedRewards +
            calculateRewards(_user);
        return _rewards;
    }

    /////////////
    // Internal//
    /////////////

    // Calculate rewards for param _staker by calculating the time passed
    // since last update in hours and mulitplying it to ERC721 Tokens Staked
    // and rewardsPerHour.
    function calculateRewards(address _staker)
        internal
        view
        returns (uint256 _rewards)
    {
        Staker memory staker = stakers[_staker];
        return (((
            ((block.timestamp - staker.timeOfLastUpdate) * staker.amountStaked)
        ) * rewardsPerHour) / 3600);
    }

    function _authorizeUpgrade(address implement_)
        internal
        virtual
        override
        onlyRole(UPGRADER_ROLE)
    {}
}

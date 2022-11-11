//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {
    ERC20,
    ERC20Permit
} from "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

import "./libraries/Bytes32Address.sol";
import "@openzeppelin/contracts/utils/structs/BitMaps.sol";

contract PMToken is ERC20Permit {
    using BitMaps for BitMaps.BitMap;
    using Bytes32Address for address;

    BitMaps.BitMap private isMinted;

    constructor(
        string memory name_,
        string memory symbol_
    ) ERC20(name_, symbol_) ERC20Permit(name_) {}

    function mint(address to_) external {
        uint256 uintTo = to_.fillLast96Bits();
        require(!isMinted.get(uintTo), "PMToken: ALREADY_MINTED");
        isMinted.set(uintTo);
        _mint(to_, 1_000 * 10 ** decimals());
    }
}

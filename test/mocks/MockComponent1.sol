// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Component } from "src/Dagfault.sol";

contract MockComponent1 is Component {

    function LABEL() public pure override returns (bytes32) {
        return toLabel(type(MockComponent1).name);
    }

    function CONFIG() internal pure override returns (Permissions[] memory deps) {}

    function INIT(bytes memory) internal pure override {
        // Mock initialization logic
    }

    function permissionedFunction1() external view permissioned returns (uint256) {
        return 1;
    }
}

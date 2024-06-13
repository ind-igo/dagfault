// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Component} from "src/Kernel.sol";

contract MockComponent1 is Component {
    constructor(address kernel_) Component(kernel_) {}

    function LABEL() public pure override returns (bytes32) {
        return bytes32("MockComponent1");
    }

    function DEPENDENCIES() external pure override returns (Dependency[] memory deps) {}

    function ENDPOINTS() external pure override returns (bytes4[] memory endpoints) {
        endpoints = new bytes4[](1);
        endpoints[0] = this.testPermissionedFunction.selector;
    }

    function _init(bytes memory) internal pure override {
        // Mock initialization logic
    }

    function testPermissionedFunction() external view permissioned returns (uint256) {
        return 1;
    }

    function testFunction() external pure returns (uint256) {
        return 2;
    }
}

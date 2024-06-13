// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Component} from "src/Kernel.sol";

// Make cause a cycle
contract MockBadComponent is Component {
    constructor(address kernel_) Component(kernel_) {}

    function LABEL() public pure override returns (bytes32) {
        return bytes32("MockBadComponent");
    }

    function DEPENDENCIES() external pure override returns (Dependency[] memory) {
        Dependency[] memory deps = new Dependency[](1);

    }

    function ENDPOINTS() external pure override returns (bytes4[] memory) {}

    function _init(bytes memory data_) internal pure override {
    }

    function mockEndpoint1() external view returns (uint256) {
        return 1;
    }

    function mockEndpoint2() external pure returns (uint256) {
        return 2;
    }
}

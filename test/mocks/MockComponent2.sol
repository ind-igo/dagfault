// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Component} from "src/Kernel.sol";
import {MockComponent1} from "./MockComponent1.sol";

// Make dependent on MockComponentOne
contract MockComponent2 is Component {
    MockComponent1 public mockComponent1;

    constructor(address kernel_) Component(kernel_) {}

    function LABEL() public pure override returns (bytes32) {
        return bytes32("MockComponentTwo");
    }

    function DEPENDENCIES() external pure override returns (Dependency[] memory deps) {
        deps = new Dependency[](1);

        deps[0].label = "MockComponentOne";
        deps[0].funcSelectors[0] = MockComponent1.testPermissionedFunction.selector;
    }

    function ENDPOINTS() external pure override returns (bytes4[] memory endpoints) {
        endpoints = new bytes4[](1);
        endpoints[0] = this.callPermissionedFunction.selector;
    }

    function _init(bytes memory) internal override {
        mockComponent1 = MockComponent1(_getComponentAddr("MockComponentOne"));
    }

    function testPermissionedFunction2() external view permissioned returns (uint256) {
        return 1;
    }

    function callPermissionedFunction() external view returns (uint256) {
        return mockComponent1.testPermissionedFunction();
    }
}

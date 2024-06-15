// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Component} from "src/Kernel.sol";
import {MockComponent1} from "./MockComponent1.sol";

// Make dependent on MockComponentOne
contract MockComponent2 is Component {
    MockComponent1 public comp1;

    constructor(address kernel_) Component(kernel_) {}

    function LABEL() public pure override returns (bytes32) {
        return toLabel(type(MockComponent2).name);
    }

    function DEPENDENCIES() external pure override returns (Dependency[] memory deps) {
        deps = new Dependency[](1);

        /*deps[0].label = "MockComponent1";*/
        deps[0].label = toLabel(type(MockComponent1).name);
        deps[0].funcSelectors = new bytes4[](1);
        deps[0].funcSelectors[0] = MockComponent1.testPermissionedFunction1.selector;
    }

    function ENDPOINTS() external pure override returns (bytes4[] memory endpoints) {
        endpoints = new bytes4[](1);
        endpoints[0] = this.callPermissionedFunction1.selector;
    }

    function _init(bytes memory) internal override {
        comp1 = MockComponent1(getComponentAddr(type(MockComponent1).name));
    }

    function testPermissionedFunction2() external view permissioned returns (uint256) {
        return 1;
    }

    function callPermissionedFunction1() external view returns (uint256) {
        return comp1.testPermissionedFunction1();
    }
}

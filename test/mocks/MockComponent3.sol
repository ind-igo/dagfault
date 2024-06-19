// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Component } from "src/Kernel.sol";
import { MockComponent1 } from "./MockComponent1.sol";
import { MockComponent2 } from "./MockComponent2.sol";

import { console2 } from "forge-std/console2.sol";

// Make dependent on MockComponentOne and MockComponentTwo
contract MockComponent3 is Component {
    MockComponent1 public comp1;
    MockComponent2 public comp2;

    address public data1;
    bytes32 public data2;
    uint256 public dataFromComponent1;

    constructor(address kernel_) Component(kernel_) { }

    function LABEL() public pure override returns (bytes32) {
        return toLabel(type(MockComponent3).name);
    }

    function DEPENDENCIES() external pure override returns (Dependency[] memory deps) {
        deps = new Dependency[](2);

        deps[0].label = toLabel(type(MockComponent1).name);
        deps[0].funcSelectors = new bytes4[](1);
        deps[0].funcSelectors[0] = MockComponent1.testPermissionedFunction1.selector;

        deps[1].label = "MockComponent2";
        deps[1].funcSelectors = new bytes4[](1);
        deps[1].funcSelectors[0] = MockComponent2.testPermissionedFunction2.selector;
    }

    function ENDPOINTS() external pure override returns (bytes4[] memory endpoints) {
        endpoints = new bytes4[](2);
        endpoints[0] = this.mockEndpoint1.selector;
        endpoints[1] = this.mockEndpoint2.selector;
    }

    function _init(bytes memory data_) internal override {
        comp1 = MockComponent1(getComponentAddr(type(MockComponent1).name));
        comp2 = MockComponent2(getComponentAddr(type(MockComponent2).name));

        // Decode data
        (data1, data2) = abi.decode(data_, (address, bytes32));
        console2.log("CALLING PERM FUNC 1");
        dataFromComponent1 = comp1.testPermissionedFunction1();
    }

    function mockEndpoint1() external pure returns (uint256) {
        return 1;
    }

    function mockEndpoint2() external pure returns (uint256) {
        return 2;
    }
}

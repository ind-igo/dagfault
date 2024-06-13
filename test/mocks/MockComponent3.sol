// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Component} from "src/Kernel.sol";
import {MockComponent1} from "./MockComponent1.sol";
import {MockComponent2} from "./MockComponent2.sol";

// Make dependent on MockComponentOne and MockComponentTwo
contract MockComponent3 is Component {
    MockComponent1 public mockComponent1;
    MockComponent2 public mockComponent2;

    address public data1;
    bytes32 public data2;
    uint256 public dataFromComponent1;

    constructor(address kernel_) Component(kernel_) {}

    function LABEL() public pure override returns (bytes32) {
        return bytes32("MockComponent3");
    }

    function DEPENDENCIES() external pure override returns (Dependency[] memory deps) {}

    function ENDPOINTS() external pure override returns (bytes4[] memory endpoints) {
        endpoints = new bytes4[](2);
        endpoints[0] = this.mockEndpoint1.selector;
        endpoints[1] = this.mockEndpoint2.selector;
    }

    function _init(bytes memory data_) internal override {
        mockComponent1 = MockComponent1(_getComponentAddr("MockComponentOne"));
        mockComponent2 = MockComponent2(_getComponentAddr("MockComponentTwo"));

        // Decode data
        (data1, data2) = abi.decode(data_, (address, bytes32));
        dataFromComponent1 = mockComponent1.testPermissionedFunction();

    }

    function mockEndpoint1() external pure returns (uint256) {
        return 1;
    }

    function mockEndpoint2() external pure returns (uint256) {
        return 2;
    }

}

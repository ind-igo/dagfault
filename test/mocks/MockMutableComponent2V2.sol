// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { MutableComponent } from "src/Kernel.sol";
import { MockComponent1 } from "./MockComponent1.sol";
import { console2 } from "forge-std/console2.sol";

contract MockMutableComponent2 is MutableComponent {
    MockComponent1 public comp1;

    uint256 randomNum = 69;
    bytes32 public testData = "test";

    constructor(address kernel_, uint256 version_) MutableComponent(kernel_) {}

    function VERSION() public pure override returns (uint8) {
        return 2;
    }

    function LABEL() public pure override returns (bytes32) {
        return toLabel(type(MockMutableComponent2).name);
    }

    function CONFIG() external override returns (Dependency[] memory) {
        Dependency[] memory deps = new Dependency[](1);

        deps[0].label = toLabel(type(MockComponent1).name);
        deps[0].funcSelectors = new bytes4[](1);
        deps[0].funcSelectors[0] = MockComponent1.testPermissionedFunction1.selector;

        comp1 = MockComponent1(getComponentAddr(deps[0].label));

        return deps;
    }

    function __init(bytes memory) internal override {
    }

    function testPermissionedFunction2() external view permissioned returns (uint256) {
        return 1;
    }

    function callPermissionedFunction1() external view returns (uint256) {
        return comp1.testPermissionedFunction1();
    }
}
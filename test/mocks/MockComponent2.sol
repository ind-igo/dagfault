// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Component } from "src/Kernel.sol";
import { MockComponent1 } from "./MockComponent1.sol";
import { console2 } from "forge-std/console2.sol";

// Make dependent on MockComponentOne
contract MockComponent2 is Component {
    MockComponent1 public comp1;

    uint256 randomNum = 69;

    /*constructor(address kernel_) Component(kernel_) {}*/

    function LABEL() public pure override returns (bytes32) {
        return toLabel(type(MockComponent2).name);
    }

    function CONFIG() internal pure override returns (Dependency[] memory deps) {
        deps = new Dependency[](1);

        deps[0].label = toLabel(type(MockComponent1).name);
        deps[0].funcSelectors = new bytes4[](1);
        deps[0].funcSelectors[0] = MockComponent1.permissionedFunction1.selector;
    }

    function INIT(bytes memory) internal override {
        comp1 = MockComponent1(getComponentAddr(toLabel(type(MockComponent1).name)));
    }

    function permissionedFunction2() external view permissioned returns (uint256) {
        return 1;
    }

    function callPermissionedFunction1() external view returns (uint256) {
        return comp1.permissionedFunction1();
    }
}

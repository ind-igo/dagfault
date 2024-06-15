// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import {Kernel, Component} from "src/Kernel.sol";
import "test/mocks/MockComponent1.sol";
import "test/mocks/MockComponent2.sol";
import "test/mocks/MockComponent3.sol";

/*
tests:
4. install component, read only dependency
5. install component with cycle
6. install component already exists
7. install component, bad config

. uninstall component
*/
contract KernelTest is Test {
    Kernel kernel;
    MockComponent1 component1;
    MockComponent2 component2;
    MockComponent3 component3;

    function setUp() public {
        kernel = new Kernel();
        component1 = new MockComponent1(address(kernel));
        component2 = new MockComponent2(address(kernel));
        component3 = new MockComponent3(address(kernel));
    }

    modifier afterInstallMockComp1() {
        kernel.executeAction(Kernel.Actions.INSTALL, address(component1), bytes(""));
        _;
    }

    modifier afterInstallMockComp2() {
        kernel.executeAction(Kernel.Actions.INSTALL, address(component2), bytes(""));
        _;
    }

    modifier afterInstallMockComp3() {
        address data1 = address(0x1234);
        bytes32 data2 = bytes32("hello");
        bytes memory encodedData = abi.encode(data1, data2);
        kernel.executeAction(Kernel.Actions.INSTALL, address(component3), encodedData);
        _;
    }

    function test_Install()
        public
        afterInstallMockComp1
    {
        assertTrue(kernel.isComponentActive(component1.LABEL()));
        assertEq(address(kernel.getComponentForLabel(component1.LABEL())), address(component1));
    }

    function test_Install_WithDep() public
        afterInstallMockComp1
        afterInstallMockComp2
    {
        assertTrue(kernel.isComponentActive(component1.LABEL()));
        assertTrue(kernel.isComponentActive(component2.LABEL()));
        assertEq(address(kernel.getComponentForLabel(component1.LABEL())), address(component1));
        assertEq(address(kernel.getComponentForLabel(component2.LABEL())), address(component2));

        // Check dependencies were properly set
        assertEq(address(component2.comp1()), address(component1));
    }

    function test_Install_WithInitAndPerms() public
        afterInstallMockComp1
        afterInstallMockComp2
        afterInstallMockComp3
    {
        assertTrue(kernel.isComponentActive(component1.LABEL()));
        assertEq(address(kernel.getComponentForLabel(component1.LABEL())), address(component1));

        // Check dependencies were properly set
        assertEq(address(component3.comp1()), address(component1));
        assertEq(address(component3.comp2()), address(component2));

        // Check data from init
        vm.prank(address(kernel));
        uint256 data3 = component3.dataFromComponent1();

        assertEq(component3.data1(), address(0x1234));
        assertEq(component3.data2(), bytes32("hello"));
        assertEq(component3.dataFromComponent1(), data3);
    }

    /*function testUninstallComponent() public {
        bytes memory data = abi.encodeWithSelector(MockComponent.init.selector);
        kernel.executeAction(Kernel.Actions.INSTALL, address(component1), data);

        kernel.executeAction(Kernel.Actions.UNINSTALL, address(component1), "");

        assertFalse(kernel.isComponentActive(component1.LABEL()));
    }*/

    function testChangeExecutor() public {
        address newExecutor = address(0x1234);
        kernel.executeAction(Kernel.Actions.CHANGE_EXEC, newExecutor, "");

        assertEq(kernel.executor(), newExecutor);
    }

    // Add more test cases for other actions and scenarios
}

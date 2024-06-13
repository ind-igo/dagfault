// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import "src/Kernel.sol";
import "test/mocks/MockComponent1.sol";
import "test/mocks/MockComponent2.sol";

/*
tests:
1. install regular component (no dependencies)
2. install component with dependencies
3. install component with data
4. install component with multiple dependencies and data
5. install component with cycle
*/
contract KernelTest is Test {
    Kernel kernel;
    MockComponent1 component1;
    MockComponent2 component2;

    function setUp() public {
        kernel = new Kernel();
        component1 = new MockComponent1(address(kernel));
        component2 = new MockComponent2(address(kernel));
    }

    function test_Install() public {
        kernel.executeAction(Kernel.Actions.INSTALL, address(component1), bytes(""));

        assertTrue(kernel.isComponentActive(component1.LABEL()));
        assertEq(address(kernel.getComponentForLabel(component1.LABEL())), address(component1));
    }

    function test_InstallWithDeps() public {
        kernel.executeAction(Kernel.Actions.INSTALL, address(component1), bytes(""));
        kernel.executeAction(Kernel.Actions.INSTALL, address(component2), bytes(""));

        /*assertTrue(kernel.isComponentActive(component1.LABEL()));
        assertTrue(kernel.isComponentActive(component2.LABEL()));
        assertEq(address(kernel.getComponentForLabel(component1.LABEL())), address(component1));
        assertEq(address(kernel.getComponentForLabel(component2.LABEL())), address(component2));*/

        // Check dependencies were properly set
        assertEq(address(component2.mockComponent1()), address(component1));
    }

    /*function testInstallComponentWithData() public {
        bytes memory data = abi.encodeWithSelector(MockComponent.init.selector);
        kernel.executeAction(Kernel.Actions.INSTALL, address(component1), data);

        assertTrue(kernel.isComponentActive(component1.LABEL()));
        assertEq(address(kernel.getComponentForName(component1.LABEL())), address(component1));
    }*/

    /*function testInstallComponentWithDependency() public {
        bytes memory data1 = abi.encodeWithSelector(MockComponent.init.selector);
        kernel.executeAction(Kernel.Actions.INSTALL, address(component1), data1);

        bytes memory data2 = abi.encodeWithSelector(MockComponent.init.selector);
        kernel.executeAction(Kernel.Actions.INSTALL, address(component2), data2);

        assertTrue(kernel.isComponentActive(component1.LABEL()));
        assertTrue(kernel.isComponentActive(component2.LABEL()));
        assertEq(address(kernel.getComponentForName(component1.LABEL())), address(component1));
        assertEq(address(kernel.getComponentForName(component2.LABEL())), address(component2));
    }*/

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

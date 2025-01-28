// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/StewardCompensation.sol";
import "./MockERC20.sol";

contract StewardCompensationTest is Test {
    event CompensationPaid(
        uint256 indexed periodId,
        address indexed recipient,
        uint256 amount,
        string role,
        uint256 batchId
    );
    StewardCompensation public stewardComp;
    MockERC20 public usdc;

    address owner;
    address recipient1;
    address recipient2;

    uint256 constant MONTH = 30 days;
    uint256 constant INITIAL_AMOUNT = 1000 * 1e6; // 1000 USDC

    function setUp() public {
        owner = address(this);
        recipient1 = makeAddr("recipient1");
        recipient2 = makeAddr("recipient2");

        // Deploy mock USDC
        usdc = new MockERC20("USDC", "USDC", 6);

        // Deploy StewardCompensation
        stewardComp = new StewardCompensation(address(usdc), owner);

        // Mint and approve USDC
        usdc.mint(owner, 100_000 * 1e6);
        usdc.approve(address(stewardComp), type(uint256).max);
    }

    function testAddRecipient() public {
        stewardComp.addRecipient(recipient1, INITIAL_AMOUNT, "Developer");

        (uint256 amount, string memory role, bool isActive) = stewardComp
            .recipients(recipient1);
        assertEq(amount, INITIAL_AMOUNT);
        assertEq(role, "Developer");
        assertTrue(isActive);
    }

    function testUpdateRecipient() public {
        stewardComp.addRecipient(recipient1, INITIAL_AMOUNT, "Developer");
        stewardComp.updateRecipient(
            recipient1,
            INITIAL_AMOUNT * 2,
            "Senior Developer"
        );

        (uint256 amount, string memory role, bool isActive) = stewardComp
            .recipients(recipient1);
        assertEq(amount, INITIAL_AMOUNT * 2);
        assertEq(role, "Senior Developer");
        assertTrue(isActive);
    }

    function testRemoveRecipient() public {
        stewardComp.addRecipient(recipient1, INITIAL_AMOUNT, "Developer");
        stewardComp.removeRecipient(recipient1);

        (, , bool isActive) = stewardComp.recipients(recipient1);
        assertFalse(isActive);
    }

    function testSetPaymentPeriod() public {
        uint256 futureTime = block.timestamp + MONTH;
        stewardComp.setPeriod(1, futureTime);

        (uint256 dueTimestamp, bool paid) = stewardComp.paymentPeriods(1);
        assertEq(dueTimestamp, futureTime);
        assertFalse(paid);
    }

    function testProcessCompensation() public {
        stewardComp.addRecipient(recipient1, INITIAL_AMOUNT, "Developer");

        uint256 futureTime = block.timestamp + MONTH;
        stewardComp.setPeriod(1, futureTime);

        // Advance time
        vm.warp(futureTime);

        // Expect CompensationPaid event
        vm.expectEmit(true, true, false, true);
        emit CompensationPaid(1, recipient1, INITIAL_AMOUNT, "Developer", 1);

        address[] memory recipients = new address[](1);
        recipients[0] = recipient1;
        stewardComp.sendComp(1, recipients, 1);

        assertEq(usdc.balanceOf(recipient1), INITIAL_AMOUNT);
    }

    function testGetActiveRecipients() public {
        stewardComp.addRecipient(recipient1, INITIAL_AMOUNT, "Developer");
        stewardComp.addRecipient(recipient2, INITIAL_AMOUNT * 2, "Designer");

        (
            address[] memory addresses,
            uint256[] memory amounts,
            string[] memory roles
        ) = stewardComp.getActiveRecipients();

        assertEq(addresses.length, 2);
        assertEq(amounts[0], INITIAL_AMOUNT);
        assertEq(roles[0], "Developer");
    }

    function testGetPaymentHistory() public {
        stewardComp.addRecipient(recipient1, INITIAL_AMOUNT, "Developer");

        uint256 futureTime = block.timestamp + MONTH;
        stewardComp.setPeriod(1, futureTime);
        vm.warp(futureTime);

        address[] memory recipients = new address[](1);
        recipients[0] = recipient1;
        stewardComp.sendComp(1, recipients, 1);

        (
            uint256[] memory periodIds,
            uint256[] memory amounts, // skip timestamps
            ,
            bool[] memory paymentStatus
        ) = stewardComp.getPaymentHistory(recipient1);

        assertEq(periodIds[0], 1);
        assertEq(amounts[0], INITIAL_AMOUNT);
        assertTrue(paymentStatus[0]);
    }

    function testPauseUnpause() public {
        stewardComp.pause();

        // Try to send compensation while paused
        vm.expectRevert("Pausable: paused");
        address[] memory recipients = new address[](1);
        recipients[0] = recipient1;
        stewardComp.sendComp(1, recipients, 1);

        stewardComp.unpause();
        // Now would work if other conditions are met
    }

    function testCheckAllowance() public {
        assertEq(stewardComp.checkAllowance(), type(uint256).max);
    }
}

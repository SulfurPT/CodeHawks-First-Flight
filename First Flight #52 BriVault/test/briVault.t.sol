// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {BriVault} from "../src/briVault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MockERC20} from "./MockErc20.t.sol";


contract BriVaultTest is Test {
    uint256 public participationFeeBsp;
    uint256 public eventStartDate;
    uint256 public eventEndDate;
    address public participationFeeAddress;
    uint256 public minimumAmount;

    // Vault contract
    BriVault public briVault;
    MockERC20 public mockToken;

    // Users
    address owner = makeAddr("owner");
    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");
    address user3 = makeAddr("user3");
    address user4 = makeAddr("user4");
    address user5 = makeAddr("user5");

    string[48] countries = [
        "United States", "Canada", "Mexico", "Argentina", "Brazil", "Ecuador",
        "Uruguay", "Colombia", "Peru", "Chile", "Japan", "South Korea",
        "Australia", "Iran", "Saudi Arabia", "Qatar", "Uzbekistan", "Jordan",
        "France", "Germany", "Spain", "Portugal", "England", "Netherlands",
        "Italy", "Croatia", "Belgium", "Switzerland", "Denmark", "Poland",
        "Serbia", "Sweden", "Austria", "Morocco", "Senegal", "Nigeria",
        "Cameroon", "Egypt", "South Africa", "Ghana", "Algeria", "Tunisia",
        "Ivory Coast", "New Zealand", "Costa Rica", "Panama", "United Arab Emirates", "Iraq"
    ];

    function setUp() public {
        participationFeeBsp = 150; // 1.5%
        eventStartDate = block.timestamp + 2 days;
        eventEndDate = eventStartDate + 31 days;
        participationFeeAddress = makeAddr("participationFeeAddress");
        minimumAmount = 0.0002 ether;

        mockToken = new MockERC20("Mock Token", "MTK");

        mockToken.mint(owner, 20 ether);
        mockToken.mint(user1, 20 ether);
        mockToken.mint(user2, 20 ether);
        mockToken.mint(user3, 20 ether);
        mockToken.mint(user4, 20 ether);
        mockToken.mint(user5, 20 ether);

        vm.startPrank(owner);
        briVault = new BriVault(
            IERC20(address(mockToken)), // replace `address(0)` with actual _asset address
            participationFeeBsp,
            eventStartDate,
            participationFeeAddress,
            minimumAmount,
            eventEndDate
        );

        briVault.approve(address(mockToken), type(uint256).max);

          vm.stopPrank();
    }

    function testSetCountryOnlyOwner() public {
        vm.startPrank(owner);
        briVault.setCountry(countries);
        string memory result = briVault.getCountry(2);
        assertEq(result, "Mexico");
    }

    function testOwnerIsSetCorrectly() public view {
    assertEq(briVault.owner(), owner, "Owner should be deployer");
    }

    function testNotOwnerCannotSetCountry() public {
        vm.prank(user1);
        vm.expectRevert();
        briVault.setCountry(countries);
    }

    function testSetWinner() public {
        vm.startPrank(owner);
        briVault.setCountry(countries);
        vm.warp(eventEndDate + 1);
        string memory winner = briVault.setWinner(2);
        console.log(winner);
        string memory result = briVault.getWinner();
        console.log(result);
        assertEq(result, "Mexico");
    }

    function test_deposit() public {
        vm.startPrank(user1);
        mockToken.approve(address(briVault), 5 ether);
        briVault.deposit(5 ether, user1);
        vm.stopPrank();

        vm.startPrank(user2);
        mockToken.approve(address(briVault), 5 ether);
        briVault.deposit(5 ether, user2);
        vm.stopPrank();

        vm.startPrank(user3);
        mockToken.approve(address(briVault), 5 ether);
        briVault.deposit(5 ether, user3);
        vm.stopPrank();

        vm.startPrank(user4);
        mockToken.approve(address(briVault), 5 ether);
        briVault.deposit(5 ether, user4);
        vm.stopPrank();

        assertEq(mockToken.balanceOf(address(briVault)), 19700000000000000000);
    }

    function test_deposit_after_event_start() public {
        vm.warp(eventStartDate + 3);
        vm.startPrank(user1);
        mockToken.approve(address(briVault), 5 ether);
        vm.expectRevert(abi.encodeWithSignature("eventStarted()"));
        briVault.deposit(5 ether, user1);
        vm.stopPrank();
    }

    function test_joinEvent_noDeposit() public {
        vm.startPrank(user5);
        mockToken.approve(address(briVault), 5 ether);
        vm.expectRevert(abi.encodeWithSignature("noDeposit()"));
        briVault.joinEvent(3);
        vm.stopPrank();
    }

    function test_joinEvent_success() public {
        vm.startPrank(user1);
        mockToken.approve(address(briVault), 5 ether);
        uint256 user1shares = briVault.deposit(5 ether, user1);

        briVault.joinEvent(10);
        console.log("user1 shares", user1shares);
        vm.stopPrank();

        vm.startPrank(user2);
        mockToken.approve(address(briVault), 5 ether);
        uint256 user2shares = briVault.deposit(5 ether, user2);

        briVault.joinEvent(20);
        console.log("user2 shares", user2shares);
        vm.stopPrank();

        vm.startPrank(user3);
        mockToken.approve(address(briVault), 5 ether);
         uint256 user3shares = briVault.deposit(5 ether, user3);
      
        briVault.joinEvent(30);
        console.log("user3 shares", user3shares);
        vm.stopPrank();

        vm.startPrank(user4);
        mockToken.approve(address(briVault), 5 ether);
         uint256 user4shares =  briVault.deposit(5 ether, user4);
    
        briVault.joinEvent(40);
        console.log("user4 shares", user4shares);
        vm.stopPrank();
        
        assertEq(briVault.balanceOf(user1), user1shares);
        assertEq(briVault.balanceOf(user2), user2shares);
        assertEq(briVault.balanceOf(user3), user3shares);
        assertEq(briVault.balanceOf(user4), user4shares);
    }

    function test_cancelParticipation () public {

        vm.startPrank(user1);
        mockToken.approve(address(briVault), 5 ether);
        briVault.deposit(5 ether, user1);
        briVault.cancelParticipation();
        vm.stopPrank();

        assertEq(briVault.stakedAsset(user1), 0 ether);

        assertEq(mockToken.balanceOf(address(participationFeeAddress)), 0.075 ether);
    }

    function test_cancelParticipation_afterEventStart() public {
        vm.startPrank(user1);
        mockToken.approve(address(briVault), 5 ether);
        briVault.deposit(5 ether, user1);
        vm.warp(eventStartDate + 4);
        vm.expectRevert(abi.encodeWithSignature("eventStarted()"));
        briVault.cancelParticipation();
        vm.stopPrank();
    }

    function test_withdraw() public {
        vm.startPrank(owner);
        briVault.setCountry(countries);
        vm.stopPrank();

        vm.startPrank(user1);
        mockToken.approve(address(briVault), 5 ether);
        uint256 user1Shares =  briVault.deposit(5 ether, user1);
        briVault.joinEvent(10);
        uint256 balanceBeforuser1 = mockToken.balanceOf(user1);
        vm.stopPrank();

        vm.startPrank(user2);
        mockToken.approve(address(briVault), 5 ether);
        uint256 user2Shares = briVault.deposit(5 ether, user2);
        briVault.joinEvent(10);
        uint256 balanceBeforuser2 = mockToken.balanceOf(user2);
        vm.stopPrank();

        vm.startPrank(user3);
        mockToken.approve(address(briVault), 5 ether);
        uint256 user3Shares = briVault.deposit(5 ether, user3);
        briVault.joinEvent(30);
        vm.stopPrank();

        vm.startPrank(user4);
        mockToken.approve(address(briVault), 5 ether);
        uint256 user4Shares = briVault.deposit(5 ether, user4);
        briVault.joinEvent(10);
        uint256 balanceBeforuser4 = mockToken.balanceOf(user4);
        vm.stopPrank();

        console.log( user3Shares);
        console.log( user2Shares);
        console.log( user1Shares);
        console.log( user4Shares);

        vm.warp(eventEndDate + 1);
        vm.startPrank(owner);
        briVault.setWinner(10);
        console.log(briVault.finalizedVaultAsset());
        vm.stopPrank();

        vm.startPrank(user1);
        briVault.withdraw();
        vm.stopPrank();

        vm.startPrank(user2);
        briVault.withdraw();
        vm.stopPrank();

        vm.startPrank(user3);
        vm.expectRevert(abi.encodeWithSignature("didNotWin()"));
        briVault.withdraw();
        vm.stopPrank();

        vm.startPrank(user4);
        briVault.withdraw();
        vm.stopPrank();

     assertEq(mockToken.balanceOf(user1), balanceBeforuser1 + 6566666666666666666);
     assertEq(mockToken.balanceOf(user2), balanceBeforuser2 + 6566666666666666666);
     assertEq(mockToken.balanceOf(user4), balanceBeforuser4 + 6566666666666666666);
       
    }
    
}
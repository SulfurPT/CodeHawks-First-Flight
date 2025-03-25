// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import {InheritanceManager} from "../src/InheritanceManager.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {MaliciousBeneficiary} from "./MaliciousBeneficiary.sol";

contract Testcontract is Test {
    InheritanceManager im;
    ERC20Mock usdc;
    ERC20Mock weth;

    address owner = makeAddr("owner");
    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");
    address user3 = makeAddr("user3");
    address user4 = makeAddr("user4");

    address public inheritanceContract;

    function setUp() public {
        _deploy();
        _initialize();
        //_fund();
    }

    function _deploy() internal {
        vm.prank(owner);
        im = new InheritanceManager();
        usdc = new ERC20Mock();
        weth = new ERC20Mock();
    }

    function _initialize() internal {
        usdc.mint(address(im), 10e18);
        weth.mint(address(im), 10e18);
    }

    function test_SendERC20From() public {
        // testes a toa, esta tudo certo
        uint256 deadline = im.getDeadline();
        uint256 expectedDeadline = 88 days;
        //vm.warp(10);
        vm.startPrank(owner);
        im.sendERC20(address(weth), 1e18, user1);
        assertEq(weth.balanceOf(address(im)), 9e18);
        assertEq(weth.balanceOf(user1), 1e18);
        deadline = im.getDeadline();
        //expectedDeadline = 90 days;
        assertGe(deadline, expectedDeadline);
        console.log("Dias passados:", expectedDeadline / 1 days);
        console.log("Dias que tem que passar:", deadline / 1 days);
        vm.stopPrank();
    }

    function test_onlyOne() public {
        vm.startPrank(owner);
        im.addBeneficiery(user1);
        vm.stopPrank();
        vm.warp(1);
        vm.deal(address(im), 10e10);
        vm.warp(1 + 90 days);
        vm.startPrank(user4);
        im.inherit();
        vm.stopPrank();
        assertEq(user4, im.getOwner());
        console.log("dinheiro no contracto:", address(im).balance);
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////////////
    // pode ser chamado por alguem que nao é Beneficiario
    // msg.sender != Beneficiario = PODE
    ////////////////////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////////////
    function test_withdrawFunds() public {
        vm.startPrank(owner);
        im.addBeneficiery(user1);
        im.addBeneficiery(user2);
        im.addBeneficiery(user3);
        vm.stopPrank();
        vm.warp(1);
        vm.deal(address(im), 20);
        console.log("dinheiro no contracto antes de ser dividido:", address(im).balance);
        vm.warp(1 + 91 days);
        vm.startPrank(user1);
        im.inherit();
        im.withdrawInheritedFunds(address(0));
        vm.stopPrank();
        console.log("User1 fica com:", user1.balance);
        console.log("User2 fica com:", user2.balance);
        console.log("User3 fica com:", user3.balance);
        // console.log("User4 fica com:", user4.balance);
        console.log("dinheiro no contracto:", address(im).balance);
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////////////
    // reentracy attack - NAO PODE
    ////////////////////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////////////
    function test_withdrawInheritedFundsReentracy() public {
        MaliciousBeneficiary malicious = new MaliciousBeneficiary(address(im));
        vm.startPrank(owner);
        im.addBeneficiery(address(malicious));
        im.addBeneficiery(user1);
        im.addBeneficiery(user2);
        vm.stopPrank();
        vm.warp(1);
        vm.deal(address(im), 9e10);
        console.log("dinheiro no contracto antes de ser dividido:", address(im).balance);

        // Deploy do contrato malicioso

        // Troca um dos beneficiários pelo contrato malicioso
        //vm.startPrank(address(owner));
        //im.addBeneficiery(address(malicious)); // Coloca o contrato malicioso como um beneficiário
        //vm.stopPrank();

        vm.warp(1 + 90 days);
        vm.startPrank(user4);
        im.inherit();
        im.withdrawInheritedFunds(address(0));
        vm.stopPrank();
        console.log("User1 fica com:", user1.balance);
        console.log("User2 fica com:", user2.balance);
        console.log("User4 (hacker) fica com:", address(malicious).balance);
        console.log("dinheiro no contracto:", address(im).balance);
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////////////
    // pode o msg.sender sem ser beneficiario criar um appointTrustee - FALHA
    ////////////////////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////////////

    function test_TrusteeCanChangeValues() public {
        vm.startPrank(owner);
        im.addBeneficiery(user1);
        im.addBeneficiery(user2);
        im.createEstateNFT("our beach-house", 20, address(usdc));
        vm.stopPrank();
        vm.warp(1 + 90 days);
        vm.startPrank(user2);
        im.inherit();
        im.appointTrustee(user3);
        vm.stopPrank();
        vm.startPrank(user3);
        im.setNftValue(1, 5);
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Comprar NFT - multiplos podem comprar o nft
    ////////////////////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////////////
    function test_buyOutEstateNFTMultiple() public {
        vm.startPrank(owner);
        im.addBeneficiery(user1);
        im.addBeneficiery(user2);
        im.addBeneficiery(user3);
        //im.removeBeneficiary(user3);
        im.createEstateNFT("our beach-house", 23, address(usdc));
        vm.stopPrank();
        usdc.mint(user2, 14);
        /* usdc.mint(user2, 20);
        usdc.mint(user3, 20);
        console.log("User1 tem:", usdc.balanceOf(user1));
        console.log("User2 tem:", usdc.balanceOf(user2));
        console.log("User3 tem:", usdc.balanceOf(user3));
        vm.warp(1 + 90 days);
        vm.startPrank(user1);
        usdc.approve(address(im), 20);
        im.inherit();
        im.buyOutEstateNFT(1);
        vm.stopPrank();

        vm.startPrank(user2);
        usdc.approve(address(im), 20);
        im.inherit();
        im.buyOutEstateNFT(1);
        vm.stopPrank(); */

        vm.warp(1 + 90 days);
        vm.startPrank(user2);
        usdc.approve(address(im), 20);
        im.inherit();
        im.buyOutEstateNFT(1);
        vm.stopPrank();

        console.log("User1 fica com:", usdc.balanceOf(user1));
        console.log("User2 fica com:", usdc.balanceOf(user2));
        console.log("User3 fica com:", usdc.balanceOf(user3));
        console.log("Contracto fica com:", usdc.balanceOf(address(im)));
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Remover um Beneficiario ao inicio faz lock do NFT e se for no fim faz as contas erradas porque vai dar ao 0
    ////////////////////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////////////
    function test_NFTFunds() public {
        vm.startPrank(owner);
        im.addBeneficiery(user1);
        im.addBeneficiery(user2);
        im.addBeneficiery(user3);
        im.createEstateNFT("our beach-house", 22, address(usdc));
        vm.stopPrank();
        vm.startPrank(user3);
        usdc.mint(user3, 14);
        usdc.approve(address(im), 22);
        vm.warp(1 + 90 days);
        im.inherit();
        im.buyOutEstateNFT(1);
        console.log("User1 Balance:", usdc.balanceOf(user1));
        console.log("User2 Balance:", usdc.balanceOf(user2));
        console.log("User3 Balance:", usdc.balanceOf(user3));
        console.log("Money on the contract after the division:", usdc.balanceOf(address(im)));
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Remover um Beneficiario ao inicio faz lock dos Funds e se for no fim faz as contas erradas porque vai dar ao 0
    ////////////////////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////////////
    function test_testremoveOneBeneficieryLockfunds() public {
        vm.startPrank(owner);
        im.addBeneficiery(user1);
        im.addBeneficiery(user2);
        im.addBeneficiery(user3);
        im.removeBeneficiary(user3);
        vm.stopPrank();
        vm.warp(1);
        vm.deal(address(im), 10e18);
        vm.warp(1 + 90 days);
        vm.startPrank(user1);
        im.inherit();
        im.withdrawInheritedFunds(address(usdc));
        vm.stopPrank();
        //assertEq(3e18, usdc.balanceOf(user1));
        //assertEq(3e18, usdc.balanceOf(user2));
        //assertEq(3e18, usdc.balanceOf(user3));

        console.log("User1 Balance:", usdc.balanceOf(user1));
        console.log("User2 Balance:", usdc.balanceOf(user2));
        console.log("User3 Balance:", usdc.balanceOf(user3));
        console.log("wtv:", usdc.balanceOf(address(usdc)));
    }

    function test_withdrawFundsRemoveBeneficiary() public {
        vm.startPrank(owner);
        im.addBeneficiery(user1);
        im.addBeneficiery(user2);
        im.addBeneficiery(user3);
        im.removeBeneficiary(user2);
        vm.stopPrank();
        vm.warp(1);
        vm.deal(address(im), 15);
        console.log("Money on the contract before the division to the Beneficieries:", address(im).balance);
        vm.warp(1 + 91 days);
        vm.startPrank(user1);
        im.inherit();
        im.withdrawInheritedFunds(address(0));
        vm.stopPrank();
        console.log("User1 have after the division:", user1.balance);
        console.log("User2 have after the division:", user2.balance);
        console.log("User3 have after the division:", user3.balance);
        console.log("Contract 0 have after the division:", address(0x0).balance);
        console.log("Money on the contract after the division:", address(im).balance);
    }

    function test_OnlyUserinFrontIsPayed() public {
        vm.startPrank(owner);
        im.addBeneficiery(user1);
        im.addBeneficiery(user2);
        im.addBeneficiery(user3);
        im.addBeneficiery(user4);
        im.createEstateNFT("our beach-house", 23, address(usdc));
        vm.stopPrank();
        usdc.mint(user2, 15);
        vm.warp(1 + 90 days);
        vm.startPrank(user2);
        usdc.approve(address(im), 20);
        im.inherit();
        im.buyOutEstateNFT(1);
        vm.stopPrank();

        console.log("User1 will have:", usdc.balanceOf(user1));
        console.log("User2 will have:", usdc.balanceOf(user2));
        console.log("User3 will have:", usdc.balanceOf(user3));
        console.log("User4 will have:", usdc.balanceOf(user4));
    }
}

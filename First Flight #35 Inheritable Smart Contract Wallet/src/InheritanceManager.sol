//SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import {Trustee} from "./modules/Trustee.sol";
import {NFTFactory} from "./NFTFactory.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract InheritanceManager is Trustee {
    using SafeERC20 for IERC20;

    //////////////////////////////////////////////////////////////////////////////////
    ///////////////////////////////// Errors /////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////
    error NotOwner(address);
    error InsufficientBalance();
    error InactivityPeriodNotLongEnough();
    error InvalidBeneficiaries();
    error NotYetInherited();

    //////////////////////////////////////////////////////////////////////////////////
    ///////////////////// State Variables & Constants ////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////
    NFTFactory nft;
    address owner;
    address[] beneficiaries;
    uint256 deadline;
    bool isInherited = false;
    mapping(address protocol => bytes) interactions;
    uint256 public constant TIMELOCK = 90 days;

    constructor() {
        owner = msg.sender;
        nft = new NFTFactory(address(this));
    }

    //////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////// Modifiers ////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////

    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert NotOwner(msg.sender);
        }
        _;
    }

    /**
     * @dev this while loop will revert on array out of bounds if not
     * called by a beneficiary.
     */
    // @audit check if the msg.sender can continue if not beneficiary
    modifier onlyBeneficiaryWithIsInherited() {
        uint256 i = 0;
        // @audit-info the contract will loop out of bounds if the sender is not a beneficiary
        while (i < beneficiaries.length + 1) {
            // @audit-info if msg.sender is not a beneficiary what will happen?
            if (msg.sender == beneficiaries[i] && isInherited) {
                break;
            }
            i++;
        }
        _;
    }

    /**
     * @dev gas efficient cross-function reentrancy lock using transient storage
     * @notice refer here: https://soliditylang.org/blog/2024/01/26/transient-storage/
     */

    // @audit check for reentrancy
    modifier nonReentrant() {
        assembly {
            if tload(1) { revert(0, 0) }
            tstore(0, 1)
        }
        _;
        assembly {
            tstore(0, 0)
        }
    }

    //////////////////////////////////////////////////////////////////////////////////
    ///////////////////////// WALLET FUNCTIONALITY ///////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////

    /**
     * @dev Sending ERC20 tokens out of the contract. Reentrancy safe, in case we interact with
     * malicious contracts.
     * @param _tokenAddress ERC20 token to send
     * @param _amount Amount of ERC20 to send
     * @param _to Address to send the ERC20 to
     */
    // @audit check if the nonReentrant modifier is enough
    function sendERC20(address _tokenAddress, uint256 _amount, address _to) external nonReentrant onlyOwner {
        if (IERC20(_tokenAddress).balanceOf(address(this)) < _amount) {
            revert InsufficientBalance();
        }
        IERC20(_tokenAddress).safeTransfer(_to, _amount);
        _setDeadline();
    }

    /**
     * @dev sends ETH out of the contract. Reentrancy safe, in case we interact with
     * malicious contracts.
     * @param _amount amount in ETH to send
     * @param _to address to send ETH to
     */
    // @audit Sent ETH to an address, check for reentrancy
    function sendETH(uint256 _amount, address _to) external nonReentrant onlyOwner {
        // @audit-info sent ETH to an address
        (bool success,) = _to.call{value: _amount}("");
        // @audit-info if the transaction fails, the contract will revert
        require(success, "Transfer Failed");
        // @audit-info the contract will reset the deadline
        _setDeadline();
    }

    /**
     * @dev to allow the owner arbitrary calls to other contracts. e.g. deposit assets into Aave to earn yield, or swap tokens on exchanges
     * @notice allows transactions to be stored in interactions[] to make it clear to beneficiaries where to look for funds outside this contract
     * and potentially withdraw those. Obviously swaps would not need to be stored, therefor we give the option.
     * This function should generally only be used by very advanced users, and we assume appropriate diligence has to be done by owner.
     * @param _target address of the target contract
     * @param _payload bytes element with interaction instructions
     * @param _value value of ether to be send with the transaction
     * @param _storeTarget bool to decide if this transaction should be stored
     */
    // @audit check better for reentrancy
    function contractInteractions(address _target, bytes calldata _payload, uint256 _value, bool _storeTarget)
        external
        nonReentrant
        onlyOwner
    {
        // @audit-info the contract will call the target contract with the payload and value
        (bool success, bytes memory data) = _target.call{value: _value}(_payload);
        // @audit-info if the transaction fails, the contract will revert
        require(success, "interaction failed");
        // @audit-info if the storeTarget is true, the contract will store the interaction
        if (_storeTarget) {
            interactions[_target] = data;
        }
    }

    //////////////////////////////////////////////////////////////////////////////////
    ///////////////////// ADDITIONAL INHERITANCE LOGIC ///////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////

    /**
     * @dev creates an NFT of an underlaying asset, for example real estate. Mints the nft and adds it
     * into nftValue mapping, connecting it to a real world price.
     * @param _description describes the asset, for example address or title number
     * @param _value uint256 describing the value of an asset, we recommend using a stablecoin like USDC or DAI
     * @param _asset the address of the asset in which beneficiaries would need to pay for that asset.
     */
    // @audit check if the payment is done correctly
    function createEstateNFT(string memory _description, uint256 _value, address _asset) external onlyOwner {
        // @audit-info the contract will create an estate NFT
        uint256 nftID = nft.createEstate(_description);
        // @audit-info the contract will set the value of the NFT
        nftValue[nftID] = _value;
        // @audit-info the contract will set the asset to pay
        assetToPay = _asset;
    }

    /**
     * @dev adds a beneficiary for possible inheritance of funds.
     * @param _beneficiary beneficiary address
     */
    // @audit LGTM
    function addBeneficiery(address _beneficiary) external onlyOwner {
        beneficiaries.push(_beneficiary);
        _setDeadline();
    }

    /**
     * @dev removes entries from beneficiaries in case inheritance gets revoked or
     * an address needs to be replaced (lost keys e.g.)
     * @param _beneficiary address to be removed from the array beneficiaries
     */
    // @audit LGTM
    function removeBeneficiary(address _beneficiary) external onlyOwner {
        uint256 indexToRemove = _getBeneficiaryIndex(_beneficiary);
        delete beneficiaries[indexToRemove];
    }

    //////////////////////////////////////////////////////////////////////////////////
    /////////////////////////// HELPER FUNCTIONS /////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////

    /**
     * @dev internal helper function to be called at contract creation and every owner controlled event/function call
     * to resett the timer off inactivity.
     */
    // @audit verify the block.timestamp but LGTM
    function _setDeadline() internal {
        deadline = block.timestamp + TIMELOCK;
    }

    /**
     * @dev takes beneciciary address and returns index as a helper function for removeBeneficiary
     * @param _beneficiary address to fetch the index for
     */
    // @audit LGTM
    function _getBeneficiaryIndex(address _beneficiary) public view returns (uint256 _index) {
        for (uint256 i = 0; i < beneficiaries.length; i++) {
            if (_beneficiary == beneficiaries[i]) {
                _index = i;
                break;
            }
        }
    }

    // @audit LGTM
    function getDeadline() public view returns (uint256) {
        return deadline;
    }

    // @audit LGTM
    function getOwner() public view returns (address) {
        return owner;
    }

    // @audit LGTM
    function getIsInherited() public view returns (bool) {
        return isInherited;
    }

    // @audit LGTM
    function getTrustee() public view returns (address) {
        return trustee;
    }
    //////////////////////////////////////////////////////////////////////////////////
    ///////////////////////// BENEFICIARIES LOGIC ////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////

    /**
     * @dev manages the inheritance of this wallet either
     * 1. the owner lost his keys and wants to reclaim this contract from beneficiaries slot0
     * 2. the owner was inactive more than 90 days and beneficiaries will claim remaining funds.
     */
    // @audit LGTM
    function inherit() external {
        // @audit-info checks if the block.timestamp is greater than the deadline (90 days)
        if (block.timestamp < getDeadline()) {
            revert InactivityPeriodNotLongEnough();
        }
        // @audit-info if theres one beneficiary, the owner will be set to the beneficiary and the deadline will be reset
        if (beneficiaries.length == 1) {
            owner = msg.sender;
            _setDeadline();
            // @audit-info if theres more than one beneficiary, the isInherited flag will be set to true
        } else if (beneficiaries.length > 1) {
            isInherited = true;
            // @audit-info if theres no beneficiary, the contract will revert
        } else {
            revert InvalidBeneficiaries();
        }
    }

    /**
     * @dev called by the beneficiaries to disperse remaining assets within the contract in equal parts.
     * @notice use address(0) to disperse ether
     * @param _asset asset address to disperse
     */
    function withdrawInheritedFunds(address _asset) external {
        // @audit-info if the contract has not been inherited, the contract will revert
        if (!isInherited) {
            revert NotYetInherited();
        }
        // @audit-info the divisor is set to the length of the beneficiaries array
        uint256 divisor = beneficiaries.length;
        // @audit-info if the asset is ether, the contract will disperse the ether to the beneficiaries and not ERC20
        if (_asset == address(0)) {
            // @audit-info the contract will check the balance of the contract
            uint256 ethAmountAvailable = address(this).balance;
            // @audit-info the contract will divide the amount per beneficiary
            uint256 amountPerBeneficiary = ethAmountAvailable / divisor;
            // @audit-info the contract will loop through the beneficiaries and send the amount per beneficiary
            // @audit reentrancy?
            for (uint256 i = 0; i < divisor; i++) {
                address payable beneficiary = payable(beneficiaries[i]);
                (bool success,) = beneficiary.call{value: amountPerBeneficiary}("");
                require(success, "something went wrong");
            }
            // @audit-info if the asset is not ether, the contract will disperse the ERC20 to the beneficiaries
        } else {
            uint256 assetAmountAvailable = IERC20(_asset).balanceOf(address(this));
            uint256 amountPerBeneficiary = assetAmountAvailable / divisor;
            // @audit-info the contract will loop through the beneficiaries and send the amount per beneficiary
            for (uint256 i = 0; i < divisor; i++) {
                IERC20(_asset).safeTransfer(beneficiaries[i], amountPerBeneficiary);
            }
        }
    }

    /**
     * @dev On-Chain payment of underlaying assets.
     * CAN NOT use ETHER
     * @param _nftID NFT ID to buy out
     */
    // @audit-info a beneficiary can buy out an estate NFT by paying the value of the NFT
    function buyOutEstateNFT(uint256 _nftID) external onlyBeneficiaryWithIsInherited {
        // @audit-info the contract will get the value of the NFT
        uint256 value = nftValue[_nftID];
        uint256 divisor = beneficiaries.length;
        // @audit-info the multiplier is set to the length of the beneficiaries array minus 1 the buyer will not be paid or will he?
        uint256 multiplier = beneficiaries.length - 1;
        // @audit-info the final amount is calculated by dividing the value by the divisor and multiplying by the multiplier (funds lost)
        uint256 finalAmount = (value / divisor) * multiplier;
        // @audit-info the contract will transfer the final amount to the contract
        IERC20(assetToPay).safeTransferFrom(msg.sender, address(this), finalAmount);
        // @audit-info the contract will loop through the beneficiaries and send the final amount divided by the divisor
        for (uint256 i = 0; i < beneficiaries.length; i++) {
            // @audit-info if the sender is a beneficiary, the contract will not send the funds
            if (msg.sender == beneficiaries[i]) {
                // @audit calling the return will not burn the NFT
                return;
            } else {
                // @audit-info the contract will send the funds to the beneficiaries
                IERC20(assetToPay).safeTransfer(beneficiaries[i], finalAmount / divisor);
            }
        }
        // @audit-info the contract will burn the NFT
        nft.burnEstate(_nftID);
    }

    /**
     * @param _trustee address of appointed trustee for asset reevaluation
     */
    // @audit LGTM
    function appointTrustee(address _trustee) external onlyBeneficiaryWithIsInherited {
        trustee = _trustee;
    }
}

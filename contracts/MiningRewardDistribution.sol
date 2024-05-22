// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";

/** 
 * @title Offline Mining Reward Distribution
 */
contract MiningRewardDistribution is Initializable, UUPSUpgradeable, ERC20Upgradeable, OwnableUpgradeable, ERC20BurnableUpgradeable {
    uint256 private treasuryTax;
    uint256 private coinbaseTax;
    uint256 private zeroOffTax; // If the receiver have no OFF, plus this tax to canxium treasury

    uint256 private burnAmount; // Number of OFF will be burn each mining transaction
    uint256 private minimumOffSupply; // Do not burn if OFF's supply < this minimum

    uint256 public minerReward; // total CAU reward distributed for offline miners.
    uint256 public treasuryReward; // total CAU reward distributed for canxium treasury.
    uint256 public validatorReward; // total CAU reward distributed for validators.

    address payable treasuryAddress; // canxium treasury wallet address

    event TreasuryTax(uint256 indexed tax, uint256 indexed burnTax);
    event CoinbaseTax(uint256 indexed tax);
    event BurnAmount(uint256 indexed amount);
    event MiningReward(address indexed from, address indexed to, uint256 indexed amount);
    event MiningTaxes(address treasury, uint256 amount1, address coinbase, uint256 amount2);

    /** 
     * @dev Create a new contract to distribute the reward to foundation wallet, coinbase and miner wallet.
     */

    function initialize() initializer public {
        __ERC20_init("Offline", "OFF");
        __Ownable_init();
        __UUPSUpgradeable_init();

        // init default values
        treasuryTax = 15; // 15%
        coinbaseTax = 15;   // 15%
        zeroOffTax = 5; // if the receiver have no OFF, foundation tax will be 15% + 5%

        burnAmount = 1000000; // Burn 1 OFF per mining transaction

        minimumOffSupply = 21000000000000; // 21m OFF
        treasuryAddress = payable(0xBd65D6efb2C3e6B4dD33C664643BEB8e5E133055);

        // pre-mine 210b OFF to foundation wallet
        _mint(treasuryAddress, 210000000000000000);
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /** 
     * @dev override default functions
     */
    function _authorizeUpgrade(address) internal override onlyOwner {}
    function decimals() public view virtual override returns (uint8) {
        return 6;
    }

    /** 
     * @dev return current foundation wallet.
     */
    function getFoundationWallet() public view returns (address) {
        return treasuryAddress;
    }

    /** 
     * @dev return current taxes
     */
    function getTaxes() public view returns (uint256, uint256, uint256) {
        return (treasuryTax, coinbaseTax, zeroOffTax);
    }

    /** 
     * @dev set and emit foundation tax
     * @param tax Percent of foundation tax
     */
    function setFoundationTax(uint256 tax, uint256 burnTax) public onlyOwner {
        treasuryTax = tax;
        zeroOffTax = burnTax;
        emit TreasuryTax(tax, zeroOffTax);
    }

    /** 
     * @dev set and emit coinbase tax
     * @param tax Percent of coinbase tax
     */
    function setCoinbaseTax(uint256 tax) public onlyOwner {
        coinbaseTax = tax;
        emit CoinbaseTax(tax);
    }

    /** 
     * @dev set and emit treasury address
     * @param addr New address of treasury wallet
     */
    function setTreasuryAddress(address addr) public onlyOwner {
        treasuryAddress = payable(addr);
    }

    /** 
     * @dev set and emit burn amount
     * @param amount Number of OFF will be burned each mining transaction
     */
    function setBurnAmount(uint256 amount) public onlyOwner {
        burnAmount = amount;
        emit BurnAmount(amount);
    }

    /** 
     * @dev return total mining reward
     */
    function totalMiningReward() public view returns (uint256) {
        return minerReward + treasuryReward + validatorReward;
    }

    /** 
     * @dev Mining distribute reward to foundation, coinbase and tx miner.
     * @param receiver Miner receiver address
     */
    function mining(address receiver) public payable {
        address payable to = payable(receiver);
        address payable coinbase = payable(block.coinbase);

        uint256 fundTax = treasuryTax;
        if (totalSupply() > minimumOffSupply && burnAmount > 0) {
            if (balanceOf(receiver) < burnAmount) {
                fundTax = fundTax + zeroOffTax;
            } else {
                _burn(to, burnAmount);
            }
        }

        uint256 fundReward = msg.value * fundTax / 100;
        uint256 coinbaseReward = msg.value * coinbaseTax / 100;
        uint256 reward = msg.value - fundReward - coinbaseReward;
        
        to.transfer(reward);
        treasuryAddress.transfer(fundReward);
        coinbase.transfer(coinbaseReward);

        minerReward = minerReward + reward;
        treasuryReward = treasuryReward + fundReward;
        validatorReward = validatorReward + coinbaseReward;
        
        // emit events
        emit MiningReward(msg.sender, to, reward);
        emit MiningTaxes(treasuryAddress, fundReward, coinbase, coinbaseReward);
    }
}
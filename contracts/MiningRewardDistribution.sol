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

    // merge mining
    uint256 private mergeMiningTreasuryTax;
    uint256 private mergeMiningCoinbaseBaseTax;
    uint256 private mergeMiningCoinbaseDefaultTax;

    uint256 public mergeMiningMinerReward; // total CAU reward distributed for offline miners.
    uint256 public mergeMiningTreasuryReward; // total CAU reward distributed for canxium treasury.
    uint256 public mergeMiningValidatorReward; // total CAU reward distributed for validators.

    uint256 private heliumForkTime;

    mapping(address => mapping(uint16 => uint256)) public mergeMiningTimestamp;

    uint256 private constant KASPA_CHAIN = 1;

    event TreasuryTax(uint256 indexed tax, uint256 indexed burnTax);
    event CoinbaseTax(uint256 indexed tax);
    event BurnAmount(uint256 indexed amount);

    event MiningReward(address indexed from, address indexed to, uint256 indexed amount);
    event MiningTaxes(address treasury, uint256 amount1, address coinbase, uint256 amount2);
    
    event MergeMiningReward(address indexed from, address indexed to, uint256 indexed amount);
    event MergeMiningTaxes(address treasury, uint256 amount1, address coinbase, uint256 amount2);

    /** 
     * @dev Create a new contract to distribute the reward to foundation wallet, coinbase and miner wallet.
     */

    function initialize() initializer public {
        __ERC20_init("Offline", "OFF");
        __Ownable_init();
        __UUPSUpgradeable_init();

        // init default values
        treasuryTax = 10; // 10%
        coinbaseTax = 15;   // 15%
        zeroOffTax = 5; // if the receiver have no OFF, treasury tax will be 10% + 5%

        // merge mining taxes
        mergeMiningTreasuryTax = 10;
        mergeMiningCoinbaseBaseTax = 100; // / 10000 = 0.01
        mergeMiningCoinbaseDefaultTax = 1000; // /10000 = 0.1
        heliumForkTime = 1737884221;

        burnAmount = 1000000; // Burn 1 OFF per mining transaction

        minimumOffSupply = 21000000000000; // 21m OFF
        treasuryAddress = payable(0xF26417eCf894678B58feda327DC01A60041856fB);

        // pre-mine 210b OFF to foundation wallet
        _mint(treasuryAddress, 21000000000000000);
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
    function getTreasuryWallet() public view returns (address) {
        return treasuryAddress;
    }

    /** 
     * @dev return current taxes
     */
    function getTaxes() public view returns (uint256, uint256, uint256) {
        return (treasuryTax, coinbaseTax, zeroOffTax);
    }

    /** 
     * @dev return current merge mining taxes
     */
    function getMergeMiningTaxes() public view returns (uint256, uint256, uint256) {
        return (mergeMiningTreasuryTax, mergeMiningCoinbaseBaseTax, mergeMiningCoinbaseDefaultTax);
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
     * @dev set and emit foundation tax
     * @param tax Percent of foundation tax
     */
    function setMergeMiningTreasuryTax(uint256 tax) public onlyOwner {
        mergeMiningTreasuryTax = tax;
    }

    /** 
     * @dev set and emit coinbase tax
     * @param baseTax Percent of coinbase tax
     * @param defaultTax Percent of coinbase tax
     */
    function setMergeMiningCoinbaseTax(uint256 baseTax, uint256 defaultTax) public onlyOwner {
        mergeMiningCoinbaseBaseTax = baseTax;
        mergeMiningCoinbaseDefaultTax = defaultTax;
    }

    /** 
     * @dev set helium fork time
     * @param forkTime helium fork time
     */
    function setHeliumForkTime(uint256 forkTime) public onlyOwner {
        heliumForkTime = forkTime;
    }

    /** 
     * @dev return total mining reward
     */
    function totalMiningReward() public view returns (uint256) {
        return minerReward + treasuryReward + validatorReward;
    }

    /** 
     * @dev return total mining reward
     */
    function totalMergeMiningReward() public view returns (uint256) {
        return mergeMiningMinerReward + mergeMiningTreasuryReward + mergeMiningValidatorReward;
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

    /** 
     * @dev Merge Mining distribute reward to foundation, coinbase and tx miner.
     * @param receiver Miner receiver address
     */
    function mergeMining(address receiver, uint16 chain, uint256 timestamp) public payable {
        require(msg.value > 0, "invalid merge mining value");
        require(chain > 0, "invalid merge mining chain id");
        require(timestamp > mergeMiningTimestamp[receiver][chain], "invalid merge mining timestamp");
        
        if (chain == KASPA_CHAIN) {
            kaspaMiningRewardDistribution(receiver);
        }

        mergeMiningTimestamp[receiver][chain] = timestamp;
    }

    function kaspaMiningRewardDistribution(address receiver) public payable {
        address payable to = payable(receiver);
        address payable coinbase = payable(block.coinbase);

        uint256 mergeMiningCoinbaseTax = coinbaseRewardPercentage(block.timestamp);

        require(mergeMiningTreasuryTax > 0, "invalid merge mining treasury tax");
        require(mergeMiningCoinbaseTax > 0 && mergeMiningCoinbaseTax < 10000, "invalid merge mining coinbase tax");

        uint256 fundReward = msg.value * mergeMiningTreasuryTax / 100;
        uint256 coinbaseReward = msg.value * mergeMiningCoinbaseTax / 10000;
        uint256 reward = msg.value - fundReward - coinbaseReward;
        
        require(reward > 0, "invalid merge mining miner reward");

        to.transfer(reward);
        treasuryAddress.transfer(fundReward);
        coinbase.transfer(coinbaseReward);

        mergeMiningMinerReward = mergeMiningMinerReward + reward;
        mergeMiningTreasuryReward = mergeMiningTreasuryReward + fundReward;
        mergeMiningValidatorReward = mergeMiningValidatorReward + coinbaseReward;

        // emit events
        emit MergeMiningReward(msg.sender, to, reward);
        emit MergeMiningTaxes(treasuryAddress, fundReward, coinbase, coinbaseReward);
    }

    function mergeMiningDay(uint256 blockTime) private view returns (uint256) {
        if (blockTime < heliumForkTime) {
            return 0;
        }

        // Calculate the difference in seconds and convert to days
        uint256 dayNumber = (blockTime - heliumForkTime) / 86400;
        return dayNumber;
    }
    
    // return percent in / 10000
    function coinbaseRewardPercentage(uint256 blockTime) private view returns (uint256) {
        uint256 dayNum = mergeMiningDay(blockTime);
        if (dayNum <= 0) {
            return mergeMiningCoinbaseBaseTax; // 0.01
        }
        if (dayNum > 0 && dayNum <= 115) {
            return mergeMiningCoinbaseBaseTax + 7*dayNum;
        }
        return mergeMiningCoinbaseDefaultTax;
    }

    function getMergeMiningTimestamp(address miner, uint16 chain) public view returns (uint256) {
        return mergeMiningTimestamp[miner][chain];
    }
}
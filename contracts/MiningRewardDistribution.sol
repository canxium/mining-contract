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
    // WARNING: Change vars, change slot number in go-canxium/core/state/statedb.go line 42
    uint256 private treasuryTax;
    uint256 private coinbaseTax;
    uint256 private zeroOffTax; // If the receiver have no OFF, plus this tax to canxium treasury

    uint256 private burnAmount; // Number of OFF will be burn each mining transaction
    uint256 private minimumOffSupply; // Do not burn if OFF's supply < this minimum

    uint256 public minerReward; // total CAU reward distributed for offline miners.
    uint256 public treasuryReward; // total CAU reward distributed for canxium treasury.
    uint256 public validatorReward; // total CAU reward distributed for validators.

    address payable treasuryAddress; // canxium treasury wallet address

    // cross chain RPoW mining
    uint256 private crossChainMiningTreasuryTax; // / 100 = 10%
    uint256 private crossChainMiningCoinbaseBaseTax;  // / 10000 = 2.5%

    uint256 public crossChainMiningMinerReward; // total CAU reward distributed for miners.
    uint256 public crossChainMiningTreasuryReward; // total CAU reward distributed for canxium treasury.
    uint256 public crossChainMiningValidatorReward; // total CAU reward distributed for validators.

    uint256 public heliumForkTime;

    mapping(address => mapping(uint16 => uint256)) public crossChainMiningTimestamp;

    uint256 private constant KASPA_CHAIN = 1;
    uint256 private constant MAX_COINBASE_TAX = 1500; // max validator tax 15% = 1500 / 10000

    event TreasuryTax(uint256 indexed tax, uint256 indexed burnTax);
    event CoinbaseTax(uint256 indexed tax);
    event BurnAmount(uint256 indexed amount);

    event MiningReward(address indexed from, address indexed to, uint256 indexed amount);
    event MiningTaxes(address treasury, uint256 amount1, address coinbase, uint256 amount2);
    
    event CrossChainMiningReward(address indexed from, address indexed to, uint256 indexed amount);
    event CrossChainMiningTaxes(address treasury, uint256 amount1, address coinbase, uint256 amount2);

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

        // cross chain mining taxes
        crossChainMiningTreasuryTax = 10;
        crossChainMiningCoinbaseBaseTax = 250;
        heliumForkTime = 1740787200;

        burnAmount = 1000000; // Burn 1 OFF per mining transaction

        minimumOffSupply = 21000000000000; // 21m OFF
        treasuryAddress = payable(0xBd65D6efb2C3e6B4dD33C664643BEB8e5E133055);

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
     * @dev return current cross chain mining taxes
     */
    function getCrossChainMiningTaxes() public view returns (uint256, uint256) {
        return (crossChainMiningTreasuryTax, crossChainMiningCoinbaseBaseTax);
    }

    /** 
     * @dev return total miner rewards
     */
    function getMinerReward() public view returns (uint256) {
        return minerReward + crossChainMiningMinerReward;
    }

    /** 
     * @dev return total validator rewards
     */
    function getValidatorReward() public view returns (uint256) {
        return validatorReward + crossChainMiningValidatorReward;
    }

    /** 
     * @dev return total treasury rewards
     */
    function getTreasuryReward() public view returns (uint256) {
        return treasuryReward + crossChainMiningTreasuryReward;
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
    function setCrossChainMiningTreasuryTax(uint256 tax) public onlyOwner {
        crossChainMiningTreasuryTax = tax;
    }

    /** 
     * @dev set and emit coinbase tax
     * @param baseTax Percent of coinbase tax
     */
    function setCrossChainMiningCoinbaseTax(uint256 baseTax) public onlyOwner {
        crossChainMiningCoinbaseBaseTax = baseTax;
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
    function totalCrossChainMiningReward() public view returns (uint256) {
        return crossChainMiningMinerReward + crossChainMiningTreasuryReward + crossChainMiningValidatorReward;
    }

    /** 
     * @dev Mining distribute reward to foundation, coinbase and tx miner in the Independent Retained Proof of Work.
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
     * @dev crossChainMining distribute reward to foundation, coinbase and tx miner in the Cross-Chain Retained Proof of Work
     * @param receiver Miner receiver address
     * @param chain Source chain Id
     * @param timestamp Timestamp of the block
     */
    function crossChainMining(address receiver, uint16 chain, uint256 timestamp) public payable {
        require(msg.value > 0, "invalid mining value");
        require(chain > 0, "invalid mining chain id");
        require(timestamp > crossChainMiningTimestamp[receiver][chain], "invalid mining timestamp");
        
        if (chain == KASPA_CHAIN) {
            kaspaMiningRewardDistribution(receiver);
        }

        crossChainMiningTimestamp[receiver][chain] = timestamp;
    }

    function kaspaMiningRewardDistribution(address receiver) public payable {
        address payable to = payable(receiver);
        address payable coinbase = payable(block.coinbase);

        uint256 crossChainMiningCoinbaseTax = coinbaseRewardPercentage(block.timestamp);

        require(crossChainMiningTreasuryTax > 0, "invalid mining treasury tax");
        require(crossChainMiningCoinbaseTax > 0 && crossChainMiningCoinbaseTax < 10000, "invalid mining coinbase tax");

        uint256 fundReward = msg.value * crossChainMiningTreasuryTax / 100;
        uint256 coinbaseReward = msg.value * crossChainMiningCoinbaseTax / 10000;
        uint256 reward = msg.value - fundReward - coinbaseReward;
        
        require(reward > 0, "invalid mining miner reward");

        to.transfer(reward);
        treasuryAddress.transfer(fundReward);
        coinbase.transfer(coinbaseReward);

        crossChainMiningMinerReward = crossChainMiningMinerReward + reward;
        crossChainMiningTreasuryReward = crossChainMiningTreasuryReward + fundReward;
        crossChainMiningValidatorReward = crossChainMiningValidatorReward + coinbaseReward;

        // emit events
        emit CrossChainMiningReward(msg.sender, to, reward);
        emit CrossChainMiningTaxes(treasuryAddress, fundReward, coinbase, coinbaseReward);
    }

    function monthPassedSinceFork(uint256 blockTime) private view returns (uint256) {
        if (blockTime < heliumForkTime) {
            return 0;
        }

        // Calculate the difference in seconds and convert to month
        uint256 month = (blockTime - heliumForkTime) / 2592000;
        return month;
    }

    // return percent in / 10000
    function coinbaseRewardPercentage(uint256 blockTime) private view returns (uint256) {
        uint256 month = monthPassedSinceFork(blockTime);
        uint256 tax = crossChainMiningCoinbaseBaseTax + 25 * month;
        if (tax > MAX_COINBASE_TAX) {
            return MAX_COINBASE_TAX;
        }

        return tax;
    }

    function getMergeMiningTimestamp(address miner, uint16 chain) public view returns (uint256) {
        return crossChainMiningTimestamp[miner][chain];
    }
}

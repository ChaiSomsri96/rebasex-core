// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IRebaseXFactory} from "./interfaces/IRebaseXFactory/IRebaseXFactory.sol";
import {IRebaseXFactoryHelper} from "./interfaces/IRebaseXFactory/IRebaseXFactoryHelper.sol";
import {IRebaseXPair} from "./interfaces/IRebaseXPair/IRebaseXPair.sol";

contract RebaseXFactory is IRebaseXFactory {
    /**
     * @inheritdoc IRebaseXFactory
     */
    address public feeTo;

    /**
     * @inheritdoc IRebaseXFactory
     */
    address public feeToSetter;

    /**
     * @inheritdoc IRebaseXFactory
     */
    mapping(address => mapping(address => mapping(uint16 => mapping(uint16 => address)))) public override getPair;

    /**
     * @inheritdoc IRebaseXFactory
     */
    address[] public allPairs;

    address internal lastToken0;

    address internal lastToken1;

    uint16 internal lastPlBps;

    uint16 internal lastFeeBps;

    /**
     * @inheritdoc IRebaseXFactory
     */
    address public paramSetter;

    /**
     * @inheritdoc IRebaseXFactory
     */
    string public tokenName;

    /**
     * @inheritdoc IRebaseXFactory
     */
    string public tokenSymbol;

    address public factoryHelper;

    /**
     * @dev The upper limit on what duration parameters can be set to.
     */
    uint32 public constant MAX_DURATION_BOUND = 12 weeks;

    /**
     * @dev The upper limit on what BPS denominated parameters can be set to.
     */
    uint16 public constant MAX_BPS_BOUND = 10_000;

    /**
     * @dev The upper limit on what MBPS denominated parameters can be set to.
     */
    uint24 public constant MAX_MBPS_BOUND = 10_000_000;

    /**
     * @dev The lower limit on what the `movingAverageWindow` can be set to.
     */
    uint32 public constant MIN_MOVING_AVERAGE_WINDOW_BOUND = 1 seconds;

    /**
     * @dev The lower limit on what the `swappableReservoirGrowthWindow` can be set to.
     */
    uint32 public constant MIN_SWAPPABLE_RESERVOIR_GROWTH_WINDOW_BOUND = 1 seconds;

    /**
     * @inheritdoc IRebaseXFactory
     */
    bool public isCreationRestricted;

    /**
     * @inheritdoc IRebaseXFactory
     */
    address public isCreationRestrictedSetter;

    /**
     * @inheritdoc IRebaseXFactory
     */
    address public isPausedSetter;

    /**
     * @inheritdoc IRebaseXFactory
     */
    mapping(uint16 => mapping(uint16 => PairCreationParameters)) public override defaultPairCreationParameters;

    /**
     * @inheritdoc IRebaseXFactory
     */
    CategoryParameters[] public override supportedCategories;

    modifier onlyPermissionSetter(address setter) {
        _onlyPermissionSetter(setter);
        _;
    }

    function _onlyPermissionSetter(address setter) internal view {
        if (msg.sender != setter) {
            revert Forbidden();
        }
    }

    /**
     * @dev `feeTo` is not initialised during deployment, and must be set separately by a call to {setFeeTo}.
     * @param _feeToSetter The account that has the ability to set `feeToSetter` and `feeTo`
     * @param _isCreationRestrictedSetter The account that has the ability to set `isCreationRestrictedSetter` and `isCreationRestricted`
     * @param _isPausedSetter The account that has the ability to set `isPausedSetter` and `isPaused`
     * @param _paramSetter The account that has the ability to set `paramSetter`, default parameters, and current parameters on existing pairs
     * @param _tokenName The name of the ERC20 liquidity token
     * @param _tokenSymbol The symbol of the ERC20 liquidity token
     */
    constructor(
        address _feeToSetter,
        address _isCreationRestrictedSetter,
        address _isPausedSetter,
        address _paramSetter,
        string memory _tokenName,
        string memory _tokenSymbol,
        address _factoryHelper
    ) {
        feeToSetter = _feeToSetter;
        isCreationRestrictedSetter = _isCreationRestrictedSetter;
        isPausedSetter = _isPausedSetter;
        paramSetter = _paramSetter;
        tokenName = _tokenName;
        tokenSymbol = _tokenSymbol;
        factoryHelper = _factoryHelper;
    }

    /**
     * @inheritdoc IRebaseXFactory
     */
    function allPairsLength() external view returns (uint256 count) {
        count = allPairs.length;
    }

    /**
     * @inheritdoc IRebaseXFactory
     */
    function supportedCategoriesLength() external view returns (uint256 count) {
        count = supportedCategories.length;
    }

    // Validate that the category parameters are supported
    function _validateCategoryParameters(uint16 plBps, uint16 feeBps) internal view {
        if (defaultPairCreationParameters[plBps][feeBps].movingAverageWindow == 0) {
            revert UnsupportedCategoryParameters();
        }
    }

    /**
     * @inheritdoc IRebaseXFactory
     */
    function createPair(address tokenA, address tokenB, uint16 plBps, uint16 feeBps) external returns (address pair) {
        if (isCreationRestricted && msg.sender != isCreationRestrictedSetter) {
            revert Forbidden();
        }
        if (tokenA == tokenB) {
            revert TokenIdenticalAddress();
        }
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        if (token0 == address(0)) {
            revert TokenZeroAddress();
        }
        // single check is sufficient
        if (getPair[token0][token1][plBps][feeBps] != address(0)) {
            revert PairExists();
        }
        // Validate that the category parameters are supported
        _validateCategoryParameters(plBps, feeBps);
        lastToken0 = token0;
        lastToken1 = token1;
        lastPlBps = plBps;
        lastFeeBps = feeBps;
        bytes memory bytecode = IRebaseXFactoryHelper(factoryHelper).getCreationCode();
        bytes32 salt = keccak256(abi.encodePacked(token0, token1, plBps, feeBps));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        // Validate that the pair was created successfully
        if (pair == address(0)) {
            revert PairCreationFailed();
        }

        // Resetting lastToken0/lastToken1/lastPlBps/lastFeebps to 0 to refund gas
        lastToken0 = address(0);
        lastToken1 = address(0);
        lastPlBps = 0;
        lastFeeBps = 0;

        getPair[token0][token1][plBps][feeBps] = pair;
        getPair[token1][token0][plBps][feeBps] = pair; // populate mapping in the reverse direction
        allPairs.push(pair);
        emit PairCreated(token0, token1, plBps, feeBps, pair, allPairs.length);
    }

    /**
     * @inheritdoc IRebaseXFactory
     */
    function setFeeTo(address _feeTo) external onlyPermissionSetter(feeToSetter) {
        feeTo = _feeTo;
    }

    /**
     * @inheritdoc IRebaseXFactory
     */
    function setFeeToSetter(address _feeToSetter) external onlyPermissionSetter(feeToSetter) {
        feeToSetter = _feeToSetter;
    }

    /**
     * @inheritdoc IRebaseXFactory
     */
    function setIsCreationRestricted(bool _isCreationRestricted)
        external
        onlyPermissionSetter(isCreationRestrictedSetter)
    {
        isCreationRestricted = _isCreationRestricted;
    }

    /**
     * @inheritdoc IRebaseXFactory
     */
    function setIsCreationRestrictedSetter(address _isCreationRestrictedSetter)
        external
        onlyPermissionSetter(isCreationRestrictedSetter)
    {
        isCreationRestrictedSetter = _isCreationRestrictedSetter;
    }

    /**
     * @inheritdoc IRebaseXFactory
     */
    function setIsPaused(address[] calldata pairs, bool isPausedNew) external onlyPermissionSetter(isPausedSetter) {
        uint256 length = pairs.length;
        for (uint256 i; i < length; ++i) {
            IRebaseXPair(pairs[i]).setIsPaused(isPausedNew);
        }
    }

    /**
     * @inheritdoc IRebaseXFactory
     */
    function setIsPausedSetter(address _isPausedSetter) external onlyPermissionSetter(isPausedSetter) {
        isPausedSetter = _isPausedSetter;
    }

    /**
     * @inheritdoc IRebaseXFactory
     */
    function setParamSetter(address _paramSetter) external onlyPermissionSetter(paramSetter) {
        paramSetter = _paramSetter;
    }

    function _validateNewMovingAverageWindow(uint32 newMovingAverageWindow) internal pure {
        if (newMovingAverageWindow < MIN_MOVING_AVERAGE_WINDOW_BOUND || newMovingAverageWindow > MAX_DURATION_BOUND) {
            revert InvalidParameter();
        }
    }

    function _validateNewMaxVolatilityBps(uint16 newMaxVolatilityBps) internal pure {
        if (newMaxVolatilityBps > MAX_BPS_BOUND) {
            revert InvalidParameter();
        }
    }

    function _validateNewMinTimelockDuration(uint32 newMinTimelockDuration) internal pure {
        if (newMinTimelockDuration > MAX_DURATION_BOUND) {
            revert InvalidParameter();
        }
    }

    function _validateNewMaxTimelockDuration(uint32 newMaxTimelockDuration) internal pure {
        if (newMaxTimelockDuration > MAX_DURATION_BOUND) {
            revert InvalidParameter();
        }
    }

    function _validateNewMaxSwappableReservoirLimitBps(uint32 newMaxSwappableReservoirLimitBps) internal pure {
        if (newMaxSwappableReservoirLimitBps > MAX_BPS_BOUND) {
            revert InvalidParameter();
        }
    }

    function _validateNewSwappableReservoirGrowthWindow(uint32 newSwappableReservoirGrowthWindow) internal pure {
        if (
            newSwappableReservoirGrowthWindow < MIN_SWAPPABLE_RESERVOIR_GROWTH_WINDOW_BOUND
                || newSwappableReservoirGrowthWindow > MAX_DURATION_BOUND
        ) {
            revert InvalidParameter();
        }
    }

    function _validateNewProtocolFeeMbps(uint24 newProtocolFeeMbps) internal pure {
        if (newProtocolFeeMbps > MAX_MBPS_BOUND) {
            revert InvalidParameter();
        }
    }

    /**
     * @dev `minBasinDuration` must be in interval [0, MAX_DURATION_BOUND]
     */
    function _validateNewMinBasinDuration(uint32 newMinBasinDuration) internal pure {
        if (newMinBasinDuration > MAX_DURATION_BOUND) {
            revert InvalidParameter();
        }
    }

    /**
     * @dev `maxBasinDuration` must be in interval [0, MAX_DURATION_BOUND]
     */
    function _validateNewMaxBasinDuration(uint32 newMaxBasinDuration) internal pure {
        if (newMaxBasinDuration > MAX_DURATION_BOUND) {
            revert InvalidParameter();
        }
    }

    /**
     * @dev `pLBPS` must be in interval [0, MAX_BPS_BOUND). pL cannot equal 1.
     */
    function _validateNewPlBps(uint32 newPlBps) internal pure {
        if (newPlBps >= MAX_BPS_BOUND) {
            revert InvalidParameter();
        }
    }

    function _validateNewFeeBps(uint16 newFeeBps) internal pure {
        if (newFeeBps > MAX_BPS_BOUND) {
            revert InvalidParameter();
        }
    }

    function _addSupportedCategory(uint16 plBps, uint16 feeBps) internal {
        for (uint256 i = 0; i < supportedCategories.length; i++) {
            if (supportedCategories[i].plBps == plBps && supportedCategories[i].feeBps == feeBps) {
                return;
            }
        }
        supportedCategories.push(CategoryParameters(plBps, feeBps));
    }

    /**
     * @inheritdoc IRebaseXFactory
     */
    function setDefaultParameters(
        uint16 plBps,
        uint16 feeBps,
        uint32 defaultMovingAverageWindow,
        uint16 defaultMaxVolatilityBps,
        uint32 defaultMinTimelockDuration,
        uint32 defaultMaxTimelockDuration,
        uint16 defaultMaxSwappableReservoirLimitBps,
        uint32 defaultSwappableReservoirGrowthWindow,
        uint24 defaultProtocolFeeMbps,
        uint32 defaultMinBasinDuration,
        uint32 defaultMaxBasinDuration
    ) external override onlyPermissionSetter(paramSetter) {
        // Validate keys
        _validateNewPlBps(plBps);
        _validateNewFeeBps(feeBps);
        // Validate values
        _validateNewMovingAverageWindow(defaultMovingAverageWindow);
        _validateNewMaxVolatilityBps(defaultMaxVolatilityBps);
        _validateNewMinTimelockDuration(defaultMinTimelockDuration);
        _validateNewMaxTimelockDuration(defaultMaxTimelockDuration);
        _validateNewMaxSwappableReservoirLimitBps(defaultMaxSwappableReservoirLimitBps);
        _validateNewSwappableReservoirGrowthWindow(defaultSwappableReservoirGrowthWindow);
        _validateNewProtocolFeeMbps(defaultProtocolFeeMbps);
        _validateNewMinBasinDuration(defaultMinBasinDuration);
        _validateNewMaxBasinDuration(defaultMaxBasinDuration);

        // Add entry to defaultPairCreationParameters
        defaultPairCreationParameters[plBps][feeBps] = PairCreationParameters(
            defaultMovingAverageWindow,
            defaultMaxVolatilityBps,
            defaultMinTimelockDuration,
            defaultMaxTimelockDuration,
            defaultMaxSwappableReservoirLimitBps,
            defaultSwappableReservoirGrowthWindow,
            defaultProtocolFeeMbps,
            defaultMinBasinDuration,
            defaultMaxBasinDuration
        );

        // Add (plBps, feeBps) to supported categories list if not already present
        _addSupportedCategory(plBps, feeBps);

        emit DefaultParametersUpdated(
            msg.sender,
            plBps,
            feeBps,
            defaultMovingAverageWindow,
            defaultMaxVolatilityBps,
            defaultMinTimelockDuration,
            defaultMaxTimelockDuration,
            defaultMaxSwappableReservoirLimitBps,
            defaultSwappableReservoirGrowthWindow,
            defaultProtocolFeeMbps,
            defaultMinBasinDuration,
            defaultMaxBasinDuration
        );
    }

    /**
     * @inheritdoc IRebaseXFactory
     */
    function removeDefaultParameters(uint16 plBps, uint16 feeBps) external override onlyPermissionSetter(paramSetter) {
        // Validate pair is supported
        _validateCategoryParameters(plBps, feeBps);

        // Remove entry from defaultPairCreationParameters
        delete defaultPairCreationParameters[plBps][feeBps];

        // Remove (plBps, feeBps) from supported categories list
        for (uint256 i = 0; i < supportedCategories.length; i++) {
            if (supportedCategories[i].plBps == plBps && supportedCategories[i].feeBps == feeBps) {
                supportedCategories[i] = supportedCategories[supportedCategories.length - 1];
                supportedCategories.pop();
                break;
            }
        }
    }

    /**
     * @inheritdoc IRebaseXFactory
     */
    function setMovingAverageWindow(address[] calldata pairs, uint32 newMovingAverageWindow)
        external
        onlyPermissionSetter(paramSetter)
    {
        _validateNewMovingAverageWindow(newMovingAverageWindow);
        uint256 length = pairs.length;
        for (uint256 i; i < length; ++i) {
            IRebaseXPair(pairs[i]).setMovingAverageWindow(newMovingAverageWindow);
        }
    }

    /**
     * @inheritdoc IRebaseXFactory
     */
    function setMaxVolatilityBps(address[] calldata pairs, uint16 newMaxVolatilityBps)
        external
        onlyPermissionSetter(paramSetter)
    {
        _validateNewMaxVolatilityBps(newMaxVolatilityBps);
        uint256 length = pairs.length;
        for (uint256 i; i < length; ++i) {
            IRebaseXPair(pairs[i]).setMaxVolatilityBps(newMaxVolatilityBps);
        }
    }

    /**
     * @inheritdoc IRebaseXFactory
     */
    function setMinTimelockDuration(address[] calldata pairs, uint32 newMinTimelockDuration)
        external
        onlyPermissionSetter(paramSetter)
    {
        _validateNewMinTimelockDuration(newMinTimelockDuration);
        uint256 length = pairs.length;
        for (uint256 i; i < length; ++i) {
            IRebaseXPair(pairs[i]).setMinTimelockDuration(newMinTimelockDuration);
        }
    }

    /**
     * @inheritdoc IRebaseXFactory
     */
    function setMaxTimelockDuration(address[] calldata pairs, uint32 newMaxTimelockDuration)
        external
        onlyPermissionSetter(paramSetter)
    {
        _validateNewMaxTimelockDuration(newMaxTimelockDuration);
        uint256 length = pairs.length;
        for (uint256 i; i < length; ++i) {
            IRebaseXPair(pairs[i]).setMaxTimelockDuration(newMaxTimelockDuration);
        }
    }
}
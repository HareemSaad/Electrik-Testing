// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "@uniswap/v3-periphery/contracts/interfaces/external/IWETH9.sol";
// import "@uniswap/v3-periphery/contracts/SwapRouter.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "swap-router-contracts/contracts/interfaces/ISwapRouter02.sol";
import "swap-router-contracts/contracts/interfaces/IV3SwapRouter.sol";

interface IL2ERC20Template {
    function decimals() external view returns (uint8);

    function balanceOf(address user) external view returns (uint256);

    function mint(address user, uint256 amount) external;

    function burn(address user, uint256 amount) external;
}

contract ElectrikTest is Test {
    INonfungiblePositionManager positionManager =
        INonfungiblePositionManager(
            vm.envAddress("NONFUNGIBLETOKEN_POSITION_MANAGER_ADDRESS")
        );
    IUniswapV3Factory factory = IUniswapV3Factory(vm.envAddress("V3_CORE_FACTORY_ADDRESSES"));
    IWETH9 weth = IWETH9(vm.envAddress("WETH"));
    IL2ERC20Template usdc = IL2ERC20Template(vm.envAddress("USDC"));
    IL2ERC20Template dai = IL2ERC20Template(vm.envAddress("DAI"));
    IUniswapV3Pool pool_usdc_weth = IUniswapV3Pool(vm.envAddress("USDC_WETH_POOL"));
    IUniswapV3Pool pool_usdc_dai;
    ISwapRouter02 swapRouter = ISwapRouter02(vm.envAddress("SWAPROUTER02"));
    // SwapRouter swapRouter1 = SwapRouter(payable(vm.envAddress("SWAPROUTER02")));
    address caller = 0x5adaf849e40B5b1303507299D3d06a4663D3A8b8;
    uint256 tokenId;
    uint128 liquidity;
    uint256 amount0;
    uint256 amount1;
    uint256 tokenId_2;
    uint128 liquidity_2;
    uint256 amount0_2;
    uint256 amount1_2;
    bytes nullBytes;
    address zero = 0xDD174edF007BC90FA2c4941A7a29efc432c14C7f;

    function setUp() public {
        vm.prank(0x63105ee97BfB22Dfe23033b3b14A4F8FED121ee9);
        usdc.mint(caller, 10000 * 10 ** 6);
        vm.prank(0x63105ee97BfB22Dfe23033b3b14A4F8FED121ee9);
        dai.mint(caller, 10000 * 10 ** 18);

        vm.startPrank(caller);

        vm.deal(caller, 20 ether);
        weth.deposit{value: 2 ether}();

        console2.log("WETH deposit successful");

        pool_usdc_dai = IUniswapV3Pool(factory.createPool(address(usdc), address(dai), 3000));
        pool_usdc_dai.initialize(79228162514264337593543950336000000);

        // token0 = usdc, token1 = weth
        pool_usdc_weth.initialize(1771595571142957166518320255467520);

        // (
        //     uint160 sqrtPriceX96,
        //     int24 tick,
        //     uint16 observationIndex,
        //     uint16 observationCardinality,
        //     uint16 observationCardinalityNext,
        //     uint8 feeProtocol,
        //     bool unlocked
        // ) = pool_usdc_dai.slot0();

        // console2.log(tick);
        IERC20(address(usdc)).approve(address(positionManager), UINT256_MAX);
        IERC20(address(weth)).approve(address(positionManager), UINT256_MAX);
        IERC20(address(dai)).approve(address(positionManager), UINT256_MAX);

        // mint a new position
        INonfungiblePositionManager.MintParams
            memory params = INonfungiblePositionManager.MintParams(
                address(usdc),
                address(weth),
                3000,
                200280,
                200340,
                2000 * 10 ** 6, // Desired amount of token0
                1 * 10 ** 18, // Desired amount of token1
                1550 * 10 ** 6, // Minimum amount of token1
                0.7 * 10 ** 18, // Minimum amount of token0
                caller,
                block.timestamp + 33600 // Deadline 1 hour from now
            );

        (tokenId, liquidity, amount0, amount1) = positionManager.mint(params);

        console2.log(tokenId, liquidity, amount0, amount1);

        // mint a new position
        INonfungiblePositionManager.MintParams
            memory params1 = INonfungiblePositionManager.MintParams(
                address(usdc),
                address(dai),
                3000,
                276300,
                276360,
                1000 * 10 ** 6, // Desired amount of token0
                1000 * 10 ** 18, // Desired amount of token1
                900 * 10 ** 6, // Minimum amount of token1
                600 * 10 ** 18, // Minimum amount of token0
                caller,
                block.timestamp + 33600 // Deadline 1 hour from now
            );

        (tokenId_2, liquidity_2, amount0_2, amount1_2) = positionManager.mint(params1);

        console2.log(tokenId_2, liquidity_2, amount0_2, amount1_2);

        vm.stopPrank();
    }

    function testIncreaseLiquidity() public {
        vm.startPrank(caller);
        (liquidity, amount0, amount1) = positionManager.increaseLiquidity(
            INonfungiblePositionManager.IncreaseLiquidityParams(
                tokenId,
                2000 * 10 ** 6, // Desired amount of token0
                1 * 10 ** 18, // Desired amount of token1
                1550 * 10 ** 6, // Minimum amount of token1
                0.7 * 10 ** 18, // Minimum amount of token0
                block.timestamp + 3600 // Deadline
            )
        );

        console2.log(liquidity, amount0, amount1);

        vm.stopPrank();
    }

    function testDecreaseLiquidity() public {
        vm.startPrank(caller);

        uint oldUsdcBal = usdc.balanceOf(caller);
        uint oldWethBal = weth.balanceOf(caller);

        (amount0, amount1) = positionManager.decreaseLiquidity(
            INonfungiblePositionManager.DecreaseLiquidityParams(
                tokenId,
                liquidity,
                1550 * 10 ** 6, // Minimum amount of token1
                0.7 * 10 ** 18, // Minimum amount of token0
                block.timestamp
            )
        );

        console2.log(liquidity, amount0, amount1);

        // get pool_usdc_weth info from LP token
        (
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            // address _token0,
            // address _token1,
            // int24 _tickLower,
            // int24 _tickUpper,
            uint128 _tokensOwed0,
            uint128 _tokensOwed1
        ) = INonfungiblePositionManager(positionManager).positions(tokenId);

        // collect tokens owed
        (amount0, amount1) = positionManager.collect(
            INonfungiblePositionManager.CollectParams(
                tokenId,
                caller,
                _tokensOwed0,
                _tokensOwed1
            )
        );

        // console2.log(IERC20Metadata(_token0).name(), IERC20Metadata(_token1).name());

        console2.log(amount0, amount1);

        uint newUsdcBal = usdc.balanceOf(caller);
        uint newWethBal = weth.balanceOf(caller);

        assertEq(newUsdcBal, oldUsdcBal + _tokensOwed0);
        assertEq(newWethBal, oldWethBal + _tokensOwed1);
        vm.stopPrank();
    }

    function testSwap() public {
        vm.startPrank(caller);
        IERC20(address(usdc)).approve(address(swapRouter), UINT256_MAX);
        IERC20(address(weth)).approve(address(swapRouter), UINT256_MAX);

        IV3SwapRouter.ExactInputSingleParams memory params = IV3SwapRouter
            .ExactInputSingleParams(
                address(usdc), // token in
                address(weth), // token out
                3000, // fee tier
                caller, // recipient
                1000 * 10 ** 6, // amount in
                0.4 ether, // amount out minimum
                0 // sqrtPriceLimitx96
            );
        uint256 amountOut = swapRouter.exactInputSingle(params);

        console2.log(amountOut);

        vm.stopPrank();
    }

    function testSwapII() public {
        vm.startPrank(caller);
        IERC20(address(usdc)).approve(address(swapRouter), UINT256_MAX);
        IERC20(address(dai)).approve(address(swapRouter), UINT256_MAX);

        IV3SwapRouter.ExactInputSingleParams memory params = IV3SwapRouter
            .ExactInputSingleParams(
                address(usdc), // token in
                address(dai), // token out
                3000, // fee tier
                caller, // recipient
                1000 * 10 ** 6, // amount in
                0.4 ether, // amount out minimum
                0 // sqrtPriceLimitx96
            );
        uint256 amountOut = swapRouter.exactInputSingle(params);

        console2.log(amountOut);

        vm.stopPrank();
    }

    function testSwapIII() public {

        vm.startPrank(caller);
        IERC20(address(usdc)).approve(address(swapRouter), UINT256_MAX);
        IERC20(address(weth)).approve(address(swapRouter), UINT256_MAX);
        IERC20(address(dai)).approve(address(swapRouter), UINT256_MAX);
        (
            uint256 amountOut
        ) = swapRouter.exactInput(
            IV3SwapRouter.ExactInputParams(
                abi.encodePacked (
                    address(weth),
                    uint24(3000),
                    address(usdc),
                    uint24(3000),
                    address(dai)
                ),
                caller,
                1 ether,
                500 * 10 ** 18
            )
        );

        console2.log(amountOut);

        vm.stopPrank();
    }
}

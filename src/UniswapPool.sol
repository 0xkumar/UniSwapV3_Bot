// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import "././Interfaces/IUniswapV3Factory.sol";
import "././Interfaces/INonfungiblePositionManager.sol";
import "././Interfaces/IUniswapV3Pool.sol";
import "./TransferHelper.sol";
import "././Interfaces/ISwapRouter.sol";
import {AggregatorV3Interface} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";


contract UniswapPool {

    uint256 public tokenId;
    // 1% fee
    uint24 public constant fee = 10000;
    //Address of the Swap Router
    ISwapRouter constant router = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);


    address[] public Createdpools;
    address public pool;
    // initial price used to initialize pool is project token0 / token1 => 2/1
    uint public  initialPrice = 1;
    IUniswapV3Factory constant factory = IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984);
    INonfungiblePositionManager constant positionManager = INonfungiblePositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);


    AggregatorV3Interface internal dataFeed1;
    AggregatorV3Interface internal dataFeed2;

    uint Arb_price_chainlink;
    uint Usdc_price_chainlink;



    constructor(){
        dataFeed1 = AggregatorV3Interface(0x31697852a68433DbCc2Ff612c516d69E3D9bd08F);
        dataFeed2 = AggregatorV3Interface(0xAed0c38402a5d19df6E4c03F4E2DceD6e29c1ee9);
    }

    /**
     * Returns the latest Arb price in terms of usd.
     */
    function getChainlinkDataFeedLatestAnswer1() public returns (uint) {
        // prettier-ignore
        (
            /* uint80 roundID */,
            int answer,
            /*uint startedAt*/,
            /*uint timeStamp*/,
            /*uint80 answeredInRound*/
        ) = dataFeed1.latestRoundData();
        Arb_price_chainlink = uint(answer) * 10000000000;
        return Arb_price_chainlink;
        
    }

    /**
     * Returns the latest Usdc price in terms of usd.
     */
    function getChainlinkDataFeedLatestAnswer2() public returns (uint) {
        // prettier-ignore
        (
            /* uint80 roundID */,
            int answer,
            /*uint startedAt*/,
            /*uint timeStamp*/,
            /*uint80 answeredInRound*/
        ) = dataFeed2.latestRoundData();
        Usdc_price_chainlink = uint(answer) * 10000000000;
        return Usdc_price_chainlink;
        
    }

    //Get the prrice of ARB in terms of Usdc
    function getArbPriceInUsdc() public view returns(int){
        (,int arbprice,,,)=dataFeed1.latestRoundData();
        (,int usdcprice,,,)=dataFeed2.latestRoundData();
        return ((arbprice )/(usdcprice));
    }

    //Function To create Pools
    function CreatePool(address token0,address token1)public returns(address){
        pool = factory.createPool(token0, token1, fee);
        Createdpools.push(pool);
        // initialize pool
        uint sqrtPriceX96 = (sqrt(initialPrice) * 2)**96;
        IUniswapV3Pool(pool).initialize(uint160(sqrtPriceX96));
        return pool;
    }

    /**
     * @notice Gets pool address
     */
    function getPools() public view returns (address[] memory) {
        return Createdpools;
    }

    /**
     * @notice Gets pool liquidity
     */
    function getLiquidity(address pool_address) public view returns (uint128) {
        return IUniswapV3Pool(pool_address).liquidity();
    }

    /**
     * @notice Gets pool price as token 0 / token 1 i.e defines how many token0 you get per token 1
     */
    function getPrice(address pool_address)
        public
        view
        returns (uint256 price)
    {
        (uint160 sqrtPriceX96,,,,,,) =  IUniswapV3Pool(pool_address).slot0();
        return uint(sqrtPriceX96) * (uint(sqrtPriceX96)) * (1e18) >> (96 * 2);
    }

    /**
     * @notice Returns Token 0 Address
     */
    function getToken0(address pool_address) public view returns (address) {
        return IUniswapV3Pool(pool_address).token0();
    }

    /**
     * @notice Returns Token 1 Address
     */
    function getToken1(address pool_address) public view returns (address) {
        return IUniswapV3Pool(pool_address).token1();
    }


    /**
     * @notice Gets sq root of a number
     * @param x no to get the sq root of
     */
    function sqrt(uint x) internal pure returns (uint y) {
        uint z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }
    
    //Function To Initialize the pool with the initial tokens amounts
    function initializePool(address pooladdress, uint256 amount_token0, uint256 amount_token1)external {
        address _token0=IUniswapV3Pool(pooladdress).token0();
        address _token1=IUniswapV3Pool(pooladdress).token1();
        TransferHelper.safeTransferFrom(_token0, msg.sender, address(this),amount_token0 );
        TransferHelper.safeTransferFrom(_token1, msg.sender, address(this),amount_token1 );
        TransferHelper.safeApprove(_token0, address(positionManager),  amount_token0); 
        TransferHelper.safeApprove(_token1, address(positionManager),  amount_token1); 

            INonfungiblePositionManager.MintParams memory params =
            INonfungiblePositionManager.MintParams({
                    token0: IUniswapV3Pool(pooladdress).token0(),
                    token1: IUniswapV3Pool(pooladdress).token1(),
                    fee: fee,
                    tickLower: -887200,
                    tickUpper: 887200,
                    amount0Desired: amount_token0,
                    amount1Desired: amount_token1,
                    amount0Min: 0,
                    amount1Min: 0,
                    recipient: address(this),
                    deadline: block.timestamp + 1000
            });
            (uint mintedId, , , ) = positionManager.mint(params);
            tokenId = mintedId;
    }


    //Function To Increase the Liquidity
    function increase_liquidity(address pooladdress, uint256 amount_token0, uint256 amount_token1 ) external payable {
    
        address _token0=IUniswapV3Pool(pooladdress).token0();
            address _token1=IUniswapV3Pool(pooladdress).token1();
            TransferHelper.safeTransferFrom(_token0, msg.sender, address(this),amount_token0 );
            TransferHelper.safeTransferFrom(_token1, msg.sender, address(this),amount_token1 );
            TransferHelper.safeApprove(_token0, address(positionManager),  amount_token0); 
            TransferHelper.safeApprove(_token1, address(positionManager),  amount_token1); 
                INonfungiblePositionManager.IncreaseLiquidityParams memory params =
                INonfungiblePositionManager.IncreaseLiquidityParams({
                        tokenId: tokenId,
                        amount0Desired: amount_token0,
                        amount1Desired: amount_token1,
                        amount0Min: 0,
                        amount1Min: 0,
                        deadline: block.timestamp + 1000
                });
                positionManager.increaseLiquidity(params);
    }

    //Swapping function Single Swap function
    function swapExactInputSingleHop(
        address tokenIn,
        address tokenOut,
        uint24 poolFee,
        uint256 amountIn
    )public returns (uint256 amountOut) {
        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        IERC20(tokenIn).approve(address(router), amountIn);

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
            .ExactInputSingleParams({
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            fee: poolFee,
            recipient: msg.sender,
            deadline: block.timestamp,
            amountIn: amountIn,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });

        amountOut = router.exactInputSingle(params);
    }

    //function To calculate the amount of tokens we have to transfer In.
    function CalculateSwapAmountAndExecuteSwap(address pool_address) public returns (uint){
       uint ArbPrice =  getChainlinkDataFeedLatestAnswer1();
       uint usdcPrice = getChainlinkDataFeedLatestAnswer2();
       uint liquidity = getLiquidity(pool_address);
       //uint Po = getPrice(pool_address);

       uint amount = ((sqrt(ArbPrice) * liquidity) / sqrt (usdcPrice)) -  liquidity;
       uint amount_to_swap = 10_000 * 100 / liquidity;
       return amount_to_swap + amount;

    }
}

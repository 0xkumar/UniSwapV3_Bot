// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import  {UniswapPool} from "../src/UniswapPool.sol";
import {ArbToken} from "../src/Arb.sol";
import {DaiToken} from "../src/Dai.sol";

contract Bot_Test is Test {

    string public ARB;
    string public AR;
    string public DAI;
    string public DI;
    address[]  pools;


    ArbToken arbtoken;
    DaiToken daitoken;
    UniswapPool pool;

    function setUp() public {
        arbtoken = new ArbToken(ARB,AR);
        daitoken = new DaiToken(DAI,DI);
        pool = new UniswapPool();
        pool.CreatePool(address(arbtoken),address(daitoken));
    }


    function testing_Bot() public {
        pools = pool.getPools();
        arbtoken.mint(100 * 1e18);
        daitoken.mint(100 * 1e18);
        arbtoken.approve(address(pool),100 * 1e18);
        daitoken.approve(address(pool),100 * 1e18);
        pool.initializePool(pools[0], 100_000_000 , 100_000_000 );

        //Fetching the prices from the chainlink
        uint arbpriceinusd = pool.getChainlinkDataFeedLatestAnswer1();
        uint daipriceinusd = pool.getChainlinkDataFeedLatestAnswer2();

        //Printing the chainlink Prices
        console.log("arbprice in usd ",arbpriceinusd);
        console.log("Dai price in usd",daipriceinusd);


        uint liquidityInThePool  = pool.getLiquidity(address(pools[0]));
        console.log("Liquidity In the pool When Initialized",liquidityInThePool);

        uint poolprice = pool.getPrice(pools[0]);
        console.log("pool price as sqrtPriceX96",poolprice);
        uint poolpricebeforeswap = pool.getPrice(pools[0]);
        console.log("pool price as token X / token Y before swap",poolpricebeforeswap);

        uint amount_to_swap = pool.CalculateSwapAmountAndExecuteSwap(pools[0]);
        console.log("Amount to swap",amount_to_swap);
        pool.swapExactInputSingleHop(address(arbtoken),address(daitoken),10000,amount_to_swap);
        uint poolpriceafterswap = pool.getPrice(pools[0]);
        console.log("Price in the pool in  token X / token Y after swap",poolpriceafterswap);
        
    }

}

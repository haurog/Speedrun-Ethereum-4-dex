// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/**
 * @title DEX Template
 * @author stevepham.eth and m00npapi.eth
 * @notice Empty DEX.sol that just outlines what features could be part of the challenge (up to you!)
 * @dev We want to create an automatic market where our contract will hold reserves of both ETH and 🎈 Balloons. These reserves will provide liquidity that allows anyone to swap between the assets.
 * NOTE: functions outlined here are what work with the front end of this branch/repo. Also return variable names that may need to be specified exactly may be referenced (if you are confused, see solutions folder in this repo and/or cross reference with front-end code).
 */
contract DEX {
    /* ========== GLOBAL VARIABLES ========== */

    using SafeMath for uint256; //outlines use of SafeMath for uint256 variables
    IERC20 token; //instantiates the imported contract

    uint256 public totalLiquidity;
    mapping(address => uint256) public liquidity;

    /* ========== EVENTS ========== */

    /**
     * @notice Emitted when ethToToken() swap transacted
     */
    event EthToTokenSwap(
        address sender,
        string message,
        uint256 valueIn,
        uint256 valueOut
    );

    /**
     * @notice Emitted when tokenToEth() swap transacted
     */
    event TokenToEthSwap(
        address sender,
        string message,
        uint256 valueIn,
        uint256 valueOut
    );

    /**
     * @notice Emitted when liquidity provided to DEX and mints LPTs.
     */
        event LiquidityProvided(
        address provider,
        uint256 providedLiquidity,
        uint256 ethProvided,
        uint256 tokensProvided
    );

    /**
     * @notice Emitted when liquidity removed from DEX and decreases LPT count within DEX.
     */
    event LiquidityRemoved(
        address receiver,
        uint256 removedLiquidity,
        uint256 ethRemoved,
        uint256 tokensRemoved
    );


    /* ========== CONSTRUCTOR ========== */

    constructor(address token_addr) public {
        token = IERC20(token_addr); //specifies the token address that will hook into the interface and be used through the variable 'token'
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    /**
     * @notice initializes amount of tokens that will be transferred to the DEX itself from the erc20 contract mintee (and only them based on how Balloons.sol is written). Loads contract up with both ETH and Balloons.
     * @param tokens amount to be transferred to DEX
     * @return totalLiquidity is the number of LPTs minting as a result of deposits made to DEX contract
     * NOTE: since ratio is 1:1, this is fine to initialize the totalLiquidity (wrt to balloons) as equal to eth balance of contract.
     */
    function init(uint256 tokens) public payable returns (uint256) {
        require(totalLiquidity == 0, "DEX: init - already has liquidity");
        totalLiquidity = address(this).balance;
        liquidity[msg.sender] = totalLiquidity;
        require(token.transferFrom(msg.sender, address(this), tokens), "DEX: init - transfer did not transact");
        return totalLiquidity;
    }
    /**
     * @notice returns yOutput, or yDelta for xInput (or xDelta)
     * @dev Follow along with the [original tutorial](https://medium.com/@austin_48503/%EF%B8%8F-minimum-viable-exchange-d84f30bd0c90) Price section for an understanding of the DEX's pricing model and for a price function to add to your contract. You may need to update the Solidity syntax (e.g. use + instead of .add, * instead of .mul, etc). Deploy when you are done.
     */
    function price(
        uint256 xInput,
        uint256 xReserves,
        uint256 yReserves
    ) public pure returns (uint256 yOutput) {
        uint256 multiplier = 1000; // multiply everything so we can deduct a fee without going into floating points
        uint256 fee = 997; // TODO: should probably be a global variable
        uint256 xReserves_m = xReserves * multiplier;
        uint256 xInput_f = xInput * fee;
        yOutput = (xInput_f * yReserves) / (xReserves_m + xInput_f); // No multiplier for yReserves so that we do not have to divide by the multiplier in the end.
    }

    /**
     * @notice returns liquidity for a user.
     * NOTE: this is not needed typically due to the `liquidity()` mapping variable being public and having a getter as a result. This is left though as it is used within the front end code (App.jsx).
     * NOTE: if you are using a mapping liquidity, then you can use `return liquidity[lp]` to get the liquidity for a user.
     * NOTE: if you will be submitting the challenge make sure to implement this function as it is used in the tests.
     */
    function getLiquidity(address lp) public view returns (uint256) {
        return liquidity[lp];
    }

    /**
     * @notice sends Ether to DEX in exchange for $BAL
     */
    function ethToToken() public payable returns (uint256 tokenOutput) {
        require(msg.value > 0, "Need ETH to swap to token.");
        uint256 ethReserves = address(this).balance - msg.value;
        uint256 tokenReserves = token.balanceOf(address(this));
        tokenOutput = price(msg.value, ethReserves, tokenReserves);
        bool succeeded = token.transfer(msg.sender, tokenOutput);
        require(succeeded, "Could not transfer token.");
        emit EthToTokenSwap(
            msg.sender,
            "ETH to Balloons",
            msg.value,
            tokenOutput
        );}

    /**
     * @notice sends $BAL tokens to DEX in exchange for Ether
     */
    function tokenToEth(uint256 tokenInput) public returns (uint256 ethOutput) {
        require(tokenInput > 0, "Need tokens to swap to ETH.");
        uint256 ethReserves = address(this).balance;
        uint256 tokenReserves = token.balanceOf(address(this));
        bool succeded = token.transferFrom(
            msg.sender,
            address(this),
            tokenInput
        );
        require(succeded, "Tokens could not be transferred to exchange.");
        ethOutput = price(tokenInput, tokenReserves, ethReserves);
        (bool sent, ) = msg.sender.call{value: ethOutput}("");
        require(sent, "Failed to send Ether.");
        emit TokenToEthSwap(
            msg.sender,
            "Balloons to ETH",
            tokenInput,
            ethOutput
        );
    }

    /**
     * @notice allows deposits of $BAL and $ETH to liquidity pool
     * NOTE: parameter is the msg.value sent with this function call. That amount is used to determine the amount of $BAL needed as well and taken from the depositor.
     * NOTE: user has to make sure to give DEX approval to spend their tokens on their behalf by calling approve function prior to this function call.
     * NOTE: Equal parts of both assets will be removed from the user's wallet with respect to the price outlined by the AMM.
     */
    function deposit() public payable returns (uint256 tokensDeposited) {
        require(msg.value > 0, "Need Eth to deposit.");
        uint256 ethReserves = address(this).balance - msg.value;
        uint256 tokenReserves = token.balanceOf(address(this));
        uint256 tokensToDeposit = (tokenReserves * msg.value) / ethReserves;
        uint256 liquidityMinted = (totalLiquidity * msg.value) / ethReserves;
        totalLiquidity += liquidityMinted;
        liquidity[msg.sender] += liquidityMinted;
        bool succeeded = token.transferFrom(
            msg.sender,
            address(this),
            tokensToDeposit
        );
        require(
            succeeded,
            "Tokens could not be transferred to liquidity pool."
        );
        emit LiquidityProvided(
            msg.sender,
            liquidityMinted,
            msg.value,
            tokensToDeposit
        );
        return tokensToDeposit;
    }

    /**
     * @notice allows withdrawal of $BAL and $ETH from liquidity pool
     * NOTE: with this current code, the msg caller could end up getting very little back if the liquidity is super low in the pool. I guess they could see that with the UI.
     */
    function withdraw(uint256 amount) public returns (uint256 eth_amount, uint256 token_amount) {
        require(amount > 0, "Nothing to withdraw");
        require(
            amount <= liquidity[msg.sender],
            "More liquidity requested than was provided"
        );
        uint256 ethReserves = address(this).balance;
        uint256 tokenReserves = token.balanceOf(address(this));

        uint256 ethToWithdraw = (ethReserves * amount) / totalLiquidity;
        uint256 tokenToWithdraw = (tokenReserves * ethToWithdraw) / ethReserves;
        // console.log("eth and token: ", ethToWithdraw, tokenToWithdraw);

        totalLiquidity -= amount;
        liquidity[msg.sender] -= amount;
        (bool sent, ) = msg.sender.call{value: ethToWithdraw}("");
        require(sent, "Failed to send Ether.");
        bool succeeded = token.transfer(msg.sender, tokenToWithdraw);
        require(succeeded, "Could not transfer token.");
        emit LiquidityRemoved(
            msg.sender,
            amount,
            ethToWithdraw,
            tokenToWithdraw
        );
        return (ethToWithdraw, tokenToWithdraw);
    }
}

/**SPDX-License-Identifier: MIT */
pragma solidity ^0.8.0;

import "./Crowdsale.sol";
import "./validation/CappedCrowdsale.sol";
import "./validation/TimedCrowdsale.sol";
import "./validation/IndividuallyCappedCrowdsale.sol";
import "./price/IncreasingPriceCrowdsale.sol";
import "./presets/IBEP20.sol";
import "./presets/SafeMath.sol";

contract NortPrivateSale is
    Crowdsale,
    CappedCrowdsale,
    TimedCrowdsale,
    IncreasingPriceCrowdsale,
    IndividuallyCappedCrowdsale
{
    uint8 constant DECIMALS = 18;
    using SafeMath for uint256;

    constructor(
        uint256 rate, // rate, in Nortbits
        uint256 finalRate, // finalRate, in Nortbits
        address payable wallet, // wallet to send BNB
        IBEP20 token, // the token
        uint256 cap, // total cap, in number
        uint256 openingTime, // opening time in unix epoch seconds
        uint256 closingTime // closing time in unix epoch seconds
    )
        CappedCrowdsale(cap * 10**uint256(DECIMALS))
        TimedCrowdsale(openingTime, closingTime)
        Crowdsale(rate, wallet, token)
        IncreasingPriceCrowdsale(rate, finalRate)
    {
        // nice, we just created a crowdsale that's only open
        // for a certain amount of time
        // and stops accepting contributions once it reaches `cap`
        // with a individual max cap
        // and incrising the price
    }

    function _preValidatePurchase(address beneficiary, uint256 weiAmount)
        internal
        view
        override(
            Crowdsale,
            CappedCrowdsale,
            TimedCrowdsale,
            IndividuallyCappedCrowdsale
        )
    {
        require(
            beneficiary != address(0),
            "Crowdsale: beneficiary is the zero address"
        );
        require(weiAmount != 0, "Crowdsale: weiAmount is 0");

        require(
            weiRaised() + weiAmount <= cap(),
            "CappedCrowdsale: cap exceeded"
        );
        require(
            _contributions[beneficiary] + weiAmount <= getCap(),
            "IndividuallyCappedCrowdsale: beneficiary's cap exceeded"
        );
    }

    /**
     * @dev Overrides parent method taking into account variable rate.
     * @param weiAmount The value in wei to be converted into tokens
     * @return The number of tokens _weiAmount wei will buy at present time
     */
    function _getTokenAmount(uint256 weiAmount)
        internal
        view
        override(Crowdsale, IncreasingPriceCrowdsale)
        returns (uint256)
    {
        uint256 currentRate = getCurrentRate();
        return currentRate.mul(weiAmount);
    }

    /**
     * @dev Extend parent behavior to update beneficiary contributions.
     * @param beneficiary Token purchaser
     * @param weiAmount Amount of wei contributed
     */
    function _updatePurchasingState(address beneficiary, uint256 weiAmount)
        internal
        virtual
        override(IndividuallyCappedCrowdsale, Crowdsale)
    {
        super._updatePurchasingState(beneficiary, weiAmount);
        _contributions[beneficiary] = _contributions[beneficiary] + weiAmount;
    }
}

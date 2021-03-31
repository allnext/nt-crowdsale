/**SPDX-License-Identifier: MIT */
pragma solidity ^0.8.0;

import "../presets/SafeMath.sol";
import "../Crowdsale.sol";
import "../roles/CapperRole.sol";

/**
 * @title IndividuallyCappedCrowdsale
 * @dev Crowdsale with per-beneficiary caps.
 */
abstract contract IndividuallyCappedCrowdsale is Crowdsale, CapperRole {
    using SafeMath for uint256;

    uint256 private _maxCap;

    mapping(address => uint256) internal _contributions;

    /**
     * @dev Sets a specific beneficiary's maximum contribution.
     * @param cap Wei limit for individual contribution
     */
    function setCap(uint256 cap) external onlyCapper {
        _maxCap = cap;
    }

    /**
     * @dev Returns the cap of a specific beneficiary.
     * @return Current cap for individual beneficiary
     */
    function getCap() public view returns (uint256) {
        return _maxCap;
    }

    /**
     * @dev Returns the amount contributed so far by a specific beneficiary.
     * @param beneficiary Address of contributor
     * @return Beneficiary contribution so far
     */
    function getContribution(address beneficiary)
        public
        view
        returns (uint256)
    {
        return _contributions[beneficiary];
    }

    /**
     * @dev Extend parent behavior requiring purchase to respect the beneficiary's funding cap.
     * @param beneficiary Token purchaser
     * @param weiAmount Amount of wei contributed
     */
    function _preValidatePurchase(address beneficiary, uint256 weiAmount)
        internal
        view
        virtual
        override
    {
        super._preValidatePurchase(beneficiary, weiAmount);
        // solhint-disable-next-line max-line-length
        require(
            _contributions[beneficiary].add(weiAmount) <= _maxCap,
            "IndividuallyCappedCrowdsale: beneficiary's cap exceeded"
        );
    }

    /**
     * @dev Extend parent behavior to update beneficiary contributions.
     * @param beneficiary Token purchaser
     * @param weiAmount Amount of wei contributed
     */
    function _updatePurchasingState(address beneficiary, uint256 weiAmount)
        internal
        virtual
        override
    {
        super._updatePurchasingState(beneficiary, weiAmount);
        _contributions[beneficiary] = _contributions[beneficiary].add(
            weiAmount
        );
    }
}

/**SPDX-License-Identifier: MIT */
pragma solidity ^0.8.0;

pragma experimental ABIEncoderV2;

import "./presets/Context.sol";
import "./presets/IBEP20.sol";
import "./presets/SafeMath.sol";
import "./presets/Ownable.sol";
import "./SafeBEP20.sol";
import "./presets/ReentrancyGuard.sol";

/**
 * @title Crowdsale
 * @dev Crowdsale is a base contract for managing a token crowdsale,
 * allowing investors to purchase tokens with ether. This contract implements
 * such functionality in its most fundamental form and can be extended to provide additional
 * functionality and/or custom behavior.
 * The external interface represents the basic interface for purchasing tokens, and conforms
 * the base architecture for crowdsales. It is *not* intended to be modified / overridden.
 * The internal interface conforms the extensible and modifiable surface of crowdsales. Override
 * the methods to add functionality. Consider using 'super' where appropriate to concatenate
 * behavior.
 */
contract Crowdsale is Context, ReentrancyGuard, Ownable {
    using SafeMath for uint256;
    using SafeBEP20 for IBEP20;

    // The token being sold
    IBEP20 private _token;

    // Address where funds are collected
    address payable private _wallet;

    //Agent struct
    struct Agent {
        address _agency_address;
        address _brother_agent_address;
    }

    //list of agents
    mapping(address => Agent) public agents;

    // How many token units a buyer gets per wei.
    // The rate is the conversion between wei and the smallest and indivisible token unit.
    // So, if you are using a rate of 1 with a BEP20Detailed token with 3 decimals called TOK
    // 1 wei will give you 1 unit, or 0.001 TOK.
    uint256 private _rate;

    // Amount of wei raised
    uint256 private _weiRaised;

    /**
     * Event for token purchase logging
     * @param agent_address wallet address of registred agent
     * @param brother_agent_address wallet address of brother agent
     * @param agency_address wallet address of relationed agency
     */
    event AgentRegistred(
        address indexed agent_address,
        address indexed brother_agent_address,
        address indexed agency_address
    );

    /**
     * Event for token purchase logging
     * @param purchaser who paid for the tokens
     * @param beneficiary who got the tokens
     * @param value weis paid for purchase
     * @param amount amount of tokens purchased
     */
    event TokensPurchased(
        address indexed purchaser,
        address indexed beneficiary,
        uint256 value,
        uint256 amount
    );

    /**
     * Event for token purchase logging
     * @param purchaser who paid for the tokens
     * @param beneficiary who got the tokens
     * @param amount amount of tokens purchased
     */
    event TokensIndicationDistributed(
        address indexed purchaser,
        address indexed beneficiary,
        uint256 amount
    );

    /**
     * @param rate_ Number of token units a buyer gets per wei
     * @dev The rate is the conversion between wei and the smallest and indivisible
     * token unit. So, if you are using a rate of 1 with a BEP20Detailed token
     * with 3 decimals called TOK, 1 wei will give you 1 unit, or 0.001 TOK.
     * @param wallet_ Address where collected funds will be forwarded to
     * @param token_ Address of the token being sold
     */
    constructor(
        uint256 rate_,
        address payable wallet_,
        IBEP20 token_
    ) {
        require(rate_ > 0, "Crowdsale: rate is 0");
        require(wallet_ != address(0), "Crowdsale: wallet is the zero address");
        require(
            address(token_) != address(0),
            "Crowdsale: token is the zero address"
        );

        _rate = rate_;
        _wallet = wallet_;
        _token = token_;
    }

    /**
     * @dev fallback function ***DO NOT OVERRIDE***
     * Note that other contracts will transfer funds with a base gas stipend
     * of 2300, which is not enough to call buyTokens. Consider calling
     * buyTokens directly when purchasing tokens from a contract.
     */
    receive() external payable {
        buyTokens(_msgSender(), address(0));
    }

    /**
     * @param agent_address Agent Wallet Addres
     * @param agency_address Agency Wallet Addres
     * @return bool
     */
    function newAgent(
        address agent_address,
        address brother_agent_address,
        address agency_address
    ) public onlyOwner returns (bool) {
        agents[agent_address]._brother_agent_address = brother_agent_address;
        agents[agent_address]._agency_address = agency_address;
        emit AgentRegistred(
            agent_address,
            brother_agent_address,
            agency_address
        );
        return true;
    }

    /**
     * @return the token being sold.
     */
    function token() public view returns (IBEP20) {
        return _token;
    }

    /**
     * @return the address where funds are collected.
     */
    function wallet() public view returns (address payable) {
        return _wallet;
    }

    /**
     * @return the number of token units a buyer gets per wei.
     */
    function rate() public view returns (uint256) {
        return _rate;
    }

    /**
     * @return the amount of wei raised.
     */
    function weiRaised() public view returns (uint256) {
        return _weiRaised;
    }

    /**
     * @dev Override to extend the way in which ether is converted to tokens.
     * @param weiAmount Value in wei to be converted into tokens
     * @return Number of tokens that can be purchased with the specified _weiAmount
     */
    function _getTokenAmount(uint256 weiAmount)
        internal
        view
        virtual
        returns (uint256)
    {
        return weiAmount.mul(_rate);
    }

    /**
     * @dev low level token purchase ***DO NOT OVERRIDE***
     * This function has a non-reentrancy guard, so it shouldn't be called by
     * another `nonReentrant` function.
     * @param beneficiary Recipient of the token purchase
     * @param agent_address Recipient of the token purchase bonus indication
     */
    function buyTokens(address beneficiary, address agent_address)
        public
        payable
        nonReentrant
    {
        uint256 weiAmount = msg.value;
        _preValidatePurchase(beneficiary, weiAmount);

        // calculate token amount to be created
        uint256 tokens = _getTokenAmount(weiAmount);

        // update state
        _weiRaised = _weiRaised.add(weiAmount);

        _processPurchase(beneficiary, tokens);
        emit TokensPurchased(_msgSender(), beneficiary, weiAmount, tokens);

        _updatePurchasingState(beneficiary, weiAmount);

        _forwardFunds();
        _postValidatePurchase(beneficiary, weiAmount);

        _payIndicationBonus(agent_address, tokens);
    }

    function _payIndicationBonus(address agent_address, uint256 tokens)
        internal
    {
        require(
            agent_address != address(0),
            "Crowdsale: beneficiary of bonus indication is the zero address"
        );

        Agent storage agent = agents[agent_address];
        if (agent._agency_address != address(0x0)) {
            uint256 agentTokens = tokens.mul(10).div(100);
            uint256 agencyTokens = tokens.mul(5).div(100);
            if (agent._brother_agent_address != address(0x0)) {
                agencyTokens = tokens.mul(25).div(10).div(100);
                uint256 agentBrotherTokens = agencyTokens;
                _processPurchase(
                    agent._brother_agent_address,
                    agentBrotherTokens
                );

                emit TokensIndicationDistributed(
                    _msgSender(),
                    agent._brother_agent_address,
                    agentBrotherTokens
                );
            }

            _processPurchase(agent_address, agentTokens);
            _processPurchase(agent._agency_address, agencyTokens);
            emit TokensIndicationDistributed(
                _msgSender(),
                agent_address,
                agentTokens
            );
            emit TokensIndicationDistributed(
                _msgSender(),
                agent._agency_address,
                agencyTokens
            );
        }
    }

    /**
     * @dev Validation of an incoming purchase. Use require statements to revert state when conditions are not met.
     * Use `super` in contracts that inherit from Crowdsale to extend their validations.
     * Example from CappedCrowdsale.sol's _preValidatePurchase method:
     *     super._preValidatePurchase(beneficiary, weiAmount);
     *     require(weiRaised().add(weiAmount) <= cap);
     * @param beneficiary Address performing the token purchase
     * @param weiAmount Value in wei involved in the purchase
     */
    function _preValidatePurchase(address beneficiary, uint256 weiAmount)
        internal
        view
        virtual
    {
        require(
            beneficiary != address(0),
            "Crowdsale: beneficiary is the zero address"
        );
        require(weiAmount != 0, "Crowdsale: weiAmount is 0");
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
    }

    /**
     * @dev Validation of an executed purchase. Observe state and use revert statements to undo rollback when valid
     * conditions are not met.
     * @param beneficiary Address performing the token purchase
     * @param weiAmount Value in wei involved in the purchase
     */
    function _postValidatePurchase(address beneficiary, uint256 weiAmount)
        internal
        view
    {
        // solhint-disable-previous-line no-empty-blocks
    }

    /**
     * @dev Source of tokens. Override this method to modify the way in which the crowdsale ultimately gets and sends
     * its tokens.
     * @param beneficiary Address performing the token purchase
     * @param tokenAmount Number of tokens to be emitted
     */
    function _deliverTokens(address beneficiary, uint256 tokenAmount) internal {
        _token.safeTransfer(beneficiary, tokenAmount);
    }

    /**
     * @dev Executed when a purchase has been validated and is ready to be executed. Doesn't necessarily emit/send
     * tokens.
     * @param beneficiary Address receiving the tokens
     * @param tokenAmount Number of tokens to be purchased
     */
    function _processPurchase(address beneficiary, uint256 tokenAmount)
        internal
    {
        _deliverTokens(beneficiary, tokenAmount);
    }

    /**
     * @dev Override for extensions that require an internal state to check for validity (current user contributions,
     * etc.)
     * @param beneficiary Address receiving the tokens
     * @param weiAmount Value in wei involved in the purchase
     */
    function _updatePurchasingState(address beneficiary, uint256 weiAmount)
        internal
        virtual
    {
        // solhint-disable-previous-line no-empty-blocks
    }

    /**
     * @dev Determines how BNB is stored/forwarded on purchases.
     */
    function _forwardFunds() internal {
        _wallet.transfer(msg.value);
    }
}

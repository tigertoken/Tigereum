pragma solidity 0.4.19;

import './Tigereum.sol';
import './Crowdsale.sol';
import './Ownable.sol';


contract TigereumCrowdsale is Ownable, Crowdsale {

    using SafeMath for uint256;
  
    //operational
    bool public LockupTokensWithdrawn = false;
    bool public isFinalized = false;
    uint256 public constant toDec = 10**18;
    uint256 public tokensLeft = 32800000*toDec;
    uint256 public constant cap = 32800000*toDec;
    uint256 public constant startRate = 1333;
    uint256 private accumulated = 0;

    enum State { BeforeSale, Bonus, NormalSale, ShouldFinalize, Lockup, SaleOver }
    State public state = State.BeforeSale;

    /* --- Ether wallets --- */

    address public admin;// = 0x021e366d41cd25209a9f1197f238f10854a0c662; // 0 - get 99% of ether
    address public ICOadvisor1;// = 0xBD1b96D30E1a202a601Fa8823Fc83Da94D71E3cc; // 1 - get 1% of ether
    uint256 private constant ICOadvisor1Sum = 400000*toDec; // also gets tokens - 0.8% - 400,000

    // Pre ICO wallets

    address public hundredKInvestor;// = 0x93da612b3DA1eF05c5D80c9B906bf9e7aAdc4a23;
    uint256 private constant hundredKInvestorSum = 3200000*toDec; // 2 - 6.4% - 3,200,000

    address public additionalPresaleInvestors;// = 0x095e80F85f3D260bF959Aa524F2f3918f56a2493;
    uint256 private constant additionalPresaleInvestorsSum = 1000000*toDec; // 3 - 2% - 1,000,000

    address public preSaleBotReserve;// = 0x095e80F85f3D260bF959Aa524F2f3918f56a2493; // same as additionalPresaleInvestors
    uint256 private constant preSaleBotReserveSum = 2500000*toDec; // 4 - 5% - 2,500,000

    address public ICOadvisor2;// = 0xe05416EAD6d997C8bC88A7AE55eC695c06693C58;
    uint256 private constant ICOadvisor2Sum = 100000*toDec; // 5 - 0.2% - 100,000

    address public team;// = 0xA919B56D099C12cC8921DF605Df2D696b30526B0;
    uint256 private constant teamSum = 1820000*toDec; // 6 - 3.64% - 1,820,000
 
    address public bounty;// = 0x20065A723d43c753AD83689C5f9F4786a73Be6e6;
    uint256 private constant bountySum = 1000000*toDec; // 7 - 2% - 1,000,000

    
    // Lockup wallets
    address public founders;// = 0x49ddcD8b4B1F54f3E5c4fEf705025C1DaDC753f6;
    uint256 private constant foundersSum = 7180000*toDec; // 8 - 14.36% - 7,180,000


    /* --- Time periods --- */


    uint256 public constant startTimeNumber = 1512723600 + 1; // 8/12/17-9:00:00 - 1512723600
    uint256 public constant endTimeNumber = 1513641540; // 18/12/17-23:59:00 - 1513641540

    uint256 public constant lockupPeriod = 90 * 1 days; // 90 days - 7776000
    uint256 public constant bonusPeriod = 12 * 1 hours; // 12 hours - 43,200

    uint256 public constant bonusEndTime = bonusPeriod + startTimeNumber;



    event LockedUpTokensWithdrawn();
    event Finalized();

    modifier canWithdrawLockup() {
        require(state == State.Lockup);
        require(endTime.add(lockupPeriod) < block.timestamp);
        _;
    }

    function TigereumCrowdsale(
        address _admin,
        address _ICOadvisor1,
        address _hundredKInvestor,
        address _additionalPresaleInvestors,
        address _preSaleBotReserve,
        address _ICOadvisor2,
        address _team,
        address _bounty,
        address _founders)
    Crowdsale(
        startTimeNumber /* start date - 8/12/17-9:00:00 */, 
        endTimeNumber /* end date - 18/12/17-23:59:00 */, 
        startRate /* start rate - 1333 */, 
        _admin
    )  
    public 
    {      
        admin = _admin;
        ICOadvisor1 = _ICOadvisor1;
        hundredKInvestor = _hundredKInvestor;
        additionalPresaleInvestors = _additionalPresaleInvestors;
        preSaleBotReserve = _preSaleBotReserve;
        ICOadvisor2 = _ICOadvisor2;
        team = _team;
        bounty = _bounty;
        founders = _founders;
        owner = admin;
    }

    function isContract(address addr) private returns (bool) {
      uint size;
      assembly { size := extcodesize(addr) }
      return size > 0;
    }

    // creates the token to be sold.
    // override this method to have crowdsale of a specific MintableToken token.
    function createTokenContract() internal returns (MintableToken) {
        return new Tigereum();
    }

    function forwardFunds() internal {
        forwardFundsAmount(msg.value);
    }

    function forwardFundsAmount(uint256 amount) internal {
        var onePercent = amount / 100;
        var adminAmount = onePercent.mul(99);
        admin.transfer(adminAmount);
        ICOadvisor1.transfer(onePercent);
        var left = amount.sub(adminAmount).sub(onePercent);
        accumulated = accumulated.add(left);
    }

    function refundAmount(uint256 amount) internal {
        msg.sender.transfer(amount);
    }

    function fixAddress(address newAddress, uint256 walletIndex) onlyOwner public {
        require(state != State.ShouldFinalize && state != State.Lockup && state != State.SaleOver);
        if (walletIndex == 0 && !isContract(newAddress)) {
            admin = newAddress;
        }
        if (walletIndex == 1 && !isContract(newAddress)) {
            ICOadvisor1 = newAddress;
        }
        if (walletIndex == 2) {
            hundredKInvestor = newAddress;
        }
        if (walletIndex == 3) {
            additionalPresaleInvestors = newAddress;
        }
        if (walletIndex == 4) {
            preSaleBotReserve = newAddress;
        }
        if (walletIndex == 5) {
            ICOadvisor2 = newAddress;
        }
        if (walletIndex == 6) {
            team = newAddress;
        }
        if (walletIndex == 7) {
            bounty = newAddress;
        }
        if (walletIndex == 8) {
            founders = newAddress;
        }
    }

    function calculateCurrentRate() internal {
        if (state == State.NormalSale) {
            rate = 1000;
        }
    }

    function buyTokensUpdateState() internal {
        if(state == State.BeforeSale && now >= startTimeNumber) { state = State.Bonus; }
        if(state == State.Bonus && now >= bonusEndTime) { state = State.NormalSale; }
        calculateCurrentRate();
        require(state != State.ShouldFinalize && state != State.Lockup && state != State.SaleOver);
        if(msg.value.mul(rate) >= tokensLeft) { state = State.ShouldFinalize; }
    }

    function buyTokens(address beneficiary) public payable {
        buyTokensUpdateState();
        var numTokens = msg.value.mul(rate);
        if(state == State.ShouldFinalize) {
            lastTokens(beneficiary);
            finalize();
        }
        else {
            tokensLeft = tokensLeft.sub(numTokens); // if negative, should finalize
            super.buyTokens(beneficiary);
        }
    }

    function lastTokens(address beneficiary) internal {
        require(beneficiary != 0x0);
        require(validPurchase());

        uint256 weiAmount = msg.value;

        // calculate token amount to be created
        uint256 tokensForFullBuy = weiAmount.mul(rate);// must be bigger or equal to tokensLeft to get here
        uint256 tokensToRefundFor = tokensForFullBuy.sub(tokensLeft);
        uint256 tokensRemaining = tokensForFullBuy.sub(tokensToRefundFor);
        uint256 weiAmountToRefund = tokensToRefundFor.div(rate);
        uint256 weiRemaining = weiAmount.sub(weiAmountToRefund);
        
        // update state
        weiRaised = weiRaised.add(weiRemaining);

        token.mint(beneficiary, tokensRemaining);
        TokenPurchase(msg.sender, beneficiary, weiRemaining, tokensRemaining);

        forwardFundsAmount(weiRemaining);
        refundAmount(weiAmountToRefund);
    }

    function withdrawLockupTokens() canWithdrawLockup public {
        rate = 1000;
        token.mint(founders, foundersSum);
        token.finishMinting();
        LockupTokensWithdrawn = true;
        LockedUpTokensWithdrawn();
        state = State.SaleOver;
    }

    function finalizeUpdateState() internal {
        if(now > endTimeNumber) { state = State.ShouldFinalize; }
        if(tokensLeft == 0) { state = State.ShouldFinalize; }
    }

    function finalize() public {
        finalizeUpdateState();
        require (!isFinalized);
        require (state == State.ShouldFinalize);

        finalization();
        Finalized();

        isFinalized = true;
    }

    function finalization() internal {
        endTime = block.timestamp;
        /* - preICO investors - */
        token.mint(ICOadvisor1, ICOadvisor1Sum);
        token.mint(hundredKInvestor, hundredKInvestorSum);
        token.mint(additionalPresaleInvestors, additionalPresaleInvestorsSum);
        token.mint(preSaleBotReserve, preSaleBotReserveSum);
        token.mint(ICOadvisor2, ICOadvisor2Sum);
        token.mint(team, teamSum);
        token.mint(bounty, bountySum);
        forwardFundsAmount(accumulated);
        tokensLeft = 0;
        state = State.Lockup;
    }
}

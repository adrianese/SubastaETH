// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Auction {
    // State Variables
    // PUBLIC VARIABLES
    bool public auctionEnded;         // auctionEnded: Indicates whether the auction has ended.
    
    // PRIVATE VARIABLES
    address private owner;            // owner: Address of the contract creator.
    uint private endTime;             // endTime: Auction ending timestamp.
    uint public highestBid;           // highestBid: Current highest bid amount.
    address private highestBidder;    // highestBidder: Address of the highest bidder.
    mapping(address => uint) private bids; // bids: Mapping storing each bidder's deposit.
    address[] private biddersList;    // biddersList: Dynamic array of bidders' addresses.
    
    struct Bid {
        address bidder;
        uint amount;
    }
    
    // EVENTS
    // NewBid: Emitted when a new bid is placed.
    event NewBid(address indexed bidder, uint amount);
    
    // AuctionEnded: Emitted when the auction is finalized.
    event AuctionEnded(address winner, uint amount);
    
    // RefundIssued: Emitted when a refund is issued to a bidder.
    event RefundIssued(address indexed bidder, uint refundedAmount);
    
    // CONSTRUCTOR: Initializes the contract with a given auction duration.
    constructor(uint _duration) {
        owner = msg.sender;
        endTime = block.timestamp + _duration; // Auction duration in seconds.
        auctionEnded = false;
    }
    
    // MODIFIERS
    /**
     * @notice Allows execution only before the auction end time.
     */
    modifier onlyBeforeEnd() {
        require(block.timestamp < endTime, "Auction has ended");
        _;
    }
    
    /**
     * @notice Ensures the auction has not yet ended.
     */
    modifier auctionNotEnded() {
        require(!auctionEnded, "Auction has already ended");
        _;
    }
    
    /**
     * @notice Allows execution only after the auction has ended.
     */
    modifier onlyAfterAuctionEnded() {
        require(auctionEnded, "Auction has not ended yet");
        _;
    }
    
    // FUNCTION: endAuction
    /**
     * @notice Finalizes the auction and emits an event.
     * @dev Can only be called if the auction duration has passed.
     */
    function endAuction() external auctionNotEnded {
        require(block.timestamp > endTime, "Auction is still active.");
        auctionEnded = true;
        emit AuctionEnded(highestBidder, highestBid);
    }
    
    // FUNCTION: getWinner
    /**
     * @notice Returns the highest bidder and the winning bid amount.
     * @return winner Address of the highest bidder.
     * @return amount Highest bid amount.
     */
    function getWinner() external view returns (address, uint) {
        require(auctionEnded, "Auction has not ended yet.");
        return (highestBidder, highestBid);
    }
    
    // FUNCTION: newBid
    /**
     * @notice Allows participants to place a bid; validates bid conditions and time constraints.
     * @dev The bid must be greater than zero and at least 5% higher than the current highest bid.
     *      If the bidder is new, their address is added to the bidders list.
     */
    function newBid() external payable onlyBeforeEnd auctionNotEnded { 
        require(msg.value > 0 && msg.value >= (highestBid * 105) / 100, "Invalid bid, check the amount");
    
        if (bids[msg.sender] == 0) {
            biddersList.push(msg.sender); // Add bidder if bidding for the first time.
        }
        
        bids[msg.sender] += msg.value;
        
        highestBidder = msg.sender;
        highestBid = msg.value;
        
        emit NewBid(msg.sender, msg.value);
    }
    
    // FUNCTION: getBids
    /**
     * @notice Provides information on all bids placed.
     * @return A tuple containing an array of bidder addresses and an array of their corresponding bid amounts.
     */
    function getBids() external view returns (address[] memory, uint[] memory) {
        uint totalBids = biddersList.length;
        
        address[] memory bidders = new address[](totalBids);
        uint[] memory amounts = new uint[](totalBids);
        // Optimization: Declare bidder outside the loop
        address bidder;
        for (uint i = 0; i < totalBids; i++) {
            bidder = biddersList[i];
            bidders[i] = bidder;
            amounts[i] = bids[bidder];
        }
        
        return (bidders, amounts);
    }
    
    // FUNCTION: partialRefund
    /**
     * @notice Allows non-winning bidders to withdraw their deposits.
     * @dev The highest bidder (winner) cannot withdraw excess funds.
     *      A 2% fee is deducted from the refund amount.
     */
    function partialRefund() external payable auctionNotEnded {
        uint amount = bids[msg.sender];
         require(msg.sender != highestBidder || bids[msg.sender] > highestBid, "Cannot withdraw last bid");
        bids[msg.sender] = 0; // Prevent reentrancy.
        uint refund = (amount * 98) / 100; // Deduct a 2% fee.
        payable(msg.sender).transfer(refund);
    }
    
    // FUNCTION: refundAllNonWinners
    /**
     * @notice Automatically refunds all non-winning bidders after the auction has ended.
     * @dev Iterates over the list of bidders and issues refunds (after deducting a 2% fee)
     *      to all bidders that are not the highest bidder.
     */
    function refundAllNonWinners() external onlyAfterAuctionEnded {
        uint totalBidders = biddersList.length;
        address bidder;     // Optimization: Declare bidder outside the loop
        for (uint i = 0; i < totalBidders; i++) {
            bidder = biddersList[i];
            
            if (bidder != highestBidder && bids[bidder] > 0) {
                uint refundAmount = (bids[bidder] * 98) / 100; // Apply 2% fee.
                bids[bidder] = 0; // Prevent reentrancy by zeroing out the deposit.
                payable(bidder).transfer(refundAmount);
                
                emit RefundIssued(bidder, refundAmount);
            }
        }
    }
}

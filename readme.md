
- Disclaimer:
As a student practice project, the author is not responsible for any malfunctions or unintended 
behavior. This is purely for experimentation and learning, so please test it thoroughly
in a safe, non-production environment (such as a local or test network).

- Educational Use Only:
The contract is provided for academic testing and learning purposes. 
It has not been audited or optimized for production use.


### Technical Detailed Explanation

#### **State Variables**

- **auctionEnded (bool)**  
  A public Boolean that indicates whether the auction has concluded.

- **owner (address)**  
  The private address of the contract creator, useful for owner-restricted functionality.

- **endTime (uint)**  
  A private variable storing the timestamp at which the auction ends. 
  It is determined once the contract is deployed (using the provided duration).

- **highestBid (uint)**  
  A public variable tracking the highest bid so far.

- **highestBidder (address)**  
  A private variable holding the address of the current highest bidder.

- **bids (mapping(address => uint))**  
  A private mapping to keep track of the deposit amounts from each bidder. 
  This serves as the record of each participant’s bid.

- **biddersList (address[])**  
  A dynamic array that stores the addresses of all the bidders. 
  It is used to iterate over the bidders when processing refunds.

- **struct Bid**  
  Although defined, the "Bid" struct is not actively used in this code but is available for 
  future enhancements that may require a structured bid record.

#### **Modifiers**

- **onlyBeforeEnd**  
  This modifier checks that the current block timestamp is less than "endTime". 
  Functions using this modifier (e.g., "newBid") can only be executed while the auction is still active.  
  _Usage_: Prevents bids after the auction deadline.

- **auctionNotEnded**  
  Ensures that the auction has not been finalized by checking that "auctionEnded" is false.  
  _Usage_: Guards functions such as "newBid", "partialRefund", and others that require the auction to be ongoing.

- **onlyAfterAuctionEnded**  
  Ensures that the function using this modifier can only be executed after the auction has ended (i.e., "auctionEnded" is true).  
  _Usage_: Ensures that functions intended to process post-auction logic 
  (like "refundAllNonWinners") are only called once the auction is complete.

#### **Functions**

- **Constructor**  
  The constructor takes a "_duration" parameter (in seconds) and:
  - Sets the "owner" to the deployer’s address.
  - Computes the "endTime" as the current block timestamp plus the provided duration.
  - Initializes "auctionEnded" to false, marking the auction as active.

- **endAuction**  
  This external function finalizes the auction. It:
  - Uses the "auctionNotEnded" modifier to ensure the auction has not already ended.
  - Requires that the current timestamp is greater than "endTime".
  - Sets "auctionEnded" to true.
  - Emits the "AuctionEnded" event with details of the highest bidder and the highest bid.
  _Technical Note_: This function must be called manually (or by a backend service) once the 
   auction duration has expired to trigger final settlement.

- **getWinner**  
  A view function that returns the winner’s address along with the winning bid amount. It:
  - Requires that the auction has already ended.
  - Returns a tuple containing "highestBidder" and "highestBid".
  _Technical Note_: This function provides read-only access to the final result of the auction.

- **newBid**  
  An external payable function for participating in the auction. It:
  - Uses both "onlyBeforeEnd" and "auctionNotEnded" modifiers to ensure it’s executed only during the active auction period.
  - Requires that the sent value ("msg.value") is greater than zero.
  - Checks that the new bid is at least 5% higher than the current "highestBid" (using the formula: "msg.value >= highestBid * 105 / 100").
  - Adds the bidder’s address to the "biddersList" if they are bidding for the first time.
  - Updates the bidder’s deposit, the overall "highestBid", and records the "highestBidder".
  - Emits the "NewBid" event.
  _Technical Note_: This function enforces bidding rules and maintains state integrity by updating the highest bid details.

- **getBids**  
  A view function that compiles and returns the list of all bidders along with their bid amounts.  
  _Technical Note_: It loops through the "biddersList" array, reads each bidder’s stored bid 
  from the "bids" mapping, and returns two parallel arrays (one for addresses and one for bid amounts).

- **partialRefund**  
  This function allows non-winning bidders to withdraw their deposits manually if they have not yet been refunded. It:
  - Ensures that the caller has a deposit and is not the highest bidder.
  - Uses a reentrancy-safe technique by setting the bidder's deposit to zero before transferring funds.
  - Applies a 2% fee to the refunded amount.
  - Transfers the resulting amount back to the caller.
  _Technical Note_: This function provides an option for participants to claim their funds 
  during the auction if, for example, they change their mind or want to recover their funds early.

- **refundAllNonWinners**  
  An external function callable only after the auction has ended. It:
  - Iterates over every address in the "biddersList".
  - For each bidder who is not the highest bidder and who still has a nonzero deposit, calculates
     the refund (with a 2% fee), resets their deposit to zero, and transfers the funds.
  - Emits a "RefundIssued" event for each refund processed.
  _Technical Note_: This function automates the refunding process post-auction, ensuring 
  that non-winning bidders receive their funds without needing to manually call a withdrawal function.

#### **Events**

- **NewBid**  
  Emitted every time a valid bid is placed. It provides transparency by logging the bidder’s address and the bid amount.

- **AuctionEnded**  
  Emitted when the auction is manually concluded via "endAuction()". It logs the winner’s address and the winning bid amount.  
  _Technical Note_: This is critical for off-chain systems that monitor auction status and help trigger subsequent actions (e.g., refund processing).

- **RefundIssued**  
  Emitted each time a refund is processed, either manually through "partialRefund" or 
  automatically via "refundAllNonWinners()". It logs the bidder’s address and the 
  refunded amount, ensuring traceability for all fund movements.

---


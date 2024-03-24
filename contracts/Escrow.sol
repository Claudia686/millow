//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

interface IERC721 {
    function transferFrom(
        address _from,
        address _to,
        uint256 _id
    ) external;
}

contract Escrow {
    address public nftAddress;
    address payable public seller;
    address public inspector;
    address public lender;

    modifier onlyBuyerAddress(address buyer) {
    require(msg.sender == buyer, "Only the buyer can call this function");
    _;
}

modifier onlyBuyer(uint256 _nftID) {
    require(msg.sender == buyer[_nftID], "Only buyer can call this method");
    _;
}

modifier onlySeller() {
    require(msg.sender == seller, "Only seller can call this method");
    _;
}

modifier onlyInspector() {
    require(msg.sender == inspector, "Only inspector can call this method");
    _;
}
    mapping(uint256 => bool) public isListed;
    mapping(uint256 => uint256) public purchasedPrice;
    mapping(uint256 => uint256) public escrowAmount;
    mapping(uint256 => address) public buyer;
    mapping(uint256 => bool) public inspectionPassed;
    mapping(uint256 => mapping(address => bool)) public approval;
    mapping(uint256 => string) public inspectionComments;
    mapping(uint256 => bool) public isInspected;
    mapping(address => uint256) public pendingWithdrawals;
    
   constructor(
        address _nftAddress, 
        address payable _seller, 
        address _inspector, 
        address _lender
        ) {

        nftAddress = _nftAddress;
        seller = _seller;
        inspector = _inspector;
        lender = _lender;
    }

    function list(
        uint256 _nftID, 
        address _buyer, 
        uint256 _purchasedPrice,
        uint256 _escrowAmount

         ) public payable onlySeller {
        // Transfer NFT from seller to this contract
        IERC721(nftAddress).transferFrom(msg.sender, address(this), _nftID);
       
        isListed[_nftID] = true;
        purchasedPrice[_nftID] = _purchasedPrice;
        escrowAmount[_nftID] = _escrowAmount;
        buyer[_nftID] = _buyer;
    }

    function markAsInspected(uint256 _nftID) public onlyBuyer(_nftID) {
        isInspected[_nftID] = true;
        emit NFTMarkedAsInspected(_nftID);
    }
    event NFTMarkedAsInspected(uint256 _nftID);

    function depositEarnest(uint256 _nftID) public payable onlyBuyer(_nftID) {
        require(msg.value >= escrowAmount[_nftID]);
    }

     function updateInspectionStatus(uint256 _nftID, bool _passed) 
         public 
         onlyInspector 
     {
        inspectionPassed[_nftID] = _passed;
     }

     function approveSale(uint256 _nftID) public {
        approval[_nftID][msg.sender] = true;
     }

    function getInspectionComments(uint256 _nftID, string memory _comments) public 
     onlyInspector {
        inspectionComments[_nftID]= _comments;
     }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function finalizeSale(uint256 _nftID) public {
        // NFT passed inspection
        require(inspectionPassed[_nftID], "Escrow: NFT inspection not passed");

        // Buyer approval required
        require(approval[_nftID][buyer[_nftID]], "Escrow: Buyer not approved");

        // Seller approval required
        require(approval[_nftID][seller], "Escrow: Seller not approved");

        // Lender approval required
        require(approval[_nftID][lender], "Escrow: Lender not approved");

        // Contract balance insufficient for purchase
        require(address(this).balance >= purchasedPrice[_nftID], "Escrow: Insufficient balance");

        // Transfer funds to the seller
        isListed[_nftID] = false;
          (bool success, ) = payable(seller).call{value: address(this).balance}(
            ""
        );
          require(success);

        IERC721(nftAddress).transferFrom(address(this), buyer[_nftID], _nftID);
    }

    function cancelSale(uint256 _nftID) public {
        if (inspectionPassed[_nftID] == false) {
            payable(buyer[_nftID]).transfer(address(this).balance);
        } else {
            payable(seller).transfer(address(this).balance);
        }
    }   
    // allows the contract to receive Ether
       receive() external payable {}

    function cancelListing(uint256 _nftID) public onlySeller {
        require(isListed[_nftID] == true, "Listing is not found");
         require(!inspectionPassed[_nftID], "Cannot cancel after inspection has passed");

        pendingWithdrawals[seller] += escrowAmount[_nftID]; 
        IERC721(nftAddress).transferFrom(address(this), seller, _nftID); // Inside the list function
    
         isListed[_nftID] = false;
         purchasedPrice[_nftID] = 0;
         escrowAmount[_nftID] = 0;
         buyer[_nftID] = address(0);
         inspectionPassed[_nftID] = false;
         approval[_nftID][buyer[_nftID]] = false;
         approval[_nftID][seller] = false;
         approval[_nftID][lender] = false;
    }

    function withdraw(uint256 _nftID) public onlySeller {
        uint256 amount = pendingWithdrawals[msg.sender];
        require(amount > 0, "No funds to withdraw");

        pendingWithdrawals[msg.sender] = 0;
        bool success = payable(msg.sender).send(amount);
        
    require(success, "Transfer failed");
    emit Withdrawal(msg.sender, amount);
  }     
     event Withdrawal(address indexed seller, uint256 amount);  
}


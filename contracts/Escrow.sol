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

     function updateInspectorStatus(uint256 _nftID, bool _passed) 
         public 
         onlyInspector 
     {
        inspectionPassed[_nftID] = _passed;

     }

     function approveSele(uint256 _nftID) public {
        approval[_nftID][msg.sender] = true;
     }

    receive() external payable {}

    function getInspectionComments(uint256 _nftID, string memory _comments) public 
     onlyInspector {
        inspectionComments[_nftID]= _comments;
     }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function fanalizedSale(uint256 _nftID) public {
        require(inspectionPassed[_nftID]);
        require(approval[_nftID][buyer[_nftID]]);
        require(approval[_nftID][seller]);
        require(approval[_nftID][lender]);
        require(address(this).balance >= purchasedPrice[_nftID]);
    }
}
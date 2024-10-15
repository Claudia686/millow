# Real Estate NFT DApp

## Technology Stack & Tools

- Solidity (Writing Smart Contracts & Tests)
- Javascript (React & Testing)
- [Hardhat](https://hardhat.org/) (Development Framework)
- [Ethers.js](https://docs.ethers.io/v5/) (Blockchain Interaction)
- [React.js](https://reactjs.org/) (Frontend Framework)

## Requirements For Initial Setup
- Install [NodeJS](https://nodejs.org/en/)

## Setting Up
### 1. Clone/Download the Repository

### 2. Install Dependencies:
`$ npm install`

### 3. Run tests
`$ npx hardhat test`

### 4. Start Hardhat node
`$ npx hardhat node`

### 5. Run deployment script
In a separate terminal execute:
`$ npx hardhat run ./scripts/deploy.js --network localhost`

### 7. Start frontend
`$ npm run start`

---

# Mishandling of ETH Vulnerability

## Contest Summary 
Date: April 20th 2024

## Results Summary
Number of findings:
High: 1
Medium: 0
Low: 0

## High Risk Findings
H-01. unauthorized withdrawals.

### Summary
The cancelSale function allows unauthorized ETH withdrawals due to the absence of a mechanism to track who deposited funds, potentially leading to loss of funds.

### Vulnerability Details:
The cancelSale and finalizeSale functions are critical to the sale process. The cancelSale function transfers the entire contract balance to either the buyer or seller based on inspection status, while the finalizeSale function completes the sale only if all approvals are met. However, the lack of tracking for deposited amounts leads to potential unauthorized withdrawals.

### POC
```solidity
function cancelSale(uint256 _nftID) public {
        if (inspectionPassed[_nftID] == false) {
            payable(buyer[_nftID]).transfer(address(this).balance);
        } else {
            payable(seller).transfer(address(this).balance);
        }
    }

function finalizeSale(uint256 _nftID) public {
        require(inspectionPassed[_nftID]);
        require(approval[_nftID][buyer[_nftID]]);
        require(approval[_nftID][seller]);
        require(approval[_nftID][lender]);
        require(address(this).balance >= purchasePrice[_nftID]);
        isListed[_nftID] = false;
        (bool success, ) = payable(seller).call{value: address(this).balance}(
            ""
        );
        require(success);
        IERC721(nftAddress).transferFrom(address(this), buyer[_nftID], _nftID);
    }
```
### Impact
Scenario 1:
Buyer 1 deposited 1 ETH for NFT 1, while Buyer 2 did not deposit for NFT 2.
Scenario 2:
Buyer 2 exploited a vulnerability to cancel the sale, risking theft from Buyer 1.

### Tools Used
### Sublime Text, Hardhat

### Recommendations  
 Add a new mapping: 
``` solidity

mapping(address => uint256) public deposited;

function finalizeSale(uint256 _nftID) public {
        uint256 escrowAmount = escrowAmount[_nftID];
        address buyerAddress = buyer[_nftID];
        uint256 depositedAmount = deposited[buyerAddress];
        
        // Ensure buyer has enough funds deposited
        require(deposited[buyerAddress] >= escrowAmount, "Escrow: Insufficient deposited funds");

        // NFT passed inspection
        require(inspectionPassed[_nftID], "Escrow: NFT inspection not passed");

        // Buyer approval required
        require(approval[_nftID][buyer[_nftID]], "Escrow: Buyer not approved");

        // Seller approval required
        require(approval[_nftID][seller], "Escrow: Seller not approved");

        // Lender approval required
        require(approval[_nftID][lender], "Escrow: Lender not approved");

        // Contract balance insufficient for purchase
        require(address(this).balance >= escrowAmount, "Escrow: Insufficient balance");

        // Transfer funds to the seller
        isListed[_nftID] = false;
          (bool success, ) = payable(seller).call{value: address(this).balance}(
            ""
        );
        require(success);

          // Reset deposited amount
        deposited[buyerAddress] = 0;

        // Transfer the NFT ownership to the buyer
        IERC721(nftAddress).transferFrom(address(this), buyerAddress, _nftID);
    }


function cancelSale(address _buyer, uint256 _nftID) public {    
        uint256 refundAmount = deposited[_buyer];
        require(refundAmount > 0, "Escrow: No deposited amount to finalize the sale");
        deposited[_buyer] = 0;

        if (inspectionPassed[_nftID] == false) {
            payable(buyer[_nftID]).transfer(refundAmount);
        } else {
            payable(seller).transfer(refundAmount);
        }
    } 
```





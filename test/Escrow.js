const {
    expect
} = require('chai');
const {
    ethers
} = require('hardhat');

const tokens = (n) => {
    return ethers.utils.parseUnits(n.toString(), 'ether')
}

describe('Escrow', () => {
    let buyer, seller, inspector, lender, hacker
    let realEstate, escrow

    beforeEach(async () => {
        [buyer, seller, inspector, lender, hacker] = await ethers.getSigners()

        const RealEstate = await ethers.getContractFactory("RealEstate")
        realEstate = await RealEstate.deploy()

        let transaction = await realEstate.connect(seller).mint("https://ipfs.io/ipfs/QmTudSYeM7mz3PkYEWXWqPjomRPHogcMFSq7XAvsvsgAPS")
        await transaction.wait()

        const Escrow = await ethers.getContractFactory("Escrow")
        escrow = await Escrow.deploy(
            realEstate.address,
            seller.address,
            inspector.address,
            lender.address
        )

        transaction = await realEstate.connect(seller).approve(escrow.address, 1)
        await transaction.wait()

        transaction = await escrow.connect(seller).list(1, buyer.address, tokens(10), tokens(5))
        await transaction.wait()
    })

    describe("Deployment", () => {
        it("Returns NFT address", async () => {
            const result = await escrow.nftAddress()
            expect(result).to.be.equal(realEstate.address)
        })

        it("Returns seller address", async () => {
            const result = await escrow.seller()
            expect(result).to.be.equal(seller.address)
        })

        it("Returns inspector address", async () => {
            const result = await escrow.inspector()
            expect(result).to.be.equal(inspector.address)
        })

        it("Returns lender address", async () => {
            const result = await escrow.lender()
            expect(result).to.be.equal(lender.address)
        })
    })

    describe("Listing", () => {
        it("Updates as listed", async () => {
            const result = await escrow.isListed(1)
            expect(result).to.equal(true)
        })

        it("Updates ownership", async () => {
            expect(await realEstate.ownerOf(1)).to.be.equal(escrow.address)
        })

        it("Returns buyer", async () => {
            const result = await escrow.buyer(1)
            expect(result).to.be.equal(buyer.address)
        })

        it("Returns purchased price", async () => {
            const result = await escrow.purchasedPrice(1)
            expect(result).to.be.equal(tokens(10))
        })

        it("Returns escrow amount", async () => {
            const result = await escrow.escrowAmount(1)
            expect(result).to.be.equal(tokens(5))
        })
    })

    describe(" Cancel Listing", () => {
        describe("Success", async () => {
            it("Cancels listing and updates state", async () => {
                const nftId = 1;
                const transaction = await escrow.connect(seller).cancelListing(nftId)
                await transaction.wait()

                expect(await escrow.isListed(nftId)).to.equal(false);
                expect(await realEstate.ownerOf(nftId)).to.equal(seller.address)
                expect(await escrow.purchasedPrice(nftId)).to.equal(0)
                expect(await escrow.escrowAmount(nftId)).to.equal(0)
                expect(await escrow.buyer(nftId)).to.equal("0x0000000000000000000000000000000000000000")
                expect(await escrow.inspectionPassed(nftId)).to.equal(false);
                expect(await escrow.approval(nftId, buyer.address)).to.equal(false);
                expect(await escrow.approval(nftId, seller.address)).to.equal(false);
                expect(await escrow.approval(nftId, lender.address)).to.equal(false);
                expect(await realEstate.ownerOf(nftId)).to.equal(seller.address)
            })

            it("Cancels unlisted NFT without affecting state", async () => {
                const listedNFTId = 1
                expect(await escrow.isListed(listedNFTId)).to.equal(true)

                const transaction = await escrow.connect(seller).cancelListing(listedNFTId)
                await transaction.wait()
                expect(await escrow.isListed(listedNFTId)).to.equal(false)
            })
        })
    })

    describe("Marked as Inspected", () => {
        describe("Success", async () => {
            it("Should mark NFT as inspected by the buyer", async () => {
                await escrow.connect(buyer).markAsInspected(1)
                expect(await escrow.isInspected(1)).to.be.true
            })
        })

        describe("Failure", () => {
            it("Should revert if not called by the buyer", async () => {
                await expect(escrow.connect(inspector).markAsInspected(1)).to.be.reverted
            })

            it("Should revert if if the NFT is not listed", async () => {
                await expect(escrow.connect(inspector).markAsInspected(2)).to.be.reverted
            })

            it("Should revert if the NFT is not owned by the buyer", async () => {
                await expect(escrow.connect(inspector).markAsInspected(1)).to.be.reverted
            })
        })
    })

    describe("Deposits", () => {
        it("Updates contract balance", async () => {
            const transaction = await escrow.connect(buyer).depositEarnest(1, {
                value: tokens(5)
            })
            await transaction.wait()

            const result = await escrow.getBalance()
            expect(result).to.be.equal(tokens(5))
        })
    })

    describe("Inspection", () => {
        it("Updates inspection status", async () => {
            const transaction = await escrow.connect(inspector).updateInspectorStatus(1, true)
            await transaction.wait()
            const result = await escrow.inspectionPassed(1)
            expect(result).to.be.equal(true)
        })

        describe("Inspection comments", () => {
            describe("Success", async () => {
                it("Should set inspection comments successfully", async () => {
                    const nftId = 1;
                    const comments = 'Successful inspection comments';

                    await escrow.connect(inspector).getInspectionComments(nftId, comments)
                    expect(await escrow.inspectionComments(nftId)).to.equal(comments)
                })

                it("Should set inspection comments for another NFT", async () => {
                    const nftId = 2;
                    const comments = 'Another inspection comments';

                    await escrow.connect(inspector).getInspectionComments(nftId, comments)
                    expect(await escrow.inspectionComments(nftId)).to.equal(comments)
                })
                it("Should allow setting comments for multiple NFTs", async () => {
                    const nftId = [3, 4, 5];
                    const comments = 'Successful inspection comments';

                    await escrow.connect(inspector).getInspectionComments(nftId, comments)
                    expect(await escrow.inspectionComments(nftId)).to.equal(comments)
                })
            })
        })

        describe("Failure", async () => {
            it("Should fail when not called by the inspector", async () => {
                const nftId = 1;
                const comments = 'Failed inspection comments';
                expect(await escrow.connect(inspector).getInspectionComments(nftId, comments)).to.be.reverted
            })
        })

        describe("Approval", () => {
            it("Updates approval status", async () => {
                let transaction = await escrow.connect(buyer).approveSele(1)
                await transaction.wait()

                transaction = await escrow.connect(seller).approveSele(1)
                await transaction.wait()

                transaction = await escrow.connect(lender).approveSele(1)
                await transaction.wait()

                expect(await escrow.approval(1, buyer.address)).to.be.equal(true)
                expect(await escrow.approval(1, seller.address)).to.be.equal(true)
                expect(await escrow.approval(1, lender.address)).to.be.equal(true)
            })
        })

        describe("Sale", () => {
            beforeEach(async () => {
                let transaction = await escrow.connect(buyer).depositEarnest(1, {
                    value: tokens(5)
                })
                await transaction.wait()

                transaction = await escrow.connect(inspector).updateInspectorStatus(1, true)
                await transaction.wait()

                transaction = await escrow.connect(buyer).approveSele(1)
                await transaction.wait()

                it('Updates balance', async () => {
                    expect(await escrow.getBalance()).to.be.equal(0)
                })
            })
        })
    })
})
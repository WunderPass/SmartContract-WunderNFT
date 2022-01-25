const chai = require('chai');
const assertArrays = require('chai-arrays');
chai.use(assertArrays);
const expect = chai.expect;

const fs = require('fs');
const names = ["Berlin", "Düsseldorf", "London", "Oxford", "NewYork", "LosAngeles", "Shanghai", "Peking", "Deutschland", "England", "USA", "China", "Europa", "Nordamerika", "Asien", "Welt"]
const parents = ["Deutschland", "Deutschland", "England", "England", "USA", "USA", "China", "China", "Europa", "Europa", "Nordamerika", "Asien", "Welt", "Welt", "Welt", "Welt"]

function wunderPassToJson(wunderpass) {
  const [owner, tokenId, status, edition, wonder, pattern] = wunderpass;
  return {
    owner,
    tokenId,
    status,
    edition,
    wonder,
    pattern
  }
}

describe('WUNDER NFT CONTRACT', () => {
  let WunderNft, contract, owner, user1, user2;

  beforeEach(async () => {
    WunderNft = await ethers.getContractFactory('WunderNFT');
    contract = await WunderNft.deploy(names, parents);

    [owner, user1, user2, _] = await ethers.getSigners();
  });

  describe('Deployment', () => {
    it('Should set all Editions with counter of 0', async () => {
      names.forEach(async (name) => {
        expect(await contract.getCounter(name)).to.equal(0);
      })
    });
  });

  describe('Roles', () => {
    it('Should give the owner OWNER_ROLE and ADMIN_ROLE', async () => {
      expect(await contract.isOwner()).to.equal(true);
      expect(await contract.isAdmin()).to.equal(true);
    })
    
    it('Should give anyone else no special roles', async () => {
      expect(await contract.connect(user1).isOwner()).to.equal(false);
      expect(await contract.connect(user1).isAdmin()).to.equal(false);
    })
      
    it('Should allow the owner to set Price and threshold', async () => {
      await contract.setEditionThreshold(20);
      expect(await contract.editionThreshold()).to.equal(20);
  
      await contract.setPublicPrice(2);
      expect(await contract.publicPrice()).to.equal(2000000000000000);
    })

    it('Should not allow anyone else to set Price and threshold', async () => {
      await expect(contract.connect(user1).setEditionThreshold(20)).to.be.reverted;
      await expect(contract.connect(user1).setPublicPrice(20)).to.be.reverted;
    })

    it('Should let the owner determine a new owner', async () => {
      await contract.connect(owner).changeOwner(user1.address);

      await expect(contract.setEditionThreshold(20)).to.be.reverted;
      expect(await contract.editionThreshold()).to.equal(10);

      await contract.connect(user1).setEditionThreshold(20);
      expect(await contract.editionThreshold()).to.equal(20);
    })

    it('Should let the owner set a new admin', async () => {
      await contract.connect(owner).addAdmin(user1.address);
      // Should not revert when user1 mints
      await expect(contract.connect(user1).mintTest('Berlin', owner.address)).to.not.be.reverted;
    })

    it('Should let the owner remove an admin', async () => {
      await contract.connect(owner).addAdmin(user1.address);
      // Should not revert when user1 mints
      await expect(contract.connect(user1).mintTest('Berlin', owner.address)).to.not.be.reverted;

      await contract.connect(owner).removeAdmin(user1.address);
      // Should revert when user1 mints
      await expect(contract.connect(user1).mintTest('Berlin', owner.address)).to.be.reverted;
    })
  });

  describe('Mint for User', () => {
    it('Should mint an NFT for a user and increase editions counter', async () => {
      await contract.mintTest('Berlin', user1.address)
      expect(await contract.getCounter('Berlin')).to.equal(1);
    });
    
    it('Should emit the WunderPassMinted event', async () => {
      const tx = await contract.mintTest('Berlin', user1.address);
      await expect(tx).to.emit(contract, 'WunderPassMinted');
    });

    it('Should increment tokenId', async () => {
      await contract.mintTest('Berlin', user1.address)
      expect(await contract.currentTokenId()).to.equal(1)
      
      await contract.mintTest('Berlin', user2.address)
      expect(await contract.currentTokenId()).to.equal(2)
    });
    
    it('Should give the correct edition', async () => {
      await contract.setEditionThreshold(1);
      await contract.mintTest('Berlin', user1.address)
      expect(wunderPassToJson(await contract.getWunderPass(0)).edition).to.equal('Berlin')
      
      for(var i = 1; i < 11; i++) {
        await contract.mintTest('Berlin', user1.address)
        expect(wunderPassToJson(await contract.getWunderPass(i)).edition).to.equal('Deutschland')
      }

      for(var i = 11; i < 111; i++) {
        await contract.mintTest('Berlin', user1.address)
        expect(wunderPassToJson(await contract.getWunderPass(i)).edition).to.equal('Europa')
      }

      for(var i = 111; i < 115; i++) {
        await contract.mintTest('Berlin', user1.address)
        expect(wunderPassToJson(await contract.getWunderPass(i)).edition).to.equal('Welt')
      }

      await contract.mintTest('Deutschland', user1.address)
      expect(wunderPassToJson(await contract.getWunderPass(115)).edition).to.equal('Welt')

      await contract.mintTest('Europa', user1.address)
      expect(wunderPassToJson(await contract.getWunderPass(116)).edition).to.equal('Welt')

      await contract.mintTest('Welt', user1.address)
      expect(wunderPassToJson(await contract.getWunderPass(117)).edition).to.equal('Welt')
    });
    
    it('Should pause the contract when a new status begins', async () => {
      for(var i = 0; i < 200; i++) {
        await contract.mintTest('Berlin', user1.address);
      }
      await expect(contract.mintTest('Berlin', user1.address)).to.be.revertedWith('Minting is currently paused. The next drop is coming soon!')
    });

    it('Should let the owner pause minting at any time', async () => {
      await expect(contract.mintTest('Berlin', user1.address)).to.not.be.reverted
      await contract.pauseMinting();
      await expect(contract.mintTest('Berlin', user1.address)).to.be.revertedWith('Minting is currently paused. The next drop is coming soon!')
      await contract.activateMinting();
      await expect(contract.mintTest('Berlin', user1.address)).to.not.be.reverted
    });

    it('Should give the correct status', async () => {
      for(var i = 0; i < 200; i++) {
        await contract.mintTest('Berlin', user1.address);
      }

      await contract.activateMinting();
      await contract.mintTest('Berlin', user1.address)
      expect(wunderPassToJson(await contract.getWunderPass(200)).status).to.equal('Black')
    });
  });

  describe('Token Transfers', () => {
    it("Owner of a token should be able to transfer", async () => {
      await contract.mintTest('Berlin', user1.address);
      await expect(contract.connect(user1).transferFrom(user1.address, user2.address, 0)).to.not.be.reverted;
      await expect(contract.connect(user2).transferFrom(user2.address, user1.address, 0)).to.not.be.reverted;
    })

    it("Only the owner of a token should be able to transfer", async () => {
      await contract.mintTest('Berlin', user1.address);
      await expect(contract.connect(user2).transferFrom(user1.address, user2.address, 0)).to.be.revertedWith('ERC721: transfer caller is not owner nor approved');
      await expect(contract.connect(user2).transferFrom(user2.address, user1.address, 0)).to.be.revertedWith('ERC721: transfer caller is not owner nor approved');
    })
  })

  describe('Token Stats', () => {
    it('Should return all tokenIds of a user', async () => {
      expect(await contract.tokensOfAddress(user1.address)).to.be.ofSize(0);
      
      await contract.mintTest('Berlin', user1.address);
      expect((await contract.tokensOfAddress(user1.address)).map(num => Number(num))).to.be.equalTo([0]);
      
      await contract.mintTest('Berlin', user1.address);
      expect((await contract.tokensOfAddress(user1.address)).map(num => Number(num))).to.be.equalTo([1, 0]);
      
      await contract.mintTest('Berlin', user2.address);
      await contract.mintTest('Berlin', user1.address);
      expect((await contract.tokensOfAddress(user1.address)).map(num => Number(num))).to.be.equalTo([3, 1, 0]);
    })

    it('Should determine the best status of a user', async () => {
      for(var i = 0; i < 200; i++) {
        await contract.mintTest('Berlin', user1.address);
      }
      expect(await contract.bestStatusOf(user1.address)).to.equal('Diamond');
      await contract.activateMinting();

      await contract.mintTest('Berlin', user2.address);
      expect(await contract.bestStatusOf(user2.address)).to.equal('Black');

      await contract.mintTest('Berlin', user1.address);
      expect(await contract.bestStatusOf(user1.address)).to.equal('Diamond');

      await contract.connect(user1).transferFrom(user1.address, user2.address, 0);
      expect(await contract.bestStatusOf(user2.address)).to.equal('Diamond');
    })

    it('Should determine the best wonder of a user', async () => {
      let wonders = ["Pyramids of Giza", "Great Wall of China", "Petra", "Colosseum", "Chichen Itza", "Machu Picchu", "Taj Mahal", "Christ the Redeemer"];
      let bestWonder;
      let wonder;

      for(var i = 0; i < 100; i++) {
        await contract.mintTest('Berlin', user1.address);
        wonder = wunderPassToJson(await contract.getWunderPass(i)).wonder;
        bestWonder = await contract.bestWonderOf(user1.address)
        expect(wonders.indexOf(bestWonder) <= wonders.indexOf(wonder)).to.equal(true)
      }
    })
  })

});
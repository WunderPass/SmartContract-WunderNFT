const chai = require('chai');
const assertArrays = require('chai-arrays');
chai.use(assertArrays);
const expect = chai.expect;

const fs = require('fs');
const names = ['Berlin // DE // EU', 'Germany // EU', 'Europe', 'New York // US // NA', 'United States // NA', 'North America', 'World'];
const parents = ['Germany // EU', 'Europe', 'World', 'United States // NA', 'North America', 'World', 'World'];

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
  let WunderPass, contract, owner, user1, user2;

  beforeEach(async () => {
    WunderPass = await ethers.getContractFactory('WunderPass');
    contract = await WunderPass.deploy();
    await contract.extendEditions(names, parents);

    [owner, user1, user2, _] = await ethers.getSigners();
  });

  describe('Deployment', () => {
    it('Should set all Editions with counter of 0', async () => {
      names.forEach(async (name) => {
        expect(await contract.getCounter(name)).to.equal(0);
      })
    });

    it('New editions should not reset the old ones', async () => {
      const testNames = ['TEST', 'FOO', 'BAR'];
      const testParents = ['FOO', 'BAR', 'BAR'];
      await contract.extendEditions(testNames, testParents)
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
  
      await contract.setPublicPrice(2, 0);
      expect(await contract.publicPrice()).to.equal(2);
    })

    it('Should not allow anyone else to set Price and threshold', async () => {
      await expect(contract.connect(user1).setEditionThreshold(20)).to.be.reverted;
      await expect(contract.connect(user1).setPublicPrice(20)).to.be.reverted;
    })

    it('Should let the owner determine a new owner', async () => {
      await contract.connect(owner).changeOwner(user1.address);

      await expect(contract.setEditionThreshold(20)).to.be.reverted;
      expect(await contract.editionThreshold()).to.equal(100);

      await contract.connect(user1).setEditionThreshold(20);
      expect(await contract.editionThreshold()).to.equal(20);
    })

    it('Should let the owner set a new admin', async () => {
      await contract.connect(owner).addAdmin(user1.address);
      // Should not revert when user1 mints
      await expect(contract.connect(user1).mintTest('Berlin // DE // EU', owner.address)).to.not.be.reverted;
    })

    it('Should let the owner remove an admin', async () => {
      await contract.connect(owner).addAdmin(user1.address);
      // Should not revert when user1 mints
      await expect(contract.connect(user1).mintTest('Berlin // DE // EU', owner.address)).to.not.be.reverted;

      await contract.connect(owner).removeAdmin(user1.address);
      // Should revert when user1 mints
      await expect(contract.connect(user1).mintTest('Berlin // DE // EU', owner.address)).to.be.reverted;
    })
  });

  describe('Mint for User', () => {
    it('Should mint an NFT for a user and increase editions counter', async () => {
      await contract.mintTest('Berlin // DE // EU', user1.address)
      expect(await contract.getCounter('Berlin // DE // EU')).to.equal(1);
    });
    
    it('Should emit the WunderPassMinted event', async () => {
      const tx = await contract.mintTest('Berlin // DE // EU', user1.address);
      await expect(tx).to.emit(contract, 'WunderPassMinted');
    });

    it('Should increment tokenId', async () => {
      await contract.mintTest('Berlin // DE // EU', user1.address)
      expect(await contract.currentTokenId()).to.equal(1)
      
      await contract.mintTest('Berlin // DE // EU', user2.address)
      expect(await contract.currentTokenId()).to.equal(2)
    });

    it('Should pause the contract when a new status begins', async () => {
      for(var i = 0; i < 200; i++) {
        await contract.mintTest('Berlin // DE // EU', user1.address);
      }
      await expect(contract.mintTest('Berlin // DE // EU', user1.address)).to.be.revertedWith('Pausable: paused')
    });

    it('Should let the owner pause minting at any time', async () => {
      await expect(contract.mintTest('Berlin // DE // EU', user1.address)).to.not.be.reverted
      await contract.pause();
      await expect(contract.mintTest('Berlin // DE // EU', user1.address)).to.be.revertedWith('Pausable: paused')
      await contract.unpause();
      await expect(contract.mintTest('Berlin // DE // EU', user1.address)).to.not.be.reverted
    });
  });

  describe('Determine Correct Properties', () => {
    it('Should give the correct edition', async () => {
      await contract.setEditionThreshold(1);
      await contract.mintTest('Berlin // DE // EU', user1.address)
      expect(wunderPassToJson(await contract.getWunderPass(0)).edition).to.equal('Berlin // DE // EU')
      
      for(var i = 1; i < 101; i++) {
        await contract.mintTest('Berlin // DE // EU', user1.address)
        expect(wunderPassToJson(await contract.getWunderPass(i)).edition).to.equal('Germany // EU')
      }

      for(var i = 101; i < 102; i++) {
        await contract.mintTest('Berlin // DE // EU', user1.address)
        expect(wunderPassToJson(await contract.getWunderPass(i)).edition).to.equal('Europe')
      }
    });

    it('Every edition should work', async () => {
      for(var i = 0; i < names.length; i++) {
        if (i == 200 || i == 1800) {
          await contract.unpause();
        }
        await contract.mintTest(names[i], user1.address)
        expect(wunderPassToJson(await contract.getWunderPass(i)).edition).to.equal(names[i])
      }
    });

    it('Should give the correct status', async () => {
      for(var i = 0; i < 200; i++) {
        await contract.mintTest('Berlin // DE // EU', user1.address);
      }

      await contract.unpause();
      await contract.mintTest('Berlin // DE // EU', user1.address)
      expect(wunderPassToJson(await contract.getWunderPass(200)).status).to.equal('Black')
    });

    it('Should determine wonders based on the correct distribution', async () => {
      const wonders = {"Pyramids of Giza": 0, "Great Wall of China": 0, "Petra": 0, "Colosseum": 0, "Chichen Itza": 0, "Machu Picchu": 0, "Taj Mahal": 0, "Christ the Redeemer": 0};
      
      for(var i = 0; i < 256; i++) {
        i == 200 && await contract.unpause();
        await contract.mintTest('Berlin // DE // EU', user1.address);
        wonders[wunderPassToJson(await contract.getWunderPass(i)).wonder] += 1;
      }
      expect(wonders["Pyramids of Giza"]).to.equal(1)
      expect(wonders["Great Wall of China"]).to.equal(2)
      expect(wonders["Petra"]).to.equal(4)
      expect(wonders["Colosseum"]).to.equal(8)
      expect(wonders["Chichen Itza"]).to.equal(16)
      expect(wonders["Machu Picchu"]).to.equal(32)
      expect(wonders["Taj Mahal"]).to.equal(64)
      expect(wonders["Christ the Redeemer"]).to.equal(129)
    });
  });

  describe('Token Transfers', () => {
    it("Owner of a token should be able to transfer", async () => {
      await contract.mintTest('Berlin // DE // EU', user1.address);
      await expect(contract.connect(user1).transferFrom(user1.address, user2.address, 0)).to.not.be.reverted;
      await expect(contract.connect(user2).transferFrom(user2.address, user1.address, 0)).to.not.be.reverted;
    })

    it("Only the owner of a token should be able to transfer", async () => {
      await contract.mintTest('Berlin // DE // EU', user1.address);
      await expect(contract.connect(user2).transferFrom(user1.address, user2.address, 0)).to.be.revertedWith('ERC721: transfer caller is not owner nor approved');
      await expect(contract.connect(user2).transferFrom(user2.address, user1.address, 0)).to.be.revertedWith('ERC721: transfer caller is not owner nor approved');
    })
  })

  describe('Token Stats', () => {
    it('Should return all tokenIds of a user', async () => {
      expect(await contract.tokensOfAddress(user1.address)).to.be.ofSize(0);
      
      await contract.mintTest('Berlin // DE // EU', user1.address);
      expect((await contract.tokensOfAddress(user1.address)).map(num => Number(num))).to.be.equalTo([0]);
      
      await contract.mintTest('Berlin // DE // EU', user1.address);
      expect((await contract.tokensOfAddress(user1.address)).map(num => Number(num))).to.be.equalTo([0, 1]);
      
      await contract.mintTest('Berlin // DE // EU', user2.address);
      await contract.mintTest('Berlin // DE // EU', user1.address);
      expect((await contract.tokensOfAddress(user1.address)).map(num => Number(num))).to.be.equalTo([0, 1, 3]);
      
      await contract.connect(user1).transferFrom(user1.address, user2.address, 1);
      expect((await contract.tokensOfAddress(user1.address)).map(num => Number(num))).to.be.equalTo([0, 3]);
    })

    // it('tokensOfAddress should work for an unlimited number of NFTs', async () => {
    //   const mintCount = 1000000;
    //   let startTimeOne;
    //   let startTimeTwo;
    //   let endTimeOne;
    //   let endTimeTwo;
    //   console.clear();
    //   console.log('Minted | Time (User1) | Time (User2)')
    //   for(var i = 0; i < mintCount; i++) {
    //     i == 200 && await contract.unpause();
    //     i == 1800 && await contract.unpause();
    //     i == 14600 && await contract.unpause();
    //     i == 117000 && await contract.unpause();
    //     i == 936200 && await contract.unpause();
    //     i == 7489800 && await contract.unpause();
    //     i == 59918600 && await contract.unpause();
    //     i == 479349000 && await contract.unpause();
    //     i == 3834792200 && await contract.unpause();
    //     await contract.mintTest('Berlin // DE // EU', user1.address);
    //     if (i % 100 == 0) {
    //       startTimeOne = new Date();
    //       await contract.tokensOfAddress(user1.address)
    //       endTimeOne = new Date();
    //       startTimeTwo = new Date();
    //       await contract.tokensOfAddress(user2.address)
    //       endTimeTwo = new Date();
    //       console.log(i, `${endTimeOne - startTimeOne}ms`, `${endTimeTwo - startTimeTwo}ms`)
    //     }
    //   }
    //   expect(await contract.tokensOfAddress(user1.address)).to.be.ofSize(mintCount);
    // })

    it('Should determine the best status of a user', async () => {
      for(var i = 0; i < 200; i++) {
        await contract.mintTest('Berlin // DE // EU', user1.address);
      }
      expect(await contract.bestStatusOf(user1.address)).to.equal('Diamond');
      await contract.unpause();

      await contract.mintTest('Berlin // DE // EU', user2.address);
      expect(await contract.bestStatusOf(user2.address)).to.equal('Black');

      await contract.mintTest('Berlin // DE // EU', user1.address);
      expect(await contract.bestStatusOf(user1.address)).to.equal('Diamond');

      await contract.connect(user1).transferFrom(user1.address, user2.address, 0);
      expect(await contract.bestStatusOf(user2.address)).to.equal('Diamond');
    })

    it('Should determine the best wonder of a user', async () => {
      let wonders = ["Pyramids of Giza", "Great Wall of China", "Petra", "Colosseum", "Chichen Itza", "Machu Picchu", "Taj Mahal", "Christ the Redeemer"];
      let bestWonder;
      let wonder;

      for(var i = 0; i < 100; i++) {
        await contract.mintTest('Berlin // DE // EU', user1.address);
        wonder = wunderPassToJson(await contract.getWunderPass(i)).wonder;
        bestWonder = await contract.bestWonderOf(user1.address)
        expect(wonders.indexOf(bestWonder) <= wonders.indexOf(wonder)).to.equal(true)
      }
    })
  })
});
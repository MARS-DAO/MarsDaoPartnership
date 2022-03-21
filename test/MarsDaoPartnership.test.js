const { time } = require('@openzeppelin/test-helpers');
const MarsDaoPartnership = artifacts.require('MarsDaoPartnership');
const MockERC20 = artifacts.require('MockERC20');


contract('MarsDaoPartnership', ([alice, bob, carol, scot,developer]) => {


    before(async () => {
        this.mars = await MockERC20.new('Mars', 'Mars', web3.utils.toWei("15000000", "ether"), { from: alice });
        this.reward = await MockERC20.new('REWARD', 'REW', web3.utils.toWei("15000000", "ether"), { from: alice });
        this.marsDaoPartnership = await MarsDaoPartnership.new({ from: alice });

        await this.mars.transfer(bob,100,{ from: alice });
        await this.mars.transfer(carol,100,{ from: alice });
        await this.mars.transfer(scot,100,{ from: alice }); 
        await this.mars.approve(this.marsDaoPartnership.address, 100, { from: bob });
        await this.mars.approve(this.marsDaoPartnership.address, 100, { from: carol });
        await this.mars.approve(this.marsDaoPartnership.address, 100, { from: scot });
    });

    it('addPool', async () => {
        await this.marsDaoPartnership.addPool(10,this.reward.address,this.mars.address,0,0,0,0,{ from: alice });
        //console.log((await time.latest ()).toString(10));
        await this.marsDaoPartnership.addPool(100,this.reward.address,this.mars.address,0,0,0,0,{ from: alice });
        //console.log((await time.latest ()).toString(10));
        this.vault0=(await this.marsDaoPartnership.poolInfo(0)).rewardsVaultAddress;
        this.vault1=(await this.marsDaoPartnership.poolInfo(1)).rewardsVaultAddress;
        await this.reward.transfer(this.vault0,1000,{ from: alice });
        await this.reward.transfer(this.vault1,1000,{ from: alice });
    });  


    it('deposit', async () => {
        //console.log((await time.latest ()).toString(10));
        await this.marsDaoPartnership.deposit(0,50,{ from: bob });
        await this.marsDaoPartnership.deposit(1,50,{ from: bob });
        await time.advanceBlock();
        //console.log((await time.latest ()).toString(10));
        await this.marsDaoPartnership.deposit(0,50,{ from: carol });
        await this.marsDaoPartnership.deposit(1,50,{ from: carol });
        await time.advanceBlock();
    });   

    it('harvest', async () => {
        //console.log((await time.latest ()).toString(10));
        await this.marsDaoPartnership.deposit(0,0,{ from: bob });
        await this.marsDaoPartnership.deposit(0,0,{ from: carol });
        expect((await this.reward.balanceOf(bob)).toString(10)).to.eq('45');
        expect((await this.reward.balanceOf(carol)).toString(10)).to.eq('20');
        //console.log((await time.latest ()).toString(10));
        await this.marsDaoPartnership.deposit(1,0,{ from: bob });
        await this.marsDaoPartnership.deposit(1,0,{ from: carol });
        expect((await this.reward.balanceOf(bob)).toString(10)).to.eq('545');
        expect((await this.reward.balanceOf(carol)).toString(10)).to.eq('270');
    });

    it('withdraw', async () => {
        await this.marsDaoPartnership.withdraw(0,50,{ from: bob });
        await this.marsDaoPartnership.withdraw(0,50,{ from: carol });
        await this.marsDaoPartnership.withdraw(1,50,{ from: bob });
        await this.marsDaoPartnership.withdraw(1,50,{ from: carol });
    });

});
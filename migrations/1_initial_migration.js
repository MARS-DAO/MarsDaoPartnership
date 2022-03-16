const MarsDaoPartnership = artifacts.require("MarsDaoPartnership");

module.exports = async (deployer, network) => {
  
  try{
    deployer.deploy(MarsDaoPartnership);
  }catch(err){
    console.log("ERROR:",err);
  }
};

// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "./lib/IERC20.sol";
import "./lib/SafeERC20.sol";
import "./lib/Ownable.sol";


contract Vault is Ownable{
    using SafeERC20 for IERC20;
    
    IERC20 immutable public rewardToken;

    constructor(address _rewardToken) public {
        rewardToken=IERC20(_rewardToken);
    }

    function safeRewardsTransfer(address _to, uint256 _amount) 
            external 
            onlyOwner returns(uint256){
        uint256 rewardTokenBalance = rewardToken.balanceOf(address(this));
        
        if(rewardTokenBalance>0){
            if (_amount > rewardTokenBalance) {
                _amount=rewardTokenBalance;
            }
            rewardToken.safeTransfer(_to, _amount);
            return _amount;
        }
        
        return 0;
    }

}

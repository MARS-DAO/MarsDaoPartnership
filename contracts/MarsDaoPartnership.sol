// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "./lib/SafeMath.sol";
import "./lib/IERC20.sol";
import "./lib/SafeERC20.sol";
import "./lib/ReentrancyGuard.sol";
import "./Vault.sol";
import "./lib/Ownable.sol";


contract MarsDaoPartnership is ReentrancyGuard,Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;


    struct UserInfo {
        uint256 depositedAmount;
        uint256 lastHarvestedBlock;
        uint256 pendingAmount;
        uint256 rewardDebt;
    }

    struct PoolInfo {
        uint256 rewardPerBlockAmount;
        address rewardTokenAddress;
        address rewardsVaultAddress;
        address depositedTokenAddress;
        uint256 totalDepositedAmount;
        uint256 lastRewardBlock;
        uint256 harvestAvailableBlock;
        uint256 harvestPeriod;
        uint256 withdrawFeeBP;
        uint256 accRewardsPerShare;
    }

    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    PoolInfo[] public poolInfo;
    address public constant burnAddress =
        0x000000000000000000000000000000000000dEaD;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event WithdrawEmergency(address indexed user, uint256 indexed pid, uint256 amount);

    modifier correctPID(uint256 _pid) {
        require(_pid<poolInfo.length,"bad pid");
        _;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }


    function addPool(uint256 _rewardPerBlockAmount,
                address _rewardTokenAddress,
                address _depositedTokenAddress,
                uint256 _startBlock,
                uint256 _harvestAvailableBlock,
                uint256 _harvestPeriod,
                uint256 _withdrawFeeBP) public onlyOwner {
        
        require(_withdrawFeeBP>=0 && _withdrawFeeBP<=300);//0-3%
        bytes memory bytecode = type(Vault).creationCode;
        bytecode = abi.encodePacked(bytecode, abi.encode(_rewardTokenAddress));
        bytes32 salt = keccak256(abi.encodePacked(poolInfo.length, block.number));

        address _rewardsVaultAddress;
        assembly {
            _rewardsVaultAddress := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        require(_rewardsVaultAddress != address(0), "Create2: Failed on deploy");
        
        uint256 _lastRewardBlock = block.number > _startBlock ? block.number : _startBlock;

        poolInfo.push(PoolInfo({
            rewardPerBlockAmount:_rewardPerBlockAmount,
            rewardTokenAddress:_rewardTokenAddress,
            rewardsVaultAddress:_rewardsVaultAddress,
            depositedTokenAddress:_depositedTokenAddress,
            totalDepositedAmount:0,
            lastRewardBlock:_lastRewardBlock,
            harvestAvailableBlock:(block.number > _harvestAvailableBlock ? block.number : _harvestAvailableBlock),
            harvestPeriod: _harvestPeriod,
            withdrawFeeBP: _withdrawFeeBP,
            accRewardsPerShare:0
        }));

    }

    function getVaultTokens(
        uint256 _pid,
        uint256 _amount,
        address _to
    ) external correctPID(_pid) onlyOwner{
        Vault(poolInfo[_pid].rewardsVaultAddress).safeRewardsTransfer(_to,_amount);
    }

    function setRewardPerBlock(uint256 _pid,
            uint256 _rewardPerBlockAmount) 
            external correctPID(_pid) onlyOwner {
        poolInfo[_pid].rewardPerBlockAmount=_rewardPerBlockAmount;
    }

    function setWithdrawFeeBP(uint256 _pid,uint256 _feeBP) 
        external correctPID(_pid) onlyOwner {
        require(_feeBP>=0 && _feeBP<=300);//0-3%
        poolInfo[_pid].withdrawFeeBP=_feeBP;
    }

    function pendingRewards(uint256 _pid, address _user) 
            external view correctPID(_pid) returns (uint256) {
        PoolInfo memory pool = poolInfo[_pid];
        UserInfo memory user = userInfo[_pid][_user];
        uint256 accRewardsPerShare = pool.accRewardsPerShare;
        
        if (block.number > pool.lastRewardBlock && pool.totalDepositedAmount != 0) {
            uint256 reward = block.number.sub(pool.lastRewardBlock).mul(pool.rewardPerBlockAmount);
            uint256 rewardBalance=IERC20(pool.rewardTokenAddress).balanceOf(pool.rewardsVaultAddress);
            if(rewardBalance<reward){
                reward=rewardBalance;
            }
            accRewardsPerShare = accRewardsPerShare.add(
                                                        reward
                                                        .mul(1e18)
                                                        .div(pool.totalDepositedAmount)
                                                    );
        }
        return user.depositedAmount
            .mul(accRewardsPerShare)
            .div(1e18)
            .sub(user.rewardDebt)
            .add(user.pendingAmount);
    }


    function updatePool(uint256 _pid) internal {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        if (pool.totalDepositedAmount == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 reward = block.number.sub(pool.lastRewardBlock).mul(pool.rewardPerBlockAmount);
        reward=Vault(pool.rewardsVaultAddress).safeRewardsTransfer(address(this),reward);

        pool.accRewardsPerShare = pool.accRewardsPerShare
                                .add(
                                    reward
                                    .mul(1e18)
                                    .div(pool.totalDepositedAmount)
                                );
        pool.lastRewardBlock = block.number;
    }


    function deposit(uint256 _pid, uint256 _amount) 
            external correctPID(_pid) nonReentrant {
        
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        
        
        uint256 pending = user.depositedAmount.mul(pool.accRewardsPerShare).div(1e18).sub(user.rewardDebt);
        uint256 rewards=0;

        if(block.number>=pool.harvestAvailableBlock 
            && block.number>user.lastHarvestedBlock.add(pool.harvestPeriod)){

            rewards=rewards.add(pending).add(user.pendingAmount);
            user.pendingAmount=0;
            user.lastHarvestedBlock=block.number;

        }else {
            user.pendingAmount=user.pendingAmount.add(pending);
        }

        if(rewards>0){
            _safeRewardsTransfer(msg.sender, rewards, IERC20(pool.rewardTokenAddress));
        }
        
        if(_amount > 0) {
            IERC20(pool.depositedTokenAddress).safeTransferFrom(address(msg.sender), address(this), _amount);
            user.depositedAmount = user.depositedAmount.add(_amount);
            pool.totalDepositedAmount=pool.totalDepositedAmount.add(_amount);
            emit Deposit(msg.sender, _pid, _amount);
        }
        user.rewardDebt = user.depositedAmount.mul(pool.accRewardsPerShare).div(1e18);
    }

    function withdraw(uint256 _pid, uint256 _amount) 
        external correctPID(_pid) nonReentrant{

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.depositedAmount >= _amount, "withdraw: not good");
        
        updatePool(_pid);

        uint256 pending = user.depositedAmount.mul(pool.accRewardsPerShare).div(1e18).sub(user.rewardDebt);
        uint256 rewards=0;

        if(block.number>=pool.harvestAvailableBlock 
            && block.number>user.lastHarvestedBlock.add(pool.harvestPeriod)){

            rewards=rewards.add(pending).add(user.pendingAmount);
            user.pendingAmount=0;
            user.lastHarvestedBlock=block.number;

        }else {
            user.pendingAmount=user.pendingAmount.add(pending);
        }

        if(rewards>0){
            _safeRewardsTransfer(msg.sender, rewards, IERC20(pool.rewardTokenAddress));
        }

        if(_amount > 0) {

            user.depositedAmount = user.depositedAmount.sub(_amount);
            pool.totalDepositedAmount=pool.totalDepositedAmount.sub(_amount);
            uint256 burnAmount=_amount.mul(pool.withdrawFeeBP).div(10000);
            if(burnAmount>0){
                IERC20(pool.depositedTokenAddress).safeTransfer(burnAddress, burnAmount);
            }
            IERC20(pool.depositedTokenAddress).safeTransfer(address(msg.sender), _amount.sub(burnAmount));
            emit Withdraw(msg.sender, _pid, _amount);
        }
        user.rewardDebt = user.depositedAmount.mul(pool.accRewardsPerShare).div(1e18);
    }

    function withdrawEmergency(uint256 _pid) 
        external correctPID(_pid) nonReentrant{
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.depositedAmount>0, "withdraw: not good");
        uint256 withdrawAmount=user.depositedAmount;
        user.depositedAmount=0;
        user.rewardDebt=0;
        pool.totalDepositedAmount=pool.totalDepositedAmount.sub(withdrawAmount);
        uint256 burnAmount=withdrawAmount.mul(pool.withdrawFeeBP).div(10000);
        if(burnAmount>0){
            IERC20(pool.depositedTokenAddress).safeTransfer(burnAddress, burnAmount);
        }
        IERC20(pool.depositedTokenAddress).safeTransfer(address(msg.sender), withdrawAmount.sub(burnAmount));
        emit WithdrawEmergency(msg.sender, _pid, withdrawAmount);
    }

    function _safeRewardsTransfer(address _to, uint256 _amount,IERC20 _token) internal {
        uint256 balance = _token.balanceOf(address(this));
        if (_amount > balance) {
            _token.safeTransfer(_to, balance);
        } else {
            _token.safeTransfer(_to, _amount);
        }
    }

}

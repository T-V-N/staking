# SSTX staking contract
## Features
- Add/Remove membership with __addMembership(threshold, APY) / removeMembership(id)__;
- Edit a membership threshold and APY using __changeMembershipAPY(newAPY) / changeMembershipThreshold(newThreshold)__;
- Weekly built in rewards. Could be changed using changeRewardPeriod(newPeriodInSecs). After adding a stake to previously staked tokens, a claim cooldown is being updated respectivly.
- Default membership levels: 
Level 1: 250,000,000 = 6% APY
Level 2: 500,000,000 = 8% APY
Level 3: 750,000,000 = 10% APY
Level 4: 1,500,000,000 = 12% APY
Level 5: 3,500,000,000 = 15% APY
- Stake, claim and unclaim using the corresponding functions;
- APY base is 360 days by default (1 year).

## Important notes

 - The contract do control the amount of tokens that are being received during staking. However, I recommend excluding it from any fees to prevent any implicity. 
 - The contract doesn't store any information about changed APY/Threshold levels. Therefore, after the owner changes membership levels, all stakers will be affected. 
 - This contract code won't work with pragma <8.0, you'll need to rewrite all math to work with SafeMath lib.

## Installation
Feel free to add hardhat configuration and deploy and verify the contract on any desired network.
[/flattened/flattened.sol](/flattened/flattened.sol) can be used to deploy with Remix.
The contracts needs to be provided with the token address.

To flatten manually:
```sh
npx hardhat compile
npx hardhat flatten ./contracts/SSTKStaking.sol >> flattened.sol
```

## Tests
The contract was tested with ethers.js + ganache setup using a simple ERC20 dummy token. 
All the features plus some corner cases were tested. Read [test/test.js](test/test.js) and feel free to add/modify tests.

To start testing:
```sh
npx hardhat test
```

## Integration notes
All APY amounts are returned multiplied by 1000. All token amounts are returned multiplied by token decimals (default is 10**7). Divide them respectivly to get the original numbers. 
All timestamps are being returned in seconds.

1. Use __stake(tokens)__ to start staking. It is __important__ that tokens on a user's wallet MUST be approved for the deployed address (check how uniswap does it) before calling stake(). The minimal stake amount is equal to the first membership level threshold. Stake can be called multiple times. Staked amount will be updated as well as claiming cooldown and APY.
2. Levels info can be acquired by calling __MembershipLevels[id]__ which returns [threshold, apy].
3. After a user has staked their tokens, their investment can be tracked via  __getStakeInfo(address)__ which returns [StackedTokens, APY, lastClaimedTimestamp, cooldownInSeconds].
4. Use __canClaim(address)__ to check whether a user can claim rewards.
5. Use __getReward(address)__ to check the amount of claimable rewards for a user.
6. Use __calculateReward(APY, cooldown, lastWithdrawn, tokens)__ in case you need more complex calculations.
7. Use __getAPY(tokens)__ to get APY on the tokens staked.
8. Use __calculateAdditionalTime(staked, added)__ to calculate additional time a user's cooldown will get after adding some tokens to the staked amount. 
9. There are 5 types of events __(MembershipAdded, MembershipRemoved, Staked, Claimed, Unstaked)__ which can be used to fetch data from and use it on the backend-side.
module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const dummy = await deploy("dummyToken", {
    from: deployer,
    args: [BigInt(10000000000000 * 10 ** 7).toString()],
    log: true,
  });
  const staking = await deploy("SSTKStaking", {
    from: deployer,
    args: [dummy.address],
    log: true,
  });
};
module.exports.tags = ["SSTKStaking"];

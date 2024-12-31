const { network } = require("hardhat")
module.exports = async ({ getNamedAccounts, deployments }) => {
    const { deploy, log } = deployments
    const { deployer } = await getNamedAccounts()
    const args = ["LPToken", "LP"]
    log("Deployments started")
    const lpToken = await deploy("LPToken", {
        from: deployer,
        args: args,
        log: true,
        waitConfirmations: network.config.blockConfirmations || 1,
    })
    log(`LPToken deployed at ${lpToken.address}`)
    return {
        tags: ["all", "token"]
    }

}



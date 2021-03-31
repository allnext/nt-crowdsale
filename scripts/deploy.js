const {
    ethers
} = require("hardhat");
const dayJs = require("dayjs");
const UtcDate = require('dayjs/plugin/utc');
dayJs.extend(UtcDate);

const {
    walletAddressMain,
    maxPreSaleContribution,
    maxPreSaleIndividualContribution,
    preSaleInitialRate,
    preSaleFinalRate,
} = require('../secrets.json')

// scripts/deploy.js
async function main() {
    // ethers is avaialble in the global scope
    const [deployer] = await ethers.getSigners();
    console.log(
        "Deploying the contracts with the account:",
        await deployer.getAddress()
    );


    const NortToken = await ethers.getContractFactory("NortToken");
    console.log("Deploying Nort Token...");

    // Deploy Nort Token to contract
    const nortToken = await NortToken.deploy('Nort Token', 'NT', { gasLimit: 4000000 });
    const token = await nortToken.deployed();
    console.log("Nort token deployed to:", token.address);

    const NortPrivateSale = await ethers.getContractFactory("NortPrivateSale");

    // Deploy Nort Private Sale Contract
    const nortPrivateSale = await NortPrivateSale.deploy(preSaleInitialRate, preSaleFinalRate, walletAddressMain, token.address, ethers.utils.parseEther(maxPreSaleContribution), getTimeInSeconds(60), getTimeInSeconds(525600), { gasLimit: 3000000 });
    await nortPrivateSale.deployed();
    console.log('Crowd sale contract deployed to:', nortPrivateSale.address);
    await nortToken.transfer(nortPrivateSale.address, ethers.utils.parseEther("40000000"));
    await nortPrivateSale.setCap(ethers.utils.parseEther(maxPreSaleIndividualContribution))
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });


function getTimeInSeconds(minutes = 1) {
    const seconds = dayJs().utc().add(minutes, 'minute').valueOf() / 1000;
    return Math.round(seconds);
}
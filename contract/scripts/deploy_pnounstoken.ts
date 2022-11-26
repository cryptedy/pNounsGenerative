import { ethers, network } from "hardhat";
import { writeFile } from "fs";
import { addresses } from "../../src/utils/addresses";

const pnouns = addresses.pnouns[network.name];

console.log("pnouns", pnouns);

const waitForUserInput = (text: string) => {
  return new Promise((resolve, reject) => {
    process.stdin.resume()
    process.stdout.write(text)
    process.stdin.once('data', data => resolve(data.toString().trim()))
  })
};

async function main() {
  const factoryToken = await ethers.getContractFactory("pNounsToken");
  const token = await factoryToken.deploy(pnouns);
  await token.deployed();
  console.log(`      token="${token.address}"`);

  const addresses = `export const addresses = {\n`
    + `  pnounstoken:"${token.address}"\n`
    + `}\n`;
  await writeFile(`../src/utils/addresses/pnounstoken_${network.name}.ts`, addresses, ()=>{});

  console.log(`npx hardhat verify ${token.address} ${pnouns} --network ${network.name}`);  
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

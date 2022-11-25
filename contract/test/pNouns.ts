import { expect } from "chai";
import { ethers } from "hardhat";
import { MerkleTree } from 'merkletreejs'
import keccak256 from 'keccak256'

let assetTokenGate: any;
let contractHelper: any;
let contractSplatter: any;
let testToken: any; // dummy token to test tokenGate
let contractArt: any;
let token: any;
let owner: any;
let authorized: any;
let unauthorized: any;
let treasury: any;

before(async () => {
  const factoryHelper = await ethers.getContractFactory("SVGHelperA");
  contractHelper = await factoryHelper.deploy();
  await contractHelper.deployed();

  const factory = await ethers.getContractFactory("SplatterProvider");
  contractSplatter = await factory.deploy(contractHelper.address);
  await contractSplatter.deployed();

  const factoryArt = await ethers.getContractFactory("MultiplexProvider");
  contractArt = await factoryArt.deploy(contractSplatter.address, "spltart", "Splatter Art");
  await contractArt.deployed();

  const factoryToken = await ethers.getContractFactory("pNounsToken");
  token = await factoryToken.deploy(contractArt.address);
  await token.deployed();

  [owner, authorized, unauthorized, treasury] = await ethers.getSigners();
});

const catchError = async (callback: any) => {
  try {
    await callback();
    console.log("unexpected success");
    return false;
  } catch(e:any) {
    const array = e.reason.split("'");
    return array.length == 3 ? array[1] : true;
  }
};

describe("pNounsToken constant values", function () {
  it("contractHelper", async function () {
    const result = await contractHelper.functions.generateSVGPart(contractSplatter.address, 1);
    expect(result.tag).equal("splt1");
  });
  it("contractSplatter", async function () {
    const result = await contractSplatter.functions.generateSVGPart(1);
    expect(result.tag).equal("splt1");
  });
  it("phase", async function () {
    await token.functions.setPhase(1, 5);
    const [phase] = await token.functions.phase();
    expect(phase).equal(1);
    const [purchaseUnit] = await token.functions.purchaseUnit();
    expect(purchaseUnit).equal(5)
  });
  it("mintLimit", async function () {
    const [mintLimit] = await token.functions.mintLimit();
    expect(mintLimit.toNumber()).equal(2100);
    const tx = await token.setMintLimit(500);
    await tx.wait();
    const [mintLimit2] = await token.functions.mintLimit();
    expect(mintLimit2.toNumber()).equal(500);
  });
  it("mintPrice", async function () {
    const [mintPrice] = await token.functions.mintPrice();
    expect(mintPrice).equal(ethers.utils.parseEther("0.05"));
    const halfPrice = mintPrice.div(ethers.BigNumber.from(2));
    const tx = await token.setMintPrice(halfPrice);
    await tx.wait();
    const [mintPrice2] = await token.functions.mintPrice();
    expect(mintPrice2).equal(halfPrice);
    const tx2 = await token.setMintPrice(mintPrice);
    await tx2.wait();
  });
  it("mintPriceFor", async function () {
    const [mintPrice] = await token.functions.mintPrice();
    const [myMintPrice] = await token.functions.mintPriceFor(owner.address);
    expect(mintPrice).equal(myMintPrice);
  });
  it("MercleRoot", async function () {
    const tree = createTree([{ address: authorized.address }]);
    await token.functions.setMerkleRoot(tree.getHexRoot());
    const [mercleRoot] = await token.functions.merkleRoot();
    expect(mercleRoot).equal(tree.getHexRoot());
  });
  it("maxMintPerAddress", async function () {
    const [maxMintPerAddress] = await token.functions.maxMintPerAddress();
    await token.functions.setMaxMintPerAddress(maxMintPerAddress.div(2));
    const [maxMintPerAddress2] = await token.functions.maxMintPerAddress();
    expect(maxMintPerAddress2).equal(maxMintPerAddress / 2);
  });
  it("treasuryAddress", async function () {
    await token.functions.setTreasuryAddress(treasury.address);
    const [treasury2] = await token.functions.treasuryAddress();
    expect(treasury2).equal(treasury.address);
  });
});

describe("pNounsToken owner's mint", function () {
  it("normal pattern", async function () {
    await token.functions.setPhase(0, 5);
    const [phase] = await token.functions.phase();
    expect(phase).equal(0);
    const [purchaseUnit] = await token.functions.purchaseUnit();
    expect(purchaseUnit).equal(5)
    const [mintPrice] = await token.functions.mintPrice();
    expect(mintPrice).equal(ethers.utils.parseEther("0.05"));

    // ownerを含まないマークルツリー
    const tree = createTree([{ address: authorized.address }]);
    await token.functions.setMerkleRoot(tree.getHexRoot());

    // ownerのマークルリーフ
    const proof = tree.getHexProof(ethers.utils.solidityKeccak256(['address'], [owner.address]));

    // 購入単位以外, ETHなしでmint
    // const tx = await token.connect(authorized).functions.mint(5,proof,{ value: mintPrice.mul(5) });
    await token.functions.mintPNouns(3, proof, { value: 0 });
    // await tx.wait();

    const [count1] = await token.functions.balanceOf(owner.address);
    expect(count1.toNumber()).equal(3);
    const [count2] = await token.functions.totalSupply();
    expect(count2.toNumber()).equal(3);
  });

  it("sold out", async function () {
    let tx, err;
    await token.functions.setPhase(0, 5);
    const [phase] = await token.functions.phase();
    expect(phase).equal(0);
    const [purchaseUnit] = await token.functions.purchaseUnit();
    expect(purchaseUnit).equal(5)
    const [mintPrice] = await token.functions.mintPrice();
    expect(mintPrice).equal(ethers.utils.parseEther("0.05"));
    const [count] = await token.functions.totalSupply();
    const [mintLimit] = await token.functions.mintLimit();

    // ownerを含まないマークルツリー
    const tree = createTree([{ address: authorized.address }]);
    await token.functions.setMerkleRoot(tree.getHexRoot());

    // ownerのマークルリーフ
    const proof = tree.getHexProof(ethers.utils.solidityKeccak256(['address'], [owner.address]));

    // 購入単位以外, ETHなしでmint
    // const tx = await token.connect(authorized).functions.mint(5,proof,{ value: mintPrice.mul(5) });
    // await token.functions.mintPNouns(2101, proof, { value: 0 });
    // await tx.wait();

    err = await catchError(async () => {
      // 最大供給量を超過
      tx = await token.functions.mintPNouns(mintLimit.toNumber() + 1, proof, { value: 0 });
      await tx.wait();
    });
    // console.log("err", err);
    expect(err).equal('Sold out');

  });

  // it("Attempt to buy by user2", async function() {
  //   err = await catchError(async () => {
  //     tx = await token2.purchase(0, user2.address, zeroAddress);
  //     await tx.wait();
  //   });
  //   expect(err).equal('Token is not on sale');
  // });


});

/**
 * https://github.com/Lavulite/ERC721MultiSale/blob/main/utils/merkletree.ts より
 */
type Node = {
  address: string,
  // allowedAmount: number
}

const createTree = (allowList: Node[]) => {
  // const leaves = allowList.map(node => ethers.utils.solidityKeccak256(['address', 'uint256'], [node.address, node.allowedAmount]))
  const leaves = allowList.map(node => ethers.utils.solidityKeccak256(['address'], [node.address]))
  return new MerkleTree(leaves, keccak256, { sortPairs: true })
}
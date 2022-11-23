// SPDX-License-Identifier: MIT

/*
 * Created by Eiba (@eiba8884)
 */

pragma solidity ^0.8.6;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "./pNounsContractFilter.sol";

contract pNounsToken is pNounsContractFilter {
    using Strings for uint256;

    enum SalePhase {
        Locked,
        PreSale1,
        PreSale2,
        PublicSale
    }
    SalePhase public phase = SalePhase.Locked;

    bytes32 public merkleRoot; // プレセールのマークルルート
    uint256 public purchaseUnit = 5; // プレセール時の購入単位
    uint256 public maxMintPerAddress = 100; // 1人当たりの最大ミント数
    // address public treasuryAddress = "0x8AE80e0B44205904bE18869240c2eC62D2342785"; // ミント代を転送する先のウォレット
    address public treasuryAddress = 0x0000000000000000000000000000000000000000; // ミント代を転送する先のウォレット
    address[] pNoundersAddress = [
        // pNounders配布用
        0x0000000000000000000000000000000000000000,
        0x0000000000000000000000000000000000000000,
        0x0000000000000000000000000000000000000000,
        0x0000000000000000000000000000000000000000,
        0x0000000000000000000000000000000000000000
    ];
    uint256 mintForTreasuryAddress = 100; // トレジャリーへの初回配布数
    uint256 mintForPNoundersAddress = 4; // pNoundersへの初回配布数
    mapping(address => uint256) public mintCount; // アドレスごとのミント数

    constructor(IAssetProvider _assetProvider, IProxyRegistry _proxyRegistry)
        pNounsContractFilter(
            _assetProvider,
            _proxyRegistry,
            "pNouns NFT",
            "pNouns"
        )
    {
        description = "This is the first NFT of pNouns project (https://pnouns.wtf/). All images are dymically generated on the blockchain.";
        mintPrice = 0.05 ether;
        mintLimit = 2100;
        admin = address(0); // TODO to be updated

        for (uint256 i = 0; i < pNoundersAddress.length; i++) {
            initMint(pNoundersAddress[i], mintForPNoundersAddress);
            mintForTreasuryAddress -= mintForPNoundersAddress;
        }

        initMint(treasuryAddress, mintForTreasuryAddress);
    }

    ////////// コンストラクタ用  /////////////
    function initMint(address _to, uint256 _num) private {
        if (_to != address(0)) {
            // ミント
            for (uint256 i; i < _num; i++) {
                _safeMint(_to, nextTokenId++);
            }
            // ミント数カウントアップ
            mintCount[_to] += _num;
        }
    }

    ////////// プレセール //////////
    function mint(
        uint256 _mintAmount, // ミント数
        bytes32[] calldata _merkleProof // マークルツリー
    ) public payable {
        // セールフェイズチェック
        if (phase == SalePhase.Locked) {
            revert("Sale locked");
        } else if (phase == SalePhase.PreSale1 || phase == SalePhase.PreSale2) {
            // マークルツリーが正しいこと
            bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
            require(
                MerkleProof.verify(_merkleProof, merkleRoot, leaf),
                "Invalid Merkle Proof"
            );
        }

        // 最大供給数に達していないこと
        require(totalSupply() + _mintAmount <= mintLimit, "Sold out");

        // ミント数が購入単位と一致していること
        require(_mintAmount % purchaseUnit == 0, "Invalid purchaseUnit");

        // アドレスごとのミント数上限チェック
        require(
            mintCount[msg.sender] + _mintAmount <= maxMintPerAddress,
            "exceeds number of earned Tokens"
        );

        // ミント数に応じた ETHが送金されていること
        uint256 cost = mintPrice * _mintAmount;
        require(cost <= msg.value, "insufficient funds");

        // ミント
        for (uint256 i; i < _mintAmount; i++) {
            _safeMint(msg.sender, nextTokenId++);
        }

        // ミント数カウントアップ
        mintCount[msg.sender] += _mintAmount;

        // トレジャリーに送金
        payable(treasuryAddress).transfer(msg.value);
    }

    function setTreasuryAddress(address _treasury) external onlyAdmin {
        treasuryAddress = _treasury;
    }

    function setPhase(SalePhase _phase, uint256 _purchaseUnit)
        external
        onlyAdmin
    {
        phase = _phase;
        purchaseUnit = _purchaseUnit;
    }

    function setMerkleRoot(bytes32 _merkleRoot) external onlyAdmin {
        merkleRoot = _merkleRoot;
    }

    function setMaxMintPerAddress(uint256 _maxMintPerAddress)
        external
        onlyAdmin
    {
        maxMintPerAddress = _maxMintPerAddress;
    }

    function mint() public payable override returns (uint256) {
        revert("this function is not used");
    }
}

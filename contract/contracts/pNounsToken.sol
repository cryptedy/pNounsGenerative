// SPDX-License-Identifier: MIT

/*
 * Created by Eiba (@eiba8884)
 */

pragma solidity ^0.8.6;

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "./pNounsContractFilter.sol";

contract pNounsToken is pNounsContractFilter {
    enum SalePhase {
        Locked,
        PreSale1,
        PreSale2,
        PublicSale
    }
    SalePhase public phase = SalePhase.Locked; // セールフェーズ
    uint256 public purchaseUnit = 5; // 購入単位

    bytes32 public merkleRoot; // プレセールのマークルルート
    uint256 public maxMintPerAddress = 100; // 1人当たりの最大ミント数
    // address public treasuryAddress = "0x8AE80e0B44205904bE18869240c2eC62D2342785"; // ミント代を転送する先のウォレット
    address public treasuryAddress = 0x0000000000000000000000000000000000000000; // ミント代を転送する先のウォレット
    uint256 mintForTreasuryAddress = 100; // トレジャリーへの初回配布数

    // 一旦トレジャリーにミント後配布する方針。コントラクトには登録しない。
    // address[] pNoundersAddress = [
    //     // pNounders配布用
    //     0x0000000000000000000000000000000000000000,
    //     0x0000000000000000000000000000000000000000,
    //     0x0000000000000000000000000000000000000000,
    //     0x0000000000000000000000000000000000000000,
    //     0x0000000000000000000000000000000000000000,
    //     0x0000000000000000000000000000000000000000,
    //     0x0000000000000000000000000000000000000000,
    //     0x0000000000000000000000000000000000000000
    // ];
    // uint256 mintForPNoundersAddress = 4; // pNoundersへの初回配布数
    mapping(address => uint256) public mintCount; // アドレスごとのミント数

    constructor(IAssetProvider _assetProvider)
        pNounsContractFilter(
            _assetProvider,
            "pNouns NFT",
            "pNouns"
        )
    {
        description = "This is the first NFT of pNouns project (https://pnouns.wtf/).";
        mintPrice = 0.05 ether;
        mintLimit = 2100;
        admin = address(0); // TODO to be updated

    // 一旦トレジャリーにミント後配布する方針。コントラクトには登録しない。
        // for (uint256 i = 0; i < pNoundersAddress.length; i++) {
        //     initMint(pNoundersAddress[i], mintForPNoundersAddress);
        //     mintForTreasuryAddress -= mintForPNoundersAddress;
        // }

        initMint(treasuryAddress, mintForTreasuryAddress);
    }

    ////////// コンストラクタ用  /////////////
    function initMint(address _to, uint256 _num) private {
        if (_to != address(0)) {
            for (uint256 i; i < _num; i++) {
                _safeMint(_to, nextTokenId++);
            }
            mintCount[_to] += _num;
        }
    }

    function mintPNouns(
        uint256 _mintAmount, // ミント数
        bytes32[] calldata _merkleProof // マークルツリー
    ) external payable {
        // オーナーチェック
        if (owner() != _msgSender() && admin != _msgSender()) {
            // セールフェイズチェック
            if (phase == SalePhase.Locked) {
                revert("Sale locked");
            } else if (
                phase == SalePhase.PreSale1 || phase == SalePhase.PreSale2
            ) {
                // マークルツリーが正しいこと
                bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
                require(
                    MerkleProof.verify(_merkleProof, merkleRoot, leaf),
                    "Invalid Merkle Proof"
                );
            }

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
        }

        // 最大供給数に達していないこと
        require(totalSupply() + _mintAmount <= mintLimit, "Sold out");

        // ミント
        for (uint256 i; i < _mintAmount; i++) {
            _safeMint(msg.sender, nextTokenId++);
        }

        // ミント数カウントアップ
        mintCount[msg.sender] += _mintAmount;

        // トレジャリーに送金
        if (treasuryAddress != address(0) && msg.value > 0) {
            payable(treasuryAddress).transfer(msg.value);
        }
    }

    function setTreasuryAddress(address _treasury) external onlyAdminOrOwner {
        treasuryAddress = _treasury;
    }

    function setPhase(SalePhase _phase, uint256 _purchaseUnit)
        external
        onlyAdminOrOwner
    {
        phase = _phase;
        purchaseUnit = _purchaseUnit;
    }

    function setMerkleRoot(bytes32 _merkleRoot) external onlyAdminOrOwner {
        merkleRoot = _merkleRoot;
    }

    function setMaxMintPerAddress(uint256 _maxMintPerAddress)
        external
        onlyAdminOrOwner
    {
        maxMintPerAddress = _maxMintPerAddress;
    }

    function mint() public payable override returns (uint256) {
        revert("this function is not used");
    }
}

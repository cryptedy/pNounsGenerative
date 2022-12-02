// SPDX-License-Identifier: MIT

/*
 * Created by Eiba (@eiba8884)
 */

pragma solidity ^0.8.6;

import "./libs/ProviderToken3.sol";
import "contract-allow-list/contracts/proxy/interface/IContractAllowListProxy.sol";

// contract pNounsToken is ProviderToken, ERC721P2P {
contract pNounsContractFilter is ProviderToken3 {

    address public admin; // コントラクト管理者。オーナーか管理者がset系メソッドを実行可能

    IContractAllowListProxy public cal;
    uint256 public calLevel = 1;

    constructor(
        IAssetProvider _assetProvider,
        string memory _title,
        string memory _shortTitle
    )
        ProviderToken3(_assetProvider, _title, _shortTitle)
    {}

    ////////// modifiers //////////
    modifier onlyAdminOrOwner() {
        require(
            owner() == _msgSender() || admin == _msgSender(),
            "caller is not the admin"
        );
        _;
    }

    ////////// onlyOwner functions start //////////
    function setAdmin(address _admin) external onlyOwner {
        require(_admin != address(0), "address shouldn't be 0");
        admin = _admin;
    }

    ////////////// CAL 関連 ////////////////
    function setCalContract(IContractAllowListProxy _cal) external onlyAdminOrOwner {
        cal = _cal;
    }

    function setCalLevel(uint256 _value) external onlyAdminOrOwner {
        calLevel = _value;
    }

    // overrides
    function setApprovalForAll(address operator, bool approved)
        public
        virtual
        override(ERC721WithOperatorFilter,IERC721A) 
    {
        if (address(cal) != address(0)) {
            require(
                cal.isAllowed(operator, calLevel) == true,
                "address no list"
            );
        }
        ERC721WithOperatorFilter.setApprovalForAll(operator, approved);
    }

    function approve(address to, uint256 tokenId)
        public
        payable
        virtual
        override(ERC721WithOperatorFilter,IERC721A) 
    {
        if (address(cal) != address(0)) {
            require(cal.isAllowed(to, calLevel) == true, "address no list");
        }
        ERC721WithOperatorFilter.approve(to, tokenId);
    }
}

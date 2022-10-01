// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";


contract NFTMarketplace is ERC721URIStorage {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    Counters.Counter private _itemsSold;
    
    // amount required to put an nft up for sale in the marketplace
    uint256 listingPrice = 0.01 ether;
    address payable owner;
    // mapping of uint to NftDetails
    mapping(uint256 => NftDetails) public nftIdToNftDetails;
    // mapping of address to boolean
    mapping(address => bool) public oneTimeListingFee;
     // mapping of address to boolean
    mapping(address => bool) public oneTimeSellingFee;

    // struct of each nft 
    struct NftDetails {
      uint256 tokenId;
      address payable seller;
      address payable owner;
      uint256 price;
      bool sold;
    }

    
    event MarketItemCreated (
      uint256 indexed tokenId,
      address seller,
      address owner,
      uint256 price,
      bool sold
    );

    modifier onlyOwner{
      require(owner == msg.sender, "Not owner of the marketplace");
      _;
    }

    constructor() ERC721("CXONFT", "Cxo") {
      owner = payable(msg.sender);
    }

    /* Updates the listing price of the contract */
    function updateListingPrice(uint _listingPrice) public payable onlyOwner{
      listingPrice = _listingPrice;
    }

    /* Returns the listing price of the contract */
    function getListingPrice() public view returns (uint256) {
      return listingPrice;
    }

    /**
    * @dev mintToken mints an nft
    */
    function mintToken(string memory tokenURI) public returns(uint){
        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();
    //   _mint() internal function is used to mint a new NFT at the given address. (msg.sender)
        _mint(msg.sender, newTokenId);
    //   _setTokenURI() Internal function to set the token URI for a given token
        _setTokenURI(newTokenId, tokenURI);
        return newTokenId;
    }

    /**
    * @dev listNftforSale this function puts up minted nft for sale in the marketplace
    */
    function listNftforSale( uint256 tokenId, uint256 price ) public payable {
      require(price > 0, "Price must be at least 1 wei");
      // runs if an address have not listed an nft before
      if(oneTimeListingFee[msg.sender] == false){
          require(msg.value == listingPrice, "Price must be equal to listing price");
      }

      nftIdToNftDetails[tokenId] =  NftDetails(
        tokenId,
        payable(msg.sender),
        payable(address(this)),
        price,
        false
      );

      _transfer(msg.sender, address(this), tokenId);
      emit MarketItemCreated(
        tokenId,
        msg.sender,
        address(this),
        price,
        false
      );
      // changes the satues of `msg.sender` to be an address that have listed an nft
      oneTimeListingFee[msg.sender] = true;
      
    }

    /* allows someone to resell a token they have purchased */
    function listBoughtToken(uint256 tokenId, uint256 price) public payable {
      require(nftIdToNftDetails[tokenId].owner == msg.sender, "Only item owner can perform this operation");
      // runs if an address have not listed Bought nft before
      if(oneTimeSellingFee[msg.sender] == false){
         require(msg.value == listingPrice, "Price must be equal to listing price");
      }
      nftIdToNftDetails[tokenId].sold = false;
      nftIdToNftDetails[tokenId].price = price;
      nftIdToNftDetails[tokenId].seller = payable(msg.sender);
      nftIdToNftDetails[tokenId].owner = payable(address(this));
      _itemsSold.decrement();
      
    //   tranfers token to the nftmarketplace contract
      _transfer(msg.sender, address(this), tokenId);

     // changes the satues of `msg.sender` to be an address that have listed bought nft
      oneTimeSellingFee[msg.sender] = true;
    }

    
    /**
    * @dev buyListedNft: This function executes the buying of an nft from the marketplace
    */
    /* Creates the sale of a marketplace item */
    /* Transfers ownership of the item, as well as funds between parties */
    function buyListedNft(
      uint256 tokenId
      ) public payable {
      uint price = nftIdToNftDetails[tokenId].price;
      address seller = nftIdToNftDetails[tokenId].seller;
      require(msg.value == price, "Please submit the asking price in order to complete the purchase");
      nftIdToNftDetails[tokenId].owner = payable(msg.sender);
      nftIdToNftDetails[tokenId].sold = true;
      nftIdToNftDetails[tokenId].seller = payable(address(0));
      _itemsSold.increment();
      _transfer(address(this), msg.sender, tokenId);
      payable(owner).transfer(listingPrice);
      payable(seller).transfer(msg.value);
    }

    /* Returns all unsold market items */
    function fetchMarketItems() public view returns (NftDetails[] memory) {
      uint itemCount = _tokenIds.current();
      uint unsoldItemCount = _tokenIds.current() - _itemsSold.current();
      uint currentIndex = 0;

      NftDetails[] memory items = new NftDetails[](unsoldItemCount);
      for (uint i = 0; i < itemCount; i++) {
        if (nftIdToNftDetails[i + 1].owner == address(this)) {
          uint currentId = i + 1;
          NftDetails storage currentItem = nftIdToNftDetails[currentId];
          items[currentIndex] = currentItem;
          currentIndex += 1;
        }
      }
      return items;
    }

    /* Returns only items that a user has purchased */
    // fetchPurchasedNFTs
    function fetchPurchasedNFTs() public view returns (NftDetails[] memory) {
      uint totalItemCount = _tokenIds.current();
      uint itemCount = 0;
      uint currentIndex = 0;

      for (uint i = 0; i < totalItemCount; i++) {
        if (nftIdToNftDetails[i + 1].owner == msg.sender) {
          itemCount += 1;
        }
      }

      NftDetails[] memory items = new NftDetails[](itemCount);
      for (uint i = 0; i < totalItemCount; i++) {
        if (nftIdToNftDetails[i + 1].owner == msg.sender) {
          uint currentId = i + 1;
          NftDetails storage currentItem = nftIdToNftDetails[currentId];
          items[currentIndex] = currentItem;
          currentIndex += 1;
        }
      }
      return items;
    }

    /* Returns only items a user has listed */
    function fetchItemsListed() public view returns (NftDetails[] memory) {
      uint totalItemCount = _tokenIds.current();
      uint itemCount = 0;
      uint currentIndex = 0;

      for (uint i = 0; i < totalItemCount; i++) {
        if (nftIdToNftDetails[i + 1].seller == msg.sender) {
          itemCount += 1;
        }
      }

     NftDetails[] memory items = new NftDetails[](itemCount);
      for (uint i = 0; i < totalItemCount; i++) {
        if (nftIdToNftDetails[i + 1].seller == msg.sender) {
          uint currentId = i + 1;
          NftDetails storage currentItem = nftIdToNftDetails[currentId];
          items[currentIndex] = currentItem;
          currentIndex += 1;
        }
      }
      return items;
    }
}
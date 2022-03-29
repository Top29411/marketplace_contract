// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "hardhat/console.sol";

contract MarketPlace is ReentrancyGuard {
  using Counters for Counters.Counter;

  Counters.Counter private itemIds;
  Counters.Counter private itemsSold;
  Counters.Counter private itemsRent;

  address payable private owner;
  uint256 private listingFee = 0.025 ether;

  constructor() {
    owner = payable(msg.sender);
  }

  struct MarketItem {
    uint256 itemId;
    address payable seller;
    address payable owner;
    uint256 price;
    uint256 rent_cost ;
    bool sold ;
    bool rent ;
  }

  struct UserSummary {
    address payable sellerAddr ;
    address payable buyerAddr ;
    uint256 rentTime ;
    uint256 rentInterval ;
    bool renting  ;
  }


  mapping(uint256 => UserSummary) private userSummaryByAddress;


  mapping(uint256 => MarketItem) private marketItemsById;
  uint256[10000] tokenIdArr ;


  function getListingFee() public view returns (uint256) {
    return listingFee;
  }

// set price for sale function
  function set_soldprice(
    uint256 tokenId,
    uint256 price
  ) public payable nonReentrant {
    require(price > 0, "Price cannot be zero");
    bool renting_flg = userSummaryByAddress[tokenId].renting ;
    require( !renting_flg, "Sorry , this item is renting now ! so , you can't sell this item.");

    uint256 itemId_sold = 0;
    uint256 rent_cost = 0 ;
    bool rent_flg  = false ;
    if(marketItemsById[tokenId].itemId == 0 ){
      itemIds.increment() ;
    }else{
      
      require(!marketItemsById[tokenId].sold , "this item is already listed ");

      uint256 inx = marketItemsById[tokenId].itemId ;
      if(marketItemsById[tokenId].rent == true){
        rent_flg = marketItemsById[tokenId].rent ;
        rent_cost = marketItemsById[tokenId].rent_cost ;
      }
      for(uint256 i = inx ; i < itemIds.current() ; i++){
        tokenIdArr[i] = tokenIdArr[i+1] ;
      }
    }
      tokenIdArr[itemIds.current()] = tokenId ;
      itemId_sold = itemIds.current() ;
  
    marketItemsById[tokenId] = MarketItem(
      itemId_sold,
      payable(msg.sender),
      payable(address(0)), // no-one
      price,
      rent_cost,
      true,
      rent_flg
    );

  }

  function createMarketSale(address nftContract, uint256 tokenId)
    public
    payable
    nonReentrant
  {
    require(marketItemsById[tokenId].sold , "This item is not listed now") ;
    uint256 price = marketItemsById[tokenId].price ;
    console.log("creating market sale for token %s for %s eh", tokenId, price) ;
    // require(
    //   msg.value >= price,
    //   "Please submit the asking price in order to complete the purchase"
    // );
    
    address payable seller = marketItemsById[tokenId].seller ;
    address buyer = msg.sender ;
    
    seller.transfer(msg.value) ; // Pay the person who posted
    IERC721(nftContract).transferFrom(seller, buyer, tokenId) ;
    marketItemsById[tokenId].owner = payable(msg.sender); // Make the payer the new owner
    marketItemsById[tokenId].sold = false ;
    marketItemsById[tokenId].rent = false ;
    
  }

// set rent price  function 
function set_rentprice(
    uint256 tokenId,
    uint256 rent_cost
  ) public payable nonReentrant {


    bool renting_flg = userSummaryByAddress[tokenId].renting ;
    require( !renting_flg, "Sorry , this item is renting now ! so , you can't rent again this item.");

    uint256 itemId_rent = 0;
    uint256 price = 0 ;
    bool sold_flg  = false ;
    if(marketItemsById[tokenId].itemId == 0 ){
      itemIds.increment() ;
    }else{
      uint256 inx = marketItemsById[tokenId].itemId ;
      if(marketItemsById[tokenId].sold == true){
        sold_flg = marketItemsById[tokenId].sold ;
        price = marketItemsById[tokenId].price ;
      }
      for(uint256 i = inx ; i < itemIds.current() ; i++){
        tokenIdArr[i] = tokenIdArr[i+1] ;
      }
    }
    tokenIdArr[itemIds.current()] = tokenId ;
    itemId_rent = itemIds.current() ;
  
    marketItemsById[tokenId] = MarketItem(
      itemId_rent,
      payable(msg.sender),
      payable(address(0)), // no-one
      price,
      rent_cost,
      sold_flg,
      true
    );
    userSummaryByAddress[tokenId].sellerAddr  = payable(msg.sender) ;

    // transfer ownsership to the marketplace
    // IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);
    

  }



//NFT meta dog rent from one to another
  function createMarketitemRent(address nftContract, uint256 tokenId, uint256 timeline)
    public
    payable
    nonReentrant
  {
    require(marketItemsById[tokenId].rent , "This item is not rent now") ;
    // console.log("creating market sale for token %s for %s eh", tokenId, rent_cost) ;
    
    address payable seller = marketItemsById[tokenId].seller ;
    address  buyer = msg.sender ;

    userSummaryByAddress[tokenId].rentInterval = timeline * 60 * 60 * 24 + block.timestamp ;
    userSummaryByAddress[tokenId].renting = true ;
    userSummaryByAddress[tokenId].buyerAddr = payable(msg.sender) ;


    seller.transfer(msg.value); // Pay the person who posted
    IERC721(nftContract).transferFrom(seller, buyer, tokenId);
    marketItemsById[tokenId].owner = payable(msg.sender); // Make the payer the new owner
    marketItemsById[tokenId].rent = false ;
    marketItemsById[tokenId].sold = false ;
  }
    
  function returnMarketitemRent(address nftContract, uint256 tokenId )
    public
    payable
    nonReentrant
  {
    uint256 now_time = block.timestamp ;
    require(now_time >= userSummaryByAddress[tokenId].rentInterval, "Sorry  , now is not available to get back your item") ;
    
    
    address payable owner1 = marketItemsById[tokenId].owner ;
    address buyer = msg.sender ;
    
    IERC721(nftContract).transferFrom(owner1, buyer, tokenId) ;
    marketItemsById[tokenId].owner = payable(msg.sender) ; // Make the payer the new owner
    marketItemsById[tokenId].rent = false ;

    userSummaryByAddress[tokenId].renting = false ;
  }

  function possible_rentback(uint256 tokenId) public view returns (bool) {
    return (userSummaryByAddress[tokenId].rentInterval  <= block.timestamp) ;
  }

 function Time_call() public view returns (uint256){
        return block.timestamp;
    }
  function fetchCreatedItems_All() public view returns (MarketItem[] memory) {
    uint256 itemCount = itemIds.current();
    uint256 currentIndex = 0;
    MarketItem[] memory items = new MarketItem[](itemCount);
    for (uint256 i = 1; i <= itemCount; i++) {
      MarketItem memory item = marketItemsById[tokenIdArr[i]];
        items[currentIndex] = item;
        currentIndex++;
    }
    return items;
  }
}

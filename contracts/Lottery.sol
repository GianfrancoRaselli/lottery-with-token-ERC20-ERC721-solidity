// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts@4.5.0/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts@4.5.0/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts@4.5.0/access/Ownable.sol";


contract Lottery is ERC20, Ownable {

  address public ticketNFT;

  uint public tokenPrice; // price in weis
  uint public ticketPrice; // price in tokens
  
  mapping(address => address) public userTicketsManager;
  address public winner;
  mapping(address => uint[]) public userTickets;
  mapping(uint => address) public ticketUser;
  uint[] public tickets;
  uint randNonce;


  constructor(uint _tokenPrice, uint _ticketPrice) ERC20("Lottery Token", "LT") payable {
    tokenPrice = _tokenPrice;
    ticketPrice = _ticketPrice;
    _mint(address(this), 1000);
    ticketNFT = address(new TicketNFT());
  }


  function mint(uint _amount) public onlyOwner {
    _mint(address(this), _amount);
  }

  function buyTokens(uint _numTokens) public payable {
    require(balanceOf(address(this)) >= _numTokens, "Buy fewer tokens");

    uint cost = _numTokens * tokenPrice;
    require(msg.value >= cost, "Insufficient sent balance");

    if (userTicketsManager[msg.sender] == address(0)) {
      _register();
    }

    _transfer(address(this), msg.sender, _numTokens);
    payable(msg.sender).transfer(msg.value - cost);
  }

  function returnTokens(uint _numTokens) public {
    require(_numTokens > 0, "The amount of tokens is 0");
    require(_numTokens <= balanceOf(msg.sender), "You can not return that amount of tokens");

    _transfer(msg.sender, address(this), _numTokens);
    payable(msg.sender).transfer(_numTokens * tokenPrice);
  }

  function buyTickets(uint _numTickets) public {
    uint cost = _numTickets * ticketPrice;
    require(balanceOf(msg.sender) >= cost, "You do not have enough tokens");

    _transfer(msg.sender, address(this), cost);

    for (uint i; i < _numTickets;) {
      uint random = uint(keccak256(abi.encodePacked(block.timestamp, msg.sender, randNonce)));

      tickets.push(random);
      ticketUser[random] = msg.sender;
      userTickets[msg.sender].push(random);
      TicketsManager(userTicketsManager[msg.sender]).mintTicket(msg.sender, random);

      unchecked {
        randNonce++;
        i++;
      }
    }
  }

  function pickWinner() public onlyOwner {
    uint len = tickets.length;
    require(len > 0, "");

    winner = ticketUser[tickets[uint(keccak256(abi.encodePacked(block.timestamp))) % len]];
    
    uint aux = len * ticketPrice * tokenPrice / 100;
    payable(winner).transfer(aux * 95);
    payable(owner()).transfer(aux * 5);
  }

  function reward() public view returns (uint) {
    return tickets.length * ticketPrice * tokenPrice;
  }

  function _register() internal {
    userTicketsManager[msg.sender] = address(new TicketsManager(msg.sender, address(this), address(ticketNFT)));
  }
  
}


contract TicketNFT is ERC721 {

  address public lottery = msg.sender;


  constructor() ERC721("TicketNFT", "TNFT") payable {
  }


  function safeMint(address _owner, uint _id) public {
    require(msg.sender == Lottery(lottery).userTicketsManager(_owner), "You can not access");
    
    _safeMint(_owner, _id);
  }

}


contract TicketsManager {

  struct Owner {
    address owner;
    address lottery;
    address ticketNFT;
  }

  Owner public owner;


  constructor(address _owner, address _lottery, address _ticketNFT) payable {
    owner = Owner(
      _owner,
      _lottery,
      _ticketNFT
    );
  }


  function mintTicket(address _owner, uint _id) public {
    require(msg.sender == owner.lottery, "You can not access");

    TicketNFT(owner.ticketNFT).safeMint(_owner, _id);
  }

}

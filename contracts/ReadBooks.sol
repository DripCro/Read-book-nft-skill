// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721URIStorage} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

interface IAggregatorV3 {
    function decimals() external view returns (uint8);
    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
}

/// @title Read Books - one NFT per book you finish reading
/// @notice Owner-only mint. Every mint (except by the skill creator) costs $0.05 in ETH,
///         priced live via the Chainlink ETH/USD feed on Base, paid to FEE_RECIPIENT.
contract ReadBooks is ERC721URIStorage, Ownable {
    uint256 private _nextTokenId;

    /// @notice Skill creator - receives the $0.05 mint fee; mints free on their own collection
    address public constant FEE_RECIPIENT = 0x35f3563C4BFc804bf60568bd7d2436d58be8064f;

    /// @notice Chainlink ETH/USD price feed on Base
    IAggregatorV3 public constant ETH_USD_FEED = IAggregatorV3(0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70);

    /// @notice Mint fee in USD cents ($0.05)
    uint256 public constant FEE_USD_CENTS = 5;

    constructor(address initialOwner) ERC721("Read Books", "READ") Ownable(initialOwner) {}

    /// @notice Current $0.05 mint fee expressed in wei, priced via Chainlink
    function mintFeeWei() public view returns (uint256) {
        (, int256 answer, , , ) = ETH_USD_FEED.latestRoundData();
        require(answer > 0, "bad oracle price");
        uint8 dec = ETH_USD_FEED.decimals();
        return (FEE_USD_CENTS * 1e18 * (10 ** dec)) / (uint256(answer) * 100);
    }

    /// @notice Mint a book NFT. Creator mints free; everyone else pays mintFeeWei().
    function mint(address to, string memory uri) external payable onlyOwner returns (uint256 tokenId) {
        if (msg.sender != FEE_RECIPIENT) {
            require(msg.value >= mintFeeWei(), "insufficient mint fee");
            (bool ok, ) = FEE_RECIPIENT.call{value: msg.value}("");
            require(ok, "fee transfer failed");
        }
        tokenId = _nextTokenId++;
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
    }
}

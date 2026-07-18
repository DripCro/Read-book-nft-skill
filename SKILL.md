---
name: read-book-nft
description: Mint an ERC-721 NFT on Base for every book you finish reading, with book metadata (title, author, year, cover) pulled from the Open Library API (Google Books fallback). One contract per user, owner-only mint, on-chain tokenURI via base64 data URI. Each mint costs $0.05 in ETH (Chainlink-priced), paid to the skill creator.
---

# Read Book NFT

Mint a permanent on-chain memento for each book you finish. Collection: "Read Books" (READ), ERC-721 + URIStorage + Ownable (OpenZeppelin 5.1.0).

## Mint fee

- Each mint costs **$0.05 USD, paid in ETH** on Base alongside the mint transaction.
- The fee is priced live on-chain via the Chainlink ETH/USD feed (`0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70`) — call `mintFeeWei() view returns (uint256)` on the deployed contract to get the exact wei amount to send.
- The fee goes to the skill creator: `0x35f3563C4BFc804bf60568bd7d2436d58be8064f` (hardcoded as `FEE_RECIPIENT`).
- The creator mints free on their own collection; everyone else must send `msg.value >= mintFeeWei()` or the mint reverts.
- Gas is extra (fractions of a cent on Base).

## Contract

- Source: `contracts/ReadBooks.sol` (Solidity 0.8.24+, compiled with solc 0.8.28, optimizer 200 runs)
- Chain: Base (8453)
- Deployment: deterministic CREATE2 via the canonical deterministic-deployment-proxy at `0x4e59b44847b379578588920cA78FbF26c0B4956C`
- Constructor arg: owner address (only owner can mint)
- Mint function: `mint(address to, string uri) payable returns (uint256 tokenId)` — auto-incrementing tokenId starting at 0
- Fee helper: `mintFeeWei() view returns (uint256)` — current $0.05 in wei

## Deploy (Path B — raw CREATE2, no private key in sandbox)

1. Compile in the Bankr sandbox with `scripts/compile.js` (packages: `solc@0.8.28`, `@openzeppelin/contracts@5.1.0`, `viem@2.21.0`; set env `OWNER=<your wallet>`). It prints:
   - PREDICTED_ADDRESS (CREATE2 address)
   - the full deploy payload = `salt (32 bytes) ++ initcode (bytecode ++ abi-encoded owner)`
   - salt: keccak256("read-books-v1-<owner lowercase>")
2. Broadcast with `submit_raw_transaction` to `0x4e59b44847b379578588920cA78FbF26c0B4956C` on Base, `data` = payload, `value` = 0.
   - Requires "arbitrary contract calls" ENABLED in Bankr Security settings.
3. Verify with `read_contract`: `owner() view returns (address)` at the predicted address.

Deployed instances:
- owner 0x35f3563c4bfc804bf60568bd7d2436d58be8064f (skill creator) → `0x9D10F5A14DdB49FdE8c036596B79Df31F51482F4` (deploy tx 0x8d3188d8a9c0d3d0c6fa00d9abd2e04ba4e59b93f7e32d9e7d797c99940faeea)

## Minting a book

1. Fetch book metadata (Open Library Search API, no key needed):
   `curl -s 'https://openlibrary.org/search.json?title=<book+title>&limit=1'`
   Extract: `title`, `author_name[0]`, `first_publish_year`, `cover_i` (cover image: `https://covers.openlibrary.org/b/id/<cover_i>-L.jpg`).
   **Fallback**: if Open Library returns 0 results, use Google Books — `curl -s 'https://www.googleapis.com/books/v1/volumes?q=intitle:<book+title>&maxResults=1'` — and use `volumeInfo.title`, `volumeInfo.authors[0]`, `volumeInfo.publishedDate` (year), and `volumeInfo.imageLinks.thumbnail` (swap `http://` for `https://` and `zoom=1` for `zoom=2` for a larger cover).
2. Build ERC-721 metadata JSON:
   `{"name":"<title> (<year>)","description":"Read, finished <date>. By <author>.","image":"<cover url>","attributes":[{"trait_type":"Author","value":"<author>"},{"trait_type":"Year","value":"<year>"},{"trait_type":"Finished","value":"<ISO date>"}]}`
3. Encode as data URI: `data:application/json;base64,<base64(json)>` (base64 it in the sandbox with `bun -e`).
4. Read the current fee: `read_contract` → `mintFeeWei() view returns (uint256)` (skip if you are the skill creator — your mints are free).
5. Call `write_contract` on Base:
   - to: the deployed contract
   - functionSignature: `mint(address to, string uri)`
   - args: [owner wallet, data URI]
   - value: the mintFeeWei amount converted to ETH (e.g. fee 27007921048189 wei → "0.000027007921048189"); use "0" if you are the skill creator

## Notes

- Only the contract owner can mint; anyone can view.
- tokenURI is fully self-contained (base64 data URI) — no IPFS pinning needed, but the cover image is a hotlink to Open Library / Google Books. For permanence, swap image to an IPFS upload later.
- To mint from X timeline posts: parse the book title from the post text, then follow the minting steps above.
- Fee is enforced on-chain — sending less than `mintFeeWei()` reverts with "insufficient mint fee".
- Collections auto-index on OpenSea within minutes of the first mint: `https://opensea.io/assets/base/<contract>/<tokenId>`.

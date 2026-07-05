// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC2981} from "@openzeppelin/contracts/interfaces/IERC2981.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {OxidationMath} from "./OxidationMath.sol";

/// ─────────────────────────────────────────────────────────────────────
///  THE PATINA
///
///  999 procedural metal surfaces that live entirely on-chain.
///  They oxidise continuously. A polish arrests decay for 30 days.
///  Nothing reverses.
///
///  There is no owner() here. No admin functions. No upgrade path.
///  The artist address is immutable and holds exactly two powers:
///  receive payments, and place the 100 curated surfaces. Neither
///  power can change any rule of the system, for anyone, ever.
///
///  The image is not a file. It is the render() function below,
///  evaluated at read time, free, forever. Kill every website on
///  earth and this contract keeps drawing rust.
///
///  A Ciridium Labs experiment. Polish arrests. Nothing reverses.
/// ─────────────────────────────────────────────────────────────────────
contract Patina is ERC721, IERC2981 {
    using OxidationMath for OxidationMath.Surface;
    using Strings for uint256;

    uint256 public constant MAX_SUPPLY = 999;
    uint256 public constant CURATED_RESERVE = 100;
    uint256 public constant PRICE = 0.015 ether;
    uint256 public constant ROYALTY_BPS = 500; // 5%

    /// Immutable. Not an admin key: can receive money and place the
    /// curated 100. Cannot pause, upgrade, reprice, or touch anyone
    /// else's surface.
    address public immutable artist;

    uint256 public totalMinted;
    uint256 public curatedMinted;

    mapping(uint256 => OxidationMath.Surface) private _surfaces;

    event Minted(uint256 indexed tokenId, address indexed to, bool curated);
    event Polished(uint256 indexed tokenId, uint256 settledDepth, uint32 polishCount);

    error SoldOut();
    error WrongPayment();
    error NotYourSurface();
    error ReserveExhausted();
    error OnlyArtist();
    error PaymentFailed();

    constructor(address artist_) ERC721("The Patina", "RUST") {
        artist = artist_;
    }

    // ── MINT ─────────────────────────────────────────────────────────
    // Push-payment: the contract never holds a balance. msg.value
    // forwards to the artist inside the same transaction. There is
    // nothing here to drain because nothing is ever here.

    function mint() external payable returns (uint256 tokenId) {
        uint256 publicMinted = totalMinted - curatedMinted;
        uint256 publicSupply = MAX_SUPPLY - CURATED_RESERVE;
        if (publicMinted >= publicSupply) revert SoldOut();
        if (msg.value != PRICE) revert WrongPayment();

        tokenId = totalMinted;
        totalMinted += 1;

        _surfaces[tokenId].initialize(block.timestamp);
        _mint(msg.sender, tokenId);
        emit Minted(tokenId, msg.sender, false);

        (bool ok, ) = artist.call{value: msg.value}("");
        if (!ok) revert PaymentFailed();
    }

    /// The 100 hand-placed surfaces. Sent, not airdropped.
    function curatedMint(address to) external returns (uint256 tokenId) {
        if (msg.sender != artist) revert OnlyArtist();
        if (curatedMinted >= CURATED_RESERVE) revert ReserveExhausted();
        if (totalMinted >= MAX_SUPPLY) revert SoldOut();

        tokenId = totalMinted;
        totalMinted += 1;
        curatedMinted += 1;

        _surfaces[tokenId].initialize(block.timestamp);
        _mint(to, tokenId);
        emit Minted(tokenId, to, true);
    }

    // ── POLISH ───────────────────────────────────────────────────────

    function polish(uint256 tokenId) external {
        if (ownerOf(tokenId) != msg.sender) revert NotYourSurface();
        _surfaces[tokenId].applyPolish(block.timestamp);
        OxidationMath.Surface memory s = _surfaces[tokenId];
        emit Polished(tokenId, s.settledDepth, s.polishCount);
    }

    // ── VIEWS ────────────────────────────────────────────────────────

    function depthOf(uint256 tokenId) public view returns (uint256) {
        _requireOwned(tokenId);
        return _surfaces[tokenId].totalDepth(block.timestamp);
    }

    function surfaceOf(uint256 tokenId)
        external
        view
        returns (uint64 lastPolished, uint32 settledDepth, uint32 polishCount, uint256 liveDepth, bool arrested)
    {
        _requireOwned(tokenId);
        OxidationMath.Surface memory s = _surfaces[tokenId];
        return (
            s.lastPolished,
            s.settledDepth,
            s.polishCount,
            s.totalDepth(block.timestamp),
            s.isArrested(block.timestamp)
        );
    }

    // ── RENDER ───────────────────────────────────────────────────────
    // The image. Not a file. A formula with a clock inside it.

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireOwned(tokenId);
        OxidationMath.Surface memory s = _surfaces[tokenId];
        uint256 depth = s.totalDepth(block.timestamp);
        bool arrested = s.isArrested(block.timestamp);

        string memory svg = render(tokenId, depth, arrested);
        string memory json = string.concat(
            '{"name":"Surface #', tokenId.toString(),
            '","description":"A metal surface that oxidises on-chain. Polish arrests. Nothing reverses.",',
            '"attributes":[',
                '{"trait_type":"Depth","value":', depth.toString(), '},',
                '{"trait_type":"Polish Count","value":', uint256(s.polishCount).toString(), '},',
                '{"trait_type":"State","value":"', arrested ? "arrested" : "oxidising", '"}',
            '],',
            '"image":"data:image/svg+xml;base64,', Base64.encode(bytes(svg)), '"}'
        );
        return string.concat("data:application/json;base64,", Base64.encode(bytes(json)));
    }

    /// Deterministic per-token seed. Fixed at deploy, forever.
    function seedOf(uint256 tokenId) public view returns (bytes32) {
        return keccak256(abi.encodePacked(tokenId, address(this)));
    }

    /// Public so the patina clock (renderer/preview.html) and anyone
    /// else can call it directly. Depth in, rust out.
    function render(uint256 tokenId, uint256 depth, bool arrested)
        public
        view
        returns (string memory)
    {
        bytes32 seed = seedOf(tokenId);

        // Base metal shifts from gleaming silver to deep oxide as
        // depth approaches MAX_DEPTH. Integer lerp, no surprises.
        uint256 t1000 = (depth * 1000) / OxidationMath.MAX_DEPTH; // 0..1000
        string memory base = _rgb(
            _lerp(196, 94, t1000),
            _lerp(199, 62, t1000),
            _lerp(203, 34, t1000)
        );

        // Rust blooms: up to 24 patches, count scales with depth.
        // Positions and sizes are carved from the seed, so every
        // surface rusts in its own pattern. Bounded loop, view-safe.
        uint256 patches = (depth * 24) / OxidationMath.MAX_DEPTH;
        string memory blooms = "";
        for (uint256 i = 0; i < patches; i++) {
            uint256 h = uint256(keccak256(abi.encodePacked(seed, i)));
            uint256 cx = 32 + (h % 448);
            uint256 cy = 32 + ((h >> 32) % 448);
            uint256 r  = 12 + ((h >> 64) % 52);
            uint256 shade = (h >> 96) % 3;
            string memory fill = shade == 0 ? "#8a4b1f" : shade == 1 ? "#6e3a14" : "#a05c2c";
            blooms = string.concat(
                blooms,
                '<circle cx="', cx.toString(), '" cy="', cy.toString(),
                '" r="', r.toString(), '" fill="', fill, '" fill-opacity="0.62"/>'
            );
        }

        // A recently polished plate carries a thin bright edge:
        // the visible mark of being tended. It fades when the
        // arrest window lapses. Legibility of care, at a glance.
        string memory edge = arrested
            ? '<rect x="6" y="6" width="500" height="500" fill="none" stroke="#f5f2ea" stroke-opacity="0.85" stroke-width="3"/>'
            : "";

        return string.concat(
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512">',
            '<rect width="512" height="512" fill="', base, '"/>',
            blooms,
            edge,
            '</svg>'
        );
    }

    function _lerp(uint256 a, uint256 b, uint256 t1000) private pure returns (uint256) {
        // a and b are 0..255; t1000 is 0..1000. Handles a > b and a < b.
        if (a >= b) return a - ((a - b) * t1000) / 1000;
        return a + ((b - a) * t1000) / 1000;
    }

    function _rgb(uint256 r, uint256 g, uint256 b) private pure returns (string memory) {
        return string.concat("rgb(", r.toString(), ",", g.toString(), ",", b.toString(), ")");
    }

    // ── ROYALTIES (ERC-2981) ─────────────────────────────────────────

    function royaltyInfo(uint256, uint256 salePrice)
        external
        view
        returns (address receiver, uint256 royaltyAmount)
    {
        return (artist, (salePrice * ROYALTY_BPS) / 10000);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, IERC165)
        returns (bool)
    {
        return interfaceId == type(IERC2981).interfaceId || super.supportsInterface(interfaceId);
    }
}

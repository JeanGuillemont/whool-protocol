// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "../lib/openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721Royalty.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "../lib/openzeppelin-contracts/contracts/security/Pausable.sol";
import "../lib/openzeppelin-contracts/contracts/utils/Base64.sol";
import "../lib/openzeppelin-contracts/contracts/utils/Strings.sol";

/**
 * @title Whool
 * @author JeanGuillemont, forked and customized from the work of bernat.eth,
 * @notice This contract implements the Whool protocol, which allows for the creation and management of unique whool NFTs that map to URLs.
 * Each whool is associated with a unique URL.
 * Random whools can be generated at no cost (other than gas fees), while custom whools entail a mint fee.
 * The contract also includes functionality for referrers to earn a share of mint fees.
 */

contract Whool is ERC721Royalty, ERC721Enumerable, Pausable, Ownable {
    struct WhoolData {
        string whool;
        bool isCustom;
    }

    uint256 public idCounter;
    uint256 public referrerFeeBips;
    mapping(string => string) public urls;
    mapping(string => uint256) public whoolToTokenId;
    mapping(uint256 => WhoolData) public tokenIdToWhoolData;
    mapping(address => uint256) public balances;
    

    event NewWhool(address indexed sender, string url, string whool, uint256 tokenId, bool isCustom, address referrer);

    bytes constant CHARSET = "0123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"; // 58 chars
    uint256 constant MAX_FEE = 10000;

    constructor()
        ERC721(
            "Whools", // Name of token
            "WHOOLs" // Symbol of token
        )
    {
        idCounter = 0;
        _setDefaultRoyalty(owner(), 100);
        referrerFeeBips = 30 * 100; // 30%
    }

    ///////////// Transactional methods /////////////

    /**
     * @notice Mint a new whool.
     * @dev Referrer is required but can be the zero address.
     *
     * Requirements:
     * - `url` cannot be empty.
     * - `whool` must not already exist.
     * - `referrer` cannot be the sender.
     *
     * Random whools are generated when whool is an empty string, and can be created at no cost.
     * If a custom whool is provided, an ETH amount equal or greater to the mint fee needs to be provided.
     *
     * Emits a {NewWhool} event.
     *
     * @param url The URL associated with the new whool.
     * @param whool The custom whool to be created. If empty, a random whool is generated.
     * @return Returns the whool that was created.
     * @param referrer The address of the referrer. Can be the zero address.
     */
    function mintWhool(string memory url, string memory whool, address referrer)
        public
        payable
        whenNotPaused
        returns (string memory)
    {
        require(bytes(url).length > 0, "URL cannot be empty");
        require(bytes(urls[whool]).length == 0, "whool already exists");
        require(msg.sender != referrer, "Referrer cannot be sender");

        bool isCustom;

        // If no custom whool provided, generate an available random one
        if (bytes(whool).length == 0) {
            whool = generateAvailableWhool();
            isCustom = false;
        // Custom whool
        } else {
            isCustom = true;
            handleCustomWhoolPayment(whool, referrer);
        }

        // Register whool -> url mapping
        _mintWhool(whool, url, isCustom);

        emit NewWhool(msg.sender, url, whool, idCounter, isCustom, referrer);
        return whool;
    }

    /**
     * @dev Edits the URL of a whool.
     *
     * Requirements:
     * - `tokenId` must be owned by the caller.
     * - `newUrl` cannot be empty.
     *
     * @param tokenId The ID of the token (whool) to edit.
     * @param newUrl The new URL to associate with the whool.
     */
    function editUrl(uint256 tokenId, string memory newUrl) public {
        require(ownerOf(tokenId) == msg.sender, "Caller is not owner nor approved");
        require(bytes(newUrl).length > 0, "URL cannot be empty");

        string memory whool = tokenIdToWhoolData[tokenId].whool;
        urls[whool] = newUrl;
    }

        /**
     * @dev Claims the ETH balance associated with the caller's address.
     *
     * Requirements:
     * - The caller must have a non-zero balance.
     *
     * Emits a {Transfer} event.
     */
    function claimBalance() public {
        uint256 balance = balances[msg.sender];
        require(balance > 0, "No balance to claim");
        balances[msg.sender] = 0;
        payable(msg.sender).transfer(balance);
    }

    receive() external payable {
        balances[owner()] += msg.value;
    }

    ///////////// Private methods /////////////

    // Generate an available random whool
    function generateAvailableWhool() private view returns (string memory) {
        string memory whool = generateWhool(idCounter);

        // avoid collisions
        while (bytes(urls[whool]).length != 0) {
            whool = incrementWhool(whool);
        }

        return whool;
    }

    // Generate a random whool
    function generateWhool(uint256 seed) private pure returns (string memory) {
        uint256 hash = uint256(keccak256(abi.encodePacked(seed)));
        string memory whool = "";
        for (uint8 i = 0; i < 8; i++) {
            whool = string(abi.encodePacked(whool, CHARSET[hash % 58])); // charset is 58 chars long
            hash = hash >> 6; // 2 ** 6 > 58 > 2 ** 5
        }
        return whool;
    }

    // Given a whool, increment it by 1 character covering the entire combinatorial charset space
    function incrementWhool(string memory whool) private pure returns (string memory) {
        bytes memory b = bytes(whool);
        for (uint8 i = 7; i >= 0; i--) {
            if (b[i] != CHARSET[57]) {
                b[i] = getNextChar(b[i]);
                return string(b);
            } else {
                b[i] = CHARSET[0]; // Reset to the first character in the CHARSET
            }
        }
        return "00000000";  // This will only be hit if all characters in the whool are the last character in CHARSET.
    }

    function getNextChar(bytes1 char) private pure returns (bytes1) {
        for (uint8 i = 0; i < 57; i++) {
            if (CHARSET[i] == char) {
                return CHARSET[i + 1];
            }
        }
        // If provided with the last character in the CHARSET, just return it.
        return char;
    }

    function handleCustomWhoolPayment(string memory whool, address referrer) private {
        uint256 whoolLength = bytes(whool).length;
        uint256 cost = getWhoolCost(whoolLength);
        require(msg.value >= cost, "Insufficient payment");

        if (msg.value > cost) {
            payable(msg.sender).transfer(msg.value - cost);
        }

        if (referrer == address(0)) {
            referrer = owner();
        }

        uint256 referrerFees = cost * referrerFeeBips / MAX_FEE;
        balances[referrer] += referrerFees;
        balances[owner()] += cost - referrerFees;
    }

    function _mintWhool(string memory whool, string memory url, bool isCustom) private {
        urls[whool] = url;
        idCounter++;
        _mint(msg.sender, idCounter);
        whoolToTokenId[whool] = idCounter;
        tokenIdToWhoolData[idCounter] = WhoolData(whool, isCustom);
    }

    

    ///////////// Public view methods /////////////

    /**
     * @notice Fetches the token ID associated with a given whool.
     * @dev This function requires that the whool is not empty and exists.
     * @param whool The whool for which to fetch the token ID.
     * @return Returns the token ID associated with the given whool.
     */
    function getTokenId(string memory whool) public view returns (uint256) {
        require(bytes(whool).length > 0, "Whool cannot be empty");
        require(bytes(urls[whool]).length > 0, "Whool does not exist");
        return whoolToTokenId[whool];
    }

    /**
     * @notice Fetches the URL associated with a given whool.
     * @dev This function requires that the whool is not empty and exists.
     * @param whool The whool for which to fetch the URL.
     * @return Returns the URL associated with the given whool.
     */
    function getURL(string memory whool) public view returns (string memory) {
        require(bytes(whool).length > 0, "Whool cannot be empty");
        require(bytes(urls[whool]).length > 0, "Whool does not exist");
        return urls[whool];
    }

    /**
     * @param whoolLength The length of the whool.
     * @return Returns the cost of the whool in ether.
     */
    function getWhoolCost(uint256 whoolLength) public pure returns (uint256) {
        return 0.001 ether;
    }

    /**
     * @notice Returns a URI for a given token ID
     * @dev Overrides ERC721's tokenURI() with metadata that includes the whool and its attributes
     * @param tokenId The ID of the token to query
     * @return A string containing the URI of the given token ID
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        bytes memory svg = generateSVG(tokenId);

        // Encode SVG to base64
        string memory base64Svg = Base64.encode(svg);

        // Generate JSON metadata
        string memory json = Base64.encode(
            bytes(
                string(
                    abi.encodePacked(
                        "{",
                        '"name": "/',
                        tokenIdToWhoolData[tokenId].whool,
                        '",',
                        '"description": "A long URL rolled into a small w(h)ool ball.",',
                        '"image": "data:image/svg+xml;base64,',
                        base64Svg,
                        '",',
                        '"attributes": [{"trait_type": "Custom", "value": "',
                        (tokenIdToWhoolData[tokenId].isCustom ? "Yes" : "No"),
                        '"}, {"trait_type": "Whool Length", "display_type": "number", "value": ',
                        Strings.toString(bytes(tokenIdToWhoolData[tokenId].whool).length),
                        "}]",
                        "}"
                    )
                )
            )
        );

        return string(abi.encodePacked("data:application/json;base64,", json));
    }

    function generateSVG(uint256 tokenId) internal view returns (bytes memory) {
            WhoolData memory data = tokenIdToWhoolData[tokenId];
            bytes memory whool = bytes(data.whool);

            uint256 fontSize = (whool.length <= 12) ? 24 : (whool.length >= 36) ? 8 : 16;
            uint256 color = uint256(keccak256(abi.encodePacked(tokenId))) % 361;
        
            string memory background = string(abi.encodePacked("hsl(", Strings.toString(color), ", 90%, 90%)"));
            string memory foreground = string(abi.encodePacked("hsl(", Strings.toString(color), ", 50%, 40%)"));
        
            bytes memory text = abi.encodePacked(
                '<text x="32%" y="56%" font-family="Roboto" font-size="16" font-weight="300" fill="',
                foreground,
                '">/',
                data.whool,
                "</text>"
            );

            bytes memory title = abi.encodePacked(
                '<text x="75%" y="90%" font-family="Roboto" font-size="24" font-weight="700" fill="',
                foreground,
                '">',
                "Whools</text>"
            );
        
            // Add the new SVG data to the existing text and logo variables
            bytes memory svg = abi.encodePacked(
                '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 500 500"><rect x="0" y="0" width="500" height="500" fill="',background,'" /><path d="M58 190c-10 3-22 10-28 19-23 29-8 71 28 80h412v-4H308l-161-1v-3c4-8 0-18-8-22-3-1-9-1-13 1-3 1-7 6-8 10s0 9 1 12l2 2H93l3-2c5-3 13-11 16-17 13-20 9-46-8-63-6-5-11-7-18-10l-14-3-14 1Zm32 15c19 18 23 22 24 25v4l-20-20-20-19h3c3 0 4 2 13 10Zm-4 18 27 27-1 2v2l-29-28-28-29c3-2 4-2 31 26Zm-10 10 31 32-2 1-1 2-5-5-5-5-13 13-14 13h-4c-1 0 0-2 13-15l14-14-4-5-5-5-17 16-18 17-2-1-1-2 17-17 17-16-5-5-5-5-17 17-17 17-1-2-2-1 17-17 17-17-5-6-5-5-14 15-15 13v-2c-1-2 0-3 12-16l14-12-5-6-5-6 3-2 32 31Zm62 32c7 3 8 14 1 18-4 2-10 1-13-1-2-2-3-5-3-7 0-9 7-14 15-10Z" style="fill:',foreground,'"/>',
                text,
                title,
                "</svg>"            
                );
        
            return svg;
        }

    ///////////// Owner methods /////////////
    function rescueERC20(address token) external onlyOwner {
        IERC20 erc20Token = IERC20(token);
        uint256 balance = erc20Token.balanceOf(address(this));
        require(balance > 0, "No token balance in the contract");
        erc20Token.transfer(owner(), balance);
    }

    function rescueERC721(address token, uint256 tokenId) external onlyOwner {
        IERC721 erc721Token = IERC721(token);
        require(erc721Token.ownerOf(tokenId) == address(this), "The token is not owned by the contract");
        erc721Token.safeTransferFrom(address(this), owner(), tokenId);
    }
    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    // Override functions

    function supportsInterface(bytes4 interfaceId)
    public view virtual override(ERC721Enumerable, ERC721Royalty)
    returns (bool) {
      return super.supportsInterface(interfaceId);
  }

    function _burn(uint256 tokenId) internal virtual override (ERC721, ERC721Royalty) {
        super._burn(tokenId);
        _resetTokenRoyalty(tokenId);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 firstTokenId,
        uint256 batchSize
    ) internal virtual override (ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, firstTokenId, batchSize);

        require(!paused(), "ERC721Pausable: token transfer while paused");
        if (batchSize > 1) {
            // Will only trigger during construction. Batch transferring (minting) is not available afterwards.
            revert("ERC721Enumerable: consecutive transfers not supported");
        }

    }
    


}

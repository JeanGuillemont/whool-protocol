// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../lib/openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "../lib/openzeppelin-contracts/contracts/security/Pausable.sol";
import "../lib/openzeppelin-contracts/contracts/utils/Base64.sol";
import "../lib/openzeppelin-contracts/contracts/utils/Strings.sol";

/**
 * @title Whool
 * @author bernat.eth, forked and customized by JeanGuillemont
 * @notice This contract implements the Whool protocol, which allows for the creation and management of unique whool NFTs that map to URLs.
 * Each whool is associated with a unique URL.
 * Random whools can be generated at no cost (other than gas fees), while custom whools entail a mint fee.
 */

contract Whool is ERC721Enumerable, Ownable, Pausable {
    struct WhoolData {
        string whool;
        bool isCustom;
    }

    uint256 public idCounter;
    mapping(string => string) public urls;
    mapping(string => uint256) public whoolToTokenId;
    mapping(uint256 => WhoolData) public tokenIdToWhoolData;
    mapping(address => uint256) public balances;

    event NewWhool(address indexed sender, string url, string whool, uint256 tokenId, bool isCustom);

    bytes constant CHARSET = "0123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"; // 58 chars
    uint256 constant MAX_FEE = 10000;

    constructor()
        ERC721(
            "Whool", // Name of token
            "WHOOL" // Symbol of token
        )
    {
        idCounter = 0;
    }

    ///////////// Transactional methods /////////////

    /**
     * @notice Mint a new whool.
     *
     * Requirements:
     * - `url` cannot be empty.
     * - `whool` must not already exist.
     *
     * Random whools are generated when whool is an empty string, and can be created at no cost.
     * If a custom whool is provided, an ETH amount equal or greater to the mint fee needs to be provided.
     *
     * Emits a {NewWhool} event.
     *
     * @param url The URL associated with the new whool.
     * @param whool The custom whool to be created. If empty, a random whool is generated.
     * @return Returns the whool that was created.
     */
    function mintWhool(string memory url, string memory whool)
        public
        payable
        whenNotPaused
        returns (string memory)
    {
        require(bytes(url).length > 0, "URL cannot be empty");
        require(bytes(urls[whool]).length == 0, "whool already exists");

        bool isCustom;

        // If no custom whool provided, generate an available random one
        if (bytes(whool).length == 0) {
            whool = generateAvailableWhool();
            isCustom = false;
        // Custom whool
        } else {
            isCustom = true;
            handleCustomWhoolPayment(whool);
        }

        // Register whool -> url mapping
        _mintWhool(whool, url, isCustom);

        emit NewWhool(msg.sender, url, whool, idCounter, isCustom);

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

    function handleCustomWhoolPayment(string memory whool) private {
        uint256 whoolLength = bytes(whool).length;
        uint256 cost = getWhoolCost(whoolLength);
        require(msg.value >= cost, "Insufficient payment");

        if (msg.value > cost) {
            payable(msg.sender).transfer(msg.value - cost);
        }

        balances[owner()] += cost;
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
    function getWhoolCost(uint256 whoolLength) public view returns (uint256) {
        return 0.000777 ether;
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
                        '"description": "A long URL rolled into small whool ball.",',
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
        
            uint256 color = uint256(keccak256(abi.encodePacked(tokenId))) % 361;
        
            string memory background = string(abi.encodePacked("hsl(", Strings.toString(color), ", 90%, 90%)"));
            string memory foreground = string(abi.encodePacked("hsl(", Strings.toString(color), ", 50%, 40%)"));
        
            bytes memory text = abi.encodePacked(
                '<text x="20%" y="53%" font-family="Roboto" font-size="18" font-weight="100" fill="',
                foreground,
                '">/',
                data.whool,
                "</text>"
            );

            bytes memory title = abi.encodePacked(
                '<text x="85%" y="95%" font-family="Roboto" font-size="12" font-weight="50" fill="',
                foreground,
                '">',
                "Whools</text>"
            );
        
            // Add the new SVG data to the existing text and logo variables
            bytes memory svg = abi.encodePacked(
                '<svg xmlns="http://www.w3.org/2000/svg" width="432" height="432" viewBox="0 0 312 324"><rect x="0" y="0" width="432" height="432" fill="',background,'" /><path d="M241 16c-2 0-6 3-8 5-14 13-4 35 14 35 13 0 21-8 21-20 0-10-6-19-16-21-5-1-5-1-11 1zM141 46A124 124 0 0 0 32 191c11 48 44 83 91 95l7 2H63l-2 2c-2 2-2 4-2 11 0 8 0 9 2 11 5 5 14 1 14-6v-2h40c47 1 44 2 45-9l1-5 7-1c16-2 36-9 52-19a122 122 0 0 0-79-224zm4 54v36h-29v-34l1-33 3-2 21-4h4v37zm35-34 8 2v68h-28V63h6l14 3zm38 19c14 12 26 27 33 46l2 5h-49V76l4 2 10 7zm-118 22v29H52l3-7c5-14 13-26 25-38l19-14 1 30zm157 53v20H48l-1-5v-14l1-9h208l1 8zm-4 39-7 15-5 11H64l-4-6-6-15-3-8h202v3zm-151 51-1 9c-2 0-13-8-18-13l-6-5h25v9zm41 7c0 14 0 15-2 15l-21-4-3-2v-25h26v16zm42-3v14l-7 2-13 2h-6v-31h26v13zm38-8c-5 4-19 14-21 14l-1-9v-10h27l-5 5zm2-191-3 6 6 4 7 4 3-5 3-5-3-2-6-4-4-3-3 5zm49-1a21 21 0 0 0 7 40c16 1 28-15 21-30-5-10-18-15-28-10zm-19 29-3 4 4 7 4 5 4-3 4-4-3-5-4-6c0-2-1-1-6 2z" style="fill:',foreground,'"/>',
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
}

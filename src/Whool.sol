pragma solidity ^0.8.13;

import "openzeppelin-contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "openzeppelin-contracts/token/ERC721/IERC721.sol";
import "openzeppelin-contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/access/Ownable.sol";
import "openzeppelin-contracts/security/Pausable.sol";
import "openzeppelin-contracts/utils/Base64.sol";
import "openzeppelin-contracts/utils/Strings.sol";

/**
 * @title Whool
 * @author bernat.eth, forked and customized by JeanGuillemont
 * @notice This contract implements the Whool protocol, which allows for the creation and management of unique whool NFTs that map to URLs.
 * Each whool is associated with a unique URL.
 * Random whools can be generated at no cost (other than gas fees), while custom whools entail a mint fee.
 */

contract Whool is ERC721Enumerable, Ownable, Pausable {
    struct WhoolData {
        string Whool;
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
     * If a custom whool is provided, an ETH amount equal or greater to the mint fee needs to be provided. See getWhoolCost for more details.
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
        require(bytes(urls[Whool]).length > 0, "Whool does not exist");
        return urls[Whool];
    }

    /**
     * @notice Calculates the cost of a whool based on its length.
     * @dev The cost is determined by a set of predefined rules.
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
                        '"description": "A unique short whool for a long URL.",',
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
        
            uint256 fontSize = (whool.length <= 12) ? 96 : (whool.length >= 48) ? 1 : 96 - (2 * whool.length);
            uint256 color = uint256(keccak256(abi.encodePacked(tokenId))) % 361;
        
            string memory background = string(abi.encodePacked("hsl(", Strings.toString(color), ", 90%, 90%)"));
            string memory foreground = string(abi.encodePacked("hsl(", Strings.toString(color), ", 50%, 40%)"));
        
            bytes memory text = abi.encodePacked(
                '<text x="10%" y="40%" font-family="Helvetica" font-size="',
                Strings.toString(fontSize),
                '" font-weight="700" fill="',
                foreground,
                '">/',
                data.whool,
                "</text>"
            );
        
            // Add the new SVG data to the existing text and logo variables
            bytes memory svg = abi.encodePacked(
                '<svg width="512" height="512" xmlns="http://www.w3.org/2000/svg" xml:space="preserve"><g class="layer"><path d="M375 371a169 169 0 1 0-239-1c65 66 172 67 239 1zm-223-16h30v23c-11-6-21-14-30-23zm52 33v-33h40v42c-14-1-27-4-40-9zm62 9v-41h41l-1 33c-13 5-26 7-40 8zm62-18 1-23h30c-10 9-20 16-31 23zm33-231c17 17 29 39 36 61h-67v-85c11 6 21 14 31 24zm-53-34v95h-41l1-104c14 1 27 4 40 9zm-62-9-1 104h-40l1-96c13-5 26-7 40-8zm-93 42c9-10 20-17 31-24l-1 86-67-1c7-22 19-44 37-61zm-42 83 291 1c1 14 1 27-1 41l-291-1c-1-14-1-27 1-41zm4 63 281 1c-4 14-10 27-19 40l-243-1c-9-13-15-26-19-40z"/><path d="m375 69 18 12-21 34-19-12z"/><circle cx="389.3" cy="68" stroke="',background,'" stroke-width="4" r="31.4"/><path d="m427 116 12 18-33 23-12-18z"/><circle cx="439.4" cy="120.6" stroke="',background,'" stroke-width="4" r="31.4"/><rect height="35.7" rx="10" ry="10" stroke=""',foreground,'"" stroke-linecap="round" stroke-linejoin="round" width="21.4" x="245.1" y="408"/><rect height="138.8" rx="10" ry="10" stroke="',foreground,'" stroke-linecap="round" stroke-linejoin="round" transform="rotate(91 197 433)" width="21.4" x="186.3" y="363.9"/><rect height="35.7" rx="10" ry="10" stroke="',foreground,'" stroke-linecap="round" stroke-linejoin="round" width="21.4" x="125.6" y="422.1"/></g></svg>'
            );
        
            // Concatenate the new SVG data with the existing text and logo variables
            svg = abi.encodePacked(svg, text);
        
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

# Whool 
**Inherits:**
ERC721Enumerable, Ownable, Pausable, ERC721Royalty

**Author:**
JeanGuillemont, forked and customized from slugs by bernat.eth

This contract implements the Whools protocol, which allows for the creation and management of unique whool NFTs that map to URLs.
Each whool is associated with a unique URL.
Random whools can be generated at no cost (other than gas fees), while custom whools entail a mint fee.
The contract also includes functionality for referrers to earn a share of mint fees.


## State Variables
### idCounter

```solidity
uint256 public idCounter;
```


### referrerFeeBips

```solidity
uint256 public referrerFeeBips;
```


### urls

```solidity
mapping(string => string) public urls;
```


### whoolToTokenId

```solidity
mapping(string => uint256) public whoolToTokenId;
```


### tokenIdToWhoolData

```solidity
mapping(uint256 => WhoolData) public tokenIdToWhoolData;
```


### balances

```solidity
mapping(address => uint256) public balances;
```


### CHARSET

```solidity
bytes constant CHARSET = "0123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz";
```


### MAX_FEE

```solidity
uint256 constant MAX_FEE = 10000;
```


## Functions
### constructor


```solidity
constructor() ERC721("Whools", "WHOOLS");
```

### mintWhool

Mint a new whool.

*Referrer is required but can be the zero address.
Requirements:
- `url` cannot be empty.
- `whool` must not already exist.
- `referrer` cannot be the sender.
Random whools are generated when whool is an empty string, and can be created at no cost.
If a custom whool is provided, an ETH amount equal or greater to the mint fee needs to be provided. See getWhoolCost for more details.
Emits a {NewWhool} event.*


```solidity
function mintWhool(string memory url, string memory whool, address referrer)
    public
    payable
    whenNotPaused
    returns (string memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`url`|`string`|The URL associated with the new whool.|
|`whool`|`string`|The custom whool to be created. If empty, a random whool is generated.|
|`referrer`|`address`|The address of the referrer. Can be the zero address.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|Returns the whool that was created.|


### editUrl

*Edits the URL of a whool.
Requirements:
- `tokenId` must be owned by the caller.
- `newUrl` cannot be empty.*


```solidity
function editUrl(uint256 tokenId, string memory newUrl) public;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tokenId`|`uint256`|The ID of the token (whool) to edit.|
|`newUrl`|`string`|The new URL to associate with the whool.|


### claimBalance

*Claims the ETH balance associated with the caller's address.
Requirements:
- The caller must have a non-zero balance.
Emits a {Transfer} event.*


```solidity
function claimBalance() public;
```

### receive


```solidity
receive() external payable;
```

### generateAvailableWhool


```solidity
function generateAvailableWhool() private view returns (string memory);
```

### generateWhool


```solidity
function generateWhool(uint256 seed) private pure returns (string memory);
```

### incrementWhool


```solidity
function incrementWhool(string memory Whool) private pure returns (string memory);
```

### isValidWhool


```solidity
function isValidWhool(string memory whool) private pure returns (bool);
```

### handleCustomWhoolPayment


```solidity
function handleCustomWhoolPayment(string memory whool, address referrer) private;
```

### _mintWhool


```solidity
function _mintWhool(string memory whool, string memory url, bool isCustom) private;
```

### getTokenId

Fetches the token ID associated with a given whool.

*This function requires that the whool is not empty and exists.*


```solidity
function getTokenId(string memory whool) public view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`whool`|`string`|The whool for which to fetch the token ID.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Returns the token ID associated with the given whool.|


### getURL

Fetches the URL associated with a given whool.

*This function requires that the whool is not empty and exists.*


```solidity
function getURL(string memory whool) public view returns (string memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`whool`|`string`|The whool for which to fetch the URL.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|Returns the URL associated with the given whool.|


### getWhoolCost

Get the standard whool cost for custom whools.

*The cost is set at 0.001eth*


```solidity
function getWhoolCost(uint256 whoolLength) public pure returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`whoolLength`|`uint256`|The length of the whool.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Returns the cost of the swhool in ether.|


### tokenURI

Returns a URI for a given token ID

*Overrides ERC721's tokenURI() with metadata that includes the whool and its attributes*


```solidity
function tokenURI(uint256 tokenId) public view override returns (string memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tokenId`|`uint256`|The ID of the token to query|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|A string containing the URI of the given token ID|


### generateSVG


```solidity
function generateSVG(uint256 tokenId) internal view returns (bytes memory);
```

### rescueERC20


```solidity
function rescueERC20(address token) external onlyOwner;
```

### rescueERC721


```solidity
function rescueERC721(address token, uint256 tokenId) external onlyOwner;
```

### modifyReferrerFee


```solidity
function modifyReferrerFee(uint256 fee) external onlyOwner;
```

### pause


```solidity
function pause() external onlyOwner;
```

### unpause


```solidity
function unpause() external onlyOwner;
```

## Events
### NewWhool

```solidity
event NewWhool(address indexed sender, string url, string whool, uint256 tokenId, bool isCustom, address referrer);
```

## Structs
### WhoolData

```solidity
struct WhoolData {
    string whool;
    bool isCustom;
}
```


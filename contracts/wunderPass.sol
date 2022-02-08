// SPDX-License-Identifier: MIT

// ██╗    ██╗██╗   ██╗███╗   ██╗██████╗ ███████╗██████╗  ██████╗  █████╗ ███████╗███████╗
// ██║    ██║██║   ██║████╗  ██║██╔══██╗██╔════╝██╔══██╗ ██╔══██╗██╔══██╗██╔════╝██╔════╝
// ██║ █╗ ██║██║   ██║██╔██╗ ██║██║  ██║█████╗  ██████╔╝ ██████╔╝███████║███████╗███████╗
// ██║███╗██║██║   ██║██║╚██╗██║██║  ██║██╔══╝  ██╔══██╗ ██╔═══╝ ██╔══██║╚════██║╚════██║
// ╚███╔███╔╝╚██████╔╝██║ ╚████║██████╔╝███████╗██║  ██║ ██║     ██║  ██║███████║███████║
//  ╚══╝╚══╝  ╚═════╝ ╚═╝  ╚═══╝╚═════╝ ╚══════╝╚═╝  ╚═╝ ╚═╝     ╚═╝  ╚═╝╚══════╝╚══════╝

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./external/WunderSafeMath.sol";

/** @title WunderPass 
  * @author The WunderPass Team
*/
contract WunderPass is ERC721, VRFConsumerBase, AccessControl, Ownable, Pausable {
    
    /// @notice WunderSafeMath used for mul, div, add, sub, mod
    using WunderSafeMath for uint256;    

    /// @notice Counter used for tokenIds
    using Counters for Counters.Counter;
    Counters.Counter private tokenIds;
    
    /// @notice Defining roles used by Access Control
    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    /// @notice Declaring Variables for Random Number Generation
    uint256 internal chainlinkFee = 0.0001 * 10 ** 18; // 0.0001 LINK 
    bytes32 internal keyHash = 0xf86195cf7690c55907b2b611ebb7343a6f649bff128701cc542f0569e2c549da;
    address internal VRFCoordinator = 0x3d2341ADb2D31f1c5530cDC622016af293177AE0;
    address internal linkToken = 0xb0897686c545045aFc77CF20eC7A532E3120E0F1;

    /// @notice OpenSea Whitelist Address
    address internal openSeaProxyAddress = 0x58807baD0B376efc12F5AD86aAc70E78ed67deaE;

    /// @notice Declaring Variables for Price & Edition handling
    uint public publicPrice = 420 * 10 ** 18; // 420 MATIC
    uint public editionThreshold = 100;
    uint public thresholdUpperLimit = 1000;
    mapping(string => Edition) editions;
    struct Edition {
        string name;
        string parent;
        uint counter;
    }

    /// @notice Declaring Variables for NFT Mapping
    /// @dev mapping of requestId to tokenId
    mapping(bytes32 => uint) requestIdToTokenId;
    /// @dev mapping of tokenId to tokenUri
    mapping (uint => string) private _tokenURIs;
    /// @dev mapping of address to tokenIds
    mapping (address => uint[]) private addressToTokenIds;
    /// @dev mapping of tokenId to WunderPass
    mapping(uint => WunderPassProps) tokenIdToWunderPassProps;

    struct WunderPassProps {
        address owner;
        uint tokenId;
        string status;
        string edition;
        string wonder;
        string pattern;
    }

    /// @notice Defining Status, Patterns & Wonders
    string[] statusArray = ["Diamond", "Black", "Pearl", "Platinum", "Ruby", "Gold", "Silver", "Bronze", "White"];
    uint[] statusLimits = [200, 1800, 14600, 117000, 936200, 7489800, 59918600, 479349000, 3834792200];
    
    string[] patterns = ["Curves", "Linear", "Zigzag", "WunderPass", "Stony desert", "Wavy waves", "Pointillism", "Triangular Bars", "Safari Fun"];

    string[] wonders = ["Pyramids of Giza", "Great Wall of China", "Petra", "Colosseum", "Chichen Itza", "Machu Picchu", "Taj Mahal", "Christ the Redeemer"];
    uint[] allocatedWonders = [0, 0, 0, 0, 0, 0, 0, 0];
    uint[] internal possibleWonders;
    uint[] internal possibleWondersRandomnessBounds;
    
    /// @notice Total available wonders per 256 WunderPasses by index
    uint[] internal wonderAllocation = [1, 2, 4, 8, 16, 32, 64, 129];

    /// @notice Defining the WunderPassMinted Event
    event WunderPassMinted(uint indexed tokenId, address indexed owner, string status, string pattern, string wonder, string edition);

    /** @notice Initializes the contract.
      * @dev Grants the deployer OWNER_ROLE and ADMIN_ROLE
      */
    constructor() 
        VRFConsumerBase(VRFCoordinator, linkToken)
        ERC721("WunderPass", "WP")
    {   
        _grantRole(OWNER_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    /** @notice Override isApprovedForAll to auto-approve OS's proxy contract.
      * @dev If OpenSea's ERC721 Proxy Address is detected, auto-return true.
      * @dev Otherwise, use the default ERC721.isApprovedForAll().
      */
    function isApprovedForAll(address _owner, address _operator) public override view returns (bool isOperator) {
        if (_operator == address(openSeaProxyAddress)) {
            return true;
        }
        return ERC721.isApprovedForAll(_owner, _operator);
    }

    /** @notice Sets new editions for the WunderPass.
      * @param _names All possible editions.
      * @param _parents All parents of the editions.
      */
    function extendEditions(string[] memory _names, string[] memory _parents) external onlyRole(OWNER_ROLE) {
        for (uint i = 0; i < _names.length; i++) {
            if (bytes(editions[_names[i]].name).length == 0) {
                editions[_names[i]] = Edition(_names[i], _parents[i], 0);
            }
        }
    }

    /** @notice Mints a WunderPass for a given address.
      * @dev Only callable by an ADMIN account.
      * @param _edition The edition, a user requested.
      * @param _owner The address of a user who will be the owner of the WunderPass.
      */
    function mintForUser(string memory _edition, address _owner) public onlyRole(ADMIN_ROLE) {
        mintInternal(_edition, _owner);
    }

    /** @notice Mints a WunderPass.
      * @dev This is the public mint function.
      * @param _edition The edition, a user requested.
      */
    function mint(string memory _edition) public payable {
        require(msg.value >= publicPrice);
        mintInternal(_edition, msg.sender);
    }

    /** @notice The internal mint function that gets called by mintForUser and mint.
      * @dev Determines Status and edition of the wunderpass and requests a random number from chainlink.
      * @param _edition The edition, passed from mintForUser or mint.
      * @param _owner The owner, passed from mintForUser or mint.
      */
    function mintInternal(string memory _edition, address _owner) internal whenNotPaused() {
        require(bytes(editions[_edition].name).length > 0, "Cant mint NFT without valid edition");
        string memory _statusProp = determineStatus();
        string memory _editionProp = determineEdition(_edition, 1);
        uint tokenId = tokenIds.current();
        bytes32 requestId = getRandomNumber();
        WunderPassProps memory wunderPassProps = WunderPassProps(_owner, tokenId, _statusProp, _editionProp, "", "");
        requestIdToTokenId[requestId] = tokenId;
        tokenIdToWunderPassProps[tokenId] = wunderPassProps;
        _mint(_owner, tokenId);
        tokenIds.increment();
    }

    /** @notice Gets the current tokenId.
      * @return id The current tokenId.
      */
    function currentTokenId() public view returns(uint id) {
        return tokenIds.current();
    }

    /** @notice Determines the status of a WunderPass based on its tokenId.
      * @dev The first 200 WunderPasses will have a Diamond status. The next 1600 WunderPasses will have a Black status etc.
      * @return status The status of the WunderPass.
      */
    function determineStatus() internal returns(string memory status) {
        uint currentId = tokenIds.current();
        for (uint256 index = 0; index < statusArray.length; index++) {
            if (currentId == (statusLimits[index].sub(1))) {
                _pause();
            }
            if (currentId < statusLimits[index]) {
                return statusArray[index];
            }
        }
        return "White";
    }

    /** @notice Determines the edition of a WunderPass based on the requested edition.
      * @dev Editions are limited and if the requested edition is not available anymore, the WunderPass will get the parent edition etc.
      * @dev The editions follow a geographical structure, i.e. World is the parent edition of Europe which is the parent edition of Germany which is the parent edition of Berlin.
      * @dev The World edition is not limited.
      * @param _edition The desired edition.
      * @param _thresholdMultiplier A multiplier that increases with every call. Hence, Europe can be issued more often than Germany which can be issued more often than Berlin etc.
      * @return edition The edition of the WunderPass.
      */
    function determineEdition(string memory _edition, uint _thresholdMultiplier) internal returns(string memory edition) {
        uint editionStepMultiplier = 100;
        Edition storage _desiredEdition = editions[_edition];
        if (keccak256(abi.encodePacked(_desiredEdition.name)) == keccak256(abi.encodePacked(_desiredEdition.parent))) {
            _desiredEdition.counter += 1;
            return _desiredEdition.name;
        }
        if (_desiredEdition.counter >= (editionThreshold.mul(_thresholdMultiplier))) {
            return determineEdition(_desiredEdition.parent, (editionStepMultiplier.mul(_thresholdMultiplier)));
        }
        _desiredEdition.counter += 1;
        return _desiredEdition.name;
    }
    
    /** @notice Determines the wonder of a WunderPass based on randomness and previously issued wonders.
      * @dev For more information on how the wonders are generated, see section 'NFT-Pass' in the White Paper: https://github.com/WunderPass/White-Paper
      * @param randomNumber A random number generated by chainLink.
      * @return wonder The wonder of the WunderPass.
      */
    function determineWonder(uint randomNumber) internal returns(string memory wonder) {
        uint availableWondersCount = 0;
        delete possibleWondersRandomnessBounds;
        delete possibleWonders;

        uint tokenId = tokenIds.current();
        uint XFactor = 256;

        for (uint i = 0; i < allocatedWonders.length; i++) {
            uint n = XFactor.mul(allocatedWonders[i]).div( tokenId);
            if (n < wonderAllocation[i]) {
                possibleWonders.push(i);
                availableWondersCount = availableWondersCount.add(wonderAllocation[i]);
                possibleWondersRandomnessBounds.push(availableWondersCount.sub(1));
            }
        }
        
        uint scaledRandomNumber = randomNumber.mod(availableWondersCount);
        
        for (uint i = 0; i < possibleWonders.length; i++) {
            if (scaledRandomNumber <= possibleWondersRandomnessBounds[i]) {
                uint wonderIndex = possibleWonders[i];
                allocatedWonders[wonderIndex] = allocatedWonders[wonderIndex].add(1);
                return wonders[wonderIndex];
            }        
        }

        return wonders[wonders.length.sub(1)];
    }

    /** @notice Determines the pattern of a WunderPass based on randomness.
      * @dev The distribution of patterns is skewed so that the probabilities of the patterns are 1/2, 1/4, 1/8, 1/16 etc.
      * @param randomNumber A random number generated by chainLink.
      * @return pattern The pattern of the WunderPass.
      */
    function determinePattern(uint randomNumber) internal view returns(string memory pattern) {
        /// @notice number of WunderPass where the rarest pattern occurs once
        uint256 patternModNumber = 512;
        uint256 modNumber = randomNumber.mod(patternModNumber).add(1);

        for (uint i = 0; i < patterns.length; i++) {
            if (modNumber >= patternModNumber.div(2 ** (i.add(1)))) {
                return patterns[i];
            }
        }
        return patterns[8];
    }

    /** @notice Returns how often the given edition was minted.
      * @dev This function is primarily used for visualizing the distribution of minted editions.
      * @param _edition Any valid edition.
      * @return count How often the given edition was minted.
      */
    function getCounter(string memory _edition) public view returns(uint count) {
        return editions[_edition].counter;
    }

    /** @notice Requests a random number from ChainLink.
      * @return requestId Used to identify the request in fulfillRandomness.
      */
    function getRandomNumber() internal returns (bytes32 requestId) {
        require(LINK.balanceOf(address(this)) >= chainlinkFee, "Not enough LINK");
        return requestRandomness(keyHash, chainlinkFee);
    }

    /** @notice Callback function from Chainlink.
      * @dev This function finalizes the minting process by requesting the wonder and the pattern, minting the ERC721 token and emitting the WunderPassMinted event.
      * @param requestId The id for the request coming from ChainLink.
      * @param randomness The random number coming from ChainLink.
      */
    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        uint tokenId = requestIdToTokenId[requestId];
        WunderPassProps storage wunderPassProps = tokenIdToWunderPassProps[tokenId];
        (uint randOne, uint randTwo) = twoFromOne(randomness);
        string memory pattern = determinePattern(randOne);
        string memory wonder = determineWonder(randTwo);
        wunderPassProps.pattern = pattern;
        wunderPassProps.wonder = wonder;
        address owner = ownerOf(tokenId);
        emit WunderPassMinted(tokenId, owner, wunderPassProps.status, pattern, wonder, wunderPassProps.edition);
    }

    /** @notice Get two random numbers from one.
      * @param randomValue The id for the request coming from ChainLink.
      * @return first The first random number.
      * @return second The second random number.
      */
    function twoFromOne(uint256 randomValue) internal pure returns (uint first, uint second) {
        uint firstRandNumber = uint256(keccak256(abi.encode(randomValue, 1)));
        uint secondRandNumber = uint256(keccak256(abi.encode(randomValue, 2)));
        return (firstRandNumber, secondRandNumber);
    }

    /** @notice Gets a WunderPass object based on its tokenId.
      * @param tokenId The tokenId of the WunderPass.
      * @return wunderPassProps A WunderPass Object.
      */
    function getWunderPass(uint tokenId) public view returns (WunderPassProps memory wunderPassProps) {
        require(_exists(tokenId), "This WunderPass does not exist");
        return tokenIdToWunderPassProps[tokenId];
    }

    /** @notice Sets the URI of a WunderPass.
      * @dev This function gets called after the metadata was generated.
      * @param tokenId The tokenId of the WunderPass.
      * @param _tokenURI The metadata URI of the WunderPass.
      */
    function _setTokenURI(uint256 tokenId, string memory _tokenURI) external onlyRole(ADMIN_ROLE) {
        require(_exists(tokenId), "ERC721Metadata: URI set of nonexistent token");
        _tokenURIs[tokenId] = _tokenURI;
    }

    /** @notice Gets the URI of a WunderPass.
      * @param tokenId The tokenId of the WunderPass.
      * @return uri The metadata URI of the WunderPass.
      */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory uri) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        return _tokenURIs[tokenId];
    }

    /** @notice Modify Availability of Editions.
      * @dev By increasing the editionThreshold, the availability of editions can be reenabled and vice versa.
      * @param _newThreshold The new threshold.
      */
    function setEditionThreshold(uint _newThreshold) external onlyRole(OWNER_ROLE) {
        require((_newThreshold > 0) || (_newThreshold <= thresholdUpperLimit), "new threshold should be higher than zero and less or equal than thresholdUpperLimit");
        editionThreshold = _newThreshold;
    }

    /** @notice Modify Public Price.
      * @param _gweiPrice The new price in gwei.
      * @param _decimals The amount of zeros.
      */
    function setPublicPrice(uint _gweiPrice, uint _decimals) external onlyRole(OWNER_ROLE) {
        require((_gweiPrice > 0), "new price should be higher than zero");
        publicPrice = _gweiPrice.mul(10 ** _decimals);
    }

    /** @notice Modify ChainLink fee.
      * @dev In case ChainLink decides to change their fees.
      * @param _gweiPrice The new price in gwei.
      * @param _decimals The amount of zeros.
      */
    function setChainlinkFee(uint _gweiPrice, uint _decimals) external onlyRole(OWNER_ROLE) {
        // Here we deliberately left out validation as we can't predict changes to the chainlink fee 
        chainlinkFee = _gweiPrice.mul(10 ** _decimals);
    }

    /** @notice Modify ChainLink fee.
      * @dev In case OpenSea decides to change their Proxy Address.
      * @param _newAddress The new Proxy Address.
      */
    function setOpenSeaProxyAddress(address _newAddress) external onlyRole(OWNER_ROLE) {
        openSeaProxyAddress = _newAddress;
    }

    /// @notice Pauses the minting process.
    function pause() public onlyRole(OWNER_ROLE) whenNotPaused() {
        _pause();
    }

    /// @notice Enables the minting process.
    function unpause() public onlyRole(OWNER_ROLE) whenPaused() {
        _unpause();
    }

    /// @notice Withdraws all LINK from the Contract.
    function withdrawLink() external onlyRole(OWNER_ROLE) {
        LINK.transfer(msg.sender, LINK.balanceOf(address(this)));
    }

    /// @notice Withdraws all MATIC from the Contract.
    function withdrawMatic() external onlyRole(OWNER_ROLE) {
        payable(msg.sender).transfer(address(this).balance);
    }

    /** @notice Changes the owner of the Contract.
      * @param _newOwner The new owner of the contract.
      */
    function changeOwner(address _newOwner) external onlyRole(OWNER_ROLE) {
        _grantRole(OWNER_ROLE, _newOwner);
        _revokeRole(OWNER_ROLE, msg.sender);
    }

    /** @notice Adds a new admin that can mint for users and set metadata URIs.
      * @param _newAdmin The new admin address.
      */
    function addAdmin(address _newAdmin) external onlyRole(OWNER_ROLE) {
        _grantRole(ADMIN_ROLE, _newAdmin);
    }

    /** @notice Removes an admin.
      * @param _admin The admin address.
      */
    function removeAdmin(address _admin) external onlyRole(OWNER_ROLE) {
        _revokeRole(ADMIN_ROLE, _admin);
    }

    /// @notice Returns true if the sender has the OWNER_ROLE.
    function isOwner() external view returns (bool) {
        return hasRole(OWNER_ROLE, msg.sender);
    }

    /// @notice Returns true if the sender has the ADMIN_ROLE.
    function isAdmin() external view returns (bool) {
        return hasRole(ADMIN_ROLE, msg.sender);
    }

    /** @notice Returns all WunderPass tokenIds owned by a given address.
      * @param _owner Any address.
      * @return tokens An array of tokenIds that the address owns.
      */
    function tokensOfAddress(address _owner) public view returns (uint[] memory tokens) {
        return addressToTokenIds[_owner];
    }

    /** @notice Returns the best status a given address has among all their WunderPasses.
      * @param _owner Any address.
      * @return status The best status of the address.
      */
    function bestStatusOf(address _owner) external view returns (string memory status) {
        uint[] memory ownerTokens = tokensOfAddress(_owner);
        string[] memory ownerStatus = new string[](ownerTokens.length);

        for (uint256 index = 0; index < ownerTokens.length; index++) {
            ownerStatus[index] = getWunderPass(ownerTokens[index]).status;
        }

        for (uint256 statusInd = 0; statusInd < statusArray.length; statusInd++) {
            for (uint256 index = 0; index < ownerStatus.length; index++) {
                if (keccak256(abi.encodePacked(statusArray[statusInd])) == keccak256(abi.encodePacked(ownerStatus[index]))) {
                    return statusArray[statusInd];
                }
            }
        }

        return "";
    }

    /** @notice Returns the best wonder a given address has among all their WunderPasses.
      * @param _owner Any address.
      * @return wonder The best wonder of the address.
      */
    function bestWonderOf(address _owner) external view returns (string memory wonder) {
        uint[] memory ownerTokens = tokensOfAddress(_owner);
        string[] memory ownerWonders = new string[](ownerTokens.length);

        for (uint256 index = 0; index < ownerTokens.length; index++) {
            ownerWonders[index] = getWunderPass(ownerTokens[index]).wonder;
        }

        for (uint256 wonderInd = 0; wonderInd < wonders.length; wonderInd++) {
            for (uint256 index = 0; index < ownerWonders.length; index++) {
                if (keccak256(abi.encodePacked(wonders[wonderInd])) == keccak256(abi.encodePacked(ownerWonders[index]))) {
                    return wonders[wonderInd];
                }
            }
        }

        return "";
    }

    /** @notice ERC721 Hook that gets called before every transfer/mint.
      * @dev Here we use this hook to update the addressToTokenIds mapping to keep track of NFT ownership.
      * @param from Sender of the token.
      * @param to Receiver of the token.
      * @param tokenId The tokenId of the transferred token.
      */
    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal virtual override {
        super._beforeTokenTransfer(from, to, tokenId);

        if (addressToTokenIds[from].length > 0) {
            uint tokenIndex = 0;
            
            while (addressToTokenIds[from][tokenIndex] != tokenId) {
                tokenIndex++;
            }

            addressToTokenIds[from][tokenIndex] = addressToTokenIds[from][addressToTokenIds[from].length.sub(1)];
            addressToTokenIds[from].pop();
        }

        addressToTokenIds[to].push(tokenId);
    }

    /// @dev So you are still reading this Contract? You must be really passionate about Solidity and Smart Contracts!
    /// @dev We need people like you to support us in our vision! 
    /// @dev Just send us an email at careers@wunderpass.io with the subject: "WunderPass Smart Contract"
}

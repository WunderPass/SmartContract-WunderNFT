// SPDX-License-Identifier: MIT

// ██╗    ██╗██╗   ██╗███╗   ██╗██████╗ ███████╗██████╗ ███╗   ██╗███████╗████████╗
// ██║    ██║██║   ██║████╗  ██║██╔══██╗██╔════╝██╔══██╗████╗  ██║██╔════╝╚══██╔══╝
// ██║ █╗ ██║██║   ██║██╔██╗ ██║██║  ██║█████╗  ██████╔╝██╔██╗ ██║█████╗     ██║   
// ██║███╗██║██║   ██║██║╚██╗██║██║  ██║██╔══╝  ██╔══██╗██║╚██╗██║██╔══╝     ██║   
// ╚███╔███╔╝╚██████╔╝██║ ╚████║██████╔╝███████╗██║  ██║██║ ╚████║██║        ██║   
//  ╚══╝╚══╝  ╚═════╝ ╚═╝  ╚═══╝╚═════╝ ╚══════╝╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝        ╚═╝   

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";

// Slava: Bitte nach Möglichkeiten die Funktionen zumindest mit einem Satz Kommentar versehen.

contract WunderNFT is ERC721, VRFConsumerBase, AccessControl, Ownable {
    // Counter for Token Id
    using Counters for Counters.Counter;
    Counters.Counter private tokenIds;

    // Access Control Roles
    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    // Random Number Generation
    // RINKEBY
    // bytes32 internal keyHash = 0x2ed0feb3e7fd2022120aa84fab1945545a9f2ffc9076fd6156fa96eaff4c1311;
    // uint256 internal fee = 0.1 * 10 ** 18; // 0.1 LINK 
    // address internal VRFCoordinator = 0xb3dCcb4Cf7a26f6cf6B120Cf5A73875B7BBc655B;
    // address internal linkToken = 0x01BE23585060835E02B77ef475b0Cc51aA1e0709;
    // ETH Mainnet
    // bytes32 internal keyHash = 0xAA77729D3466CA35AE8D28B3BBAC7CC36A5031EFDC430821C02BC31A238AF445;
    // uint256 internal fee = 2 * 10 ** 18; // 2 LINK 
    // address internal VRFCoordinator = 0xf0d54349aDdcf704F77AE15b96510dEA15cb7952;
    // address internal linkToken = 0x514910771AF9Ca656af840dff83E8264EcF986CA;
    // Mumbai
    bytes32 internal keyHash = 0x6e75b569a01ef56d18cab6a8e71e6600d6ce853834d4a5748b720d06f878b3a4;
    uint256 internal fee = 0.0001 * 10 ** 18; // 0.0001 LINK 
    address internal VRFCoordinator = 0x8C7382F9D8f56b33781fE506E897a4F1e2d17255;
    address internal linkToken = 0x326C977E6efc84E512bB9C30f76E30c160eD06FB;
    // Polygon Mainnet
    // bytes32 internal keyHash = 0xf86195cf7690c55907b2b611ebb7343a6f649bff128701cc542f0569e2c549da;
    // uint256 internal fee = 0.0001 * 10 ** 18; // 0.0001 LINK 
    // address internal VRFCoordinator = 0x3d2341ADb2D31f1c5530cDC622016af293177AE0;
    // address internal linkToken = 0xb0897686c545045aFc77CF20eC7A532E3120E0F1;

    // Price & Edition handling
    uint public publicPrice = 420 * 10 ** 18; // 420 MATIC
    uint public editionThreshold = 10;
    mapping(string => Edition) editions;
    struct Edition {
        string name;
        string parent;
        uint counter;
    }

    // NFT Mapping
    // requestId => tokenId
    mapping(bytes32 => uint) requestIdToTokenId;
    // tokenId => WunderPass
    mapping(uint => WunderPass) tokenIdToWunderPass;
    // tokenId => tokenUri
    mapping (uint => string) private _tokenURIs;
    struct WunderPass {
        address owner;
        uint tokenId;
        string status;
        string edition;
        string wonder;
        string pattern;
    }

    // Patterns & Wonders
    string[] patterns;
    
    string[] wonders;
    uint[] allocatedWonders;
    uint[] internal possibleWonders;
    uint[] internal wonderAllocation;

    // Pausing
    bool public mintingPaused = true;

    // events
    event WunderPassMinted(uint indexed tokenId, address indexed owner, string status, string pattern, string wonder, string edition);

    constructor(string[] memory _names, string[] memory _parents) 
        VRFConsumerBase(VRFCoordinator, linkToken)
        ERC721("WunderPassNFT", "WPN")
    {
        for (uint i = 0; i < _names.length; i++) {
            editions[_names[i]] = Edition(_names[i], _parents[i], 0);
        }
        
        // SLava: Warum definiert man die patterns und die wonders innerhalb des Konstruktors und nicht außerhalb, wie die anderen Konstanten
        // wie "mintingPaused = true"?
        // Gleiches gilt eigentlich für wonderAllocation
        
        patterns = ["Safari", "Bars", "Dots", "Waves", "Stones", "WunderPass", "ZigZag", "Lines", "Worms"];
       
        wonders = ["Pyramids of Giza", "Great Wall of China", "Petra", "Colosseum", "Chichen Itza", "Machu Picchu", "Taj Mahal", "Christ the Redeemer"];
        wonderAllocation = [1, 2, 4, 8, 16, 32, 64, 1000];
        allocatedWonders = [0, 0, 0, 0, 0, 0, 0, 0];
       
        _grantRole(OWNER_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    /**
    * Override isApprovedForAll to auto-approve OS's proxy contract
    */
    function isApprovedForAll(address _owner, address _operator) public override view returns (bool isOperator) {
        
       // Slava: Sollte '0x58807baD0B376efc12F5AD86aAc70E78ed67deaE' nicht lieber als Konstante oben definiert werden? 
       
        // if OpenSea's ERC721 Proxy Address is detected, auto-return true
        if (_operator == address(0x58807baD0B376efc12F5AD86aAc70E78ed67deaE)) {
            return true;
        }
        // otherwise, use the default ERC721.isApprovedForAll()
        return ERC721.isApprovedForAll(_owner, _operator);
    }

    function mintForUser(string memory _edition, address _owner) public onlyRole(ADMIN_ROLE) {
        mintInternal(_edition, _owner);
    }

    function mint(string memory _edition) public payable {
        require(msg.value >= publicPrice);
        mintInternal(_edition, msg.sender);
    }

    // Slava: Kommentieren, dass es rauskommt
    function mintTest(string memory _edition, address _owner) public onlyRole(ADMIN_ROLE) {
        require(bytes(editions[_edition].name).length > 0, "Cant mint NFT without valid edition");
        require(mintingPaused == false, "Minting is currently paused. The next drop is coming soon!");
        address owner = _owner;
        string memory _statusProp = determineStatus();
        string memory _editionProp = determineEdition(_edition, 1);
        uint tokenId = tokenIds.current();

        bytes32 requestId = bytes32(tokenId);
        WunderPass memory wunderPass = WunderPass(owner, tokenId, _statusProp, _editionProp, "", "");
        requestIdToTokenId[requestId] = tokenId;
        tokenIdToWunderPass[tokenId] = wunderPass;
        _mint(owner, tokenId);
        tokenIds.increment();

        fulfillRandomness(requestId, uint256(keccak256(abi.encode(tokenId, 1, _edition))));
    }

    function mintInternal(string memory _edition, address _owner) internal {
        require(bytes(editions[_edition].name).length > 0, "Cant mint NFT without valid edition");
        require(mintingPaused == false, "Minting is currently paused. The next drop is coming soon!");
        string memory _statusProp = determineStatus();
        string memory _editionProp = determineEdition(_edition, 1);
        uint tokenId = tokenIds.current();
        bytes32 requestId = getRandomNumber();
        WunderPass memory wunderPass = WunderPass(_owner, tokenId, _statusProp, _editionProp, "", "");
        requestIdToTokenId[requestId] = tokenId;
        tokenIdToWunderPass[tokenId] = wunderPass;
        _mint(_owner, tokenId);
        tokenIds.increment();
    }

    function currentTokenId() public view returns(uint) {
        return tokenIds.current();
    }

    // Slava: Wir sollten hierbei Konstanten für die Werte 200, 1800, 14600 etc. benutzen und dann auch nicht 199, 1799 etc. schreiben, sondern 
    // const_a - 1, const_b - 1 etc.
    function determineStatus() internal returns(string memory) {
        uint currentId = tokenIds.current();
        if (currentId == 199 || currentId == 1799 || currentId == 14599 || currentId == 116999 || currentId == 936199 || currentId == 7489799 || currentId == 59918599 || currentId == 479348999) {
            mintingPaused = true;
        } 
        if (currentId < 200) {
            return "Diamond";
        } else if (currentId < 1800) {
            return "Black";
        } else if (currentId < 14600) {
            return "Pearl";
        } else if (currentId < 117000) {
            return "Platinum";
        } else if (currentId < 936200) {
            return "Ruby";
        } else if (currentId < 7489800) {
            return "Gold";
        } else if (currentId < 59918600) {
            return "Silver";
        } else if (currentId < 479349000) {
            return "Bronze";
        } else {
            return "White";
        }
        
        
        // Slava: Nur ne Stil-Frage, ich würde jedoch folgende Schreibweis immer bevorzugen, wenn man innerhalb eines if-Blocks return:
//        if (currentId < 200) {
//            return "Diamond";
//        }         
//        if (currentId < 1800) {
//            return "Black";
//        } 
//        if (currentId < 14600) {
//            return "Pearl";
//        } 
//        if (currentId < 117000) {
//            return "Platinum";
//        } 
//        if (currentId < 936200) {
//            return "Ruby";
//        } 
//        if (currentId < 7489800) {
//            return "Gold";
//        } 
//        if (currentId < 59918600) {
//            return "Silver";
//        } 
//        if (currentId < 479349000) {
//            return "Bronze";
//        }
//        return "White";
    }

    function determineEdition(string memory _edition, uint _thresholdMultiplier) internal returns(string memory) {
        Edition storage _desiredEdition = editions[_edition];
        if (keccak256(abi.encodePacked(_desiredEdition.name)) == keccak256(abi.encodePacked(_desiredEdition.parent))) {
            _desiredEdition.counter += 1;
            return _desiredEdition.name;
        } else if (_desiredEdition.counter >= (editionThreshold * _thresholdMultiplier)) {
            return determineEdition(_desiredEdition.parent, (10 * _thresholdMultiplier));
        } else {
            _desiredEdition.counter += 1;
            return _desiredEdition.name;
        }
        
        // Slava: Gleicher Kommentar bzgl. else-if wie oben ;)
    }

    function determineWonder(uint randomNumber) internal returns(string memory) {
        delete possibleWonders;
        uint tokenId = tokenIds.current();

        for (uint i = 0; i < allocatedWonders.length; i++) {
            uint n = allocatedWonders[i] * 256 / tokenId;
            if (n < wonderAllocation[i]) {
                possibleWonders.push(i);
            }
        }

        // Slava: Über die folgende Zeile müssen wir nochmal sprechen. Dies hab ich im White-Paper nämlich tatsächlich bewusst anders gewollt.
        // Und zwar so, dass die seltenen Wunder auch tatsächlich eine geringere Wahrscheinlichkeit haben als die häufigeren.
        // Der Vorteil deiner aktuellen Implementierung ist, dass sie halbwegs simpel ist.
        // Der Nachteil aber, dass diese das first-come-first-serve-Prinzip befeuert, denn nach jedem 256. Pass lohnt sich das Minten plötzlich viel mehr
        // als kurz vor Ende des 256er-Zykel, weil da noch die seltene Wunder verfügbar sind und die Chance auf diese mit 1:8 recht hoch ist.
        uint wonderIndex = possibleWonders[(randomNumber % possibleWonders.length)];
        allocatedWonders[wonderIndex] = allocatedWonders[wonderIndex] + 1;
        return wonders[wonderIndex];
    }

    function determinePattern(uint randomNumber) internal view returns(string memory) {
        uint modNumber = (randomNumber % 512) + 1;

        for (uint i = 0; i < patterns.length; i++) {
            if (modNumber >= 512 / (2 ** (i + 1))) {
                return patterns[i];
            }
        }
        return patterns[8];
    }

    function getCounter(string memory _edition) public view returns(uint) {
        return editions[_edition].counter;
    }

    function getRandomNumber() internal returns (bytes32 requestId) {
        require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK");
        return requestRandomness(keyHash, fee);
    }

    // Callback function from Chainlink
    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        uint tokenId = requestIdToTokenId[requestId];
        WunderPass storage wunderPass = tokenIdToWunderPass[tokenId];
        (uint randOne, uint randTwo) = twoFromOne(randomness);
        string memory pattern = determinePattern(randOne);
        string memory wonder = determineWonder(randTwo);
        wunderPass.pattern = pattern;
        wunderPass.wonder = wonder;
        address owner = ownerOf(tokenId);
        emit WunderPassMinted(tokenId, owner, wunderPass.status, pattern, wonder, wunderPass.edition);
    }

    // Get two random numbers from one
    function twoFromOne(uint256 randomValue) internal pure returns (uint, uint) {
        uint firstRandNumber = uint256(keccak256(abi.encode(randomValue, 1)));
        uint secondRandNumber = uint256(keccak256(abi.encode(randomValue, 2)));
        return (firstRandNumber, secondRandNumber);
    }

    function getWunderPass(uint tokenId) public view returns (WunderPass memory) {
        require(_exists(tokenId), "This WunderPass does not exist");
        return tokenIdToWunderPass[tokenId];
    }

    function _setTokenURI(uint256 tokenId, string memory _tokenURI) external onlyRole(ADMIN_ROLE) {
        require(_exists(tokenId), "ERC721Metadata: URI set of nonexistent token");
        _tokenURIs[tokenId] = _tokenURI;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        return _tokenURIs[tokenId];
    }

    // Modify Availability of Editions
    function setEditionThreshold(uint _newThreshold) external onlyRole(OWNER_ROLE) {
        editionThreshold = _newThreshold;
    }

    // Modify Public Price
    function setPublicPrice(uint _newPrice) external onlyRole(OWNER_ROLE) {
        // Slava: Kommentar auf MATIC beziehen bzw. zumindest ergänzend erwähnen
        publicPrice = _newPrice * 10**15; // Always in Finney (Lowest possible Price = 0.001 ether)
    }

    function activateMinting() external onlyRole(OWNER_ROLE) {
        mintingPaused = false;
    }

    function pauseMinting() external onlyRole(OWNER_ROLE) {
        mintingPaused = true;
    }

    // Withdraw functions
    function withdrawLink() external onlyRole(OWNER_ROLE) {
        LINK.transfer(msg.sender, LINK.balanceOf(address(this)));
    }

    function withdrawMatic() external onlyRole(OWNER_ROLE) {
        payable(msg.sender).transfer(address(this).balance);
    }

    // Role Assignments
    // Owner can be changed
    // Owner can assign and remove admins
    // Owner can withdraw funds
    // Admins can mint for users
    function changeOwner(address _newOwner) external onlyRole(OWNER_ROLE) {
        _grantRole(OWNER_ROLE, _newOwner);
        _revokeRole(OWNER_ROLE, msg.sender);
    }

    function addAdmin(address _newAdmin) external onlyRole(OWNER_ROLE) {
        _grantRole(ADMIN_ROLE, _newAdmin);
    }

    function removeAdmin(address _admin) external onlyRole(OWNER_ROLE) {
        _revokeRole(ADMIN_ROLE, _admin);
    }

    function isOwner() external view returns (bool) {
        return hasRole(OWNER_ROLE, msg.sender);
    }

    function isAdmin() external view returns (bool) {
        return hasRole(ADMIN_ROLE, msg.sender);
    }

    function tokensOfAddress(address _owner) public view returns (uint[] memory) {
        uint count = balanceOf(_owner);
        uint[] memory ownerTokens = new uint[](count);
        if (count == 0) {
            return ownerTokens;
        }

        for (uint256 index = 0; index < currentTokenId(); index++) {
            if (ownerOf(index) == _owner) {
                count = count - 1;
                ownerTokens[count] = index;
            }
        }

        return ownerTokens;
    }

    function tokenIdToOwn(uint id) public view returns (address) {
        return ownerOf(id);
    }

    function bestStatusOf(address _owner) external view returns (string memory) {
        uint[] memory ownerTokens = tokensOfAddress(_owner);
        return getWunderPass(ownerTokens[ownerTokens.length - 1]).status;
    }

    function bestWonderOf(address _owner) external view returns (string memory) {
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
    }
}

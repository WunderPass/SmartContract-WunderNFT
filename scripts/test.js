async function main() {
  const [deployer] = await ethers.getSigners();
  const address = "0xeC827421505972a2AE9C320302d3573B42363C26";
  const abi = ["constructor(string[] _names, string[] _parents)","event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId)","event ApprovalForAll(address indexed owner, address indexed operator, bool approved)","event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)","event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole)","event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender)","event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender)","event Transfer(address indexed from, address indexed to, uint256 indexed tokenId)","event WunderPassMinted(uint256 indexed tokenId, address indexed owner, string status, string pattern, string wonder, string edition)","function ADMIN_ROLE() view returns (bytes32)","function DEFAULT_ADMIN_ROLE() view returns (bytes32)","function OWNER_ROLE() view returns (bytes32)","function _setTokenURI(uint256 tokenId, string _tokenURI)","function activateMinting()","function addAdmin(address _newAdmin)","function approve(address to, uint256 tokenId)","function balanceOf(address owner) view returns (uint256)","function bestStatusOf(address _owner) view returns (string)","function bestWonderOf(address _owner) view returns (string)","function changeOwner(address _newOwner)","function currentTokenId() view returns (uint256)","function editionThreshold() view returns (uint256)","function getApproved(uint256 tokenId) view returns (address)","function getCounter(string _edition) view returns (uint256)","function getRoleAdmin(bytes32 role) view returns (bytes32)","function getWunderPass(uint256 tokenId) view returns (tuple(address owner, uint256 tokenId, string status, string edition, string wonder, string pattern))","function grantRole(bytes32 role, address account)","function hasRole(bytes32 role, address account) view returns (bool)","function isAdmin() view returns (bool)","function isApprovedForAll(address owner, address operator) view returns (bool)","function isOwner() view returns (bool)","function mint(string _edition) payable","function mintForUser(string _edition, address _owner)","function mintTest(string _edition, address _owner)","function mintingPaused() view returns (bool)","function name() view returns (string)","function owner() view returns (address)","function ownerOf(uint256 tokenId) view returns (address)","function pauseMinting()","function publicPrice() view returns (uint256)","function rawFulfillRandomness(bytes32 requestId, uint256 randomness)","function removeAdmin(address _admin)","function renounceOwnership()","function renounceRole(bytes32 role, address account)","function revokeRole(bytes32 role, address account)","function safeTransferFrom(address from, address to, uint256 tokenId)","function safeTransferFrom(address from, address to, uint256 tokenId, bytes _data)","function setApprovalForAll(address operator, bool approved)","function setEditionThreshold(uint256 _newThreshold)","function setPublicPrice(uint256 _newPrice)","function supportsInterface(bytes4 interfaceId) view returns (bool)","function symbol() view returns (string)","function tokenURI(uint256 tokenId) view returns (string)","function tokensOfAddress(address _owner) view returns (uint256[])","function transferFrom(address from, address to, uint256 tokenId)","function transferOwnership(address newOwner)","function withdrawLink()","function withdrawMatic()"];

  const contract = await ethers.getContractAt("WunderNFT", address, deployer);

  for (let index = 0; index < 50; index++) {
    await contract.mintTest('Berlin', '0x7E0b49362897706290b7312D0b0902a1629397D8')
  }
  const allTokens = await contract.tokensOfAddress('0x7E0b49362897706290b7312D0b0902a1629397D8')
  
  console.log('All Tokens:', allTokens)
  console.log('Best Status:', await contract.bestStatusOf('0x7E0b49362897706290b7312D0b0902a1629397D8'))
  console.log('Best Wonder:', await contract.bestWonderOf('0x7E0b49362897706290b7312D0b0902a1629397D8'))

  for (let index = 0; index < allTokens.length; index++) {
    const [owner, id, status, pattern, wonder] = await contract.getWunderPass(allTokens[index]);
    console.log(Number(allTokens[index]), status, wonder)
  }
}

main()
  .then(() => {
    process.exit(0)
  })
  .catch((err) => {
    console.error(err)
    process.exit(1)
  })
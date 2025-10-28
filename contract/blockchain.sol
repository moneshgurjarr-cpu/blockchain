// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title EthicalFashionSupplyChain
 * @dev Transparent supply chain tracking for ethical fashion from raw materials to consumer
 */
contract EthicalFashionSupplyChain {
    
    enum Stage { RawMaterial, Manufacturing, Quality, Distribution, Retail, Sold }
    
    struct Product {
        string productId;
        string productName;
        Stage currentStage;
        uint256 createdAt;
        bool isActive;
    }
    
    struct TrackingRecord {
        Stage stage;
        address handler;
        string location;
        uint256 timestamp;
        string certifications;
        uint256 carbonFootprint; // in grams of CO2
        string workingConditions;
        uint256 fairWagesPaid; // in wei
        string additionalNotes;
    }
    
    // Mapping from product ID to Product
    mapping(bytes32 => Product) public products;
    
    // Mapping from product ID to array of tracking records
    mapping(bytes32 => TrackingRecord[]) public productJourney;
    
    // Mapping to track authorized stakeholders (farmers, manufacturers, distributors, etc.)
    mapping(address => bool) public authorizedStakeholders;
    
    // Mapping to track stakeholder type
    mapping(address => string) public stakeholderType;
    
    address public admin;
    uint256 public totalProducts;
    
    event ProductRegistered(bytes32 indexed productId, string productName, address indexed registrar);
    event StageUpdated(bytes32 indexed productId, Stage newStage, address indexed handler, string location);
    event StakeholderAuthorized(address indexed stakeholder, string stakeholderType);
    event StakeholderRevoked(address indexed stakeholder);
    
    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can perform this action");
        _;
    }
    
    modifier onlyAuthorized() {
        require(authorizedStakeholders[msg.sender], "Only authorized stakeholders can perform this action");
        _;
    }
    
    constructor() {
        admin = msg.sender;
        authorizedStakeholders[msg.sender] = true;
        stakeholderType[msg.sender] = "Admin";
    }
    
    /**
     * @dev Authorize a stakeholder in the supply chain
     * @param _stakeholder Address of the stakeholder to authorize
     * @param _type Type of stakeholder (Farmer, Manufacturer, Distributor, Retailer, etc.)
     */
    function authorizeStakeholder(address _stakeholder, string memory _type) external onlyAdmin {
        require(_stakeholder != address(0), "Invalid stakeholder address");
        require(!authorizedStakeholders[_stakeholder], "Stakeholder already authorized");
        require(bytes(_type).length > 0, "Stakeholder type required");
        
        authorizedStakeholders[_stakeholder] = true;
        stakeholderType[_stakeholder] = _type;
        
        emit StakeholderAuthorized(_stakeholder, _type);
    }
    
    /**
     * @dev Register a new product in the supply chain
     * @param _productId Unique product identifier (SKU or barcode)
     * @param _productName Name/description of the product
     * @param _location Origin location of raw materials
     * @param _certifications Organic, Fair Trade, etc.
     * @param _carbonFootprint Initial carbon footprint
     * @param _workingConditions Description of working conditions
     * @param _fairWagesPaid Amount of fair wages paid at this stage
     * @param _notes Additional information
     */
    function registerProduct(
        string memory _productId,
        string memory _productName,
        string memory _location,
        string memory _certifications,
        uint256 _carbonFootprint,
        string memory _workingConditions,
        uint256 _fairWagesPaid,
        string memory _notes
    ) external onlyAuthorized returns (bytes32) {
        require(bytes(_productId).length > 0, "Product ID required");
        require(bytes(_productName).length > 0, "Product name required");
        
        bytes32 productHash = keccak256(abi.encodePacked(_productId, block.timestamp, msg.sender));
        
        require(!products[productHash].isActive, "Product already registered");
        
        // Create product
        products[productHash] = Product({
            productId: _productId,
            productName: _productName,
            currentStage: Stage.RawMaterial,
            createdAt: block.timestamp,
            isActive: true
        });
        
        // Add initial tracking record
        productJourney[productHash].push(TrackingRecord({
            stage: Stage.RawMaterial,
            handler: msg.sender,
            location: _location,
            timestamp: block.timestamp,
            certifications: _certifications,
            carbonFootprint: _carbonFootprint,
            workingConditions: _workingConditions,
            fairWagesPaid: _fairWagesPaid,
            additionalNotes: _notes
        }));
        
        totalProducts++;
        
        emit ProductRegistered(productHash, _productName, msg.sender);
        emit StageUpdated(productHash, Stage.RawMaterial, msg.sender, _location);
        
        return productHash;
    }
    
    /**
     * @dev Update product stage with tracking information
     * @param _productHash Hash ID of the product
     * @param _newStage New stage in the supply chain
     * @param _location Current location
     * @param _certifications Relevant certifications at this stage
     * @param _carbonFootprint Carbon footprint added at this stage
     * @param _workingConditions Working conditions description
     * @param _fairWagesPaid Fair wages paid at this stage
     * @param _notes Additional tracking information
     */
    function updateProductStage(
        bytes32 _productHash,
        Stage _newStage,
        string memory _location,
        string memory _certifications,
        uint256 _carbonFootprint,
        string memory _workingConditions,
        uint256 _fairWagesPaid,
        string memory _notes
    ) external onlyAuthorized {
        Product storage product = products[_productHash];
        require(product.isActive, "Product does not exist or is inactive");
        require(_newStage > product.currentStage, "Invalid stage progression");
        require(_newStage <= Stage.Sold, "Invalid stage");
        
        // Update product stage
        product.currentStage = _newStage;
        
        // Add tracking record
        productJourney[_productHash].push(TrackingRecord({
            stage: _newStage,
            handler: msg.sender,
            location: _location,
            timestamp: block.timestamp,
            certifications: _certifications,
            carbonFootprint: _carbonFootprint,
            workingConditions: _workingConditions,
            fairWagesPaid: _fairWagesPaid,
            additionalNotes: _notes
        }));
        
        emit StageUpdated(_productHash, _newStage, msg.sender, _location);
    }
    
    /**
     * @dev Get complete journey/provenance of a product
     * @param _productHash Hash ID of the product
     * @return product Product details
     * @return journey Array of all tracking records
     */
    function getProductProvenance(bytes32 _productHash) 
        external 
        view 
        returns (Product memory product, TrackingRecord[] memory journey) 
    {
        require(products[_productHash].isActive, "Product does not exist");
        
        product = products[_productHash];
        journey = productJourney[_productHash];
        
        return (product, journey);
    }
    
    /**
     * @dev Get total carbon footprint for a product across all stages
     * @param _productHash Hash ID of the product
     * @return totalFootprint Total carbon footprint in grams CO2
     */
    function getTotalCarbonFootprint(bytes32 _productHash) 
        external 
        view 
        returns (uint256 totalFootprint) 
    {
        require(products[_productHash].isActive, "Product does not exist");
        
        TrackingRecord[] memory journey = productJourney[_productHash];
        
        for (uint256 i = 0; i < journey.length; i++) {
            totalFootprint += journey[i].carbonFootprint;
        }
        
        return totalFootprint;
    }
    
    /**
     * @dev Get total fair wages paid across supply chain for a product
     * @param _productHash Hash ID of the product
     * @return totalWages Total fair wages paid in wei
     */
    function getTotalFairWages(bytes32 _productHash) 
        external 
        view 
        returns (uint256 totalWages) 
    {
        require(products[_productHash].isActive, "Product does not exist");
        
        TrackingRecord[] memory journey = productJourney[_productHash];
        
        for (uint256 i = 0; i < journey.length; i++) {
            totalWages += journey[i].fairWagesPaid;
        }
        
        return totalWages;
    }
    
    /**
     * @dev Get journey length (number of stages) for a product
     * @param _productHash Hash ID of the product
     * @return Number of recorded stages
     */
    function getJourneyLength(bytes32 _productHash) external view returns (uint256) {
        require(products[_productHash].isActive, "Product does not exist");
        return productJourney[_productHash].length;
    }
    
    /**
     * @dev Revoke stakeholder authorization
     * @param _stakeholder Address of stakeholder to revoke
     */
    function revokeStakeholder(address _stakeholder) external onlyAdmin {
        require(authorizedStakeholders[_stakeholder], "Stakeholder not authorized");
        require(_stakeholder != admin, "Cannot revoke admin");
        
        authorizedStakeholders[_stakeholder] = false;
        
        emit StakeholderRevoked(_stakeholder);
    }
}

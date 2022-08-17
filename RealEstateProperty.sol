// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0 < 0.9.0;

import "@openzeppelin/contracts@4.7.1/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts@4.7.1/access/Ownable.sol";
import "@openzeppelin/contracts@4.7.1/utils/Counters.sol";
import "@openzeppelin/contracts@4.7.1/utils/Address.sol";
import "@openzeppelin/contracts@4.7.1/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts@4.7.1/token/ERC20/IERC20.sol";

contract RealEstateProperty is ERC721, ERC721URIStorage, Ownable, IERC20{
    IERC20 public ierc20;
    address private token_address;
    constructor(address _token_address){
        ierc20 = IERC20(_token_address);
    }

    address Koscom_chairperson;//only Koscom is able to tokenize residential properties
    address payable buyer;// stores buyer wallet address interested in purchasing property.
    uint asking_price;// stores the asking price of the property posted by the seller(property/token owner)
    uint start_date; // transaction start date, necessary for creating and maintaining deadlines for sell/buy transaction
    uint closing_date_deadline;// due date for final amount to be deoposited
    uint public deposit_value; // initial deposit/earnest money, to turn property from for-sale to pending.
    uint deposit_deadline;// due date for deposit
    uint deposit_basis_points;// this allows the seller to set amount for initial deposit to for buyer to commit to buy property/token
    uint total_amount;// this represents
    bool appraisal_pass;// represents the action/result of the appraisal decision
    bool inspection_pass;// represents the action/results of the inspection decision
    address appraiser; //wallet address for appraiser/third party, involved with reporting appriasal decision
    address inspector; //wallet address for inspector/third party, involved with reporting inspection decision

    enum STATE{not_forSale, forSale,pending, sold} //purpose to follow the state of the property through the process of being tokenized(not_forSale), put in the market(forSale), pending transaction(progressing),  taken of the market sold.

    struct Property {
        address payable current_owner;// property owner/ token owner
        address payable prospective_buyer;// potential buyers if owner decides to sell
        string locationAddress;// property address
        uint token_id;
        string property_type;// values in this variable should represent wether the property is a single family, duplex, etc.
        uint last_price;// how much the property last sold for
        STATE status;// tells if the property is for sale, pending, sold, or not for sale.
        string uri;// uri that points to property's token file, ideally ipfs uri.// uri that points to property's token file, ideally ipfs uri.
    }


    mapping(uint => Property) public properties; // maps the token id for each property to  its corresponding property

    event Status(STATE pending, string report_uri);
    event NewOwner(STATE Sold_Property, address NewOwner, uint SoldFor, string report_uri);

    constructor() ERC721("Korea Residential Properties", "KRP") {
        Koscom_chairperson = msg.sender;
    }
    using Counters for Counters.Counter;

    Counters.Counter token_ids; //tokenized id for properties
    //소각 가능으로 함 - 해당 부동산 등기의 소멸/삭제 등 가능 (용도변경 시 새로운 token으로 변경 필요)
    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function getPropertyStatus(uint256 tokenId)  public view returns (STATE)
    {
        return properties[tokenId].status;
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }
    // @params _current_owner This is the deed owner that goes to tokenize the property with city hall, _locationAddress property address, _property_type Single Family, Duplex, etc., _last_price last sold for price, uri address where the token will live
    function tokenizeProperty(address payable _current_owner, string memory _locationAddress, string memory _property_type, uint _last_price, string memory uri) public onlyOwner returns(uint) {
        token_ids.increment();
        uint token_id = token_ids.current();
        require(!_exists(token_id), "Property already Tokenized!");
        _mint(Koscom_chairperson, token_id);
        _setTokenURI(token_id, uri);
        properties[token_id] =  Property(_current_owner, payable(0), _locationAddress, token_id, _property_type, _last_price, STATE.not_forSale, uri);
        return token_id;
    }
    // @params _owner Seller posts his/her wallet address, token_id Token identifier number, _asking_price How much seller wants to sell token for, _uri Pointer for where token/info is stored
    function sale(address payable _owner, uint token_id, uint _asking_price, string memory _uri) public returns(uint, uint, uint, string memory){
        require(_owner == properties[token_id].current_owner, "you don't own this property");

        require(keccak256(abi.encodePacked(properties[token_id].uri)) == keccak256(abi.encodePacked(_uri)), "Address doesn't match");
        asking_price = _asking_price;
        properties[token_id].status = STATE.forSale;
        return(token_id, asking_price, start_date, _uri);
    }
    // @params _owner Wallet address for property owner, _deposti_deadline Allows owner to set deposit submission deadline, _deposit_basis_points Allows owner to set percantage amount of deposit, token_id Token id for token/property thats for sale
    function dates_buyer(address _owner, address payable _buyer, uint _deposti_deadline, uint _closing_date, uint _deposit_basis_points, uint token_id) public {
        require(_owner == properties[token_id].current_owner, "you don't own this property");
        properties[token_id].prospective_buyer = _buyer;
        start_date = block.timestamp;
        deposit_deadline = _deposti_deadline;
        closing_date_deadline = _closing_date;
        deposit_basis_points = _deposit_basis_points;
    }
    // @dev no one can submit a deposit that isn't the buyer that the seller agreed to make a buyer.
    // @params _buyer prospective_buyer's wallet address, token_id Identifier for token/property that buyer is interested in, _uri Pointer for that property, report_uri URI that will store event emissions.
    function earnest_deposit(address payable _buyer, uint token_id, string memory _uri, string memory report_uri)public payable{
        require(_buyer == properties[token_id].prospective_buyer, "You are not the buyer!");
        require(properties[token_id].status == STATE.forSale, "Property not for sale");
        require(keccak256(abi.encodePacked(properties[token_id].uri)) == keccak256(abi.encodePacked(_uri)), "Address doesn't match");
        require(start_date <= start_date + deposit_deadline);
        require(msg.value == (asking_price * deposit_basis_points)/10000, 'deposit must be exactly {deposit_basis_points} percent');

        require(ierc20.balanceOf(msg.sender) > 0,"Not Sufficient Balance");
        ierc20.transferfrom(msg.sender,properties[token_id].current_owner,asking_price);
        
        deposit_value = msg.value;
        properties[token_id].status = STATE.pending;

        emit Status(properties[token_id].status, report_uri);

    }
    // @params _appraiser Wallet address for third party that report on appraisal decision, _appraiser_pass Only reports true or false/if the sale should continue, token_id Property/Token identifier
    function appraisal(address _appraiser, bool _appraisal_pass, uint token_id) public returns(bool){
        require(msg.sender != properties[token_id].prospective_buyer || msg.sender != properties[token_id].current_owner || msg.sender != inspector, "you don't have permission");
        appraiser = _appraiser;
        appraisal_pass = _appraisal_pass;
        return appraisal_pass;
    }
    // @params _inspector Wallet address for third party that report on inspection decision, _inspection_pass Only reports true or false/if the sale should continue, token_id Property/Token identifier
    function inspection(address _inspector, bool _inspection_pass, uint token_id) public returns(bool){
        require(msg.sender != properties[token_id].prospective_buyer || msg.sender != properties[token_id].current_owner || msg.sender != appraiser, "you don't have permission");
        inspector = _inspector;
        inspection_pass = _inspection_pass;
        return inspection_pass;
    }
    // @dev this function allows buyer to take out their deposit, ONLY if inspection or appraisal decision are returned false
    // @params token_id Identifier for property/token
    function returnDeposit(uint token_id) public {
        require(properties[token_id].status != STATE.sold, "property is sold already");
        if (appraisal_pass == false || inspection_pass == false){
            properties[token_id].prospective_buyer.transfer(deposit_value);
        payable(properties[token_id].prospective_buyer);
        }
    }
    // @dev payable function with multiple requirement the ensure stipulations have been taken care of and balance is paid in full
    // @params token_id takes token_id and makes checks on the state of the sale in addition, updates the token to include current status of token
    function askingPrice_balance(uint token_id, string memory report_uri) public payable {
        require(properties[token_id].status != STATE.pending, "Sale is not Pending!");
        require(appraisal_pass == true && inspection_pass == true);
        require(start_date == start_date + closing_date_deadline);
        require(msg.value == asking_price - deposit_value, 'amount must be sale price minus deposit');
        total_amount = msg.value + deposit_value;
        properties[token_id].current_owner.transfer(total_amount);
        transferOwnership(properties[token_id].prospective_buyer);//add transfer token ownership
        properties[token_id].status = STATE.sold;
        properties[token_id].last_price = total_amount;
        properties[token_id].current_owner = properties[token_id].prospective_buyer;
        payable(properties[token_id].prospective_buyer);

        emit NewOwner(properties[token_id].status, properties[token_id].current_owner, properties[token_id].last_price, report_uri);

    }


}

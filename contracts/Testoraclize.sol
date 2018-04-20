pragma solidity 0.4.21;

import "../ethereum-api/oraclizeAPI_0.5.sol";
import "../solidity-stringutils/src/strings.sol";
import "zeppelin-solidity/contracts/lifecycle/Destructible.sol";


contract Testoraclize is usingOraclize, Destructible {

    using strings for *;

    OraclizeAddrResolverI OAR = OraclizeAddrResolverI(0x6f485C8BF6fc43eA212E93BBF8ce046C7f1cb475);

    struct Request {
        uint id;
        address owner;
        string country;
        string city;
        string location;
        uint goal;
        uint value;
        address executor;
        uint when;
        bool active;
    }

    mapping(uint => Request) public requests;
    mapping(bytes32 => Request) public queryIds;

    string private url = "https://api.openaq.org/v1/latest";
    string private co = "co";
    string private path = ".results.0.measurements.0.value";
    string private query = "";
    uint private unique = 0;

    function getRequest(uint id) public view
        returns (string country, string city, string location, uint goal, uint price) {
        return (requests[id].country, requests[id].city,
            requests[id].location, requests[id].goal, requests[id].value);
    }

    function createRequest(string country, string city, string location, uint goal) public payable returns (uint) {

        requests[unique] = Request({
            id : unique,
            owner : msg.sender,
            value : msg.value,
            country : country,
            city : city,
            location : location,
            goal : goal,
            active : false,
            when: 0,
            executor: address(0)
        });

        unique++;

        return unique - 1;
    }

    function applyRequest(uint requestId, uint timestamp) public payable {
        // require(block.timestamp + 1 days < timestamp);
        // require(requests[requestId].owner != address(0));
        // require(requests[requestId].active == false);

        requests[requestId].executor = msg.sender;
        requests[requestId].value += msg.value;
        requests[requestId].active = true;
        requests[requestId].when = timestamp;

        query = "";
        query = concat(query, "json(", url);
        query = concat(query, "?country=", requests[requestId].country);
        query = concat(query, "&city=", requests[requestId].city);
        query = concat(query, "&location=", requests[requestId].location);
        query = concat(query, "&parameter=", co);
        query = concat(query, ")", path);

        bytes32 queryId = oraclize_query(requests[requestId].when, "URL", query);

        queryIds[queryId] = requests[requestId];
    }

    function __callback(bytes32 id, string result) public {
        require(msg.sender == oraclize_cbAddress());

        if (queryIds[id].goal >= parseInt(result)) {
            queryIds[id].executor.transfer(queryIds[id].value);
        } else {
            queryIds[id].owner.transfer(queryIds[id].value);
        }

        delete requests[queryIds[id].id];
        delete queryIds[id];
    }

    function concat(string part1, string part2, string part3) private pure returns (string) {
        return part1.toSlice().concat(part2.toSlice()).toSlice().concat(part3.toSlice());
    }

    // uint private value = 0;

    // function run(string country, string city, string location, uint goal) public payable returns (uint) {
    //     query = "";
    //     query = concat(query, "json(", url);
    //     query = concat(query, "?country=", country);
    //     query = concat(query, "&city=", city);
    //     query = concat(query, "&location=", location);
    //     query = concat(query, "&parameter=", parameter);
    //     query = concat(query, ")", path);

    //     bytes32 queryId = oraclize_query("URL", query);

    //     return createRequest(country, city, location, goal);
    // }

    // function __callback(bytes32 id, string result) public {
    //     require(msg.sender == oraclize_cbAddress());
    //     value = parseInt(result);
    // }

    // function getValue() public view returns (uint) {
    //     return value;
    // }
}